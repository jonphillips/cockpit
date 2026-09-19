import Dependencies
import Foundation
import SQLiteData

/// The Gmail label operations, injected so the barrier and Undo are deterministic in tests. The live
/// value issues the real `messages.modify`/`trash`/`untrash` calls; a test supplies a fake label API.
/// Each operation is idempotent on Gmail's side (ADR-0002 D5), so a retry cannot double-apply.
public struct GmailDispositionClient: Sendable {
  /// `messages.modify` removing `INBOX`.
  public var archive: @Sendable (_ messageID: String) async throws -> Void
  /// `messages.trash`.
  public var trash: @Sendable (_ messageID: String) async throws -> Void
  /// `messages.modify` re-adding `INBOX` — the inverse of `archive`.
  public var reAddInbox: @Sendable (_ messageID: String) async throws -> Void
  /// `messages.untrash` — the inverse of `trash`, valid until Gmail purges the message.
  public var untrash: @Sendable (_ messageID: String) async throws -> Void

  public init(
    archive: @escaping @Sendable (_ messageID: String) async throws -> Void,
    trash: @escaping @Sendable (_ messageID: String) async throws -> Void,
    reAddInbox: @escaping @Sendable (_ messageID: String) async throws -> Void,
    untrash: @escaping @Sendable (_ messageID: String) async throws -> Void
  ) {
    self.archive = archive
    self.trash = trash
    self.reAddInbox = reAddInbox
    self.untrash = untrash
  }

  public static func live(accessToken: String) -> Self {
    let api = GmailDispositionAPI(accessToken: accessToken)
    return Self(
      archive: { try await api.archive(messageID: $0) },
      trash: { try await api.trash(messageID: $0) },
      reAddInbox: { try await api.reAddInbox(messageID: $0) },
      untrash: { try await api.untrash(messageID: $0) }
    )
  }
}

/// Raised when a disposition is attempted before the app has supplied an authorized client. It makes a
/// missing wiring fail loudly instead of silently dropping a provider write.
public enum GmailDispositionConfigurationError: Error, Equatable, Sendable {
  case notConfigured
}

extension GmailDispositionClient: DependencyKey {
  /// The app overrides this in `prepareDependencies` with a client wired to the authorized Gmail
  /// account; the default refuses, since a provider write must never be attempted unauthorized.
  public static let liveValue = GmailDispositionClient(
    archive: { _ in throw GmailDispositionConfigurationError.notConfigured },
    trash: { _ in throw GmailDispositionConfigurationError.notConfigured },
    reAddInbox: { _ in throw GmailDispositionConfigurationError.notConfigured },
    untrash: { _ in throw GmailDispositionConfigurationError.notConfigured }
  )
  public static let testValue = liveValue
}

extension DependencyValues {
  public var gmailDispositionClient: GmailDispositionClient {
    get { self[GmailDispositionClient.self] }
    set { self[GmailDispositionClient.self] = newValue }
  }
}

/// Applies and reverses Gmail dispositions behind the disposition barrier (ADR-0002 D4). The barrier
/// ordering — verify the promised durable result is committed, *then* mutate the provider, *then*
/// record the reversible log entry — lives here so it is exercised by every caller and provable in a
/// test against a fake label API.
public struct GmailDispositionService: Sendable {
  @Dependency(\.uuid) private var uuid

  private let client: GmailDispositionClient
  private let now: @Sendable () -> Date

  public init(client: GmailDispositionClient, now: @escaping @Sendable () -> Date = Date.init) {
    self.client = client
    self.now = now
  }

  /// Resolves the message backing `contentPieceID` and applies `disposition` behind the barrier.
  /// `leave` mutates nothing and records nothing. A repeated `archive`/`trash` is idempotent: it
  /// re-uses the existing log entry and does not mutate again. Returns the log entry for a mutation,
  /// or `nil` for `leave`.
  @discardableResult
  public func apply(
    _ disposition: GmailSourceDisposition,
    toContentPieceID contentPieceID: ContentPiece.ID,
    in database: any DatabaseWriter
  ) async throws -> GmailDispositionLogEntry? {
    guard let operation = disposition.loggedOperation else { return nil }

    // Barrier, step 1: prove the promised durable result is committed before any mutation. This read
    // throws if the message is unknown or its ContentPiece is not durable, so the client is never
    // reached for an unverified message.
    let (providerID, messageID, existing) = try await database.read { db in
      let target = try GmailDispositionOperations.verifiedTarget(forContentPieceID: contentPieceID, in: db)
      let active = try GmailDispositionOperations.activeEntry(
        providerID: target.providerID, operation: operation, in: db)
      return (target.providerID, target.messageID, active)
    }
    if let existing { return existing }

    // Barrier, step 2: mutate the provider only now.
    switch operation {
    case .archive: try await client.archive(messageID)
    case .trash: try await client.trash(messageID)
    }

    // Barrier, step 3: record the reversible entry after the mutation succeeds.
    let id = uuid()
    let appliedAt = now()
    return try await database.write { db in
      try GmailDispositionOperations.recordApplied(
        id: id, providerID: providerID, operation: operation, at: appliedAt, in: db)
    }
  }

  /// Reverses a previously applied disposition by issuing the inverse label operation and stamping
  /// the log entry. Reversing an already-reversed entry is idempotent. If Gmail refuses the inverse
  /// (e.g. a Trashed message purged past its window), the error propagates and the entry stays
  /// un-reversed — the log never claims a reversal that did not happen.
  public func undo(_ entry: GmailDispositionLogEntry, in database: any DatabaseWriter) async throws {
    if entry.reversedAt != nil { return }
    guard let messageID = GmailDispositionOperations.messageID(fromProviderID: entry.providerID) else {
      throw GmailDispositionOperations.Failure.notGmailArtifact
    }
    switch entry.operation {
    case .archive: try await client.reAddInbox(messageID)
    case .trash: try await client.untrash(messageID)
    }
    let reversedAt = now()
    try await database.write { db in
      try GmailDispositionOperations.markReversed(entryID: entry.id, at: reversedAt, in: db)
    }
  }
}
