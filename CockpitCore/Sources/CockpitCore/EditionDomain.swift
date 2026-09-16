import Foundation
import SQLiteData

/// `JudgmentSection` (from S2) is the `EditionEntry.section` column; it stores as its raw value.
extension JudgmentSection: QueryBindable {}

/// The materialised daily Edition's lifecycle. `composing → open → closed`
/// (IMPLEMENTATION-CONTRACT §3). An Edition is composed once per day; once `open` its entry
/// set is stable except append-only intraday admission of Essential/time-critical material.
public enum EditionState: String, Codable, QueryBindable, CaseIterable, Sendable {
  case composing
  case open
  case closed
}

/// An entry's lifecycle within its Edition (IMPLEMENTATION-CONTRACT §3). Legality is defined
/// here, in one place, so every writer (the day-boundary finaliser and the Reader-facing model
/// alike) goes through the same check and no illegal transition can be persisted.
public enum EditionEntryState: String, Codable, QueryBindable, CaseIterable, Sendable {
  case admitted
  case seen
  case dismissed
  case resolved
  case aged
  case carried

  /// `dismissed`, `resolved`, `aged` are terminal (IMPLEMENTATION-CONTRACT §3). `carried` is
  /// not a resolution: it is a hand-off — the entry is re-admitted to the next Edition as a new
  /// `EditionEntry`, so the carried row itself takes no further transitions either.
  public var isResolutionTerminal: Bool {
    switch self {
    case .dismissed, .resolved, .aged: true
    case .admitted, .seen, .carried: false
    }
  }

  /// The exhaustive legal-transition table (IMPLEMENTATION-CONTRACT §3) and only these:
  /// `admitted→seen`; `admitted/seen→dismissed`; `admitted/seen→resolved`;
  /// `admitted/seen→aged`; any non-terminal (`admitted`/`seen`) → `carried` at the day boundary.
  public func canTransition(to next: EditionEntryState) -> Bool {
    switch (self, next) {
    case (.admitted, .seen),
      (.admitted, .dismissed), (.seen, .dismissed),
      (.admitted, .resolved), (.seen, .resolved),
      (.admitted, .aged), (.seen, .aged),
      (.admitted, .carried), (.seen, .carried):
      true
    default:
      false
    }
  }
}

/// Product constants introduced by M2 S3, all from IMPLEMENTATION-CONTRACT §3 and all tunable.
/// They are named here rather than inlined so the state machine cites the contract, not a round
/// number (the M1 constants rule).
public enum EditionPolicy {
  /// A non-Essential entry may be carried at most this many times, then `aged` (§3).
  public static let carryoverBudget = 3
  /// An unresolved Essential entry carried more than this many times moves to
  /// `section = essentialBacklog`, a separate reachable group outside `targetSize` (§3).
  public static let essentialBacklogRelief = 14
  /// The default objective the judgment pass optimises against (§3).
  public static let defaultTargetSize = 20
}

/// The daily materialised newspaper (ADR-0001 D5; IMPLEMENTATION-CONTRACT §2–3). A past Edition
/// explains itself entirely from these stored columns — cost, prompt version, and model included —
/// with no re-derivation.
@Table("editions")
public struct Edition: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  /// The start-of-day instant this Edition is the newspaper for. One Edition per day: `id` is
  /// derived from the day (`EditionDay`) and composition is a no-op when today's row exists. The
  /// `date` index is deliberately not unique — SQLiteData's SyncEngine rejects uniqueness
  /// constraints on synchronized tables, and Edition syncs (ADR-0001 D6).
  public var date: Date
  public var composedAt: Date?
  public var state: EditionState
  public var targetSize: Int
  /// The Gate-1 composition-cost estimate from `JudgmentRun.estimatedCost`, in USD. Stored as a
  /// `Double` because StructuredQueries has no `Decimal` column binding; this is an estimate, not
  /// a billed-invoice assertion (JudgmentRun), so the conversion is immaterial.
  public var estimatedCostUSD: Double?
  /// The prompt version and model the composition actually used — a closed Edition must be able
  /// to say how it was composed (IMPLEMENTATION-CONTRACT §3; M2 prompt-versioning rule).
  public var promptVersion: String?
  public var modelName: String?

  public init(
    id: UUID,
    date: Date,
    composedAt: Date? = nil,
    state: EditionState = .composing,
    targetSize: Int = EditionPolicy.defaultTargetSize,
    estimatedCostUSD: Double? = nil,
    promptVersion: String? = nil,
    modelName: String? = nil
  ) {
    self.id = id
    self.date = date
    self.composedAt = composedAt
    self.state = state
    self.targetSize = targetSize
    self.estimatedCostUSD = estimatedCostUSD
    self.promptVersion = promptVersion
    self.modelName = modelName
  }
}

