import Foundation
import SQLiteData

/// The local resolution marker for a Gmail-backed Today concern. It records only Cockpit's
/// attention decision; Gmail's Inbox membership and any provider disposition remain untouched.
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
}
