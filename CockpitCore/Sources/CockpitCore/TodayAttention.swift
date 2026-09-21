import Foundation
import SQLiteData

/// The local resolution marker for a Gmail-backed Today concern. It records the reason a concern is
/// no longer live on Today: either a user's explicit `Clear`, or reconciliation clearing a message
/// that left the Inbox in Gmail (archived/trashed there). Recording a clear performs no provider
/// mutation and leaves Library/Later custody untouched.
@Table("todayAttentions")
public struct TodayAttention: Equatable, Identifiable, Sendable {
  @Column(primaryKey: true) public let contentPieceID: ContentPiece.ID
  public let clearedAt: Date

  public var id: ContentPiece.ID { contentPieceID }

  public init(contentPieceID: ContentPiece.ID, clearedAt: Date) {
    self.contentPieceID = contentPieceID
    self.clearedAt = clearedAt
  }
}

/// Deterministic, Cockpit-local Today resolution. The API intentionally has no provider client:
/// provider mutation begins only after Gate 3 and an explicit authorized disposition policy.
public enum TodayAttentionOperations {
  public enum Failure: Error, Equatable, Sendable {
    case notGmailContentPiece
  }

  public static func clear(_ id: ContentPiece.ID, at date: Date, in db: Database) throws {
    guard try ContentPiece.find(id).fetchOne(db)?.kind == .email,
      try Artifact.where({
        $0.contentPieceID.eq(id) && $0.transport.eq(StreamTransport.gmail)
      }).fetchOne(db) != nil
    else { throw Failure.notGmailContentPiece }

    try TodayAttention.insert {
      TodayAttention.Draft(contentPieceID: id, clearedAt: date)
    } onConflictDoUpdate: { _ in
      // The first explicit resolution is the durable explanation; repeating Clear is idempotent.
    }.execute(db)
  }

  /// Clears every Today concern whose Gmail message has left the Primary Inbox in Gmail. This is the
  /// write half of the delta-sync reconciliation (see `GmailInboxAPI.departedChangedIDs`): a message
  /// archived or trashed directly in Gmail stops appearing on Today. Provider ids that were never
  /// ingested, or are not Gmail-backed, are skipped. Idempotent — it records the same durable clear a
  /// user `Clear` would, and never mutates Gmail.
  public static func clearDeparted(providerIDs: [String], at date: Date, in db: Database) throws {
    for providerID in Set(providerIDs) {
      guard let artifact = try Artifact.where({
        $0.transport.eq(StreamTransport.gmail) && $0.providerID.eq(providerID)
      }).fetchOne(db), let contentPieceID = artifact.contentPieceID else { continue }
      try TodayAttention.insert {
        TodayAttention.Draft(contentPieceID: contentPieceID, clearedAt: date)
      } onConflictDoUpdate: { _ in }.execute(db)
    }
  }
}
