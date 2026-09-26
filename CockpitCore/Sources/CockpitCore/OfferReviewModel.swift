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
  @ObservationIgnored @Dependency(\.gmailDispositionClient) private var dispositionClient
  @ObservationIgnored @Dependency(\.date.now) private var now

  public let role: ContentRole
  public private(set) var content = OfferReviewRequest.Value()
  public private(set) var lastBatch: [GmailDispositionLogEntry] = []
  public var statusMessage: String?
  public var errorMessage: String?
  private let didChangeBatch: @MainActor ([GmailDispositionLogEntry]) -> Void

  public init(
    role: ContentRole,
    didChangeBatch: @escaping @MainActor ([GmailDispositionLogEntry]) -> Void = { _ in }
  ) {
    self.role = role
    self.didChangeBatch = didChangeBatch
  }

  public var rows: [OfferReviewRequest.Row] { content.rows }
  public var keptCount: Int { rows.filter { $0.pendingFind?.state == .confirmed }.count }
  public var isClear: Bool { rows.isEmpty && !lastBatch.isEmpty }

  public func reload() async {
    do {
      content = try await database.read { db in try OfferReviewRequest(role: role).fetch(db) }
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

  public func trashAll() async {
    let ids = rows.map(\.id)
    guard !ids.isEmpty else { return }
    let service = dispositionService
    var applied: [GmailDispositionLogEntry] = []
    var failures = 0
    for (index, id) in ids.enumerated() {
      do {
        if let entry = try await service.apply(.trash, toContentPieceID: id, in: database) {
          applied.append(entry)
        }
      } catch is CancellationError {
        failures += ids.count - index
        break
      } catch {
        failures += 1
      }
    }
    lastBatch = applied
    didChangeBatch(applied)
    await reload()
    if failures > 0 {
      statusMessage = "Trashed \(applied.count) of \(ids.count). \(failures) couldn't be trashed."
    } else {
      statusMessage = nil
    }
  }

  public func undoLastBatch() async {
    guard !lastBatch.isEmpty else { return }
    let batch = lastBatch
    let service = dispositionService
    var failed: [GmailDispositionLogEntry] = []
    for (index, entry) in batch.enumerated() {
      do {
        try await service.undo(entry, in: database)
      } catch is CancellationError {
        failed.append(contentsOf: batch[index...])
        break
      } catch {
        failed.append(entry)
      }
    }
    lastBatch = failed
    didChangeBatch(failed)
    await reload()
    statusMessage = failed.isEmpty ? nil : "Restored \(batch.count - failed.count) of \(batch.count). \(failed.count) couldn't be restored."
  }

  public func dismissUndo() {
    lastBatch = []
    didChangeBatch([])
  }

  private var dispositionService: GmailDispositionService {
    let date = now
    return GmailDispositionService(client: dispositionClient, now: { date })
  }
}
