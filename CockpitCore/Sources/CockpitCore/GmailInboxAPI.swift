import Foundation

/// The transport is intentionally isolated from persistence: every request is an authenticated
/// Gmail GET, and `GmailInboxIngestor` owns the resulting canonical writes.
struct GmailInboxAPI {
  let accessToken: String

  /// Gmail bills each `messages.get` at 5 quota units against a ~250 unit/user/second ceiling.
  /// Fetching every Inbox message at once trips HTTP 429, so per-message reads run through a
  /// bounded window rather than an unbounded fan-out.
  private static let maxConcurrentMessageReads = 6

  func currentInbox() async throws -> GmailInboxSnapshot {
    async let profile: GmailProfile = get(path: "profile")
    let listed = try await listMessages()
    let messages = try await fetchMessages(ids: listed.ids)
    let resolvedProfile = try await profile
    return GmailInboxSnapshot(
      accountID: resolvedProfile.emailAddress, historyID: resolvedProfile.historyID,
      pageCount: listed.pageCount, messages: messages
    )
  }

  /// Reads each message with at most `maxConcurrentMessageReads` requests in flight, refilling the
  /// window as each completes. Order is not preserved; ingestion derives identity per message.
  private func fetchMessages(ids: [String]) async throws -> [GmailInboxMessage] {
    var messages: [GmailInboxMessage] = []
    messages.reserveCapacity(ids.count)
    try await withThrowingTaskGroup(of: GmailInboxMessage.self) { group in
      var iterator = ids.makeIterator()
      for _ in 0..<Self.maxConcurrentMessageReads {
        guard let id = iterator.next() else { break }
        group.addTask { try await message(id: id) }
      }
      while let fetched = try await group.next() {
        messages.append(fetched)
        if let id = iterator.next() {
          group.addTask { try await message(id: id) }
        }
      }
    }
    return messages
  }

  /// A viability probe reads the Primary tab only, bounded, not the whole mailbox. Gmail's category
  /// tabs (Primary/Promotions/Social/…) all carry the `INBOX` label, so `labelIds=INBOX` alone pulls
  /// every promotional message too; a large Promotions backlog then trips `userRateLimitExceeded`
  /// (each `messages.get` bills 5 quota units against a per-minute per-user ceiling).
  ///
  /// The Primary tab is "INBOX minus the other categories", and Gmail does not stamp
  /// `CATEGORY_PERSONAL` on every Primary message (newsletters and other uncategorized mail carry no
  /// category label at all), so filtering by that label under-reads. The `category:primary` search
  /// operator resolves to the tab as the user sees it. Primary is the attention surface S4 needs; the
  /// other categories are in scope for later stages (promo sifting, retail/wine Finds) but their
  /// read/quota/delta strategy is a Gate-3 ADR decision, not S4's — see docs/m4-s4-gmail-observations.md.
  private static let maxMessagesToRead = 100

  private func listMessages() async throws -> (ids: [String], pageCount: Int) {
    let query = [
      URLQueryItem(name: "labelIds", value: "INBOX"),
      URLQueryItem(name: "q", value: "category:primary"),
      URLQueryItem(name: "maxResults", value: String(Self.maxMessagesToRead)),
    ]
    let page: GmailMessageList = try await get(path: "messages", query: query)
    let ids = Array((page.messages?.map(\.id) ?? []).prefix(Self.maxMessagesToRead))
    return (ids, 1)
  }

  private func message(id: String) async throws -> GmailInboxMessage {
    let response: GmailMessageResponse = try await get(
      path: "messages/\(id)", query: [URLQueryItem(name: "format", value: "full")]
    )
    return GmailInboxMessage(
      id: response.id, threadID: response.threadID, headers: response.payload.headers,
      bodyHTML: response.payload.text(matching: "text/html"),
      bodyPlainText: response.payload.text(matching: "text/plain")
    )
  }

