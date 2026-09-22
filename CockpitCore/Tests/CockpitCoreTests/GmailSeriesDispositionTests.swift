@testable import CockpitCore
import CustomDump
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@Suite(
  .serialized,
  .dependencies {
    $0.uuid = .incrementing
    $0.date.now = Date(timeIntervalSince1970: 10_000)
    try $0.bootstrapDatabase()
  }
)
struct GmailSeriesDispositionTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("List-ID drives series identity, preserves same-sender distinctions, and falls back to sender")
  func seriesKeyNormalization() async throws {
    let first = try await seed(
      id: "series-key-first", treatment: .newsletter, sender: "digest@example.com",
      listID: "The Morning <morning.example.com>")
    let second = try await seed(
      id: "series-key-second", treatment: .newsletter, sender: "digest@example.com",
      listID: "Account Notices <account.example.com>")
    let fallback = try await seed(
      id: "series-key-fallback", treatment: .newsletter, sender: "Digest <digest@example.com>")
    let personal = try await seed(
      id: "series-key-personal", treatment: .personal, sender: "Friend <digest@example.com>",
      listID: "A List <morning.example.com>")

    let keys = try await database.read { db in
      (
        try GmailSeriesKey.seriesKey(forContentPieceID: first, in: db),
        try GmailSeriesKey.seriesKey(forContentPieceID: second, in: db),
        try GmailSeriesKey.seriesKey(forContentPieceID: fallback, in: db),
        try GmailSeriesKey.seriesKey(forContentPieceID: personal, in: db)
      )
    }
    expectNoDifference(keys.0, "morning.example.com")
    expectNoDifference(keys.1, "account.example.com")
    expectNoDifference(keys.2, "digest@example.com")
    expectNoDifference(keys.3, nil)
  }

  @MainActor
  @Test("Declaration is explicit and the model refuses non-newsletter mail")
  func declarationGuard() async throws {
    let newsletterID = try await seed(
      id: "series-declare-newsletter", treatment: .newsletter, sender: "morning@example.com",
      listID: "morning.example.com")
    let personalID = try await seed(
      id: "series-declare-personal", treatment: .personal, sender: "morning@example.com",
      listID: "morning.example.com")
    let model = TodayModel()
    try await model.$content.load()
    let newsletter = try #require(model.content.rows.first { $0.id == newsletterID })
    let personal = try #require(model.content.rows.first { $0.id == personalID })

    await model.declareSeriesTrash(for: newsletter)
    await model.declareSeriesTrash(for: personal)

    let declared = try await database.read { db in
      try GmailSeriesDispositionOperations.declaredKeys(in: db)
    }
    expectNoDifference(declared, ["morning.example.com"])
  }

  @MainActor
  @Test("Only leaving a read declared newsletter Trashes once, while unread and undeclared mail stays")
  func readTriggerAndOncePerMessage() async throws {
    let declaredID = try await seed(
      id: "series-read-declared", treatment: .newsletter, sender: "morning@example.com",
      listID: "morning.example.com")
    let unreadID = try await seed(
      id: "series-read-unread", treatment: .newsletter, sender: "morning@example.com",
      listID: "morning.example.com")
    let undeclaredID = try await seed(
      id: "series-read-undeclared", treatment: .newsletter, sender: "other@example.com",
      listID: "other.example.com")
    try await database.write { db in
      try GmailSeriesDispositionOperations.declare(
        seriesKey: "morning.example.com", at: .distantPast, in: db)
    }

    let log = CallLog()
    try await withDependencies {
      $0.gmailDispositionClient = log.client
    } operation: {
      let model = TodayReadingQueueModel()
      try await model.$content.load()
      // No leave event is sent for this piece: being declared is not itself a trigger.
      #expect(model.rows.contains { $0.id == unreadID })

      await model.applySeriesTrashOnLeave(undeclaredID)
      #expect(model.rows.contains { $0.id == undeclaredID })

      await model.applySeriesTrashOnLeave(declaredID)
      await model.applySeriesTrashOnLeave(declaredID)
      #expect(!model.rows.contains { $0.id == declaredID })
    }
    expectNoDifference(log.calls, ["trash:series-read-declared"])
  }

  @MainActor
  @Test("Undo after delta reconciliation returns an auto-trashed row and preserves custody")
  func undoAfterInterleavedReconciliation() async throws {
    let pieceID = try await seed(
      id: "series-read-undo", treatment: .newsletter, sender: "morning@example.com",
      listID: "morning.example.com")
    let providerID = "gmail:jon@example.com:message:series-read-undo"
    try await database.write { db in
      try GmailSeriesDispositionOperations.declare(
        seriesKey: "morning.example.com", at: .distantPast, in: db)
      try LaterMembership.insert {
        LaterMembership(contentPieceID: pieceID, addedAt: .distantPast)
      }.execute(db)
      try LibraryMembership.insert {
        LibraryMembership(contentPieceID: pieceID, addedAt: .distantPast, admittedBy: "explicit")
      }.execute(db)
      try PendingFind.insert {
        PendingFind(
          id: UUID(88_001), contentPieceID: pieceID, kind: "briefing",
          name: "A preserved find", descriptor: "Evidence from the briefing.",
          rationale: "The source was read before it was trashed.")
      }.execute(db)
    }

    let log = CallLog()
    try await withDependencies {
      $0.gmailDispositionClient = log.client
    } operation: {
      let model = TodayReadingQueueModel()
      try await model.$content.load()
      let row = try #require(model.rows.first { $0.id == pieceID })
      await model.applySeriesTrashOnLeave(pieceID)

      // D9 reconciliation must skip a Cockpit-caused departure or Undo would be stranded.
      try await database.write { db in
        try TodayAttentionOperations.clearDeparted(providerIDs: [providerID], at: .distantPast, in: db)
      }
      let markerCount = try await database.read { db in
        try TodayAttention.where { $0.contentPieceID.eq(pieceID) }.fetchCount(db)
      }
      expectNoDifference(markerCount, 0)

      await model.undoDisposition(row)
      #expect(model.rows.contains { $0.id == pieceID })
    }

    let custody = try await database.read { db in
      (
        try LaterMembership.find(pieceID).fetchOne(db) != nil,
        try LibraryMembership.find(pieceID).fetchOne(db) != nil,
        try PendingFind.where { $0.contentPieceID.eq(pieceID) }.fetchCount(db)
      )
    }
    expectNoDifference(custody.0, true)
    expectNoDifference(custody.1, true)
    expectNoDifference(custody.2, 1)
    expectNoDifference(log.calls, ["trash:series-read-undo", "untrash:series-read-undo"])
  }

  @MainActor
  @Test("Selected queue disposition advances and Undo restores and reselects the issue")
  func queueSelectionAndUndo() async throws {
    for suffix in ["queue-a", "queue-b", "queue-c"] {
      _ = try await seed(id: suffix, treatment: .personal, sender: "friend-\(suffix)@example.com")
    }
    let log = CallLog()
    try await withDependencies {
      $0.gmailDispositionClient = log.client
    } operation: {
      let model = TodayReadingQueueModel()
      try await model.$content.load()
      // Select two known test rows in their actual queue order, independent of older fixture rows.
      let inserted = model.rows.filter { $0.title.hasPrefix("Subject queue-") }
      let selected = try #require(inserted.first)
      let expectedNext = ReadingQueueSelection.neighbour(of: selected.id, in: model.rows)
      model.selectedContentPieceID = selected.id
      await model.archive(selected)

      expectNoDifference(model.selectedContentPieceID, expectedNext)
      #expect(!model.rows.contains { $0.id == selected.id })
      #expect(model.lastDisposition?.contentPieceID == selected.id)
      await model.undoLastDisposition()
      expectNoDifference(model.selectedContentPieceID, selected.id)
      #expect(model.rows.contains { $0.id == selected.id })
      #expect(model.lastDisposition == nil)
    }
    #expect(log.calls.count == 2)
    #expect(log.calls.first?.hasPrefix("archive:queue-") == true)
    #expect(log.calls.last?.hasPrefix("reAddInbox:queue-") == true)
  }

  @MainActor
  @Test("A failed disposition leaves the selected queue row unchanged")
  func queueSelectionSurvivesFailure() async throws {
    let pieceID = try await seed(id: "queue-failure", treatment: .personal, sender: "friend@example.com")
    let failingClient = GmailDispositionClient(
      archive: { _ in throw GmailDispositionOperations.Failure.notGmailArtifact },
      trash: { _ in throw GmailDispositionOperations.Failure.notGmailArtifact },
      reAddInbox: { _ in throw GmailDispositionOperations.Failure.notGmailArtifact },
      untrash: { _ in throw GmailDispositionOperations.Failure.notGmailArtifact }
    )
    try await withDependencies {
      $0.gmailDispositionClient = failingClient
    } operation: {
      let model = TodayReadingQueueModel()
      try await model.$content.load()
      let row = try #require(model.rows.first { $0.id == pieceID })
      model.selectedContentPieceID = pieceID
      await model.archive(row)
      expectNoDifference(model.selectedContentPieceID, pieceID)
      #expect(model.rows.contains { $0.id == pieceID })
      #expect(model.errorMessage != nil)
    }
  }

  @Test("An active archive prevents series trash-on-leave")
  func archivePreventsSeriesTrashOnLeave() async throws {
    let pieceID = try await seed(
      id: "series-already-archived", treatment: .newsletter, sender: "morning@example.com",
      listID: "morning.example.com")
    try await database.write { db in
      try GmailSeriesDispositionOperations.declare(
        seriesKey: "morning.example.com", at: .distantPast, in: db)
    }
    let log = CallLog()
    let service = GmailDispositionService(client: log.client, now: { .distantPast })
    _ = try await service.apply(.archive, toContentPieceID: pieceID, in: database)
    let didTrash = try await GmailSeriesDispositionOperations.applyTrashOnLeave(
      contentPieceID: pieceID, in: database, using: service)
    #expect(!didTrash)
    expectNoDifference(log.calls, ["archive:series-already-archived"])
  }

  @MainActor
  @Test("Un-declaring stops future read-triggered Trash")
  func undeclarationStopsFutureTrash() async throws {
    let pieceID = try await seed(
      id: "series-undeclare", treatment: .newsletter, sender: "morning@example.com",
      listID: "morning.example.com")
    try await database.write { db in
      try GmailSeriesDispositionOperations.declare(
        seriesKey: "morning.example.com", at: .distantPast, in: db)
    }
    let model = TodayModel()
    try await model.$content.load()
    let row = try #require(model.content.rows.first { $0.id == pieceID })
    await model.undeclareSeriesTrash(for: row)

    let log = CallLog()
    try await withDependencies {
      $0.gmailDispositionClient = log.client
    } operation: {
      let queueModel = TodayReadingQueueModel()
      try await queueModel.$content.load()
      await queueModel.applySeriesTrashOnLeave(pieceID)
    }
    #expect(log.calls.isEmpty)
    #expect(try await database.read { db in
      try GmailSeriesDispositionOperations.declaredKeys(in: db).contains("morning.example.com") == false
    })
  }

  @discardableResult
  private func seed(
    id: String, treatment: EmailTreatment, sender: String, listID: String? = nil
  ) async throws -> ContentPiece.ID {
    let pieceID = UUID()
    let provenance = GmailArtifactProvenance(
      accountID: "jon@example.com", messageID: id, threadID: "thread-\(id)",
      rfcMessageID: nil, listUnsubscribe: listID == nil ? nil : "<https://example.com/unsubscribe>",
      listID: listID, precedence: listID == nil ? nil : "bulk",
      senderAddress: sender, sendingDomain: "example.com", dkimDomain: "example.com",
      toRecipientCount: listID == nil ? 1 : 3, ccRecipientCount: 0)
    let provenanceJSON = String(
      data: try JSONEncoder().encode(provenance), encoding: .utf8)
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          id: pieceID, kind: .email, title: "Subject \(id)", creator: sender,
          publisher: sender, publishedAt: .distantPast, emailTreatment: treatment,
          createdAt: .distantPast)
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(
          id: UUID(), transport: .gmail,
          providerID: "gmail:jon@example.com:message:\(id)", acquiredAt: .distantPast,
          rawSourceText: "<p>Readable body.</p>", providerProvenance: provenanceJSON,
          contentPieceID: pieceID)
      }.execute(db)
    }
    return pieceID
  }
}
