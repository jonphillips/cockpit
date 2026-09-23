import Foundation
import SQLiteData

/// The bounded set of explicit disposition policies a user may establish. This is deliberately a small
/// closed enum, not a condition/action engine (DECISIONS §7; ADR-0002 D7): each case is one hard-coded,
/// user-established policy that classifies-to-apply and is individually turned on. Adding a case is a
/// deliberate product decision, never something the app infers from behaviour.
public enum GmailDispositionPolicyKind: String, CaseIterable, Codable, QueryBindable, Sendable {
  /// Trash a disposable retail offer once a Find has been extracted from it (the wine/promo case). The
  /// Find is the promised durable result, so the barrier requires it committed before the Trash.
  case offerWithFind
  /// Trash a login / verification code once ingested (the S3 ephemeral case). An OTP has no durable
  /// result to retain, so the barrier is satisfied by the committed ContentPiece alone.
  case loginCode

  public var displayName: String {
    switch self {
    case .offerWithFind: "Trash retail offers after confirming a Find"
    case .loginCode: "Trash login & verification codes"
    }
  }
}

/// One explicit, user-established policy record. Presence is not enough — `enabled` gates action — so
/// that turning a policy off halts future dispositions while preserving the record that it was
/// established (ADR-0002 D6/D7). This is the whole persistence footprint: one row per policy kind.
@Table("gmailDispositionPolicies")
public struct GmailDispositionPolicy: Codable, Equatable, Identifiable, Sendable {
  @Column(primaryKey: true) public let kind: GmailDispositionPolicyKind
  public let establishedAt: Date
  public var enabled: Bool

  public var id: GmailDispositionPolicyKind { kind }

  public init(kind: GmailDispositionPolicyKind, establishedAt: Date, enabled: Bool = true) {
    self.kind = kind
    self.establishedAt = establishedAt
    self.enabled = enabled
  }
}

/// Database-only policy helpers: establishing/enabling a policy, and classifying which committed
/// messages a policy matches. Nothing here mutates Gmail — application goes through
/// `GmailDispositionPolicyService`, which rides the same barrier and Undo log as a per-action
/// disposition — so "classify" and "propose" are provably separate from "authorize".
public enum GmailDispositionPolicyOperations {
  /// Establishes (or re-enables) a policy. This is the only way a policy comes to exist; it must be an
  /// explicit user action, never inferred from observed mail (D7; §8 "knowledge does not grant agency").
  public static func establish(
    _ kind: GmailDispositionPolicyKind, at date: Date, in db: Database
  ) throws {
    try GmailDispositionPolicy
      .upsert { GmailDispositionPolicy.Draft(GmailDispositionPolicy(kind: kind, establishedAt: date)) }
      .execute(db)
  }

  /// Turns a policy off without un-disposing anything it already did (that is Undo's job).
  public static func setEnabled(
    _ kind: GmailDispositionPolicyKind, _ enabled: Bool, in db: Database
  ) throws {
    try GmailDispositionPolicy.find(kind).update { $0.enabled = #bind(enabled) }.execute(db)
  }

  public static func enabledKinds(in db: Database) throws -> [GmailDispositionPolicyKind] {
    try GmailDispositionPolicy.where { $0.enabled.eq(true) }.fetchAll(db).map(\.kind)
  }

  /// The messages an enabled policy would dispose right now: matched, barrier-satisfied, and not
  /// already disposed by a prior policy pass (the policy acts at most once per message, so a user's
  /// Undo is not re-fought). With no policy enabled this is empty — nothing acts from classification.
  public static func matchingPieceIDs(in db: Database) throws -> [ContentPiece.ID] {
    var ids: [ContentPiece.ID] = []
    for kind in try enabledKinds(in: db) {
      for id in try candidatePieceIDs(for: kind, in: db) where try !hasTrashLogEntry(forContentPieceID: id, in: db) {
        if !ids.contains(id) { ids.append(id) }
      }
    }
    return ids
  }

  /// The messages a policy *would* match if established — the classify/propose surface. It never
  /// disposes; a proposal is not authority (D7). Used to surface "you could turn this on".
  public static func candidatePieceIDs(
    for kind: GmailDispositionPolicyKind, in db: Database
  ) throws -> [ContentPiece.ID] {
    switch kind {
    case .loginCode:
      return try ContentPiece
        .where { $0.emailTreatment.eq(EmailTreatment.transactional) }
        .fetchAll(db)
        .filter { $0.emailTransactionalKind == .ephemeral }
        .map(\.id)
    case .offerWithFind:
      let offers = try ContentPiece.where { $0.emailTreatment.eq(EmailTreatment.offer) }.fetchAll(db)
      // A model proposal has no user authority: Jon must confirm the Find before it can satisfy the
      // policy barrier. A handoff also implies that the Find was confirmed.
      return try offers
        .filter { offer in
          try PendingFind.where {
            $0.contentPieceID.eq(offer.id)
              && ($0.state.eq(PendingFindState.confirmed) || $0.state.eq(PendingFindState.handedOff))
          }.fetchCount(db) > 0
        }
        .map(\.id)
    }
  }

  /// True once any Trash has been logged for the message, reversed or not — the once-per-message guard.
  static func hasTrashLogEntry(forContentPieceID id: ContentPiece.ID, in db: Database) throws -> Bool {
    try GmailDispositionOperations.hasTrashLogEntry(forContentPieceID: id, in: db)
  }
}
