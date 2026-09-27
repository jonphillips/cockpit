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

      model.markPresented(undeclaredID)
      await model.applySeriesTrashOnLeave(undeclaredID)
      #expect(model.rows.contains { $0.id == undeclaredID })

      model.markPresented(declaredID)
      await model.applySeriesTrashOnLeave(declaredID)
      await model.applySeriesTrashOnLeave(declaredID)
      #expect(!model.rows.contains { $0.id == declaredID })
      expectNoDifference(model.lastDisposition?.title, "Subject series-read-declared")
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
      model.markPresented(pieceID)
      await model.applySeriesTrashOnLeave(pieceID)

      // D9 reconciliation must skip a Cockpit-caused departure or Undo would be stranded.
      try await database.write { db in
        try TodayAttentionOperations.clearDeparted(providerIDs: [providerID], at: .distantPast, in: db)
      }
      let markerCount = try await database.read { db in
        try TodayAttention.where { $0.contentPieceID.eq(pieceID) }.fetchCount(db)
      }
      expectNoDifference(markerCount, 0)

      await model.undoLastDisposition()
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
      let nonSelected = try #require(inserted.last { $0.id != selected.id })
      model.selectedContentPieceID = selected.id
      await model.archive(nonSelected)
      expectNoDifference(model.selectedContentPieceID, selected.id)

      let selectedIndex = try #require(model.rows.firstIndex { $0.id == selected.id })
      let expectedNext = try #require(model.rows.dropFirst(selectedIndex + 1).first)
      await model.archive(selected)

      expectNoDifference(model.selectedContentPieceID, expectedNext.id)
      #expect(!model.rows.contains { $0.id == selected.id })
      #expect(model.lastDisposition?.contentPieceID == selected.id)
      await model.undoLastDisposition()
      expectNoDifference(model.selectedContentPieceID, selected.id)
      #expect(model.rows.contains { $0.id == selected.id })
      #expect(model.lastDisposition == nil)
    }
    #expect(log.calls.count == 3)
    #expect(log.calls.prefix(2).allSatisfy { $0.hasPrefix("archive:queue-") })
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
      let previousDisposition = TodayReadingQueueModel.LastDisposition(
        contentPieceID: UUID(), title: "Earlier issue", disposition: .trash)
      model.lastDisposition = previousDisposition
      await model.archive(row)
      expectNoDifference(model.selectedContentPieceID, pieceID)
      #expect(model.rows.contains { $0.id == pieceID })
      #expect(model.errorMessage != nil)
      expectNoDifference(model.lastDisposition, previousDisposition)
    }
  }

  @MainActor
  @Test("Undo after auto-advance does not trash the item it advanced to")
  func undoSkipsSeriesTrashForAdvancedItem() async throws {
    _ = try await seed(id: "queue-before-series", treatment: .personal, sender: "before@example.com")
    let advancedID = try await seed(
      id: "queue-series-after-advance", treatment: .newsletter, sender: "morning@example.com",
      listID: "morning.example.com")
    try await database.write { db in
      try GmailSeriesDispositionOperations.declare(
        seriesKey: "morning.example.com", at: .distantPast, in: db)
      try StreamOperations.saveRoutingRule(
        ContentRoleRoutingRule(locator: "morning.example.com", role: .dailyNews), in: db)
    }
    let log = CallLog()
    try await withDependencies {
      $0.gmailDispositionClient = log.client
    } operation: {
      let model = TodayReadingQueueModel()
      try await model.$content.load()
      _ = try #require(model.rows.first { $0.id == advancedID })
      let advancedIndex = try #require(model.rows.firstIndex { $0.id == advancedID })
      let previous = try #require(model.rows[..<advancedIndex].last { $0.isGmailSource })
      model.selectedContentPieceID = previous.id
      model.markPresented(previous.id)

      await model.archive(previous)
      expectNoDifference(model.selectedContentPieceID, advancedID)
      // This mirrors the first selection-change callback; the archived issue must not be auto-trashed.
      await model.applySeriesTrashOnLeave(previous.id)
      model.markPresented(advancedID)
      await model.undoLastDisposition()
      expectNoDifference(model.selectedContentPieceID, previous.id)
      await model.applySeriesTrashOnLeave(advancedID)

      #expect(model.rows.contains { $0.id == advancedID })
      #expect(model.lastDisposition == nil)
    }
    #expect(log.calls.count == 2)
    #expect(log.calls.first?.hasPrefix("archive:") == true)
    #expect(log.calls.last?.hasPrefix("reAddInbox:") == true)
  }

  @MainActor
  @Test("Today and Process share one disposition projection and Undo restores both")
  func todayAndProcessShareDispositionState() async throws {
    let pieceID = try await seed(
      id: "shared-projection", treatment: .personal, sender: "friend@example.com")
    let log = CallLog()

    try await withDependencies {
      $0.gmailDispositionClient = log.client
    } operation: {
      let today = TodayModel()
      let queue = TodayReadingQueueModel()
      try await today.$content.load()
      try await queue.$content.load()

      let todayRow = try #require(today.content.rows.first { $0.id == pieceID })
      let queueRow = try #require(queue.rows.first { $0.id == pieceID })

      await queue.archive(queueRow)
      try await today.$content.load()
      #expect(!today.content.rows.contains { $0.id == pieceID })

      await queue.undoLastDisposition()
      try await today.$content.load()
      #expect(today.content.rows.contains { $0.id == pieceID })
      #expect(queue.rows.contains { $0.id == pieceID })

      await today.archive(todayRow)
      await queue.reload()
      #expect(!queue.rows.contains { $0.id == pieceID })

      await today.undoDisposition(todayRow)
      await queue.reload()
      #expect(today.content.rows.contains { $0.id == pieceID })
      #expect(queue.rows.contains { $0.id == pieceID })
    }
  }

  @MainActor
  @Test("Leaving Process trashes a declared series and advances, but preserves undeclared selection")
  func leaveProcessAppliesSeriesPolicy() async throws {
    let declaredID = try await seed(
      id: "process-leave-declared", treatment: .newsletter, sender: "morning@example.com",
      listID: "morning.example.com")
    let undeclaredID = try await seed(
      id: "process-leave-undeclared", treatment: .personal, sender: "friend@example.com")
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

      model.selectedContentPieceID = declaredID
      model.markPresented(declaredID)
      let expectedNeighbour = ReadingQueueSelection.neighbour(of: declaredID, in: model.rows)
      await model.leaveProcess()

      #expect(!model.rows.contains { $0.id == declaredID })
      expectNoDifference(model.selectedContentPieceID, expectedNeighbour)

      model.selectedContentPieceID = undeclaredID
      model.markPresented(undeclaredID)
      await model.leaveProcess()
      #expect(model.rows.contains { $0.id == undeclaredID })
      expectNoDifference(model.selectedContentPieceID, undeclaredID)
    }
    expectNoDifference(log.calls, ["trash:process-leave-declared"])
  }

  @MainActor
  @Test("An off-screen Process neighbour is safe until it is actually presented")
  func offscreenNeighbourRequiresPresentation() async throws {
    for suffix in ["a", "b", "c"] {
      _ = try await seed(
        id: "presented-guard-\(suffix)", treatment: .newsletter,
        sender: "morning@example.com", listID: "presented.example.com")
    }
    try await database.write { db in
      try GmailSeriesDispositionOperations.declare(
        seriesKey: "presented.example.com", at: .distantPast, in: db)
      try StreamOperations.saveRoutingRule(
        ContentRoleRoutingRule(locator: "presented.example.com", role: .dailyNews), in: db)
    }

    let log = CallLog()
    try await withDependencies {
      $0.gmailDispositionClient = log.client
    } operation: {
      let model = TodayReadingQueueModel()
      try await model.$content.load()
      let seriesRows = model.rows.filter { $0.title.hasPrefix("Subject presented-guard-") }
      expectNoDifference(seriesRows.count, 3)
      let first = try #require(seriesRows.first)

      model.selectedContentPieceID = first.id
      model.markPresented(first.id)
      await model.leaveProcess()

      let neighbourID = try #require(model.selectedContentPieceID)
      let other = try #require(
        model.rows.first { $0.title.hasPrefix("Subject presented-guard-") && $0.id != neighbourID }
      )
      model.selectedContentPieceID = other.id
      await model.applySeriesTrashOnLeave(neighbourID)
      #expect(model.rows.contains { $0.id == neighbourID })

      model.selectedContentPieceID = neighbourID
      model.markPresented(neighbourID)
      model.selectedContentPieceID = other.id
      await model.applySeriesTrashOnLeave(neighbourID)
      #expect(!model.rows.contains { $0.id == neighbourID })
    }
    expectNoDifference(log.calls.count, 2)
    #expect(log.calls.allSatisfy { $0.hasPrefix("trash:presented-guard-") })
  }

  @MainActor
  @Test("Process from here changes selection without trashing an unseen declared-series row")
  func processFromHerePreservesUnseenSeries() async throws {
    for suffix in ["old", "target"] {
      _ = try await seed(
        id: "process-from-\(suffix)", treatment: .newsletter,
        sender: "digest@example.com", listID: "process-from.example.com")
    }
    try await database.write { db in
      try GmailSeriesDispositionOperations.declare(
        seriesKey: "process-from.example.com", at: .distantPast, in: db)
      try StreamOperations.saveRoutingRule(
        ContentRoleRoutingRule(locator: "process-from.example.com", role: .dailyNews), in: db)
    }

    let log = CallLog()
    try await withDependencies {
      $0.gmailDispositionClient = log.client
    } operation: {
      let queue = TodayReadingQueueModel()
      try await queue.$content.load()
      let rows = queue.rows.filter { $0.title.hasPrefix("Subject process-from-") }
      expectNoDifference(rows.count, 2)
      let old = try #require(rows.first)
      let target = try #require(rows.last)

      queue.selectedContentPieceID = old.id
      let shell = ShellModel()
      shell.connectProcessSelection { contentPieceID in
        if let contentPieceID { queue.selectedContentPieceID = contentPieceID }
      }
      shell.process(from: target.id)

      expectNoDifference(shell.selection, .process)
      expectNoDifference(queue.selectedContentPieceID, target.id)
      await queue.applySeriesTrashOnLeave(old.id)

      #expect(queue.rows.contains { $0.id == old.id })
      #expect(queue.rows.contains { $0.id == target.id })
    }
    #expect(log.calls.isEmpty)
  }

  @MainActor
  @Test("Closing a quick look on Process's selected series row trashes it and advances selection")
  func quickLookLeaveAdvancesProcessSelection() async throws {
    for suffix in ["a", "b"] {
      _ = try await seed(
        id: "quick-look-leave-\(suffix)", treatment: .newsletter,
        sender: "brief@example.com", listID: "quick-look.example.com")
    }
    try await database.write { db in
      try GmailSeriesDispositionOperations.declare(
        seriesKey: "quick-look.example.com", at: .distantPast, in: db)
      try StreamOperations.saveRoutingRule(
        ContentRoleRoutingRule(locator: "quick-look.example.com", role: .dailyNews), in: db)
    }

    let log = CallLog()
    try await withDependencies {
      $0.gmailDispositionClient = log.client
    } operation: {
      let queue = TodayReadingQueueModel()
      try await queue.$content.load()
      let rows = queue.rows.filter { $0.title.hasPrefix("Subject quick-look-leave-") }
      expectNoDifference(rows.count, 2)
      let selected = try #require(rows.first)
      let expectedNeighbour = ReadingQueueSelection.neighbour(of: selected.id, in: queue.rows)

      queue.selectedContentPieceID = selected.id
      await queue.applySeriesTrashOnQuickLookLeave(selected.id)

      #expect(!queue.rows.contains { $0.id == selected.id })
      expectNoDifference(queue.selectedContentPieceID, expectedNeighbour)
      #expect(queue.position != nil)
    }
    expectNoDifference(log.calls.count, 1)
    #expect(log.calls.allSatisfy { $0.hasPrefix("trash:quick-look-leave-") })
  }

  @MainActor
  @Test("Clear removes Today attention and counts as queue progress")
  func clearCountsAsDone() async throws {
    let pieceID = try await seed(
      id: "clear-counts-done", treatment: .personal, sender: "friend@example.com")
    _ = try await seed(
      id: "clear-counts-neighbour", treatment: .personal, sender: "other@example.com")
    let today = TodayModel()
    let queue = TodayReadingQueueModel()
    try await today.$content.load()
    try await queue.$content.load()
    _ = try #require(today.content.rows.first { $0.id == pieceID })
    let queueRow = try #require(queue.rows.first { $0.id == pieceID })
    let totalBefore = queue.rows.count
    queue.selectedContentPieceID = pieceID

    await queue.clear(queueRow)
    try await today.$content.load()

    #expect(!today.content.rows.contains { $0.id == pieceID })
    #expect(!queue.rows.contains { $0.id == pieceID })
    expectNoDifference(queue.doneCount, 1)
    expectNoDifference(queue.position?.total, totalBefore)
  }

  @MainActor
  @Test("Queue position tracks dispositions, completed roles, Undo, and local-day rollover")
  func queueProgress() async throws {
    _ = try await seed(id: "progress-for-you-a", treatment: .personal, sender: "a@example.com")
    _ = try await seed(id: "progress-for-you-b", treatment: .personal, sender: "b@example.com")
    for suffix in ["a", "b", "c"] {
      _ = try await seed(
        id: "progress-daily-\(suffix)", treatment: .newsletter,
        sender: "daily@example.com", listID: "daily.example.com")
    }
    try await database.write { db in
      try StreamOperations.saveRoutingRule(
        ContentRoleRoutingRule(locator: "daily.example.com", role: .dailyNews), in: db)
    }

    let log = CallLog()
    try await withDependencies {
      $0.gmailDispositionClient = log.client
    } operation: {
      let model = TodayReadingQueueModel()
      try await model.$content.load()
      model.resetDoneTrackingIfNeeded(at: Date(timeIntervalSince1970: 10_000))

      let forYouRows = model.rows.filter {
        $0.title.hasPrefix("Subject progress-for-you-")
      }
      let dailyRows = model.rows.filter {
        $0.title.hasPrefix("Subject progress-daily-")
      }
      expectNoDifference(forYouRows.count, 2)
      expectNoDifference(dailyRows.count, 3)

      model.selectedContentPieceID = dailyRows.first?.id
      for row in forYouRows {
        await model.archive(row)
      }

      expectNoDifference(model.doneCount, 2)
      expectNoDifference(model.doneRoles, [.forYou])
      expectNoDifference(model.position?.index, 3)
      expectNoDifference(model.position?.total, 5)

      await model.undoLastDisposition()
      expectNoDifference(model.doneCount, 1)
      expectNoDifference(model.doneRoles, [])
      expectNoDifference(model.position?.index, 2)
      expectNoDifference(model.position?.total, 5)

      model.resetDoneTrackingIfNeeded(at: Date(timeIntervalSince1970: 100_000))
      expectNoDifference(model.doneCount, 0)
      expectNoDifference(model.doneRoles, [])
      expectNoDifference(model.position?.index, 1)
      expectNoDifference(model.position?.total, 4)
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
      queueModel.markPresented(pieceID)
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
