import Dependencies
import Foundation
import Observation
import SQLiteData

/// Owns the one ordered reading queue used by Today’s split reader. It owns source disposition
/// actions, but never lets those actions rewrite Stream membership or Edition state.
@MainActor
@Observable
public final class TodayReadingQueueModel {
  public struct Section: Equatable, Identifiable, Sendable {
    public let role: ContentRole
    public let rows: [TodayReadingQueueRequest.Row]

    public var id: ContentRole { role }

    public init(role: ContentRole, rows: [TodayReadingQueueRequest.Row]) {
      self.role = role
      self.rows = rows
    }
  }

  public struct LastDisposition: Equatable, Sendable {
    public let contentPieceID: ContentPiece.ID
    public let title: String
    public let disposition: GmailSourceDisposition

    public init(contentPieceID: ContentPiece.ID, title: String, disposition: GmailSourceDisposition) {
      self.contentPieceID = contentPieceID
      self.title = title
      self.disposition = disposition
    }
  }

  @ObservationIgnored @Dependency(\.defaultDatabase) private var database
  @ObservationIgnored @Dependency(\.date.now) private var now
  @ObservationIgnored @Dependency(\.gmailDispositionClient) private var dispositionClient
  @ObservationIgnored @Fetch(TodayReadingQueueRequest()) public var content = .init()
  public var selectedContentPieceID: ContentPiece.ID?
  public var errorMessage: String?
  public var lastDisposition: LastDisposition?

  public init() {}

  public var rows: [TodayReadingQueueRequest.Row] { content.rows }

  public var sections: [Section] {
    ContentRole.allCases.sorted { $0.sortOrder < $1.sortOrder }.compactMap { role in
      let rows = content.rows.filter { $0.role == role }
      return rows.isEmpty ? nil : Section(role: role, rows: rows)
    }
  }

  public func reload() async {
    do {
      try await $content.load()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func archive(_ row: TodayReadingQueueRequest.Row) async {
    await applyDisposition(.archive, to: row.id)
  }

  public func trash(_ row: TodayReadingQueueRequest.Row) async {
    await applyDisposition(.trash, to: row.id)
  }

  public func undoDisposition(_ row: TodayReadingQueueRequest.Row) async {
    await undoDisposition(contentPieceID: row.id)
  }

  public func undoLastDisposition() async {
    guard let lastDisposition else { return }
    await undoDisposition(contentPieceID: lastDisposition.contentPieceID)
  }

  private func undoDisposition(contentPieceID: ContentPiece.ID) async {
    do {
      guard let entry = try await database.read({ db in
        try GmailDispositionOperations.activeDisposition(forContentPieceID: contentPieceID, in: db)
      }) else { return }
      try await dispositionService.undo(entry, in: database)
      await reload()
      selectedContentPieceID = contentPieceID
      lastDisposition = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// Applies the explicit M6 S1 series policy when a followed-stream issue leaves the Reader.
  public func applySeriesTrashOnLeave(_ contentPieceID: ContentPiece.ID) async {
    do {
      let didTrash = try await GmailSeriesDispositionOperations.applyTrashOnLeave(
        contentPieceID: contentPieceID, in: database, using: dispositionService)
      guard didTrash else { return }
      if let row = rows.first(where: { $0.id == contentPieceID }) {
        lastDisposition = LastDisposition(contentPieceID: contentPieceID, title: row.title, disposition: .trash)
      }
      await reload()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func applyDisposition(_ disposition: GmailSourceDisposition, to id: ContentPiece.ID) async {
    guard let row = rows.first(where: { $0.id == id }), row.isGmailSource else { return }
    let shouldAdvance = selectedContentPieceID == id
    let nextSelection = shouldAdvance ? ReadingQueueSelection.neighbour(of: id, in: rows) : nil
    lastDisposition = nil
    do {
      _ = try await dispositionService.apply(disposition, toContentPieceID: id, in: database)
      lastDisposition = LastDisposition(contentPieceID: row.id, title: row.title, disposition: disposition)
      await reload()
      if shouldAdvance { selectedContentPieceID = nextSelection }
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private var dispositionService: GmailDispositionService {
    let date = now
    return GmailDispositionService(client: dispositionClient, now: { date })
  }
}

public enum ReadingQueueSelection {
  /// The queue is already in reading order: advance, then fall back to the previous row.
  public static func neighbour(
    of id: ContentPiece.ID, in rows: [TodayReadingQueueRequest.Row]
  ) -> ContentPiece.ID? {
    guard let index = rows.firstIndex(where: { $0.id == id }) else { return nil }
    if rows.indices.contains(index + 1) { return rows[index + 1].id }
    if index > rows.startIndex { return rows[index - 1].id }
    return nil
  }
}
