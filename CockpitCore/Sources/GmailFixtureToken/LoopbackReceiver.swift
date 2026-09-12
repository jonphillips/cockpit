import Foundation

/// A one-shot loopback HTTP receiver for the OAuth redirect, on a raw BSD socket bound to
/// 127.0.0.1 on an OS-assigned port. `NWListener` refuses to bind in this toolchain (EINVAL on
/// every parameterisation), and a POSIX socket is both reliable and unambiguously loopback-only.
final class LoopbackReceiver: Sendable {
  let port: UInt16
  private let descriptor: Int32

  init() throws {
    let fd = socket(AF_INET, SOCK_STREAM, 0)
    guard fd >= 0 else { throw OAuthError.listenerFailed }
    var reuse: Int32 = 1
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
    var address = sockaddr_in()
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = 0  // ephemeral
    address.sin_addr.s_addr = inet_addr("127.0.0.1")  // loopback only
    let bound = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }
    guard bound == 0, listen(fd, 1) == 0 else { close(fd); throw OAuthError.listenerFailed }
    var assigned = sockaddr_in()
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    _ = withUnsafeMutablePointer(to: &assigned) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &length) }
    }
    descriptor = fd
    port = UInt16(bigEndian: assigned.sin_port)
  }

  /// Blocks on a background thread for the single redirect, verifies `state`, and returns `code`.
  func waitForCode(expectedState: String) async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.global().async {
        continuation.resume(with: Result { try self.acceptOnce(expectedState: expectedState) })
      }
    }
  }

  private func acceptOnce(expectedState: String) throws -> String {
    defer { close(descriptor) }
    let client = accept(descriptor, nil, nil)
    guard client >= 0 else { throw OAuthError.listenerFailed }
    defer { close(client) }
    var buffer = [UInt8](repeating: 0, count: 16_384)
    let count = read(client, &buffer, buffer.count)
    let data = count > 0 ? Data(buffer.prefix(count)) : nil
    let result = HTTPCallback.parse(data, expectedState: expectedState)
    let response = HTTPCallback.response(for: result)
    _ = response.withUnsafeBytes { write(client, $0.baseAddress, $0.count) }
    switch result {
    case let .code(code): return code
    case let .failure(error): throw error
    }
  }
}

/// Parses the single redirect request and renders its reply.
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
