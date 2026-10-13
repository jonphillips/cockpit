@testable import CockpitCore
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Synchronization
import Testing

@Suite(.serialized, .dependencies {
  $0.uuid = .incrementing
  $0.date.now = Date(timeIntervalSince1970: 10_000)
  try $0.bootstrapDatabase()
})
@MainActor
struct GmailDispositionQueueTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("Queue hides immediately, caps concurrency at four, and drops duplicate live IDs")
  func boundedQueueAndDeduplication() async throws {
    let ids = try await seed(7, prefix: "bounded")
    let gate = DispositionGate()
    let queue = GmailDispositionQueue()
    try await withDependencies {
      $0.gmailDispositionClient = gate.client
    } operation: {
      let batchID = try #require(queue.submit(
        .trash, contentPieceIDs: Array(ids.prefix(5)), origin: .offerReview(.offers)))
      let secondBatchID = try #require(queue.submit(
        .trash, contentPieceIDs: Array(ids.suffix(2)), origin: .offerReview(.wine)))
      #expect(queue.hiddenContentPieceIDs == Set(ids))
      #expect(queue.submit(.trash, contentPieceIDs: ids, origin: .offerReview(.offers)) == nil)
      await gate.waitForStarted(4)
      #expect(await gate.snapshot().maximumInFlight == 4)
      #expect(await gate.snapshot().started.count == 4)
      await gate.open()
      await queue.waitForSettlement(batchID)
      await queue.waitForSettlement(secondBatchID)
      #expect(await gate.snapshot().started.count == 7)
      #expect(queue.batches.map(\.applied.count).sorted() == [2, 5])
      #expect(queue.hiddenContentPieceIDs.isEmpty)
      #expect(queue.alert == nil)
    }
  }

  @Test("Undo while running stops unstarted messages and reverses in-flight successes")
  func undoRunningBatch() async throws {
    let ids = try await seed(6, prefix: "undo-running")
    let gate = DispositionGate()
    let queue = GmailDispositionQueue()
    try await withDependencies {
      $0.gmailDispositionClient = gate.client
    } operation: {
      let batchID = try #require(queue.submit(.trash, contentPieceIDs: ids, origin: .offerReview(.offers)))
      await gate.waitForStarted(4)
      let undoTask = Task { await queue.undo(batchID) }
      while queue.batches.first?.phase != .undoing { await Task.yield() }
      await gate.open()
      await undoTask.value
      let snapshot = await gate.snapshot()
      #expect(snapshot.started.count == 4)
      #expect(snapshot.trashed.count == 4)
      #expect(snapshot.untrashed.count == 4)
      #expect(queue.batches.isEmpty)
      #expect(queue.hiddenContentPieceIDs.isEmpty)
      #expect(queue.alert == nil)
    }
  }

  @Test("Partial failure returns failed rows while applied messages remain hidden by the log")
  func partialFailure() async throws {
    let ids = try await seed(3, prefix: "partial-queue")
    let failedID = ids[1]
    let calls = QueueCallLog(failingTrashID: "partial-queue-1")
    let queue = GmailDispositionQueue()
    try await withDependencies {
      $0.gmailDispositionClient = calls.client
    } operation: {
      let batchID = try #require(queue.submit(.trash, contentPieceIDs: ids, origin: .offerReview(.offers)))
      await queue.waitForSettlement(batchID)
      let batch = try #require(queue.batches.first)
      #expect(batch.applied.count == 2)
      #expect(batch.failures.map(\.contentPieceID) == [failedID])
      #expect(queue.hiddenContentPieceIDs.isEmpty)
      #expect(queue.alert?.title == "Couldn't trash 1 of 3 emails")
      var active: [GmailDispositionLogEntry?] = []
      for id in ids {
        active.append(try await database.read { db in
          try GmailDispositionOperations.activeDisposition(forContentPieceID: id, in: db)
        })
      }
      #expect(active.filter { $0 != nil }.count == 2)
      queue.clearAlert()
      await queue.undo(batchID)
      #expect(queue.batches.isEmpty)
      #expect(queue.alert == nil)
    }
    #expect(await calls.snapshot().filter { $0.hasPrefix("trash:") }.count == 3)
  }

  @Test("Total failure leaves every row available and exposes only an alert")
  func totalFailure() async throws {
    let ids = try await seed(2, prefix: "total-queue")
    let client = GmailDispositionClient(
      archive: { _ in throw URLError(.timedOut) },
      trash: { _ in throw URLError(.timedOut) },
      reAddInbox: { _ in throw URLError(.timedOut) },
      untrash: { _ in throw URLError(.timedOut) })
    let queue = GmailDispositionQueue()
    try await withDependencies { $0.gmailDispositionClient = client } operation: {
      let batchID = try #require(queue.submit(.trash, contentPieceIDs: ids, origin: .offerReview(.offers)))
      await queue.waitForSettlement(batchID)
      #expect(queue.batches.isEmpty)
      #expect(queue.hiddenContentPieceIDs.isEmpty)
      #expect(queue.alert?.title == "Couldn't trash 2 of 2 emails")
    }
  }

  @Test("Undo failure keeps unrestored entries available for another restore attempt")
  func undoCanBeRetriedAfterFailure() async throws {
    let ids = try await seed(1, prefix: "undo-retry")
    let queue = GmailDispositionQueue()
    try await withDependencies {
      $0.gmailDispositionClient = UndoRetryClient.client
    } operation: {
      let batchID = try #require(queue.submit(.trash, contentPieceIDs: ids))
      await queue.waitForSettlement(batchID)
      await queue.undo(batchID)
      #expect(queue.batches.first?.applied.count == 1)
      #expect(queue.alert?.title == "Couldn't restore 1 of 1 emails")
      queue.clearAlert()
      await queue.undo(batchID)
      #expect(queue.batches.isEmpty)
      #expect(queue.alert == nil)
    }
  }

  @Test("Applied IDs remain hidden until the log-filtered projection can hide them")
  func noFlickerAcrossSettlement() async throws {
    let ids = try await seed(2, prefix: "no-flicker")
    let queue = GmailDispositionQueue()
    let owner = NSObject()
    var projectionRemainedHidden = true
    queue.registerReloadHandler(owner: owner) { [weak queue] in
      guard let queue else { return }
      do {
        let loggedIDs = Set(try await self.activeDispositionIDs(for: ids))
        projectionRemainedHidden = ids.allSatisfy {
          queue.hiddenContentPieceIDs.contains($0) || loggedIDs.contains($0)
        }
      } catch {
        projectionRemainedHidden = false
      }
    }
    try await withDependencies {
      $0.gmailDispositionClient = QueueCallLog().client
    } operation: {
      let batchID = try #require(queue.submit(.trash, contentPieceIDs: ids))
      await queue.waitForSettlement(batchID)
      #expect(projectionRemainedHidden)
      #expect(queue.hiddenContentPieceIDs.isEmpty)
    }
  }

  @Test("Offer review batches are scoped to the model and settled history is pruned")
  func originScopingAndPruning() async throws {
    let ids = try await seed(3, prefix: "origins")
    let queue = GmailDispositionQueue()
    try await withDependencies {
      $0.gmailDispositionClient = QueueCallLog().client
    } operation: {
      let firstRowBatch = try #require(queue.submit(.trash, contentPieceIDs: [ids[0]]))
      await queue.waitForSettlement(firstRowBatch)
      let rowUndoOwner = NSObject()
      queue.setBatchReference(firstRowBatch, owner: rowUndoOwner)
      let secondRowBatch = try #require(queue.submit(.trash, contentPieceIDs: [ids[1]]))
      await queue.waitForSettlement(secondRowBatch)
      #expect(Set(queue.batches.map(\.id)) == Set([firstRowBatch, secondRowBatch]))
      queue.setBatchReference(nil, owner: rowUndoOwner)
      #expect(queue.batches.map(\.id) == [secondRowBatch])

      let rowBatchForWine = try #require(queue.submit(.trash, contentPieceIDs: [ids[2]]))
      await queue.waitForSettlement(rowBatchForWine)
      let wineReview = OfferReviewModel(role: .wine, dispositionQueue: queue)
      #expect(wineReview.batch == nil)

      let reviewBatch = try #require(queue.submit(
        .trash, contentPieceIDs: [ids[2]], origin: .offerReview(.wine)))
      await queue.waitForSettlement(reviewBatch)
      let reopenedReview = OfferReviewModel(role: .wine, dispositionQueue: queue)
      #expect(reopenedReview.batch == nil)
      #expect(queue.offerReviewBatches.map(\.id) == [reviewBatch])
    }
  }

  private func seed(_ count: Int, prefix: String) async throws -> [ContentPiece.ID] {
    let ids = (0..<count).map { UUID(80_000 + count * 10 + $0) }
    try await database.write { db in
      for (index, id) in ids.enumerated() {
        let messageID = "\(prefix)-\(index)"
        try ContentPiece.insert {
          ContentPiece.Draft(
            id: id, kind: .email, title: "Subject \(messageID)", creator: "sender@example.com",
            publisher: "Sender", emailTreatment: .personal, createdAt: .distantPast)
        }.execute(db)
        try Artifact.insert {
          Artifact.Draft(Artifact(
            id: UUID(), transport: .gmail,
            providerID: "gmail:jon@example.com:message:\(messageID)",
            acquiredAt: .distantPast, contentPieceID: id))
        }.execute(db)
      }
    }
    return ids
  }

  private func activeDispositionIDs(for ids: [ContentPiece.ID]) async throws -> [ContentPiece.ID] {
    try await database.read { db in
      try ids.filter { try GmailDispositionOperations.activeDisposition(forContentPieceID: $0, in: db) != nil }
    }
  }
}

