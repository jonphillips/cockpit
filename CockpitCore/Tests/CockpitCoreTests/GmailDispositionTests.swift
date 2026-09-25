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
    $0.date.now = Date(timeIntervalSince1970: 10_000)
    try $0.bootstrapDatabase()
  }
)
struct GmailDispositionTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("The only dispositions are Leave/Archive/Trash — no permanent delete (D5)")
  func noDeleteForever() {
    expectNoDifference(Set(GmailSourceDisposition.allCases), [.leave, .archive, .trash])
  }

  @Test("Leave mutates nothing and records nothing (D5)")
  func leaveIsNoOp() async throws {
    let log = CallLog()
    let service = GmailDispositionService(client: log.client, now: { .distantPast })
    let pieceID = try await seedGmailMessage(id: "message-leave")

    let entry = try await service.apply(.leave, toContentPieceID: pieceID, in: database)

    expectNoDifference(entry, nil)
    expectNoDifference(log.calls, [])
    let logged = try await database.read { db in try GmailDispositionLogEntry.fetchCount(db) }
    expectNoDifference(logged, 0)
  }

  @Test("Archive applies the label operation, logs it once, and re-applying is idempotent (D5)")
  func archiveAppliesAndIsIdempotent() async throws {
    let log = CallLog()
    let service = GmailDispositionService(client: log.client, now: { .distantPast })
    let pieceID = try await seedGmailMessage(id: "message-archive")

    let first = try await service.apply(.archive, toContentPieceID: pieceID, in: database)
    let second = try await service.apply(.archive, toContentPieceID: pieceID, in: database)

    // Applied once against the message, recorded once, and the repeat re-used the same log entry.
    expectNoDifference(log.calls, ["archive:message-archive"])
    expectNoDifference(first?.operation, .archive)
    expectNoDifference(first?.providerID, "gmail:jon@example.com:message:message-archive")
    expectNoDifference(first?.id, second?.id)
    // The disposition is inspectable through the recent-log surface Undo is offered from (D6).
    let entries = try await database.read { db in try GmailDispositionOperations.recent(in: db) }
    expectNoDifference(entries.count, 1)
    expectNoDifference(entries.first?.reversedAt, nil)
    expectNoDifference(entries.first?.id, first?.id)
  }

  @Test("The barrier refuses to mutate when the promised durable result is not committed (D4)")
  func barrierRefusesUncommittedResult() async throws {
    let log = CallLog()
    let service = GmailDispositionService(client: log.client, now: { .distantPast })
    // A message whose promised durable result was never committed — a failed per-message ingest
    // commit leaves no ContentPiece to resolve, so there is nothing safe to dispose.
    let uncommittedPieceID = UUID(999)

    await #expect(throws: GmailDispositionOperations.Failure.resultNotCommitted) {
      try await service.apply(.archive, toContentPieceID: uncommittedPieceID, in: database)
    }

    // No mutation was attempted, and nothing was logged: the message keeps INBOX and re-enters sync.
    expectNoDifference(log.calls, [])
    let logged = try await database.read { db in try GmailDispositionLogEntry.fetchCount(db) }
    expectNoDifference(logged, 0)
  }

  @Test("Undo issues the inverse operation, stamps the log, and is itself idempotent (D6)")
  func undoReversesViaInverseAndStamps() async throws {
    let log = CallLog()
    let service = GmailDispositionService(client: log.client, now: { .distantPast })
    let pieceID = try await seedGmailMessage(id: "message-trash")

    let entry = try #require(try await service.apply(.trash, toContentPieceID: pieceID, in: database))
    try await service.undo(entry, in: database)

    // Trash then its inverse untrash; the log entry is now stamped reversed.
    expectNoDifference(log.calls, ["trash:message-trash", "untrash:message-trash"])
    let reversed = try await database.read { db in
      try GmailDispositionLogEntry.find(entry.id).fetchOne(db)
    }
    #expect(reversed?.reversedAt != nil)

    // Re-undoing the now-reversed entry issues no further provider mutation.
    let reloaded = try #require(reversed)
    try await service.undo(reloaded, in: database)
    expectNoDifference(log.calls, ["trash:message-trash", "untrash:message-trash"])
  }

  @Test("Clear resolves Cockpit attention and never writes a provider disposition (carried from S4)")
  func clearWritesNoDisposition() async throws {
    let pieceID = try await seedGmailMessage(id: "message-clear")

    try await database.write { db in
      try TodayAttentionOperations.clear(pieceID, at: .distantPast, in: db)
    }

    let dispositions = try await database.read { db in try GmailDispositionLogEntry.fetchCount(db) }
    expectNoDifference(dispositions, 0)
    // The Gmail Artifact is untouched: Clear is attention-only, not a provider mutation.
    let stillPresent = try await database.read { db in
      try Artifact.where { $0.contentPieceID.eq(pieceID) && $0.transport.eq(StreamTransport.gmail) }
        .fetchCount(db)
    }
    expectNoDifference(stillPresent, 1)
  }

  @MainActor
  @Test("Today row menu archives and undoes the source through the injected client")
  func todayModelDispositionWiring() async throws {
    let pieceID = try await seedGmailMessage(id: "message-today")
    let log = CallLog()
    try await withDependencies {
      $0.gmailDispositionClient = log.client
    } operation: {
      let model = TodayModel()
      try await model.$content.load()
      let row = try #require(model.content.rows.first { $0.id == pieceID })
      await model.archive(row)
      await model.undoDisposition(row)
    }
    expectNoDifference(log.calls, ["archive:message-today", "reAddInbox:message-today"])
  }

  @MainActor
  @Test("Archiving from Cockpit removes the row from Today at once, and Undo returns it")
  func archivedRowLeavesTodayImmediately() async throws {
    let pieceID = try await seedGmailMessage(id: "message-vanish")
    let log = CallLog()
    try await withDependencies {
      $0.gmailDispositionClient = log.client
    } operation: {
      let model = TodayModel()
      try await model.$content.load()
      let row = try #require(model.content.rows.first { $0.id == pieceID })

      await model.archive(row)
      // The disposition log hides the archived row from the reloaded projection without waiting for
      // a Gmail sync to observe the departure.
      #expect(!model.content.rows.contains { $0.id == pieceID })

      await model.undoDisposition(row)
      // Undo reverses the log entry, so the row returns to Today.
      #expect(model.content.rows.contains { $0.id == pieceID })
    }
    expectNoDifference(log.calls, ["archive:message-vanish", "reAddInbox:message-vanish"])
  }

  @MainActor
  @Test("Reader archives and undoes the Gmail source, and offers it only for email pieces")
  func readerModelDispositionWiring() async throws {
    let pieceID = try await seedGmailMessage(id: "message-reader")
    let log = CallLog()
    try await withDependencies {
      $0.gmailDispositionClient = log.client
    } operation: {
      let model = ContentPieceReaderModel(contentPieceID: pieceID)
      try await model.$content.load()
      #expect(model.isGmailSource)
      #expect(await model.trashSource())
      await model.undoDisposition()
    }
    expectNoDifference(log.calls, ["trash:message-reader", "untrash:message-reader"])
  }

  @MainActor
  @Test("Reader reports a failed source disposition without claiming it committed")
  func readerModelDispositionFailureReturnsFalse() async throws {
    let pieceID = try await seedGmailMessage(id: "message-reader-failure")
    let failingClient = GmailDispositionClient(
      archive: { _ in throw URLError(.timedOut) },
      trash: { _ in throw URLError(.timedOut) },
      reAddInbox: { _ in throw URLError(.timedOut) },
      untrash: { _ in throw URLError(.timedOut) }
    )
    try await withDependencies {
      $0.gmailDispositionClient = failingClient
    } operation: {
      let model = ContentPieceReaderModel(contentPieceID: pieceID)
      try await model.$content.load()
      #expect(!(await model.archiveSource()))
      #expect(model.errorMessage != nil)
    }
  }

  // MARK: - Helpers

  @discardableResult
  private func seedGmailMessage(id: String) async throws -> ContentPiece.ID {
    let message = GmailInboxMessage(
      id: id, threadID: "thread-\(id)",
      headers: [
        GmailInboxHeader(name: "From", value: "Sender <sender@example.com>"),
        GmailInboxHeader(name: "Subject", value: "Subject \(id)"),
      ],
      bodyHTML: "<p>A readable body for \(id).</p>"
    )
    let snapshot = GmailInboxSnapshot(accountID: "jon@example.com", messages: [message])
    let report = try await GmailInboxIngestor(
      client: GmailInboxClient(currentInbox: { snapshot }), now: { .distantPast }
    ).ingest(into: database)
    return try #require(report.contentPieces.first).id
  }
}

/// A fake Gmail label API that records each operation by message id, standing in for the live
/// transport so the barrier and Undo are exercised without touching Gmail.
final class CallLog: Sendable {
  private let entries = Mutex<[String]>([])

  var calls: [String] { entries.withLock { $0 } }

  var client: GmailDispositionClient {
    GmailDispositionClient(
      archive: { id in self.record("archive:\(id)") },
      trash: { id in self.record("trash:\(id)") },
      reAddInbox: { id in self.record("reAddInbox:\(id)") },
      untrash: { id in self.record("untrash:\(id)") }
    )
  }

  private func record(_ call: String) { entries.withLock { $0.append(call) } }
}
