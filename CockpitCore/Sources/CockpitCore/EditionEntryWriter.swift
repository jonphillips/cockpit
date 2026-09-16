import Dependencies
import Foundation
import SQLiteData
import os

private let compositionLog = Logger(
  subsystem: "com.jonphillips.cockpit", category: "edition-composition")

/// Turns a plan plus the judgment outcomes into the Edition's entries and the ContentPiece
/// classifications, deterministically. Judgment proposes; this decides: it enforces the Essential
/// guarantee, carryover, and the backlog relief valve, never the model (IMPLEMENTATION-CONTRACT §3).
struct EditionEntryWriter: Sendable {
  @Dependency(\.uuid) private var uuid

  func write(
    editionID: Edition.ID,
    plan: EditionPlan,
    outcomesByID: [ContentPiece.ID: JudgmentOutcome],
    in db: Database
  ) throws {
    for (pieceID, context) in plan.contexts {
      let outcome = outcomesByID[pieceID]
      let hasError = outcome?.errorDescription != nil

      // Fail-closed: a per-piece decode/contract error (S2) is never admitted and never crashes the
      // composition. Log it so a silently-quiet piece is explainable (JUDGMENT-CONTRACT §3).
      if hasError {
        compositionLog.error(
          "Fail-closed piece \(pieceID.uuidString, privacy: .public): \(outcome?.errorDescription ?? "unknown", privacy: .public)")
      }
      if let outcome, !hasError {
        try EditionOperations.applyClassification(outcome, in: db)
        try PendingFindOperations.persist(outcome.finds, for: pieceID, in: db)
      }

      // Essential protection is stream-level Essential + substantive-primary. Read the flag back
      // after the classification write, so it reflects a fresh judgment when there was one and the
      // stored value (from an earlier composition) when this pass failed closed.
      let substantive =
        (try ContentPiece.find(pieceID).select(\.isSubstantivePrimary).fetchOne(db)) ?? nil
      let isEssentialProtected = context.isFromEssentialStream && (substantive == true)
      let fresh = hasError ? nil : outcome

      if let carried = context.carried {
        try writeCarried(
          editionID: editionID, pieceID: pieceID, isEssentialProtected: isEssentialProtected,
          carried: carried, outcome: fresh, in: db)
      } else {
        try writeNew(
          editionID: editionID, pieceID: pieceID, isEssentialProtected: isEssentialProtected,
          outcome: fresh, in: db)
      }
    }
  }

  /// Carryover is a deterministic guarantee, not a re-decision: a carried piece always gets a
  /// successor entry (until the budget ages it at a boundary or the user resolves it). A fresh valid
  /// judgment refreshes its presentation; a fail-closed one keeps the predecessor's.
  private func writeCarried(
    editionID: Edition.ID,
    pieceID: ContentPiece.ID,
    isEssentialProtected: Bool,
    carried: EditionCarriedPredecessor,
    outcome: JudgmentOutcome?,
    in db: Database
  ) throws {
    let timesCarried = carried.timesCarried + 1
    let admitted = outcome?.admit == true
    let section = section(
      isEssentialProtected: isEssentialProtected, timesCarried: timesCarried,
      proposed: admitted ? outcome?.section : nil, fallback: carried.section)
    try EditionEntry.insert {
      EditionEntry.Draft(
        EditionEntry(
          id: uuid(), editionID: editionID, contentPieceID: pieceID, section: section,
          rank: (admitted ? outcome?.rank : nil) ?? carried.rank,
          rationale: (admitted ? outcome?.rationale : nil) ?? carried.rationale,
          matchedPersonalKnowledgeClaimID: (admitted ? outcome?.matchedPersonalKnowledgeClaimID : nil)
            ?? carried.matchedPersonalKnowledgeClaimID,
          entryState: .admitted, firstAdmittedEditionID: carried.firstAdmittedEditionID,
          timesCarried: timesCarried))
    }.execute(db)
  }

  /// A new piece becomes an entry only if admitted. Essential substantive-primary material is
  /// admitted even when the model declined it, so it can never silently fail to surface (§3); a
  /// fail-closed piece has no classification and is simply not admitted (logged, never crashed).
  private func writeNew(
    editionID: Edition.ID,
    pieceID: ContentPiece.ID,
    isEssentialProtected: Bool,
    outcome: JudgmentOutcome?,
    in db: Database
  ) throws {
    guard (outcome?.admit == true) || isEssentialProtected else { return }
    let section = section(
      isEssentialProtected: isEssentialProtected, timesCarried: 0,
      proposed: outcome?.section, fallback: .forYou)
    try EditionEntry.insert {
      EditionEntry.Draft(
        EditionEntry(
          id: uuid(), editionID: editionID, contentPieceID: pieceID, section: section,
          rank: outcome?.rank ?? 0, rationale: outcome?.rationale,
          matchedPersonalKnowledgeClaimID: outcome?.matchedPersonalKnowledgeClaimID,
          entryState: .admitted,
          firstAdmittedEditionID: editionID, timesCarried: 0))
    }.execute(db)
  }

  /// Resolve an entry's section, enforcing the Essential relief valve: a protected entry carried
  /// more than `essentialBacklogRelief` times moves to `essentialBacklog`; otherwise a protected
  /// entry sits in `essentials`; otherwise the model's proposed section (or a fallback) stands (§3).
  private func section(
    isEssentialProtected: Bool, timesCarried: Int,
    proposed: JudgmentSection?, fallback: JudgmentSection
  ) -> JudgmentSection {
    guard isEssentialProtected else { return proposed ?? fallback }
    return timesCarried > EditionPolicy.essentialBacklogRelief ? .essentialBacklog : .essentials
  }
}
