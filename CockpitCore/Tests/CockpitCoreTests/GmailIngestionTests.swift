@testable import CockpitCore
import CustomDump
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Synchronization
import Testing

@Suite(
  .serialized,
  .dependencies {
    $0.uuid = .incrementing
    try $0.bootstrapDatabase()
  }
)
struct GmailIngestionTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("Inbox messages become one provider Artifact and derived email ContentPiece")
  func inboxMessageUsesExistingPersistenceSpine() async throws {
    let snapshot = sampleSnapshot
    let ingestor = GmailInboxIngestor(
      client: GmailInboxClient(currentInbox: { snapshot }),
      identityNamespace: UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!,
      now: { Date(timeIntervalSince1970: 1) }
    )

    let first = try await ingestor.ingest(into: database)
    let second = try await ingestor.ingest(into: database)

    expectNoDifference(first.messageCount, 1)
    expectNoDifference(first.pageCount, 2)
    expectNoDifference(first.historyID, "history-7")
    expectNoDifference(first.contentPieces.map(\.id), second.contentPieces.map(\.id))
    let expectedProviderID = "gmail:jon@example.com:message:message-1"
    let expectedID = ContentIdentity.derive(
      for: ContentIdentityInput(providerStableID: expectedProviderID, title: "Inbox dispatch", publisher: "Dispatch <letters@example.com>"),
      namespace: UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!
    )
    expectNoDifference(first.contentPieces.first?.id, expectedID)

    try await database.read { db in
      let persistedPiece = try ContentPiece.find(expectedID).fetchOne(db)
      let piece = try #require(persistedPiece)
      expectNoDifference(piece.kind, .email)
      expectNoDifference(piece.emailTreatment, .newsletter)
      expectNoDifference(piece.bodyCompleteness, .full)
      expectNoDifference(try NormalizedTextOperations.text(for: piece.id, in: db), "A readable email body.")
      let artifacts = try Artifact.where { $0.contentPieceID.eq(piece.id) }.fetchAll(db)
      expectNoDifference(artifacts.count, 1)
      let artifact = try #require(artifacts.first)
      expectNoDifference(artifact.id == piece.id, false)
      expectNoDifference(artifact.transport, .gmail)
      expectNoDifference(artifact.providerID, expectedProviderID)
      expectNoDifference(artifact.rawSourceText, "<p>A readable <strong>email</strong> body.</p>")
      let provenance = try JSONDecoder().decode(
        GmailArtifactProvenance.self, from: try #require(artifact.providerProvenance?.data(using: .utf8))
      )
      expectNoDifference(provenance.accountID, "jon@example.com")
      expectNoDifference(provenance.messageID, "message-1")
      expectNoDifference(provenance.threadID, "thread-1")
      expectNoDifference(provenance.rfcMessageID, "<rfc-1@example.com>")
      expectNoDifference(provenance.listUnsubscribe, "<https://example.com/unsubscribe>")
      expectNoDifference(provenance.listID, "Letters <letters.example.com>")
      expectNoDifference(provenance.precedence, "bulk")
      expectNoDifference(provenance.sendingDomain, "example.com")
      expectNoDifference(provenance.dkimDomain, "example.com")
      expectNoDifference(provenance.toRecipientCount, 2)
      expectNoDifference(provenance.ccRecipientCount, 1)
    }
  }

  @Test("Gmail UNREAD labels are mirrored on insert and every re-read")
  func unreadMirrorTracksMessageLabels() async throws {
    let unread = GmailInboxSnapshot(
      accountID: "jon@example.com", historyID: "read-state-1",
      messages: [Self.message(id: "read-state-message", unread: true)])
    let read = GmailInboxSnapshot(
      accountID: "jon@example.com", historyID: "read-state-2",
      messages: [Self.message(id: "read-state-message", unread: false)])
    let ingestor = GmailInboxIngestor(
      client: GmailInboxClient(
        currentInbox: { unread },
        inboxChanges: { _, _ in read }
      ), now: { Date(timeIntervalSince1970: 10) }
    )

    let first = try await ingestor.ingest(into: database)
    let pieceID = try #require(first.contentPieces.first?.id)
    var artifacts = try await database.read { db in
      try Artifact.where { $0.contentPieceID.eq(pieceID) }.fetchAll(db)
    }
    #expect(artifacts.first?.providerIsUnread == true)
    try await database.write { db in
      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(), transport: .gmail,
          providerID: "gmail:jon@example.com:message:read-state-second",
          acquiredAt: Date(timeIntervalSince1970: 11), providerIsUnread: false,
          contentPieceID: pieceID
        ))
      }.execute(db)
    }
    let queue = try await database.read { db in try TodayReadingQueueRequest().fetch(db).rows }
    #expect(queue.first(where: { $0.id == pieceID })?.isUnread == true)

    _ = try await ingestor.ingest(into: database)
    artifacts = try await database.read { db in
      try Artifact.where { $0.contentPieceID.eq(pieceID) }.fetchAll(db)
    }
    #expect(artifacts.first?.providerIsUnread == false)
    let today = try await database.read { db in try TodayRequest().fetch(db).rows }
    #expect(today.first(where: { $0.id == pieceID })?.isUnread == false)
  }

  @Test("legacy Today unread refresh runs once and records completion")
  func legacyUnreadRefreshRunsOnce() async throws {
    let snapshot = GmailInboxSnapshot(
      accountID: "jon@example.com", historyID: "refresh-1",
      messages: [Self.message(id: "refresh-message", unread: false)])
    let calls = Mutex<[[String]]>([])
    let initialIngestor = GmailInboxIngestor(
      client: GmailInboxClient(currentInbox: { snapshot }),
      now: { Date(timeIntervalSince1970: 20) }
    )
    let report = try await initialIngestor.ingest(into: database)
    let pieceID = try #require(report.contentPieces.first?.id)
    try await database.write { db in
      try Artifact.where { $0.contentPieceID.eq(pieceID) }
        .update { $0.providerIsUnread = #bind(nil as Bool?) }.execute(db)
    }
    let refreshIngestor = GmailInboxIngestor(
      client: GmailInboxClient(
        currentInbox: { snapshot },
        inboxChanges: { _, _ in
          GmailInboxSnapshot(accountID: "jon@example.com", historyID: "refresh-2", messages: [])
        },
        refreshUnreadStates: { ids in
          calls.withLock { $0.append(ids) }
          return Dictionary(uniqueKeysWithValues: ids.map { ($0, true) })
        }
      ), now: { Date(timeIntervalSince1970: 20) }
    )

    _ = try await refreshIngestor.ingest(into: database)
    _ = try await refreshIngestor.ingest(into: database)
    #expect(calls.withLock { $0.count } == 1)
    #expect(calls.withLock { $0.first } == ["refresh-message"])
    let cursor = try await database.read { db in try GmailSyncState.all.fetchAll(db).first }
    #expect(cursor?.readStateRefreshCompletedAt == Date(timeIntervalSince1970: 20))
    let today = try await database.read { db in try TodayRequest().fetch(db).rows }
    #expect(today.first(where: { $0.id == pieceID })?.isUnread == true)
  }

  @Test("read state service marks only mirrored unread messages and leaves failures unchanged")
  func readStateServiceMutatesMirrorQuietly() async throws {
    let ingestor = GmailInboxIngestor(
      client: GmailInboxClient(currentInbox: {
        GmailInboxSnapshot(
          accountID: "jon@example.com",
          messages: [Self.message(id: "service-unread", unread: true)]
        )
      }), now: { Date(timeIntervalSince1970: 30) }
    )
    let report = try await ingestor.ingest(into: database)
    let pieceID = try #require(report.contentPieces.first?.id)
    let calls = Mutex<[String]>([])
    let service = GmailReadStateService(client: GmailReadStateClient(
      markRead: { messageID in
        calls.withLock { $0.append("read:\(messageID)") }
        throw TestReadStateError.offline
      },
      markUnread: { messageID in calls.withLock { $0.append("unread:\(messageID)") } }
    ))

    await service.markReadOnOpen(contentPieceID: pieceID, in: database)
    #expect(calls.withLock { $0 } == ["read:service-unread"])
    var artifact = try await database.read { db in
      try Artifact.where { $0.contentPieceID.eq(pieceID) }.fetchOne(db)
    }
    #expect(artifact?.providerIsUnread == true)

    await service.markUnread(contentPieceID: pieceID, in: database)
    #expect(calls.withLock { $0.last } == "unread:service-unread")
    artifact = try await database.read { db in
      try Artifact.where { $0.contentPieceID.eq(pieceID) }.fetchOne(db)
    }
    #expect(artifact?.providerIsUnread == true)
  }

  @Test("Missing body is an honest teaser while classification headers remain readable")
  func bodylessMessageRetainsProvenance() async throws {
    let message = GmailInboxMessage(
      id: "message-2", threadID: "thread-2",
      headers: [
        GmailInboxHeader(name: "From", value: "Jordan <jordan@friends.example>"),
        GmailInboxHeader(name: "Subject", value: "Dinner"),
        GmailInboxHeader(name: "To", value: "jon@example.com"),
      ]
    )
    let snapshot = GmailInboxSnapshot(accountID: "jon@example.com", messages: [message])
    let report = try await GmailInboxIngestor(
      client: GmailInboxClient(currentInbox: { snapshot }), now: { .distantPast }
    ).ingest(into: database)

    expectNoDifference(report.contentPieces.first?.bodyCompleteness, .teaser)
    let contentPieceID = try #require(report.contentPieces.first).id
    let artifact = try await database.read { db in
      try Artifact.where { $0.contentPieceID.eq(contentPieceID) }.fetchOne(db)
    }
    let provenance = try JSONDecoder().decode(
      GmailArtifactProvenance.self, from: try #require(artifact?.providerProvenance?.data(using: .utf8))
    )
    expectNoDifference(provenance.sendingDomain, "friends.example")
    expectNoDifference(provenance.toRecipientCount, 1)
    expectNoDifference(provenance.ccRecipientCount, 0)
  }

  @Test("Delta keeps changed messages by Primary membership, not by category label")
  func deltaSelectsByPrimaryMembership() {
    // "updates-in-primary" is a message Gmail tagged CATEGORY_UPDATES but folds into the Primary tab
    // (the account has no Updates tab). The old label-exclusion heuristic dropped it; selecting by
    // `category:primary` membership keeps it. A message that just left Primary is dropped though it
    // still appears as a change, and order is preserved.
    let changed = ["updates-in-primary", "personal", "archived-left-primary", "promo-not-primary"]
    let primary: Set<String> = ["personal", "updates-in-primary"]
    expectNoDifference(
      GmailInboxAPI.primaryChangedIDs(changedIDs: changed, primaryInboxIDs: primary),
      ["updates-in-primary", "personal"]
    )
    // The complement is the departure set: changed messages no longer in Primary (archived/trashed in
    // Gmail). Order is preserved, and messages still in Primary are never treated as departed.
    expectNoDifference(
      GmailInboxAPI.departedChangedIDs(changedIDs: changed, primaryInboxIDs: primary),
      ["archived-left-primary", "promo-not-primary"]
    )
  }

  @Test("A message trashed in Gmail is reconciled out of Today on the next delta sync")
  func departedMessageIsClearedFromToday() async throws {
    let client = GmailInboxClient(
      currentInbox: {
        GmailInboxSnapshot(
          accountID: "jon@example.com", historyID: "h1",
          messages: [Self.simpleMessage(id: "message-1", threadID: "thread-1", subject: "Morning")]
        )
      },
      inboxChanges: { _, _ in
        // The delta observed message-1 change (it left Primary in Gmail) and carried no new mail.
        GmailInboxSnapshot(
          accountID: "jon@example.com", historyID: "h2",
          messages: [], departedMessageIDs: ["message-1"]
        )
      }
    )
    let ingestor = GmailInboxIngestor(client: client, now: { Date(timeIntervalSince1970: 1) })

    // First sync lands message-1 on Today.
    let first = try await ingestor.ingest(into: database)
    let pieceID = try #require(first.contentPieces.first).id
    let beforeRows = try await database.read { db in try TodayRequest().fetch(db).rows }
    expectNoDifference(beforeRows.map(\.id), [pieceID])

    // Second sync reconciles the Gmail-side departure: the row leaves Today, but the Artifact and
    // ContentPiece are untouched (custody is not a Today decision) and no provider write is made.
    _ = try await ingestor.ingest(into: database)
    let afterRows = try await database.read { db in try TodayRequest().fetch(db).rows }
    expectNoDifference(afterRows, [])
    let cleared = try await database.read { db in try TodayAttention.all.fetchAll(db).map(\.contentPieceID) }
    expectNoDifference(cleared, [pieceID])
    let artifacts = try await database.read { db in
      try Artifact.where { $0.contentPieceID.eq(pieceID) }.fetchCount(db)
    }
    expectNoDifference(artifacts, 1)
    let dispositions = try await database.read { db in try GmailDispositionLogEntry.fetchCount(db) }
    expectNoDifference(dispositions, 0)
  }

  @Test("A Cockpit archive that Gmail later reports departed is still restored by Undo (D9)")
  func cockpitArchiveIsNotStrandedByReconciliation() async throws {
    let client = GmailInboxClient(
      currentInbox: {
        GmailInboxSnapshot(
          accountID: "jon@example.com", historyID: "h1",
          messages: [Self.simpleMessage(id: "message-1", threadID: "thread-1", subject: "Morning")]
        )
      },
      inboxChanges: { _, _ in
        // Cockpit's Archive removed INBOX in Gmail, so the next delta reports message-1 as departed —
        // exactly like an external archive. Reconciliation must tell the two apart.
        GmailInboxSnapshot(
          accountID: "jon@example.com", historyID: "h2",
          messages: [], departedMessageIDs: ["message-1"]
        )
      }
    )
    let ingestor = GmailInboxIngestor(client: client, now: { Date(timeIntervalSince1970: 1) })
    let first = try await ingestor.ingest(into: database)
    let pieceID = try #require(first.contentPieces.first).id

    // Archive from Cockpit: the barrier writes the reversible log entry, and TodayRequest hides the row.
    let log = CallLog()
    let service = GmailDispositionService(client: log.client, now: { Date(timeIntervalSince1970: 2) })
    _ = try await service.apply(.archive, toContentPieceID: pieceID, in: database)
    let afterArchive = try await database.read { db in try TodayRequest().fetch(db).rows }
    expectNoDifference(afterArchive, [])

    // A delta sync now reports the Gmail-side departure. Because Cockpit caused it (an un-reversed
    // disposition), reconciliation must NOT record a terminal attention marker (D9): doing so would
    // shadow the reversible log entry and strand the row off Today after Undo.
    _ = try await ingestor.ingest(into: database)
    let markers = try await database.read { db in
      try TodayAttention.all.fetchAll(db).map(\.contentPieceID)
    }
    expectNoDifference(markers, [])

    // Undo reverses the disposition and returns the row to Today.
    let entry = try #require(
      try await database.read { db in
        try GmailDispositionOperations.activeDisposition(forContentPieceID: pieceID, in: db)
      })
    try await service.undo(entry, in: database)
    let afterUndo = try await database.read { db in try TodayRequest().fetch(db).rows }
    expectNoDifference(afterUndo.map(\.id), [pieceID])
    expectNoDifference(log.calls, ["archive:message-1", "reAddInbox:message-1"])
  }

  @Test("Delta sync: once a cursor commits, a re-read goes through history.list and never re-lists the Inbox")
  func deltaSyncReadsFromCommittedCursor() async throws {
    let listCalls = Mutex(0)
    let deltaArgs = Mutex<[String]>([])
    let client = GmailInboxClient(
      currentInbox: {
        listCalls.withLock { $0 += 1 }
        return GmailInboxSnapshot(
          accountID: "Jon@Example.com", historyID: "h1",
          messages: [Self.simpleMessage(id: "message-1", threadID: "thread-1", subject: "First")]
        )
      },
      inboxChanges: { accountID, historyID in
        deltaArgs.withLock { $0.append("\(accountID)@\(historyID)") }
        return GmailInboxSnapshot(
          accountID: "jon@example.com", historyID: "h2",
          messages: [Self.simpleMessage(id: "message-2", threadID: "thread-2", subject: "Reply")]
        )
      }
    )
    let ingestor = GmailInboxIngestor(client: client, now: { Date(timeIntervalSince1970: 1) })

    _ = try await ingestor.ingest(into: database)
    // Cursor advanced to h1 on the first commit; the account is canonicalized before it is stored.
    let firstCursor = try await database.read { db in try GmailSyncState.all.fetchAll(db) }
    expectNoDifference(firstCursor.map(\.accountID), ["jon@example.com"])
    expectNoDifference(firstCursor.map(\.historyID), ["h1"])

    _ = try await ingestor.ingest(into: database)

    // The full-Inbox list ran exactly once; the second read went through history.list with the
    // committed cursor, and the cursor advanced only after that delta committed.
    expectNoDifference(listCalls.withLock { $0 }, 1)
    expectNoDifference(deltaArgs.withLock { $0 }, ["jon@example.com@h1"])
    let secondCursor = try await database.read { db in try GmailSyncState.all.fetchAll(db) }
    expectNoDifference(secondCursor.map(\.historyID), ["h2"])
  }

  @Test("Partial commit: a per-message failure keeps the range and re-enters, without discarding its neighbours")
  func partialCommitPreservesCursorAndReEnters() async throws {
    let deltaArgs = Mutex<[String]>([])
    let client = GmailInboxClient(
      currentInbox: {
        GmailInboxSnapshot(
          accountID: "jon@example.com", historyID: "h1",
          messages: [Self.simpleMessage(id: "message-1", threadID: "thread-1", subject: "Clean")]
        )
      },
      inboxChanges: { _, historyID in
        deltaArgs.withLock { $0.append(historyID) }
        return GmailInboxSnapshot(
          accountID: "jon@example.com", historyID: "h2",
          messages: [Self.simpleMessage(id: "message-2", threadID: "thread-2", subject: "Committed")],
          failures: [GmailInboxMessageFailure(messageID: "message-3", description: "Read failed.")]
        )
      }
    )
    let ingestor = GmailInboxIngestor(client: client, now: { Date(timeIntervalSince1970: 1) })

    // A clean first sync commits its cursor at h1.
    _ = try await ingestor.ingest(into: database)

    // The delta sync reads a good message alongside a failed one.
    let report = try await ingestor.ingest(into: database)

    // The good neighbour is committed even though the batch carried a failure.
    expectNoDifference(report.messageCount, 1)
    expectNoDifference(report.failures.map(\.messageID), ["message-3"])
    let committed = try await database.read { db in
      try ContentPiece.where { $0.title.eq("Committed") }.fetchCount(db)
    }
    expectNoDifference(committed, 1)

    // The cursor stays at h1 because the range did not fully commit, so the failure re-enters.
    let cursor = try await database.read { db in try GmailSyncState.all.fetchAll(db) }
    expectNoDifference(cursor.map(\.historyID), ["h1"])

    // A subsequent sync re-requests the same history range rather than advancing past the failure.
    _ = try await ingestor.ingest(into: database)
    expectNoDifference(deltaArgs.withLock { $0 }, ["h1", "h1"])
  }

  private static func simpleMessage(id: String, threadID: String, subject: String) -> GmailInboxMessage {
    GmailInboxMessage(
      id: id, threadID: threadID,
      headers: [
        GmailInboxHeader(name: "From", value: "Sender <sender@example.com>"),
        GmailInboxHeader(name: "Subject", value: subject),
      ]
    )
  }

  private static func message(id: String, unread: Bool) -> GmailInboxMessage {
    GmailInboxMessage(
      id: id, threadID: "thread-\(id)",
      headers: [
        GmailInboxHeader(name: "From", value: "Sender <sender@example.com>"),
        GmailInboxHeader(name: "Subject", value: "Read state \(id)"),
      ],
      bodyPlainText: "An email body.", labelIDs: unread ? ["INBOX", "UNREAD"] : ["INBOX"]
    )
  }

  private enum TestReadStateError: Error { case offline }

  private var sampleSnapshot: GmailInboxSnapshot {
    GmailInboxSnapshot(
      accountID: "Jon@Example.com", historyID: "history-7", pageCount: 2,
      messages: [
        GmailInboxMessage(
          id: "message-1", threadID: "thread-1",
          headers: [
            GmailInboxHeader(name: "From", value: "Dispatch <letters@example.com>"),
            GmailInboxHeader(name: "Subject", value: "Inbox dispatch"),
            GmailInboxHeader(name: "Date", value: "Tue, 16 Sep 2026 10:00:00 -0400"),
            GmailInboxHeader(name: "Message-ID", value: "<rfc-1@example.com>"),
            GmailInboxHeader(name: "List-Unsubscribe", value: "<https://example.com/unsubscribe>"),
            GmailInboxHeader(name: "List-ID", value: "Letters <letters.example.com>"),
            GmailInboxHeader(name: "Precedence", value: "bulk"),
            GmailInboxHeader(name: "DKIM-Signature", value: "v=1; d=example.com; s=mail;"),
            GmailInboxHeader(name: "To", value: "jon@example.com, assistant@example.com"),
            GmailInboxHeader(name: "Cc", value: "copy@example.com"),
          ],
          bodyHTML: "<p>A readable <strong>email</strong> body.</p>"
        ),
      ]
    )
  }
}
