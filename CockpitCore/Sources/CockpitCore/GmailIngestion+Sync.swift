import Foundation

extension GmailInboxIngestor {
  static func fetchSnapshot(
    using client: GmailInboxClient, cursor: GmailSyncState?, startedAt: Date
  ) async throws -> GmailInboxSnapshot {
    guard let cursor else { return try await client.currentInbox() }
    return try await client.inboxChanges(
      cursor.accountID, cursor.historyID, cursor.promotionsSince ?? startedAt)
  }
}
