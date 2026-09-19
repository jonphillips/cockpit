import Foundation
import SQLiteData

/// The source disposition a user resolves for one Gmail message (DECISIONS §7). `leave` is a Cockpit
/// no-op that keeps the message in `INBOX`; `archive` and `trash` are the only provider mutations
/// Cockpit performs in V1 (ADR-0002 D5). There is deliberately no `Delete Forever`.
///
/// Named to distinguish it from `JudgmentFixtureSupport.GmailDisposition`, which is the *observed*
/// state of a harvested message (inbox/archived/trashed); this is the *action* Cockpit applies.
public enum GmailSourceDisposition: String, CaseIterable, Codable, Sendable {
  case leave
  case archive
  case trash

  /// The mutating operations record a log entry; `leave` records nothing because it changes no
  /// provider state.
  var loggedOperation: GmailDispositionOperation? {
    switch self {
    case .leave: nil
    case .archive: .archive
    case .trash: .trash
    }
  }
}

/// The provider mutation actually applied, and therefore the thing the Undo log records. The inverse
/// is a pure function of the operation (ADR-0002 D5), so the log does not store a redundant column
/// for it (persistence discipline: the smallest table the behaviour justifies).
public enum GmailDispositionOperation: String, Codable, QueryBindable, Sendable {
  case archive
  case trash
}

/// A bounded, device-local, inspectable record of one applied disposition and whether it has been
/// reversed (ADR-0002 D6). It is not a parallel thread-resolution state: reversing a row issues the
/// inverse label operation and stamps `reversedAt`; it does not model Gmail's Inbox membership.
@Table("gmailDispositionLogEntries")
public struct GmailDispositionLogEntry: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  /// The Gmail message target, `gmail:{account}:message:{id}` — the same stable key as its Artifact.
  public let providerID: String
  public let operation: GmailDispositionOperation
  public let appliedAt: Date
  /// `nil` until Undo issues the inverse operation and it succeeds.
  public var reversedAt: Date?

  public init(
    id: UUID, providerID: String, operation: GmailDispositionOperation, appliedAt: Date,
    reversedAt: Date? = nil
  ) {
    self.id = id
    self.providerID = providerID
    self.operation = operation
    self.appliedAt = appliedAt
    self.reversedAt = reversedAt
  }
}

/// Database-only helpers for the disposition barrier and the Undo log. Anything that touches Gmail
/// itself lives in `GmailDispositionService`; this enum never performs a provider mutation, so the
/// barrier's "verify the commit" step is testable in isolation from the network.
public enum GmailDispositionOperations {
  public enum Failure: Error, Equatable, Sendable {
    /// The resolved ContentPiece is not backed by a committed Gmail Artifact.
    case notGmailArtifact
    /// The promised durable result for this message is not committed, so the barrier refuses to
    /// mutate (ADR-0002 D4). The message keeps `INBOX` and re-enters on the next delta sync.
    case resultNotCommitted
    case unknownLogEntry
  }

  /// The barrier's read side: resolve the Gmail message backing a ContentPiece and prove its promised
  /// durable result is committed before any mutation is attempted. Throws rather than returning nil so
  /// a caller cannot accidentally proceed past an unverified message.
  static func verifiedTarget(
    forContentPieceID id: ContentPiece.ID, in db: Database
  ) throws -> (providerID: String, messageID: String) {
    // Promised durable result = the shared ContentPiece the message produced. If ingest did not
    // commit it (a failed per-message commit leaves nothing to resolve), the disposition is a no-op:
    // the message keeps `INBOX` and re-enters on the next delta sync (ADR-0002 D4).
    guard try ContentPiece.find(id).fetchOne(db) != nil else { throw Failure.resultNotCommitted }

    // The mutation target is the message's Gmail Artifact. The DB's foreign key already guarantees an
    // Artifact's `contentPieceID` links a committed piece, so a present Artifact is a committed one.
    guard let artifact = try Artifact.where({
      $0.contentPieceID.eq(id) && $0.transport.eq(StreamTransport.gmail)
    }).fetchOne(db), let providerID = artifact.providerID,
      let messageID = messageID(fromProviderID: providerID)
    else { throw Failure.notGmailArtifact }

    return (providerID, messageID)
  }

  /// Parses the Gmail message id out of a `gmail:{account}:message:{id}` provider key. The canonical
  /// account is an email address and carries no `:message:`, so a single split is unambiguous.
  static func messageID(fromProviderID providerID: String) -> String? {
    guard let range = providerID.range(of: ":message:") else { return nil }
    let id = providerID[range.upperBound...]
    return id.isEmpty ? nil : String(id)
  }

  /// The un-reversed log entry for this exact operation, if one exists. Its presence makes a repeated
  /// disposition idempotent (ADR-0002 D5): the mutation and the record are not duplicated.
  static func activeEntry(
    providerID: String, operation: GmailDispositionOperation, in db: Database
  ) throws -> GmailDispositionLogEntry? {
    try GmailDispositionLogEntry.where {
      $0.providerID.eq(providerID) && $0.operation.eq(operation) && $0.reversedAt.is(nil)
    }.fetchOne(db)
  }

  static func recordApplied(
    id: UUID, providerID: String, operation: GmailDispositionOperation, at date: Date, in db: Database
  ) throws -> GmailDispositionLogEntry {
    let entry = GmailDispositionLogEntry(
      id: id, providerID: providerID, operation: operation, appliedAt: date)
    try GmailDispositionLogEntry.insert { GmailDispositionLogEntry.Draft(entry) }.execute(db)
    return entry
  }

  /// Recent dispositions, newest first — the inspectable surface Undo is offered from (ADR-0002 D6).
  public static func recent(limit: Int = 50, in db: Database) throws -> [GmailDispositionLogEntry] {
    try GmailDispositionLogEntry.order { $0.appliedAt.desc() }.limit(limit).fetchAll(db)
  }

  static func markReversed(entryID: UUID, at date: Date, in db: Database) throws {
    guard try GmailDispositionLogEntry.find(entryID).fetchOne(db) != nil else {
      throw Failure.unknownLogEntry
    }
    try GmailDispositionLogEntry.find(entryID).update { $0.reversedAt = #bind(date) }.execute(db)
  }
}
