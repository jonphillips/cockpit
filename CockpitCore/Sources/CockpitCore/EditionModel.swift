import Dependencies
import Foundation
import LLMClientKit
import Observation
import SQLiteData

/// The outcome of the current tail-compose attempt. It is deliberately separate from an Edition's
/// persisted state: a timeout can happen before an Edition opens.
public enum EditionCompositionState: Equatable, Sendable {
  case idle
  case composing(EditionCompositionPhase)
  case composed
  case empty
  case failed
}

public enum EditionCompositionPhase: Equatable, Sendable {
  case preparing
  case screeningCandidates
  case selectingEdition
  case saving

  public var title: String {
    switch self {
    case .preparing: "Preparing the tail"
    case .screeningCandidates: "Screening tail candidates"
    case .selectingEdition: "Selecting today’s tail"
    case .saving: "Saving today’s tail"
    }
  }

  public var detail: String {
    switch self {
    case .preparing: "Gathering new arrivals and unresolved carryovers."
    case .screeningCandidates: "Classifying material before editorial selection."
    case .selectingEdition: "Making the finite editorial selection. This can take a few minutes."
    case .saving: "Committing the completed tail."
    }
  }
}

private enum EditionCompositionTimeoutError: LocalizedError {
  case exceeded

  var errorDescription: String? {
    "Tail composition took longer than eight minutes. Nothing was published; try again."
  }
}

private func runWithinTimeout<T: Sendable>(
  _ timeout: Duration, operation: @escaping @Sendable () async throws -> T
) async throws -> T {
  try await withThrowingTaskGroup(of: T.self) { group in
    group.addTask { try await operation() }
    group.addTask {
      try await Task.sleep(for: timeout)
      throw EditionCompositionTimeoutError.exceeded
    }
    defer { group.cancelAll() }
    guard let result = try await group.next() else { throw CancellationError() }
    return result
  }
}

/// The `@Observable` model that owns the day's Edition (`AGENTS.md`: Edition behaviour is verified
/// through this, not the device). It triggers background composition and owns every
/// `EditionEntry` state transition, routing each through the validated state machine so an illegal
/// transition can never be persisted (IMPLEMENTATION-CONTRACT §3).
@MainActor
@Observable
public final class EditionModel {
  /// A known working device compose takes about six minutes (DECISIONS §23). Eight minutes keeps
  /// that path viable while ensuring the UI reaches a definite, retryable error instead of an
  /// indefinite spinner.
  public static let compositionTimeout: Duration = .seconds(8 * 60)

  @ObservationIgnored @Dependency(\.defaultDatabase) private var database
  @ObservationIgnored @Dependency(\.date.now) private var now
  @ObservationIgnored @Dependency(\.modelClient) private var modelClient
  @ObservationIgnored @Fetch(CurrentEditionRequest()) public var current = .init()

  /// Surfaced while composition runs so the shell can show a composing state without blocking on
  /// it — composition can take minutes on device (DECISIONS §23).
  public private(set) var compositionState: EditionCompositionState = .idle
  public var errorMessage: String?
  private let timeout: Duration
  private var attemptID: UUID?

  public init(timeout: Duration = .seconds(8 * 60)) {
    self.timeout = timeout
  }

  public var edition: Edition? { current.edition }
  public var entries: [CurrentEditionRequest.Row] { current.entries }
  public var isComposing: Bool {
    if case .composing = compositionState { return true }
    return false
  }

  /// Compose today's Edition if it does not already exist. The single judgment pass runs off the
  /// main actor inside the composer; `await` here releases the main actor while it works, so the
  /// UI stays responsive. Safe to call on every launch — it is a no-op once today is materialised.
  public func composeIfNeeded(
    targetSize: Int = EditionPolicy.defaultTargetSize, currentContext: String = ""
  ) async {
    await compose(targetSize: targetSize, currentContext: currentContext, force: false)
  }

  /// Explicit "reconsider": discard today's Edition and re-drive it from scratch (the Reader/Edition
  /// retry action). Unlike `composeIfNeeded` this is *not* a no-op when today already exists — it is
  /// the deliberate way to rebuild a stale, empty, or previously-failed Edition
  /// (IMPLEMENTATION-CONTRACT §3).
  public func recompose(
    targetSize: Int = EditionPolicy.defaultTargetSize, currentContext: String = ""
  ) async {
    await compose(targetSize: targetSize, currentContext: currentContext, force: true)
  }

