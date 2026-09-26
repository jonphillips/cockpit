import Dependencies
import Foundation
import SQLiteData

public struct GmailInboxIngestor {
  @Dependency(\.uuid) private var uuid

  public let client: GmailInboxClient
  public let identityNamespace: UUID
  public let now: @Sendable () -> Date
  /// S8 processing is opt-in at this boundary so S4's read-only ingest remains independently
  /// testable and callers can surface a model failure without treating it as a Gmail failure.
  public let treatmentProcessor: EmailTreatmentProcessor?

  public init(
    client: GmailInboxClient,
    identityNamespace: UUID = ContentIdentity.cockpitNamespace,
    now: @escaping @Sendable () -> Date = Date.init,
    treatmentProcessor: EmailTreatmentProcessor? = nil
  ) {
    self.client = client
    self.identityNamespace = identityNamespace
    self.now = now
    self.treatmentProcessor = treatmentProcessor
  }

  @discardableResult
  public func ingest(into database: any DatabaseWriter) async throws -> GmailInboxIngestReport {
    try Task.checkCancellation()
    let savedCursor = try await database.read { db in
      try GmailSyncState.all.fetchAll(db).first
    }
    let snapshot: GmailInboxSnapshot
    if let savedCursor {
      snapshot = try await client.inboxChanges(savedCursor.accountID, savedCursor.historyID)
    } else {
      snapshot = try await client.currentInbox()
    }
    let acquiredAt = now()
    let namespace = identityNamespace
    var pieces: [ContentPiece] = []
    var failures = snapshot.failures

    // Every successful message gets its own durable write. One bad message therefore cannot throw
    // away its neighbours, and the history cursor below remains behind the failure for a retry.
    for message in snapshot.messages {
      try Task.checkCancellation()
      let artifactID = uuid()
      do {
        let piece = try await database.write { db in
          let recorded = try Self.record(
            message: message,
            artifactID: artifactID,
            accountID: snapshot.accountID,
            acquiredAt: acquiredAt,
            namespace: namespace,
            in: db
          )
          let reconciled = try GmailStreamResolver.linkUnresolvedArtifacts(in: db)
          let classified = try EmailTreatmentOperations.classify(
            emailContentPieceIDs: [recorded.id] + reconciled, in: db)
          return classified.first(where: { $0.id == recorded.id }) ?? recorded
        }
        pieces.append(piece)
      } catch is CancellationError {
        throw CancellationError()
      } catch {
        failures.append(GmailInboxMessageFailure(messageID: message.id, description: error.localizedDescription))
      }
    }
    if let treatmentProcessor {
      _ = try? await treatmentProcessor.process(emailContentPieceIDs: pieces.map(\.id), in: database)
    }

    await Self.reconcileDepartures(in: snapshot, at: acquiredAt, database: database)

    var refreshedAt = savedCursor?.readStateRefreshCompletedAt
    if refreshedAt == nil, let refreshUnreadStates = client.refreshUnreadStates {
      refreshedAt = await Self.refreshTodayUnreadState(
        using: refreshUnreadStates, at: acquiredAt, database: database
      )
    }

    try await Self.advanceCursorIfClean(
      snapshot: snapshot, failures: failures, at: acquiredAt,
      readStateRefreshCompletedAt: refreshedAt, database: database)

    let reportSnapshot = GmailInboxSnapshot(
      accountID: snapshot.accountID,
      historyID: snapshot.historyID,
      pageCount: snapshot.pageCount,
      messages: snapshot.messages,
      failures: failures
    )
    return GmailInboxIngestReport(snapshot: reportSnapshot, contentPieces: pieces)
  }
}

extension GmailInboxIngestor {
  @Selection
  struct GmailUnreadRefreshTarget: Equatable, Sendable {
    let id: Artifact.ID
    let providerID: String?
  }

  /// Reconciles Gmail-side departures: any Primary message that left the Inbox since the cursor
  /// (archived/trashed/re-categorized in Gmail) is cleared from Today, so the surface reflects the
  /// provider instead of growing without bound. Best-effort and idempotent — it clears Today attention
  /// only and never fails an otherwise-successful read.
  /// Advances the history cursor — itself a committed local write — only after every message in the
  /// range is durable. Keeping the old cursor on even one failure makes the next history request retry
  /// that message without inventing a parallel retry queue.
  private static func advanceCursorIfClean(
    snapshot: GmailInboxSnapshot, failures: [GmailInboxMessageFailure], at date: Date,
    readStateRefreshCompletedAt: Date?,
    database: any DatabaseWriter
  ) async throws {
    guard failures.isEmpty, let historyID = snapshot.historyID else { return }
    let accountID = canonicalAccountID(snapshot.accountID)
    try await database.write { db in
      try GmailSyncState.upsert {
        GmailSyncState.Draft(
          GmailSyncState(
            accountID: accountID, historyID: historyID, updatedAt: date,
            readStateRefreshCompletedAt: readStateRefreshCompletedAt)
        )
      }.execute(db)
    }
  }