/// One surfaced ContentPiece within an Edition (IMPLEMENTATION-CONTRACT §2–3). Relationships to
/// `editions` and `contentPieces` are enforced in deterministic code, not by foreign keys — the
/// same constraint the memberships hit (SQLiteData cannot express a non-null single-parent FK;
/// see `DestinationMigration`).
@Table("editionEntries")
public struct EditionEntry: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public var editionID: Edition.ID
  public var contentPieceID: ContentPiece.ID
  public var section: JudgmentSection
  public var rank: Int
  public var rationale: String?
  /// The current Personal Knowledge claim named by this materialised rationale, if any. It is
  /// persisted beside the rationale so a past Edition can still offer the same correction route
  /// without re-running judgment or reverse-matching prose.
  public var matchedPersonalKnowledgeClaimID: PersonalKnowledgeClaim.ID?
  public var entryState: EditionEntryState
  /// The Edition this piece was *first* admitted in, preserved across every re-admission so a
  /// carried chain remains traceable to its origin (IMPLEMENTATION-CONTRACT §3).
  public var firstAdmittedEditionID: Edition.ID
  /// How many day boundaries this piece has been carried across to reach this entry. `0` on first
  /// admission; incremented on each re-admission. It makes the carryover budget and the Essential
  /// relief valve (§3) provable from a single stored row.
  public var timesCarried: Int

  public init(
    id: UUID,
    editionID: Edition.ID,
    contentPieceID: ContentPiece.ID,
    section: JudgmentSection,
    rank: Int,
    rationale: String? = nil,
    matchedPersonalKnowledgeClaimID: PersonalKnowledgeClaim.ID? = nil,
    entryState: EditionEntryState = .admitted,
    firstAdmittedEditionID: Edition.ID,
    timesCarried: Int = 0
  ) {
    self.id = id
    self.editionID = editionID
    self.contentPieceID = contentPieceID
    self.section = section
    self.rank = rank
    self.rationale = rationale
    self.matchedPersonalKnowledgeClaimID = matchedPersonalKnowledgeClaimID
    self.entryState = entryState
    self.firstAdmittedEditionID = firstAdmittedEditionID
    self.timesCarried = timesCarried
  }
}

/// The day-boundary calendar. Composition is a materialised daily entity, so "which day is it"
/// must be deterministic and the same across test runs and devices. A fixed UTC gregorian
/// calendar gives that; the user-timezone morning boundary is a device/Gate-1 concern, not a
/// composition-correctness one, and can be revisited when the shell owns a real clock.
public enum EditionDay {
  static let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }()

  /// The start-of-day instant an Edition is keyed to.
  public static func start(of date: Date) -> Date {
    calendar.startOfDay(for: date)
  }

  /// A stable `yyyy-MM-dd` key for the day, used to derive the Edition's convergent identity.
  public static func key(for date: Date) -> String {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
  }

  /// The Edition identity for a day, derived (like ContentPiece identity) via UUIDv5 over the day
  /// key so two devices composing the same day converge on one row (ADR-0001 D3/D6).
  public static func editionID(for date: Date) -> Edition.ID {
    ContentIdentity.uuidV5(namespace: ContentIdentity.cockpitNamespace, name: "edition:\(key(for: date))")
  }
}
