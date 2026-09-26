import Foundation

extension GmailInboxAPI {
  /// Reads current UNREAD labels without downloading bodies. Legacy mirrors are backfilled only
  /// for Gmail messages already in Today, using the normal bounded message-read window.
  func unreadStates(messageIDs: [String]) async throws -> [String: Bool] {
    try Task.checkCancellation()
    var values: [String: Bool] = [:]
    try await withThrowingTaskGroup(of: (String, Bool)?.self) { group in
      var iterator = messageIDs.makeIterator()
      for _ in 0..<Self.maxConcurrentMessageReads {
        guard let id = iterator.next() else { break }
        group.addTask { try await readUnreadState(id: id) }
      }
      while let result = try await group.next() {
        if let (id, isUnread) = result { values[id] = isUnread }
        if let nextID = iterator.next() {
          group.addTask { try await readUnreadState(id: nextID) }
        }
      }
    }
    try Task.checkCancellation()
    return values
  }

  private func readUnreadState(id: String) async throws -> (String, Bool)? {
    do {
      let response: GmailMessageMetadata = try await get(
        path: "messages/\(id)", query: [URLQueryItem(name: "format", value: "minimal")]
      )
      return (response.id, response.labelIDs.contains("UNREAD"))
    } catch let error as GmailInboxError where error.status == 404 {
      return nil
    }
  }
}

private struct GmailMessageMetadata: Decodable {
  let id: String
  let labelIDs: [String]
  enum CodingKeys: String, CodingKey { case id; case labelIDs = "labelIds" }
}
