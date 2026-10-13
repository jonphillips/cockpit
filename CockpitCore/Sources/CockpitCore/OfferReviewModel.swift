import Dependencies
import Foundation
import Observation
import SQLiteData

/// Owns one role's offer review flow. Find keeping is independent from Gmail disposition; a batch
/// Trash runs each email through the shared disposition barrier and retains its ordinary Undo rows.
@MainActor
@Observable
public final class OfferReviewModel {
  @ObservationIgnored @Dependency(\.defaultDatabase) private var database
  public let role: ContentRole
  public let dispositionQueue: GmailDispositionQueue
  public private(set) var content = OfferReviewRequest.Value()
  public private(set) var batchID: UUID? {
    didSet { dispositionQueue.setBatchReference(batchID, owner: self) }
  }
  public var errorMessage: String?

  public init(
    role: ContentRole,
    dispositionQueue: GmailDispositionQueue = .shared
  ) {
    self.role = role
    self.dispositionQueue = dispositionQueue
    dispositionQueue.registerReloadHandler(owner: self) { [weak self] in await self?.reload() }
  }

  public var rows: [OfferReviewRequest.Row] {
    content.rows.filter { !dispositionQueue.hiddenContentPieceIDs.contains($0.id) }
  }
  public var keptCount: Int { rows.filter { $0.pendingFind?.state == .confirmed }.count }
  public var batch: GmailDispositionQueue.Batch? {
    guard let batchID else { return nil }
    return dispositionQueue.batches.first { $0.id == batchID }
  }
  public var isClear: Bool { rows.isEmpty && batchID != nil }

  public func reload() async {
    do {
      content = try await database.read { db in
        try OfferReviewRequest(role: role, heroLimit: nil).fetch(db)
      }
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func keep(_ id: PendingFind.ID) async {
    do {
      try await database.write { db in try PendingFindOperations.confirm(id, in: db) }
      await reload()
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func unkeep(_ id: PendingFind.ID) async {
    do {
      try await database.write { db in try PendingFindOperations.unconfirm(id, in: db) }
      await reload()
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  @discardableResult
  public func trashAll() -> UUID? {
    let ids = rows.map(\.id)
    guard !ids.isEmpty else { return nil }
    let submittedBatchID = dispositionQueue.submit(
      .trash, contentPieceIDs: ids, origin: .offerReview(role))
    batchID = submittedBatchID
    return submittedBatchID
  }
}
