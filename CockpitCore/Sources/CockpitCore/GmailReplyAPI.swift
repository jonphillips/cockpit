import Foundation

/// Live Gmail API calls for the narrow Reader reply feature.
struct GmailReplyAPI {
  let accessToken: String

  func replyHeaders(messageID: String) async throws -> GmailReplyHeaders {
    let requested = ["From", "Reply-To", "Subject", "Message-ID", "References"]
    let query = [URLQueryItem(name: "format", value: "metadata")] + requested.map {
      URLQueryItem(name: "metadataHeaders", value: $0)
    }
    var components = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(messageID)")!
    components.queryItems = query
    var request = URLRequest(url: components.url!)
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    let data = try await read(request)
    let message = try JSONDecoder().decode(GmailReplyMetadata.self, from: data)
    let values = Dictionary(message.payload.headers.map { ($0.name.lowercased(), $0.value) }, uniquingKeysWith: { first, _ in first })
    guard let from = values["from"], let subject = values["subject"], let messageID = values["message-id"] else {
      throw GmailReplyAPIError.missingHeaders
    }
    return GmailReplyHeaders(
      from: from, replyTo: values["reply-to"], subject: subject, messageID: messageID,
      references: values["references"]
    )
  }

  /// This endpoint is never retried: an ambiguous HTTP failure must not risk a duplicate reply.
  func send(raw: String, threadID: String) async throws {
    let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/send")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let encodedRaw = Data(raw.utf8).base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
    request.httpBody = try JSONSerialization.data(withJSONObject: ["raw": encodedRaw, "threadId": threadID])
    _ = try await read(request)
  }

  private func read(_ request: URLRequest) async throws -> Data {
    for attempt in 0...Self.maxRetries {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let http = response as? HTTPURLResponse else { throw GmailReplyAPIError.noResponse }
      if 200..<300 ~= http.statusCode { return data }
      let failure = GmailReplyAPIError(status: http.statusCode, body: data)
      guard request.httpMethod != "POST", failure.isRetryable, attempt < Self.maxRetries else { throw failure }
      try await Task.sleep(for: Self.retryDelay(response: http, attempt: attempt))
    }
    throw GmailReplyAPIError.noResponse
  }

  private static let maxRetries = 4

  private static func retryDelay(response: HTTPURLResponse, attempt: Int) -> Duration {
    if let value = response.value(forHTTPHeaderField: "Retry-After"), let seconds = Int(value) {
      return .seconds(seconds)
    }
    return .seconds(Double(1 << attempt))
  }
}

private struct GmailReplyMetadata: Decodable {
  struct Payload: Decodable {
    struct Header: Decodable { let name: String; let value: String }
    let headers: [Header]
  }
  let payload: Payload
}

private enum GmailReplyAPIError: LocalizedError {
  case missingHeaders
  case noResponse
  case status(Int, String?, String?)

  init(status: Int, body: Data) {
    let decoded = try? JSONDecoder().decode(GmailReplyErrorEnvelope.self, from: body)
    self = .status(status, decoded?.error.errors?.first?.reason, decoded?.error.message)
  }

  var isRetryable: Bool {
    guard case let .status(status, reason, _) = self else { return false }
    return switch status {
    case 429, 503: true
    case 403: reason == "rateLimitExceeded" || reason == "userRateLimitExceeded"
    default: false
    }
  }

  var errorDescription: String? {
    switch self {
    case .missingHeaders: return "Gmail did not return all required reply headers."
    case .noResponse: return "Gmail returned no HTTP response."
    case let .status(status, reason, message):
      let detail = [reason, message].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }.joined(separator: " — ")
      return detail.isEmpty
        ? "Gmail returned HTTP \(status)."
        : "Gmail returned HTTP \(status): \(detail)"
    }
  }

}

private struct GmailReplyErrorEnvelope: Decodable {
  struct APIError: Decodable {
    struct Item: Decodable { let reason: String? }
    let message: String?
    let errors: [Item]?
  }
  let error: APIError
}