private actor UndoRetryClient {
  private var restoreAttempts = 0

  nonisolated static var client: GmailDispositionClient {
    GmailDispositionClient(
      archive: { _ in },
      trash: { _ in },
      reAddInbox: { _ in },
      untrash: { _ in try await Self.restore() })
  }

  private static let shared = UndoRetryClient()

  private static func restore() async throws {
    try await shared.restoreOnce()
  }

  private func restoreOnce() throws {
    restoreAttempts += 1
    if restoreAttempts == 1 { throw URLError(.timedOut) }
  }
}

private actor DispositionGate {
  struct Snapshot: Sendable {
    let started: [String]
    let trashed: [String]
    let untrashed: [String]
    let maximumInFlight: Int
  }

  private var opened = false
  private var started: [String] = []
  private var trashed: [String] = []
  private var untrashed: [String] = []
  private var inFlight = 0
  private var maximumInFlight = 0
  private var releaseWaiters: [CheckedContinuation<Void, Never>] = []
  private var startWaiters: [(Int, CheckedContinuation<Void, Never>)] = []

  nonisolated var client: GmailDispositionClient {
    GmailDispositionClient(
      archive: { _ in },
      trash: { id in await self.trash(id) },
      reAddInbox: { _ in },
      untrash: { id in await self.untrash(id) })
  }

  func waitForStarted(_ count: Int) async {
    guard started.count < count else { return }
    await withCheckedContinuation { startWaiters.append((count, $0)) }
  }

  func open() {
    opened = true
    let waiters = releaseWaiters
    releaseWaiters.removeAll()
    waiters.forEach { $0.resume() }
  }

  func snapshot() -> Snapshot {
    Snapshot(started: started, trashed: trashed, untrashed: untrashed, maximumInFlight: maximumInFlight)
  }

  private func trash(_ id: String) async {
    started.append(id)
    inFlight += 1
    maximumInFlight = max(maximumInFlight, inFlight)
    let ready = startWaiters.filter { started.count >= $0.0 }
    startWaiters.removeAll { started.count >= $0.0 }
    ready.forEach { $0.1.resume() }
    if !opened { await withCheckedContinuation { releaseWaiters.append($0) } }
    inFlight -= 1
    trashed.append(id)
  }

  private func untrash(_ id: String) { untrashed.append(id) }
}

private actor QueueCallLog {
  private var values: [String] = []
  private let failingTrashID: String?
  init(failingTrashID: String? = nil) { self.failingTrashID = failingTrashID }

  nonisolated var client: GmailDispositionClient {
    let failingTrashID = failingTrashID
    return GmailDispositionClient(
      archive: { _ in },
      trash: { id in
        await self.record("trash:\(id)")
        if id == failingTrashID { throw URLError(.timedOut) }
      },
      reAddInbox: { _ in },
      untrash: { id in await self.record("untrash:\(id)") })
  }

  func snapshot() -> [String] { values }
  private func record(_ value: String) { values.append(value) }
}
