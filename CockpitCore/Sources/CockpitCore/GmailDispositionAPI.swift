import Foundation

/// The Gmail mutation transport: the only place Cockpit issues a provider write. It is kept separate
/// from the read `GmailInboxAPI` so the read path stays read-only in intent. Every operation maps to
/// one label call in ADR-0002 D5 and is idempotent, so the shared retry/back-off is safe. This live
/// path is exercised only on device (a real label change, a real Trash purge); the barrier and Undo
/// logic that call it are model-tested against a fake `GmailDispositionClient`.
struct GmailDispositionAPI {
  let accessToken: String

  /// `messages.modify` removing `INBOX`.
  func archive(messageID: String) async throws {
    try await modify(messageID: messageID, add: [], remove: ["INBOX"])
  }

  /// `messages.modify` re-adding `INBOX` (inverse of `archive`).
  func reAddInbox(messageID: String) async throws {
    try await modify(messageID: messageID, add: ["INBOX"], remove: [])
  }

  /// `messages.trash`.
  func trash(messageID: String) async throws {
    try await send(path: "messages/\(messageID)/trash", body: nil)
  }

  /// `messages.untrash` (inverse of `trash`).
  func untrash(messageID: String) async throws {
    try await send(path: "messages/\(messageID)/untrash", body: nil)
  }

  private func modify(messageID: String, add: [String], remove: [String]) async throws {
    let body = try JSONSerialization.data(
      withJSONObject: ["addLabelIds": add, "removeLabelIds": remove])
    try await send(path: "messages/\(messageID)/modify", body: body)
  }

  private func send(path: String, body: Data?) async throws {
    let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/\(path)")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    if let body {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = body
    }

    for attempt in 0...Self.maxRetries {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let http = response as? HTTPURLResponse else { throw GmailDispositionError.noResponse }
      if 200..<300 ~= http.statusCode { return }
      let failure = GmailDispositionError(status: http.statusCode, body: data)
      guard failure.isRetryable, attempt < Self.maxRetries else { throw failure }
      try await Task.sleep(for: Self.retryDelay(response: http, attempt: attempt))
    }
    throw GmailDispositionError.noResponse
  }

  private static let maxRetries = 4

  private static func retryDelay(response: HTTPURLResponse, attempt: Int) -> Duration {
    if let value = response.value(forHTTPHeaderField: "Retry-After"), let seconds = Int(value) {
      return .seconds(seconds)
    }
    return .seconds(Double(1 << attempt))
  }
}

/// Mirrors the read path's error handling: a `usageLimits` 403 is retryable throttling, a scope/config
/// 403 is fatal, and the surfaced message names the real reason.
private struct GmailDispositionError: LocalizedError {
  let status: Int
  let reason: String?
  let message: String?

  init(status: Int, reason: String?, message: String?) {
    self.status = status
    self.reason = reason
    self.message = message
  }

  init(status: Int, body: Data) {
    let decoded = try? JSONDecoder().decode(GmailMutationErrorEnvelope.self, from: body)
    self.init(status: status, reason: decoded?.error.errors?.first?.reason, message: decoded?.error.message)
  }

  static let noResponse = GmailDispositionError(
    status: -1, reason: nil, message: "Gmail returned no HTTP response.")

  var isRetryable: Bool {
    switch status {
    case 429, 503: true
    case 403: reason == "rateLimitExceeded" || reason == "userRateLimitExceeded"
    default: false
    }
  }

  var errorDescription: String? {
    let detail = [reason, message].compactMap { $0?.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }.joined(separator: " — ")
    return detail.isEmpty ? "Gmail returned HTTP \(status)." : "Gmail returned HTTP \(status): \(detail)"
  }
}

private struct GmailMutationErrorEnvelope: Decodable {
  struct APIError: Decodable {
    struct Item: Decodable { let reason: String? }
    let message: String?
    let errors: [Item]?
  }
  let error: APIError
}
