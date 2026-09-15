import Foundation
import SQLiteData

/// Deterministic Edition writes: the validated entry-state transition, the day-boundary
/// finaliser, and the ContentPiece back-write. These are the canonical writers the AI boundary
/// (`AGENTS.md`) requires — judgment proposes, this code decides and persists.
public enum EditionOperations {
  public enum Failure: Error, Equatable, Sendable {
    case missingEntry(EditionEntry.ID)
    /// An attempt to move an entry along an edge the state machine forbids (IMPLEMENTATION-CONTRACT §3).
    case illegalTransition(from: EditionEntryState, to: EditionEntryState)
  }

  /// Move one entry to `newState`, rejecting every transition the state machine forbids
  /// (IMPLEMENTATION-CONTRACT §3). The single validated write path for both the Reader-facing
  /// model and the day-boundary finaliser.
  public static func transition(
    _ id: EditionEntry.ID, to newState: EditionEntryState, in db: Database
  ) throws {
    guard let entry = try EditionEntry.find(id).fetchOne(db) else {
      throw Failure.missingEntry(id)
    }
    guard entry.entryState.canTransition(to: newState) else {
      throw Failure.illegalTransition(from: entry.entryState, to: newState)
    }
    try EditionEntry.find(id).update { $0.entryState = #bind(newState) }.execute(db)
  }

  /// Mark-Seen on Reader open is best-effort and idempotent (IMPLEMENTATION-CONTRACT §3): it
  /// advances a freshly `admitted` entry to `seen` and does nothing for an entry that is already
  /// `seen`, already resolved/dismissed/aged, or already carried. Opening a piece — including
  /// reopening an already-Seen one in the split view, where the detail's `.task` re-fires — must
  /// never surface a state-machine error, so this is the one mark path that treats a non-`admitted`
  /// entry as a no-op instead of the `seen → seen` illegal transition `transition` correctly rejects.
  public static func markSeen(_ entryID: EditionEntry.ID, in db: Database) throws {
    guard let entry = try EditionEntry.find(entryID).fetchOne(db) else { return }
    guard entry.entryState == .admitted else { return }
    try transition(entryID, to: .seen, in: db)
  }

  /// Close a still-open Edition at the day boundary, moving each non-terminal entry to `carried`
  /// or `aged` per §3:
  /// - an Essential substantive-primary entry is **never** aged — it is always carried (invariant 5);
  /// - any other entry that has already been carried `carryoverBudget` times is `aged`;
  /// - everything else non-terminal is `carried`, ready to re-admit to the next Edition.
  static func finalize(_ edition: Edition, in db: Database) throws {
    guard edition.state != .closed else { return }
    let essentialPieceIDs = try essentialSubstantivePrimaryPieceIDs(in: db)
    let entries = try EditionEntry.where { $0.editionID.eq(edition.id) }.fetchAll(db)
    for entry in entries where entry.entryState == .admitted || entry.entryState == .seen {
      let isEssentialProtected = essentialPieceIDs.contains(entry.contentPieceID)
      let next: EditionEntryState =
        if isEssentialProtected {
          .carried
        } else if entry.timesCarried >= EditionPolicy.carryoverBudget {
          .aged
        } else {
          .carried
        }
      try transition(entry.id, to: next, in: db)
    }
    try Edition.find(edition.id).update { $0.state = #bind(EditionState.closed) }.execute(db)
  }

  /// Save for Later (EDITION-EXPERIENCE §3, IMPLEMENTATION-CONTRACT §4): resolves the Edition
  /// relationship and records the explicit deferred-attention membership in the same write, so an
  /// illegal transition (an already-terminal entry) rolls back before the membership is ever
  /// written. The Reader-facing model's single entry point for this action (M2 S4).
  public static func saveForLater(_ entryID: EditionEntry.ID, at date: Date, in db: Database) throws {
    guard let entry = try EditionEntry.find(entryID).fetchOne(db) else {
      throw Failure.missingEntry(entryID)
    }
    try transition(entryID, to: .resolved, in: db)
    try DestinationOperations.saveForLater(entry.contentPieceID, at: date, in: db)
  }

  /// Add to Library is orthogonal to Edition state (IMPLEMENTATION-CONTRACT §3–4): it writes the
  /// membership and never touches `entryState` (M2 S4).
  public static func addToLibrary(_ entryID: EditionEntry.ID, at date: Date, in db: Database) throws {
    guard let entry = try EditionEntry.find(entryID).fetchOne(db) else {
      throw Failure.missingEntry(entryID)
    }
    try DestinationOperations.addToLibrary(entry.contentPieceID, at: date, in: db)
  }

  /// `isSubstantivePrimary` is inspectable and correctable from the Reader
  /// (IMPLEMENTATION-CONTRACT §1): a deterministic, explicit user correction, never model output
  /// (the AI boundary — judgment proposes, this code decides and persists) (M2 S4).
  public static func correctIsSubstantivePrimary(
    _ entryID: EditionEntry.ID, to value: Bool, in db: Database
  ) throws {
    guard let entry = try EditionEntry.find(entryID).fetchOne(db) else {
      throw Failure.missingEntry(entryID)
    }
    try ContentPiece.find(entry.contentPieceID).update {
      $0.isSubstantivePrimary = #bind(value)
    }.execute(db)
  }

  /// The Stream a ContentPiece arrived through, if any — the lookup contextual Stream Handling
  /// access from the Reader needs (EDITION-EXPERIENCE §6; DECISIONS §7). A piece may have more than
  /// one Artifact (invariant 1); the first with a Stream wins, matching how Essential eligibility
  /// is already read from the same table.
  public static func streamID(for contentPieceID: ContentPiece.ID, in db: Database) throws -> Stream.ID? {
    try Artifact
      .where { $0.contentPieceID.eq(contentPieceID) && $0.streamID.isNot(nil) }
      .select(\.streamID)
      .fetchOne(db) ?? nil
  }

  /// Write the judgment pass's per-piece classification back onto the ContentPiece: `subjects`
  /// (as a JSON array string), `summary`, and `isSubstantivePrimary`. Done for every classified
  /// piece whether or not it was admitted, so quiet material stays searchable (JUDGMENT-CONTRACT §3).
  static func applyClassification(_ outcome: JudgmentOutcome, in db: Database) throws {
    guard outcome.errorDescription == nil else { return }
    let subjectsJSON = encodeSubjects(outcome.subjects)
    let currentCompleteness = try ContentPiece.find(outcome.contentPieceID)
      .select(\.bodyCompleteness).fetchOne(db) ?? nil
    let completeness = currentCompleteness ?? outcome.bodyCompleteness
    try ContentPiece.find(outcome.contentPieceID).update {
      $0.subjects = #bind(subjectsJSON)
      $0.summary = #bind(outcome.summary)
      $0.isSubstantivePrimary = #bind(outcome.isSubstantivePrimary)
      $0.bodyCompleteness = #bind(completeness)
    }.execute(db)
  }

  /// The set of ContentPieces carried by at least one Essential Stream. This is a **stream-level**
  /// fact, independent of judgment, so a brand-new piece is known to be Essential-eligible before
  /// it has ever been classified. Substantive-primary is the other half of the trigger and is
  /// applied where the classification is available (IMPLEMENTATION-CONTRACT §1, §3).
  static func essentialStreamPieceIDs(in db: Database) throws -> Set<ContentPiece.ID> {
    let essentialStreamIDs = try Stream.where { $0.isEssential }.select(\.id).fetchAll(db)
    guard !essentialStreamIDs.isEmpty else { return [] }
    let essentialStreamIDsOptional = essentialStreamIDs.map { $0 as Stream.ID? }
    let pieceIDs = try Artifact
      .where { $0.streamID.in(essentialStreamIDsOptional) }
      .select(\.contentPieceID)
      .fetchAll(db)
      .compactMap { $0 }
    return Set(pieceIDs)
  }

  /// The set of ContentPieces that are **substantive-primary material from an Essential Stream** —
  /// the exact trigger of the Essential guarantee (IMPLEMENTATION-CONTRACT §1, §3). Read at the day
  /// boundary, when every carried piece has already been classified, so its stored
  /// `isSubstantivePrimary` is trustworthy.
  static func essentialSubstantivePrimaryPieceIDs(in db: Database) throws -> Set<ContentPiece.ID> {
    let fromEssential = try essentialStreamPieceIDs(in: db)
    guard !fromEssential.isEmpty else { return [] }
    let substantivePrimary = try ContentPiece
      .where { $0.id.in(Array(fromEssential)) && $0.isSubstantivePrimary.eq(true) }
      .select(\.id)
      .fetchAll(db)
    return Set(substantivePrimary)
  }

  /// Encode subjects as a JSON array string for `ContentPiece.subjects`
  /// (IMPLEMENTATION-CONTRACT §1). `nil`/empty subjects clear the column.
  static func encodeSubjects(_ subjects: [String]?) -> String? {
    guard let subjects, !subjects.isEmpty else { return nil }
    guard let data = try? JSONEncoder().encode(subjects) else { return nil }
    return String(data: data, encoding: .utf8)
  }
}