  /// Backfills the mirror only for messages in the current Today projection. A deleted Gmail message
  /// is omitted by the client; other failures leave the completion marker unset for a natural retry.
  private static func refreshTodayUnreadState(
    using refresh: @Sendable ([String]) async throws -> [String: Bool],
    at date: Date,
    database: any DatabaseWriter
  ) async -> Date? {
    do {
      let targets = try await database.read { db -> [(Artifact.ID, String)] in
        let todayIDs = Set(try TodayRequest().fetch(db).rows.map(\.id))
        guard !todayIDs.isEmpty else { return [] }
        let optionalTodayIDs: [ContentPiece.ID?] = todayIDs.map { $0 }
        return try Artifact
          .where {
            $0.transport.eq(StreamTransport.gmail) && $0.providerIsUnread.is(nil)
              && $0.contentPieceID.in(optionalTodayIDs)
          }
          .select { GmailUnreadRefreshTarget.Columns(id: $0.id, providerID: $0.providerID) }
          .fetchAll(db)
          .compactMap { target in
            guard let messageID = GmailReadStateService.messageID(from: target.providerID) else {
              return nil
            }
            return (target.id, messageID)
          }
      }
      let messageIDs = Array(Set(targets.map(\.1)))
      guard !messageIDs.isEmpty else { return date }
      let states = try await refresh(messageIDs)
      try await database.write { db in
        for (artifactID, messageID) in targets {
          guard let isUnread = states[messageID] else { continue }
          try Artifact.find(artifactID).update { $0.providerIsUnread = #bind(isUnread) }.execute(db)
        }
      }
      return date
    } catch {
      return nil
    }
  }

  private static func reconcileDepartures(
    in snapshot: GmailInboxSnapshot, at date: Date, database: any DatabaseWriter
  ) async {
    guard !snapshot.departedMessageIDs.isEmpty else { return }
    let providerIDs = snapshot.departedMessageIDs.map {
      stableProviderID(accountID: snapshot.accountID, messageID: $0)
    }
    try? await database.write { db in
      try TodayAttentionOperations.clearDeparted(providerIDs: providerIDs, at: date, in: db)
    }
  }

  private static func record(
    message: GmailInboxMessage,
    artifactID: UUID,
    accountID: String,
    acquiredAt: Date,
    namespace: UUID,
    in db: Database
  ) throws -> ContentPiece {
    let providerID = stableProviderID(accountID: accountID, messageID: message.id)
    let existingID = ContentIdentity.derive(
      for: ContentIdentityInput(
        providerStableID: providerID,
        title: message.subject,
        publisher: message.sender,
        publishedAt: message.date
      ),
      namespace: namespace
    )
    let existing = try ContentPiece.find(existingID).fetchOne(db)
    let piece = ContentPiece(
      id: existingID,
      kind: .email,
      title: message.subject,
      creator: message.sender,
      publisher: message.sender,
      publishedAt: message.date ?? existing?.publishedAt,
      canonicalURL: nil,
      summary: existing?.summary,
      subjects: existing?.subjects,
      isSubstantivePrimary: existing?.isSubstantivePrimary,
      bodyCompleteness: BodyCompletenessDetector.detect(normalizedText: message.normalizedText)
        ?? existing?.bodyCompleteness,
      createdAt: existing?.createdAt ?? acquiredAt
    )
    try ContentPiece.upsert { ContentPiece.Draft(piece) }.execute(db)
    if let text = message.normalizedText {
      try NormalizedTextOperations.store(text, for: piece.id, in: db)
    }
    try NormalizedTextOperations.supplyLibraryTextIfMissing(for: piece.id, in: db)

    let provenance = GmailArtifactProvenance.make(accountID: accountID, message: message)
    let matchedStreamID = try GmailStreamResolver.streamID(
      for: provenance, sender: message.sender, in: db)
    if let artifact = try Artifact.where({ $0.providerID.eq(providerID) }).fetchOne(db) {
      // Provider IDs are account-scoped (`gmail:<account>:message:<id>`), so they identify one
      // Artifact regardless of whether this new deterministic lookup now finds its Stream.
      try Artifact.find(artifact.id).update { row in
        row.providerIsUnread = #bind(message.labelIDs.contains("UNREAD"))
        if artifact.streamID == nil, let matchedStreamID {
          row.streamID = #bind(matchedStreamID)
        }
      }.execute(db)
    } else {
      let provenanceJSON = String(data: try JSONEncoder().encode(provenance), encoding: .utf8)
      try Artifact.insert {
        Artifact.Draft(
          Artifact(
            id: artifactID,
            streamID: matchedStreamID,
            transport: .gmail,
            providerID: providerID,
            acquiredAt: acquiredAt,
            rawSourceText: message.sourceText,
            providerProvenance: provenanceJSON,
            providerIsUnread: message.labelIDs.contains("UNREAD"),
            contentPieceID: piece.id
          )
        )
      }.execute(db)
    }
    return piece
  }

  static func stableProviderID(accountID: String, messageID: String) -> String {
    "gmail:\(canonicalAccountID(accountID)):message:\(messageID)"
  }

  static func canonicalAccountID(_ accountID: String) -> String {
    accountID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }
}
