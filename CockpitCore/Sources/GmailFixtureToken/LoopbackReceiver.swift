import Foundation
@preconcurrency import Network

/// A one-shot loopback HTTP receiver for the OAuth redirect. It binds *only* the loopback
/// interface on an OS-assigned port, accepts a single request, extracts `code`, and replies with a
/// small closable page. `@preconcurrency` keeps Network's un-`Sendable` types quiet under Swift 6.
final class LoopbackReceiver: @unchecked Sendable {
  private let listener: NWListener
  private let queue = DispatchQueue(label: "GmailFixtureToken.loopback")

  init() throws {
    let parameters = NWParameters.tcp
    parameters.requiredInterfaceType = .loopback
    parameters.allowLocalEndpointReuse = true
    listener = try NWListener(using: parameters)
  }

  /// Starts listening and returns the assigned loopback port.
  func start() async throws -> UInt16 {
    let ports = AsyncThrowingStream<UInt16, Error> { continuation in
      listener.stateUpdateHandler = { state in
        switch state {
        case .ready: continuation.yield(self.listener.port?.rawValue ?? 0); continuation.finish()
        case let .failed(error): continuation.finish(throwing: error)
        default: break
        }
      }
      listener.start(queue: queue)
    }
    for try await port in ports where port != 0 { return port }
    throw OAuthError.listenerFailed
  }

  /// Waits for the browser redirect, verifies `state`, and returns the authorization code.
  func waitForCode(expectedState: String) async throws -> String {
    defer { listener.cancel() }
    let codes = AsyncThrowingStream<String, Error> { continuation in
      listener.newConnectionHandler = { connection in
        connection.start(queue: self.queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { data, _, _, _ in
          let result = HTTPCallback.parse(data, expectedState: expectedState)
          connection.send(
            content: HTTPCallback.response(for: result),
            completion: .contentProcessed { _ in connection.cancel() })
          switch result {
          case let .code(code): continuation.yield(code); continuation.finish()
          case let .failure(error): continuation.finish(throwing: error)
          }
        }
      }
    }
    for try await code in codes { return code }
    throw OAuthError.noCode
  }
}

/// Parses the single redirect request and renders its reply. Pure, so it stays outside the
/// Network callbacks' concurrency domain.
enum HTTPCallback {
  enum CallbackResult {
    case code(String)
    case failure(Error)
  }

  static func parse(_ data: Data?, expectedState: String) -> CallbackResult {
    guard let data, let request = String(data: data, encoding: .utf8),
      let line = request.split(separator: "\r\n").first,
      let target = line.split(separator: " ").dropFirst().first,
      let query = target.split(separator: "?").dropFirst().first
    else { return .failure(OAuthError.noCode) }
    var components = URLComponents()
    components.query = String(query)
    let items = components.queryItems ?? []
    let value = { (name: String) in items.first { $0.name == name }?.value }
    if let error = value("error") { return .failure(OAuthError.authorizationDenied(error)) }
    guard value("state") == expectedState else { return .failure(OAuthError.stateMismatch) }
    guard let code = value("code") else { return .failure(OAuthError.noCode) }
    return .code(code)
  }

  static func response(for result: CallbackResult) -> Data {
    let message: String
    switch result {
    case .code: message = "Authorization complete — you can close this tab and return to the terminal."
    case .failure: message = "Authorization failed — return to the terminal for the error."
    }
    let body = "<!doctype html><meta charset=utf-8><body style=\"font:16px system-ui;padding:3rem\">\(message)</body>"
    let response = """
      HTTP/1.1 200 OK\r
      Content-Type: text/html; charset=utf-8\r
      Content-Length: \(body.utf8.count)\r
      Connection: close\r
      \r
      \(body)
      """
    return Data(response.utf8)
  }
}
