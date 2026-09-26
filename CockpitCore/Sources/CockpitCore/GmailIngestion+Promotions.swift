import Foundation
import SQLiteData

extension GmailInboxIngestor {
  static func fetchSnapshot(
    using client: GmailInboxClient, cursor: GmailSyncState?, startedAt: Date
  ) async throws -> GmailInboxSnapshot {
    guard let cursor else { return try await client.currentInbox() }
    if let fetch = client.inboxChangesIncludingPromotions {
      return try await fetch(cursor.accountID, cursor.historyID, cursor.promotionsSince ?? startedAt)
    }
    return try await client.inboxChanges(cursor.accountID, cursor.historyID)
  }

  static func recordArtifact(
    message: GmailInboxMessage, artifactID: UUID, providerID: String, accountID: String,
    pieceID: ContentPiece.ID, acquiredAt: Date, in db: Database
  ) throws {
    let provenance = GmailArtifactProvenance.make(accountID: accountID, message: message)
    let provenanceJSON = String(data: try JSONEncoder().encode(provenance), encoding: .utf8)
    let matchedStreamID = try GmailStreamResolver.streamID(
      for: provenance, sender: message.sender, in: db)
    if let artifact = try Artifact.where({ $0.providerID.eq(providerID) }).fetchOne(db) {
      try Artifact.find(artifact.id).update { row in
        row.providerIsUnread = #bind(message.labelIDs.contains("UNREAD"))
        row.providerProvenance = #bind(provenanceJSON)
        if artifact.streamID == nil, let matchedStreamID { row.streamID = #bind(matchedStreamID) }
      }.execute(db)
    } else {
      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: artifactID, streamID: matchedStreamID, transport: .gmail,
          providerID: providerID, acquiredAt: acquiredAt, rawSourceText: message.sourceText,
          providerProvenance: provenanceJSON, providerIsUnread: message.labelIDs.contains("UNREAD"),
          contentPieceID: pieceID))
      }.execute(db)
    }
  }
}

extension GmailInboxIngestor {
  static func stableProviderID(accountID: String, messageID: String) -> String {
    "gmail:\(canonicalAccountID(accountID)):message:\(messageID)"
  }

  static func canonicalAccountID(_ accountID: String) -> String {
    accountID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }
}
