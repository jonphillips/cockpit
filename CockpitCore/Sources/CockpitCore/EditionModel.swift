import Dependencies
import Foundation
import LLMClientKit
import Observation
import SQLiteData

/// The `@Observable` model that owns the day's Edition (`AGENTS.md`: Edition behaviour is verified
/// through this, not the device). It triggers background composition and owns every
/// `EditionEntry` state transition, routing each through the validated state machine so an illegal
/// transition can never be persisted (IMPLEMENTATION-CONTRACT §3).
@MainActor
@Observable
public final class EditionModel {
  @ObservationIgnored @Dependency(\.defaultDatabase) private var database
  @ObservationIgnored @Dependency(\.date.now) private var now
  @ObservationIgnored @Dependency(\.modelClient) private var modelClient
  @ObservationIgnored @Fetch(CurrentEditionRequest()) public var current = .init()

  /// Surfaced while composition runs so the shell can show a composing state without blocking on
  /// it — composition can take >60s (122s measured on a Mac in the S2 run).
  public var isComposing = false
  public var errorMessage: String?

  public init() {}

  public var edition: Edition? { current.edition }
  public var entries: [CurrentEditionRequest.Row] { current.entries }

  /// Compose today's Edition if it does not already exist. The single judgment pass runs off the
  /// main actor inside the composer; `await` here releases the main actor while it works, so the
  /// UI stays responsive. Safe to call on every launch — it is a no-op once today is materialised.
  public func composeIfNeeded(
    targetSize: Int = EditionPolicy.defaultTargetSize, currentContext: String = ""
  ) async {
    isComposing = true
    defer { isComposing = false }
    let composer = EditionComposer(
      engine: JudgmentEngine(modelClient: modelClient),
      targetSize: targetSize, currentContext: currentContext)
    do {
      _ = try await composer.composeIfNeeded(now: now, in: database)
      try await $current.load()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// Opening a piece in the Reader (`admitted → seen`). The Reader that triggers it is S4; the
  /// transition lives here.
  public func markSeen(_ entryID: EditionEntry.ID) async {
    await transition(entryID, to: .seen)
  }

  /// Edition's resolution action (IMPLEMENTATION-CONTRACT §4): `admitted/seen → dismissed`.
  public func dismiss(_ entryID: EditionEntry.ID) async {
    await transition(entryID, to: .dismissed)
  }

  /// Save for Later resolves the Edition relationship (`admitted/seen → resolved`). Writing the
  /// `LaterMembership` is S4; S3 owns only the entry-state transition.
  public func saveForLater(_ entryID: EditionEntry.ID) async {
    await transition(entryID, to: .resolved)
  }

  /// The single validated transition entry point. Rejects every edge the state machine forbids
  /// (IMPLEMENTATION-CONTRACT §3); a rejection surfaces on `errorMessage` and changes nothing.
  public func transition(_ entryID: EditionEntry.ID, to newState: EditionEntryState) async {
    do {
      try await database.write { db in
        try EditionOperations.transition(entryID, to: newState, in: db)
      }
      try await $current.load()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
