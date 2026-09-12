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
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
      let status = (response as? HTTPURLResponse)?.statusCode ?? -1
      throw HarvestError.httpStatus(status, String(decoding: data, as: UTF8.self))
    }
    return try JSONDecoder.gmail.decode(Response.self, from: data)
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
