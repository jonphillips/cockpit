import Dependencies
import Foundation
import Observation
import SQLiteData

/// Runs explicit Gmail dispositions optimistically while retaining the reversible service barrier.
@MainActor
@Observable
public final class GmailDispositionQueue {
  public static let maxConcurrentDispositions = 4
  public static let shared = GmailDispositionQueue()

  public struct Batch: Identifiable, Equatable, Sendable {
    public enum Phase: Equatable, Sendable { case running, undoing, settled }
    public struct Failure: Equatable, Sendable {
      public let contentPieceID: ContentPiece.ID
      public let message: String
      public init(contentPieceID: ContentPiece.ID, message: String) {
        self.contentPieceID = contentPieceID
        self.message = message
      }
    }

    public let id: UUID
    public let disposition: GmailSourceDisposition
    public let contentPieceIDs: [ContentPiece.ID]
    public let label: String
    public var phase: Phase
    public var applied: [GmailDispositionLogEntry]
    public var appliedContentPieceIDs: [ContentPiece.ID]
    public var failures: [Failure]
    public var undoAttempted: Bool
  }

  public struct Alert: Equatable, Identifiable, Sendable {
    public var id: String { title + message }
    public let title: String
    public let message: String
  }

  @ObservationIgnored @Dependency(\.defaultDatabase) private var database
  @ObservationIgnored @Dependency(\.gmailDispositionClient) private var client
  @ObservationIgnored @Dependency(\.date.now) private var now
  public private(set) var batches: [Batch] = []
  public private(set) var hiddenContentPieceIDs: Set<ContentPiece.ID> = []
  public var alert: Alert?
  @ObservationIgnored private var tasks: [UUID: Task<Void, Never>] = [:]
  @ObservationIgnored private var reloadHandlers: [UUID: [UUID: @MainActor () async -> Void]] = [:]
  @ObservationIgnored private let callLimiter = GmailDispositionCallLimiter(limit: maxConcurrentDispositions)

  public init() {}

  public var liveBatches: [Batch] { batches.filter { $0.phase != .settled } }
  public var latestBatch: Batch? { batches.last }
  public var latestOfferBatch: Batch? {
    batches.last { $0.label == "Offers" && ($0.phase != .settled || !$0.applied.isEmpty) }
  }

  /// Registers a projection owner that must reload before successful IDs can be unhidden.
  @discardableResult
  public func registerReloadHandler(
    owner: UUID, handlerID: UUID = UUID(), reload: @escaping @MainActor () async -> Void
  ) -> UUID {
    reloadHandlers[owner, default: [:]][handlerID] = reload
    return handlerID
  }

  public func unregisterReloadHandler(owner: UUID, handlerID: UUID) {
    reloadHandlers[owner]?.removeValue(forKey: handlerID)
  }

  @discardableResult
  public func submit(
    _ disposition: GmailSourceDisposition,
    contentPieceIDs: [ContentPiece.ID],
    label: String
  ) -> UUID? {
    guard disposition != .leave else { return nil }
    let liveIDs = Set(liveBatches.flatMap(\.contentPieceIDs))
    var seen: Set<ContentPiece.ID> = []
    let ids = contentPieceIDs.filter { seen.insert($0).inserted && !liveIDs.contains($0) }
    guard !ids.isEmpty else { return nil }
    let id = UUID()
    batches.append(Batch(
      id: id, disposition: disposition, contentPieceIDs: ids, label: label,
      phase: .running, applied: [], appliedContentPieceIDs: [], failures: [], undoAttempted: false))
    hiddenContentPieceIDs.formUnion(ids)
    tasks[id] = Task { [weak self] in await self?.run(id) }
    return id
  }

  public func undo(_ batchID: UUID) async {
    guard let index = batches.firstIndex(where: { $0.id == batchID }) else { return }
    if batches[index].phase == .undoing {
      await tasks[batchID]?.value
      return
    }
    if batches[index].phase == .settled {
      batches[index].phase = .undoing
      hiddenContentPieceIDs.formUnion(batches[index].appliedContentPieceIDs)
      let task = Task { [weak self] in
        guard let self else { return }
        await self.restoreApplied(in: batchID)
      }
      tasks[batchID] = task
      await task.value
      return
    }
    batches[index].phase = .undoing
    await tasks[batchID]?.value
  }

  public func dismiss(_ batchID: UUID) {
    guard let index = batches.firstIndex(where: { $0.id == batchID }), batches[index].phase == .settled
    else { return }
    batches.remove(at: index)
  }

  public func clearAlert() { alert = nil }

  public func waitForSettlement(_ batchID: UUID) async { await tasks[batchID]?.value }

}

