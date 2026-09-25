import Foundation
import LLMClientKit
import SQLiteData

public enum PendingFindState: String, Codable, QueryBindable, Sendable {
  case pending
  case confirmed
  case referred
  case handedOff
  case declined
  case dismissed
}

@Table("pendingFinds")
public struct PendingFind: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public let contentPieceID: ContentPiece.ID
  public var kind: String
  public var name: String
  public var descriptor: String
  public var rationale: String
  public var sourceURL: String?
  /// JSON-encoded lightweight hints. Hints remain descriptive input for a future receiver, not a
  /// Cockpit-owned domain model (CONTENT-PIECE-MODEL §6).
  public var hints: String?
  public var state: PendingFindState

  public init(
    id: UUID, contentPieceID: ContentPiece.ID, kind: String, name: String, descriptor: String,
    rationale: String, sourceURL: String? = nil, hints: String? = nil,
    state: PendingFindState = .pending
  ) {
    self.id = id
    self.contentPieceID = contentPieceID
    self.kind = kind
    self.name = name
    self.descriptor = descriptor
    self.rationale = rationale
    self.sourceURL = sourceURL
    self.hints = hints
    self.state = state
  }
}

public enum PendingFindOperations {
  public enum Failure: LocalizedError, Equatable, Sendable {
    case cannotRefer

    public var errorDescription: String? { "This Find was already sent or is no longer available." }
  }

  /// Writes only the finds proposed by this judgment outcome. IDs are derived from the originating
  /// ContentPiece and the find's stable descriptive identity, so repeated composition converges and
  /// does not create duplicate orphan rows.
  public static func persist(
    _ finds: [JudgmentFind]?, for contentPieceID: ContentPiece.ID, in db: Database
  ) throws {
    guard let finds else { return }
    for find in finds {
      let hints = try encodeHints(find.hints)
      let id = ContentIdentity.uuidV5(
        namespace: ContentIdentity.cockpitNamespace,
        name: [
          "pending-find", contentPieceID.uuidString, find.kind, find.name,
          find.sourceURL ?? ""
        ].map(ContentIdentity.normalizeText).joined(separator: "\u{001F}"))
      if try PendingFind.find(id).fetchOne(db) != nil {
        try PendingFind.find(id).update {
          $0.kind = #bind(find.kind)
          $0.name = #bind(find.name)
          $0.descriptor = #bind(find.descriptor)
          $0.rationale = #bind(find.rationale)
          $0.sourceURL = #bind(find.sourceURL)
          $0.hints = #bind(hints)
        }.execute(db)
      } else {
        try PendingFind.insert {
          PendingFind.Draft(
            PendingFind(
              id: id, contentPieceID: contentPieceID, kind: find.kind, name: find.name,
              descriptor: find.descriptor, rationale: find.rationale, sourceURL: find.sourceURL,
              hints: hints))
        }.execute(db)
      }
    }
  }

  /// Records Jon's explicit decision to keep a proposed Find.
  public static func confirm(_ id: PendingFind.ID, in db: Database) throws {
    try PendingFind.find(id).update { $0.state = #bind(PendingFindState.confirmed) }.execute(db)
  }

  /// Records Jon's explicit decision to reject a proposed Find.
  public static func dismiss(_ id: PendingFind.ID, in db: Database) throws {
    try PendingFind.find(id).update { $0.state = #bind(PendingFindState.dismissed) }.execute(db)
  }

  public static func refer(_ id: PendingFind.ID, in db: Database) throws {
    try PendingFind.find(id).update { $0.state = #bind(PendingFindState.referred) }.execute(db)
  }

  public static func returnToConfirmed(_ id: PendingFind.ID, in db: Database) throws {
    try PendingFind.find(id).update { $0.state = #bind(PendingFindState.confirmed) }.execute(db)
  }

  public static func startReferral(
    referralID: UUID, for id: PendingFind.ID, at date: Date, in db: Database
  ) throws {
    guard let find = try PendingFind.find(id).fetchOne(db),
      RecipeCandidateKind.matches(find.kind),
      find.state == .pending || find.state == .confirmed
    else { throw Failure.cannotRefer }
    try refer(id, in: db)
    try PendingFindReferral.insert {
      PendingFindReferral.Draft(PendingFindReferral(id: referralID, pendingFindID: id, sentAt: date))
    }.execute(db)
  }

  public static func recordReferralOpenFailure(
    referralID: UUID, for id: PendingFind.ID, at date: Date, in db: Database
  ) throws {
    let rawOutcomeSet = try FindReferralOperations.encodeOutcomeRecord(.delivery(.openFailed))
    try returnToConfirmed(id, in: db)
    try PendingFindReferral.find(referralID).update {
      $0.resolvedAt = #bind(date)
      $0.rawOutcomeSet = #bind(rawOutcomeSet)
    }.execute(db)
  }

  private static func encodeHints(_ hints: [String: JSONValue]) throws -> String? {
    guard !hints.isEmpty else { return nil }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return String(decoding: try encoder.encode(hints), as: UTF8.self)
  }
}
