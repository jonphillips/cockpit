import CockpitCore
import Foundation
import JudgmentFixtureSupport

/// Read-only Gmail access. Every request is a `GET`; nothing here can mutate the mailbox.
struct GmailReadOnlyClient {
  let accessToken: String

  /// Full messages for the confirmed allowlist within the window — the body-bearing pull used by
  /// `export` once Jon has confirmed which senders are editorial.
  func messages(after: String, before: String, fromContains: [String]) async throws -> [GmailMessage] {
    let senders = fromContains.map { "from:\($0)" }.joined(separator: " ")
    let ids = try await listIDs(query: "\(Self.window(after, before)) {\(senders)}")
    var fetched: [GmailMessage] = []
    for id in ids {
      fetched.append(try await message(id: id, format: "full"))
    }
    return fetched
  }

  /// Metadata-only sender discovery: aggregates `From` across a free-text query without ever
  /// requesting a body. Used by `discover`; nothing it returns is written until Jon confirms.
  func senderCandidates(
    matching query: String, after: String, before: String, cap: Int
  ) async throws -> [SenderCandidate] {
    let ids = try await listIDs(query: "\(Self.window(after, before)) \(query)").prefix(cap)
    var counts: [String: Int] = [:]
    var samples: [String: String] = [:]
    for id in ids {
      let message = try await message(id: id, format: "metadata", metadataHeaders: ["From"])
      guard let from = message.header(named: "From") else { continue }
      let email = SenderCandidate.email(from: from)
      counts[email, default: 0] += 1
      samples[email] = from
    }
    return counts
      .map { SenderCandidate(email: $0.key, sampleFrom: samples[$0.key] ?? $0.key, count: $0.value) }
      .sorted { ($0.count, $1.email) > ($1.count, $0.email) }
  }

  /// Gmail's `after:`/`before:` operators want `YYYY/MM/DD`; the CLI takes ISO dashes, so translate.
  private static func window(_ after: String, _ before: String) -> String {
    let slash = { (date: String) in date.replacingOccurrences(of: "-", with: "/") }
    return "after:\(slash(after)) before:\(slash(before))"
  }

  private func listIDs(query: String) async throws -> [String] {
    var ids: [String] = []
    var pageToken: String?
    repeat {
      var components = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages")!
      components.queryItems = [
        URLQueryItem(name: "q", value: query),
        URLQueryItem(name: "maxResults", value: "500"),
        pageToken.map { URLQueryItem(name: "pageToken", value: $0) },
      ].compactMap { $0 }
      let page: GmailMessageList = try await get(components.url!)
      ids += page.messages?.map(\.id) ?? []
      pageToken = page.nextPageToken
    } while pageToken != nil
    return ids
  }

  private func message(id: String, format: String, metadataHeaders: [String] = []) async throws -> GmailMessage {
    var components = URLComponents(
      string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)")!
    components.queryItems = [URLQueryItem(name: "format", value: format)]
      + metadataHeaders.map { URLQueryItem(name: "metadataHeaders", value: $0) }
    return try await get(components.url!)
  }

  private func get<Response: Decodable>(_ url: URL) async throws -> Response {
    var request = URLRequest(url: url)
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    var attempt = 0
    while true {
      try await Task.sleep(nanoseconds: GmailThrottle.spacing)  // pace under the per-minute quota
      let (data, response) = try await URLSession.shared.data(for: request)
      let http = response as? HTTPURLResponse
      let status = http?.statusCode ?? -1
      if 200..<300 ~= status {
        return try JSONDecoder.gmail.decode(Response.self, from: data)
      }
      guard GmailThrottle.isRateLimited(status: status, body: data), attempt < GmailThrottle.maxRetries
      else { throw HarvestError.httpStatus(status, String(decoding: data, as: UTF8.self)) }
      let delay = GmailThrottle.backoff(attempt: attempt, retryAfter: http?.value(forHTTPHeaderField: "Retry-After"))
      fputs("gmail rate limit — backing off \(delay / 1_000_000_000)s (retry \(attempt + 1)/\(GmailThrottle.maxRetries))\n", stderr)
      try await Task.sleep(nanoseconds: delay)
      attempt += 1
    }
  }
}

/// Keeps the harvest under Gmail's per-user quota (units/minute): a fixed gap between requests, plus
/// exponential backoff-and-retry when the API reports a rate limit anyway.
enum GmailThrottle {
  static let spacing: UInt64 = 300_000_000  // 300ms ≈ 3.3 req/s; conservative headroom under quota
  static let maxRetries = 6

  static func isRateLimited(status: Int, body: Data) -> Bool {
    if status == 429 { return true }
    guard status == 403 else { return false }
    let text = String(decoding: body, as: UTF8.self)
    return text.contains("rateLimitExceeded") || text.contains("userRateLimitExceeded")
      || text.contains("Quota exceeded")
  }

  static func backoff(attempt: Int, retryAfter: String?) -> UInt64 {
    if let retryAfter, let seconds = Double(retryAfter), seconds > 0 {
      return UInt64(seconds * 1_000_000_000)
    }
    return UInt64(min(pow(2.0, Double(attempt + 1)), 32) * 1_000_000_000)  // 2,4,8,16,32,32s
  }
}

/// One discovered sender for a seed: the address, a sample raw `From` for Jon to eyeball, and how
/// many messages in the window carried it.
struct SenderCandidate {
  let email: String
  let sampleFrom: String
  let count: Int

  /// Extracts the address from a `From` header, falling back to the trimmed whole value.
  static func email(from header: String) -> String {
    if let open = header.lastIndex(of: "<"), let close = header[open...].firstIndex(of: ">") {
      return String(header[header.index(after: open)..<close]).lowercased()
    }
    return header.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }
}