private extension GmailDispositionQueue {
  func run(_ batchID: UUID) async {
    guard let initial = batch(batchID) else { return }
    let database = database
    let client = client.limited(by: callLimiter)
    let date = now
    let service = GmailDispositionService(client: client, now: { date })
    var next = 0
    await withTaskGroup(of: (ContentPiece.ID, Result<GmailDispositionLogEntry?, Error>).self) { group in
      func launch(_ id: ContentPiece.ID) {
        group.addTask {
          do { return (id, .success(try await service.apply(initial.disposition, toContentPieceID: id, in: database))) }
          catch { return (id, .failure(error)) }
        }
      }
      while next < initial.contentPieceIDs.count && next < Self.maxConcurrentDispositions {
        launch(initial.contentPieceIDs[next]); next += 1
      }
      while let (pieceID, result) = await group.next() {
        guard let index = batches.firstIndex(where: { $0.id == batchID }) else { continue }
        switch result {
        case let .success(entry):
          if let entry {
            batches[index].applied.append(entry)
            batches[index].appliedContentPieceIDs.append(pieceID)
          }
        case let .failure(error):
          if !(error is CancellationError) {
            batches[index].failures.append(.init(contentPieceID: pieceID, message: error.localizedDescription))
          }
        }
        if batches[index].phase == .running && !Task.isCancelled && next < initial.contentPieceIDs.count {
          launch(initial.contentPieceIDs[next]); next += 1
        }
      }
    }
    guard let index = batches.firstIndex(where: { $0.id == batchID }) else { return }
    if Task.isCancelled {
      batches[index].phase = .settled
      await settle(batchID)
    } else if batches[index].phase == .undoing {
      await restoreApplied(in: batchID)
    } else {
      batches[index].phase = .settled
      await settle(batchID)
    }
  }

  func restoreApplied(in batchID: UUID) async {
    guard let index = batches.firstIndex(where: { $0.id == batchID }) else { return }
    batches[index].undoAttempted = true
    let entries = batches[index].applied
    let pieceIDsByEntry = Dictionary(uniqueKeysWithValues: zip(entries, batches[index].appliedContentPieceIDs).map { ($0.0.id, $0.1) })
    let client = client.limited(by: callLimiter)
    let date = now
    let service = GmailDispositionService(client: client, now: { date })
    let failed = await service.undo(entries, in: database)
    batches[index].applied = failed
    batches[index].appliedContentPieceIDs = failed.compactMap { pieceIDsByEntry[$0.id] }
    batches[index].failures = failed.compactMap { entry in
      pieceIDsByEntry[entry.id].map {
        .init(contentPieceID: $0, message: "Gmail could not restore this message.")
      }
    }
    batches[index].phase = .settled
    await settle(batchID)
  }

  func settle(_ batchID: UUID) async {
    guard let index = batches.firstIndex(where: { $0.id == batchID }) else { return }
    let batch = batches[index]
    for handler in reloadHandlers.values.flatMap(\.values) { await handler() }
    let successfulIDs = Set(batch.contentPieceIDs).subtracting(batch.failures.map(\.contentPieceID))
    hiddenContentPieceIDs.subtract(successfulIDs)
    hiddenContentPieceIDs.subtract(batch.failures.map(\.contentPieceID))
    tasks[batchID] = nil
    if !batch.failures.isEmpty {
      let action = batch.undoAttempted ? "restore" : batch.disposition == .trash ? "trash" : "archive"
      let count = batch.failures.count
      alert = Alert(
        title: "Couldn't \(action) \(count) of \(batch.contentPieceIDs.count) emails",
        message: batch.failures.first?.message ?? "Please try again.")
    }
  }

  func batch(_ id: UUID) -> Batch? { batches.first { $0.id == id } }

}

private actor GmailDispositionCallLimiter {
  private let limit: Int
  private var activeCalls = 0
  private var waiters: [CheckedContinuation<Void, Never>] = []

  init(limit: Int) { self.limit = limit }

  func perform(_ operation: @escaping @Sendable () async throws -> Void) async throws {
    await acquire()
    guard !Task.isCancelled else {
      release()
      throw CancellationError()
    }
    do {
      try await operation()
      release()
    } catch {
      release()
      throw error
    }
  }

  private func acquire() async {
    if activeCalls < limit {
      activeCalls += 1
      return
    }
    await withCheckedContinuation { waiters.append($0) }
  }

  private func release() {
    if waiters.isEmpty {
      activeCalls -= 1
    } else {
      waiters.removeFirst().resume()
    }
  }
}

private extension GmailDispositionClient {
  func limited(by limiter: GmailDispositionCallLimiter) -> Self {
    let archive = archive
    let trash = trash
    let reAddInbox = reAddInbox
    let untrash = untrash
    return Self(
      archive: { id in try await limiter.perform { try await archive(id) } },
      trash: { id in try await limiter.perform { try await trash(id) } },
      reAddInbox: { id in try await limiter.perform { try await reAddInbox(id) } },
      untrash: { id in try await limiter.perform { try await untrash(id) } })
  }
}
