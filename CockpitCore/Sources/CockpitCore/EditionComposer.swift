import Foundation
import SQLiteData

/// Materialises the daily Edition (ADR-0001 D5). It drives the S2 `JudgmentEngine` **once** over
/// the day's candidates and writes the Edition, its entries, and the ContentPiece classifications
/// from the same pass. A plain `Sendable` value with `async` methods so the heavy judgment call
/// runs off the main actor — the shell never blocks on composition (which took 122s on a Mac in the
/// S2 run). Planning (`EditionPlanner`) and writing (`EditionEntryWriter`) are separate types; this
/// is the three-phase orchestration that keeps the model call outside any transaction.
public struct EditionComposer: Sendable {
  public enum Result: Equatable, Sendable {
    /// Today's Edition already exists; nothing was composed (materialise-once, ADR-0001 D5).
    case alreadyComposed(Edition.ID)
    /// A new Edition was composed and opened.
    case composed(Edition.ID)
    /// No candidates for the day; no Edition row is created.
    case nothingToCompose
  }

  private let engine: JudgmentEngine
  private let planner = EditionPlanner()
  private let writer = EditionEntryWriter()
  private let targetSize: Int
  private let currentContext: String

  public init(
    engine: JudgmentEngine = JudgmentEngine(),
    targetSize: Int = EditionPolicy.defaultTargetSize,
    currentContext: String = ""
  ) {
    self.engine = engine
    self.targetSize = targetSize
    self.currentContext = currentContext
  }

  /// Compose today's Edition if it does not already exist. Three phases keep the model call outside
  /// any database transaction: finalise the prior day and gather a plan (opening a `composing` row),
  /// judge, then materialise the entries and record the cost as the Edition opens.
  @discardableResult
  public func composeIfNeeded(
    now: Date, in database: any DatabaseWriter
  ) async throws -> Result {
    let editionID = EditionDay.editionID(for: now)

    let plan = try await database.write { db -> EditionPlan? in
      if let existing = try Edition.find(editionID).fetchOne(db) {
        // A `composing` row with no open/closed state is a crash between Phase 1 and Phase 3 — the
        // model call or the entry write died. Clear the partial materialisation and re-drive rather
        // than leave the day blocked by an empty, permanently-`composing` Edition. (The prior
        // Edition was already finalised by the crashed run and is closed, so it is not re-finalised.)
        guard existing.state == .composing else { return nil }
        try EditionEntry.where { $0.editionID.eq(editionID) }.delete().execute(db)
        try Edition.find(editionID).delete().execute(db)
      }
      let previous = try Edition
        .where { $0.id.neq(editionID) }
        .order { $0.date.desc() }
        .fetchOne(db)
      if let previous, previous.state != .closed {
        try EditionOperations.finalize(previous, in: db)
      }
      let plan = try self.planner.buildPlan(
        previousEditionID: previous?.id, since: previous?.date, in: db)
      guard !plan.candidates.isEmpty else { return plan }
      try Edition.insert {
        Edition.Draft(
          Edition(
            id: editionID, date: EditionDay.start(of: now), state: .composing,
            targetSize: self.targetSize, promptVersion: JudgmentEngine.promptVersion,
            modelName: JudgmentModel.displayName))
      }.execute(db)
      return plan
    }

    guard let plan else { return .alreadyComposed(editionID) }
    guard !plan.candidates.isEmpty else { return .nothingToCompose }

    // Phase 2 (no database): the single judgment pass, off the main actor.
    let run = await engine.judge(
      candidates: plan.candidates, personalKnowledge: plan.personalKnowledge,
      currentContext: currentContext, targetSize: targetSize)

    // Phase 3 (write): back-write classifications, materialise entries, record cost, open.
    let outcomesByID = Dictionary(
      uniqueKeysWithValues: run.outcomes.map { ($0.contentPieceID, $0) })
    try await database.write { db in
      try self.writer.write(
        editionID: editionID, plan: plan, outcomesByID: outcomesByID, in: db)
      try Edition.find(editionID).update {
        $0.estimatedCostUSD = #bind(run.estimatedCost.map { NSDecimalNumber(decimal: $0).doubleValue })
        $0.modelName = #bind(run.modelName)
        $0.composedAt = #bind(now)
        $0.state = #bind(EditionState.open)
      }.execute(db)
    }
    return .composed(editionID)
  }
}