  private func compose(targetSize: Int, currentContext: String, force: Bool) async {
    let attemptID = UUID()
    self.attemptID = attemptID
    compositionState = .composing(.preparing)
    errorMessage = nil
    let compositionNow = now
    let compositionDatabase = database
    let composer = EditionComposer(
      engine: JudgmentEngine(modelClient: modelClient),
      targetSize: targetSize, currentContext: currentContext,
      reportProgress: { [weak self] progress in
        await self?.report(progress, for: attemptID)
      })
    do {
      let result = try await runWithinTimeout(timeout) {
        if force {
          return try await composer.recompose(now: compositionNow, in: compositionDatabase)
        } else {
          return try await composer.composeIfNeeded(now: compositionNow, in: compositionDatabase)
        }
      }
      guard self.attemptID == attemptID else { return }
      switch result {
      case .composed, .alreadyComposed:
        compositionState = .composed
      case .nothingToCompose:
        compositionState = .empty
      }
      try await $current.load()
      errorMessage = nil
    } catch {
      guard self.attemptID == attemptID else { return }
      compositionState = .failed
      errorMessage = error.localizedDescription
    }
  }

  private static func phase(for progress: EditionCompositionProgress) -> EditionCompositionPhase {
    switch progress {
    case .preparing: .preparing
    case .classifyingCandidates: .screeningCandidates
    case .selectingEdition: .selectingEdition
    case .saving: .saving
    }
  }

  private func report(_ progress: EditionCompositionProgress, for attemptID: UUID) {
    guard self.attemptID == attemptID else { return }
    compositionState = .composing(Self.phase(for: progress))
  }

  /// Opening a piece in the Reader (`admitted → seen`). The Reader that triggers it is S4; the
  /// transition lives here.
  public func markSeen(_ entryID: EditionEntry.ID) async {
    await run { try EditionOperations.markSeen(entryID, in: $0) }
  }

  /// Edition's resolution action (IMPLEMENTATION-CONTRACT §4): `admitted/seen → dismissed`.
  public func dismiss(_ entryID: EditionEntry.ID) async {
    await transition(entryID, to: .dismissed)
  }

  /// Save for Later (`admitted/seen → resolved`): resolves the Edition relationship and records
  /// the explicit deferred-attention membership in one atomic write (EDITION-EXPERIENCE §3).
  public func saveForLater(_ entryID: EditionEntry.ID) async {
    let date = now
    await run { try EditionOperations.saveForLater(entryID, at: date, in: $0) }
  }

  /// Add to Library (M2 S4): orthogonal to Edition state, per IMPLEMENTATION-CONTRACT §3–4 — it
  /// records the durable membership and never changes `entryState`.
  public func addToLibrary(_ entryID: EditionEntry.ID) async {
    let date = now
    await run { try EditionOperations.addToLibrary(entryID, at: date, in: $0) }
  }

  /// `isSubstantivePrimary` is inspectable and correctable from the Reader
  /// (IMPLEMENTATION-CONTRACT §1) — an explicit user correction, never model output.
  public func correctIsSubstantivePrimary(_ entryID: EditionEntry.ID, to value: Bool) async {
    await run { try EditionOperations.correctIsSubstantivePrimary(entryID, to: value, in: $0) }
  }

  /// The single validated transition entry point. Rejects every edge the state machine forbids
  /// (IMPLEMENTATION-CONTRACT §3); a rejection surfaces on `errorMessage` and changes nothing.
  public func transition(_ entryID: EditionEntry.ID, to newState: EditionEntryState) async {
    await run { try EditionOperations.transition(entryID, to: newState, in: $0) }
  }

  /// The shared write-then-reload-then-report shape every Reader action follows: run one
  /// deterministic operation in a transaction, refresh `current` from stored state, and surface a
  /// failure on `errorMessage` rather than throwing past the model.
  private func run(_ operation: @escaping @Sendable (Database) throws -> Void) async {
    do {
      try await database.write { db in try operation(db) }
      try await $current.load()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
