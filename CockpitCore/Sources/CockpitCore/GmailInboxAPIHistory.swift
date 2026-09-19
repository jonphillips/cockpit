import Foundation

/// Decodes Gmail's `history.list` response for S6 delta sync. Every change kind that can surface a
/// message id is flattened here; the API layer then reads those messages and filters to Primary, and
/// the ingestor derives identity per message, so duplicate ids across change kinds are harmless.
struct GmailHistoryList: Decodable {
  let history: [GmailHistory]?
  let nextPageToken: String?

  var messageIDs: [String] {
    (history ?? []).flatMap(\.messageIDs)
  }
}

struct GmailHistory: Decodable {
  struct Change: Decodable { let message: GmailMessageReference }

  let messages: [GmailMessageReference]?
  let messagesAdded: [Change]?
  let labelsAdded: [Change]?
  let labelsRemoved: [Change]?

  var messageIDs: [String] {
    (messages ?? []).map(\.id) + [messagesAdded, labelsAdded, labelsRemoved]
      .compactMap { $0 }
      .flatMap { $0.map(\.message.id) }
  }
}
