import Foundation
import SQLiteData

/// The local resolution marker for a Gmail-backed Today concern. It records the reason a concern is
/// no longer live on Today: either a user's explicit `Clear`, or reconciliation clearing a message
/// that left the Inbox in Gmail *on its own* — archived/trashed directly in Gmail, not through
/// Cockpit (ADR-0002 D9). A Cockpit-initiated Archive/Trash is deliberately *not* recorded here; that
/// departure is tracked reversibly in the disposition log so Undo can restore the row. The marker is
/// terminal (nothing un-clears it), which is why reconciliation must stay external-only. Recording a
/// clear performs no provider mutation and leaves Library/Later custody untouched.
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

  /// Clears every Today concern whose Gmail message has left the Primary Inbox *externally* — archived
  /// or trashed directly in Gmail, not through Cockpit. This is the write half of the delta-sync
  /// reconciliation (see `GmailInboxAPI.departedChangedIDs`), so the surface reflects the provider
  /// instead of growing without bound. Provider ids that were never ingested, or are not Gmail-backed,
  /// are skipped. Idempotent — it records the same durable clear a user `Clear` would, and never
  /// mutates Gmail.
  ///
  /// A departure Cockpit *itself* caused (an Archive/Trash still un-reversed in the disposition log) is
  /// deliberately skipped: that row is already hidden from Today by `TodayRequest` and, crucially, is
  /// still reversible. Writing the terminal attention marker for it would shadow that — a later Undo
  /// re-adds the message in Gmail and clears the log entry, but nothing un-clears an attention marker,
  /// so the row would be stranded off Today forever (ADR-0002 D9). Reconciliation is therefore the
  /// strict complement of Cockpit-initiated disposition, not an overlap.
  public static func clearDeparted(providerIDs: [String], at date: Date, in db: Database) throws {
    let cockpitDisposedProviderIDs = Set(
      try GmailDispositionLogEntry.where { $0.reversedAt.is(nil) }.fetchAll(db).map(\.providerID))
    for providerID in Set(providerIDs) where !cockpitDisposedProviderIDs.contains(providerID) {
      guard let artifact = try Artifact.where({
        $0.transport.eq(StreamTransport.gmail) && $0.providerID.eq(providerID)
      }).fetchOne(db), let contentPieceID = artifact.contentPieceID else { continue }
      try TodayAttention.insert {
        TodayAttention.Draft(contentPieceID: contentPieceID, clearedAt: date)
      } onConflictDoUpdate: { _ in }.execute(db)
    }
  }
}
