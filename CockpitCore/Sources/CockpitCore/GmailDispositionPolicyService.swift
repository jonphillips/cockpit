import Dependencies
import Foundation
import SQLiteData

/// Applies established disposition policies. It does not itself decide anything destructive: it Trashes
/// only messages an *enabled* policy matches, and it does so through the very same
/// `GmailDispositionService` a per-action Trash uses — so every policy disposition passes the barrier,
/// is logged, and is reversible (ADR-0002 D4/D6/D7). With no policy enabled it disposes nothing, which
/// is what keeps "AI classifies and proposes" from ever becoming "AI authorizes" (§8).
public struct GmailDispositionPolicyService: Sendable {
  private let disposition: GmailDispositionService

  public init(client: GmailDispositionClient, now: @escaping @Sendable () -> Date = Date.init) {
    self.disposition = GmailDispositionService(client: client, now: now)
  }

  /// Trashes every message an enabled policy matches (barrier-satisfied, once per message). Returns the
  /// log entries it created. A caller runs this after a sync/classification pass; it is idempotent, so
  /// re-running it does not re-Trash or duplicate log entries.
  @discardableResult
  public func applyEnabledPolicies(in database: any DatabaseWriter) async throws -> [GmailDispositionLogEntry] {
    let pieceIDs = try await database.read { db in
      try GmailDispositionPolicyOperations.matchingPieceIDs(in: db)
    }
    var applied: [GmailDispositionLogEntry] = []
    for id in pieceIDs {
      // Each disposition re-runs the per-message barrier inside `apply`; a piece that cannot be
      // verified is simply skipped, never Trashed.
      if let entry = try await disposition.apply(.trash, toContentPieceID: id, in: database) {
        applied.append(entry)
      }
    }
    return applied
  }

  /// Applies an enabled policy to one specific piece after an explicit Reader action. It reuses
  /// policy matching (including the Find barrier and once-per-message guard) and then the existing
  /// disposition service (including its commit barrier and Undo log).
  @discardableResult
  public func applyEnabledPolicies(
    forContentPieceID id: ContentPiece.ID, in database: any DatabaseWriter
  ) async throws -> [GmailDispositionLogEntry] {
    let matches = try await database.read { db in
      try GmailDispositionPolicyOperations.matchingPieceIDs(in: db).contains(id)
    }
    guard matches, let entry = try await disposition.apply(.trash, toContentPieceID: id, in: database)
    else { return [] }
    return [entry]
  }
}