  private func get<Response: Decodable>(path: String, query: [URLQueryItem] = []) async throws -> Response {
    var components = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/\(path)")!
    components.queryItems = query
    var request = URLRequest(url: components.url!)
    request.httpMethod = "GET"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    for attempt in 0...Self.maxRetries {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let http = response as? HTTPURLResponse else { throw GmailInboxError.noResponse }
      if 200..<300 ~= http.statusCode {
        return try JSONDecoder().decode(Response.self, from: data)
      }
      let failure = GmailInboxError(status: http.statusCode, body: data)
      guard failure.isRetryable, attempt < Self.maxRetries else { throw failure }
      try await Task.sleep(for: Self.retryDelay(response: http, attempt: attempt))
    }
    throw GmailInboxError.noResponse
  }

  private static let maxRetries = 4

  /// Honors a `Retry-After` header (seconds) when present, otherwise backs off exponentially.
  private static func retryDelay(response: HTTPURLResponse, attempt: Int) -> Duration {
    if let value = response.value(forHTTPHeaderField: "Retry-After"), let seconds = Int(value) {
      return .seconds(seconds)
    }
    return .seconds(Double(1 << attempt))
  }
}

private struct GmailProfile: Decodable {
  let emailAddress: String
  let historyID: String?
  enum CodingKeys: String, CodingKey { case emailAddress; case historyID = "historyId" }
}
private struct GmailMessageList: Decodable { let messages: [GmailMessageReference]?; let nextPageToken: String? }
private struct GmailMessageReference: Decodable { let id: String }
private struct GmailMessageResponse: Decodable {
  let id: String
  let threadID: String
  let payload: GmailPayload
  enum CodingKeys: String, CodingKey { case id; case threadID = "threadId"; case payload }
}
private struct GmailPayload: Decodable {
  let mimeType: String?
  let headers: [GmailInboxHeader]
  let body: GmailBody?
  let parts: [GmailPayload]?

  func text(matching expectedMIMEType: String) -> String? {
    if mimeType?.caseInsensitiveCompare(expectedMIMEType) == .orderedSame,
      let encoded = body?.data, let data = Data(base64URLEncoded: encoded),
      let text = String(data: data, encoding: .utf8), !text.isEmpty { return text }
    return parts?.lazy.compactMap { $0.text(matching: expectedMIMEType) }.first
  }
}
private struct GmailBody: Decodable { let data: String? }

/// Preserves the Gmail error body so a 403 rate-limit (`usageLimits`) is retried and distinguished
/// from a configuration/scope 403, and so the surfaced message names the real reason.
private struct GmailInboxError: LocalizedError {
  let status: Int
  let reason: String?
  let message: String?

  init(status: Int, reason: String?, message: String?) {
    self.status = status
    self.reason = reason
    self.message = message
  }

  init(status: Int, body: Data) {
    let decoded = try? JSONDecoder().decode(GmailAPIErrorEnvelope.self, from: body)
    self.init(status: status, reason: decoded?.error.errors?.first?.reason, message: decoded?.error.message)
  }

  static let noResponse = GmailInboxError(status: -1, reason: nil, message: "Gmail returned no HTTP response.")

  /// Gmail signals per-user throttling as 429, 503, or a 403 in the `usageLimits` domain.
  var isRetryable: Bool {
    switch status {
    case 429, 503: return true
    case 403: return reason == "rateLimitExceeded" || reason == "userRateLimitExceeded"
    default: return false
    }
  }

  var errorDescription: String? {
    let detail = [reason, message].compactMap { $0?.trimmedNonEmpty }.joined(separator: " — ")
    return detail.isEmpty ? "Gmail returned HTTP \(status)." : "Gmail returned HTTP \(status): \(detail)"
  }
}

private struct GmailAPIErrorEnvelope: Decodable {
  struct APIError: Decodable {
    struct Item: Decodable { let reason: String? }
    let message: String?
    let errors: [Item]?
  }
  let error: APIError
}

private extension Data {
  init?(base64URLEncoded value: String) {
    let padding = String(repeating: "=", count: (4 - value.count % 4) % 4)
    self.init(base64Encoded: value.replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/") + padding)
  }
}
