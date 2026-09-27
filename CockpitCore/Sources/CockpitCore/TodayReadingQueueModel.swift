import Dependencies
import Foundation
import Observation
import SQLiteData

/// Owns the one ordered reading queue shared by Today and Process. It owns source disposition
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
  @ObservationIgnored private var skipSeriesTrashOnLeaveIDs: Set<ContentPiece.ID> = []
  private var doneByID: [ContentPiece.ID: ContentRole] = [:]
  private var doneTrackingDay: Date?

  public var selectedContentPieceID: ContentPiece.ID?
  public var errorMessage: String?
  public var lastDisposition: LastDisposition?

  public init() {}

  public var rows: [TodayReadingQueueRequest.Row] { content.rows }

  public var selectedRole: ContentRole? {
    Self.selectedRole(for: selectedContentPieceID, in: sections)
  }

  public var doneCount: Int { doneByID.count }

  public var doneRoles: [ContentRole] {
    let completedRoles = Set(doneByID.values).filter { role in
      !rows.contains { $0.role == role }
    }
    return ContentRole.allCases
      .sorted { $0.sortOrder < $1.sortOrder }
      .filter { completedRoles.contains($0) }
  }

  public var position: (index: Int, total: Int)? {
    guard let selectedContentPieceID,
      let selectedIndex = rows.firstIndex(where: { $0.id == selectedContentPieceID })
    else { return nil }

    return (
      index: doneByID.count + selectedIndex + 1,
      total: doneByID.count + rows.count
    )
  }

  public static func selectedRole(
    for contentPieceID: ContentPiece.ID?, in sections: [Section]
  ) -> ContentRole? {
    guard let contentPieceID else { return nil }
    return sections.first { section in section.rows.contains { $0.id == contentPieceID } }?.role
  }

  public var sections: [Section] {
    ContentRole.allCases.sorted { $0.sortOrder < $1.sortOrder }.compactMap { role in
      let rows = content.rows.filter { $0.role == role }
      return rows.isEmpty ? nil : Section(role: role, rows: rows)
    }
  }

  public func reload() async {
    resetDoneTrackingIfNeeded(at: now)
    do {
      try await $content.load()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func selectPrevious() {
    guard !rows.isEmpty else {
      selectedContentPieceID = nil
      return
    }
    guard let selectedContentPieceID,
      let index = rows.firstIndex(where: { $0.id == selectedContentPieceID })
    else {
      self.selectedContentPieceID = rows.first?.id
      return
    }
    guard index > rows.startIndex else { return }
    self.selectedContentPieceID = rows[index - 1].id
  }

  public func selectNext() {
    guard !rows.isEmpty else {
      selectedContentPieceID = nil
      return
    }
    guard let selectedContentPieceID,
      let index = rows.firstIndex(where: { $0.id == selectedContentPieceID })
    else {
      self.selectedContentPieceID = rows.first?.id
      return
    }
    let nextIndex = index + 1
    guard rows.indices.contains(nextIndex) else { return }
    self.selectedContentPieceID = rows[nextIndex].id
  }

  public func archive(_ row: TodayReadingQueueRequest.Row) async {
    await applyDisposition(.archive, to: row.id)
  }

  public func trash(_ row: TodayReadingQueueRequest.Row) async {
    await applyDisposition(.trash, to: row.id)
  }

  public func undoLastDisposition() async {
    guard let lastDisposition else { return }
    await undoDisposition(contentPieceID: lastDisposition.contentPieceID)
  }

  public func undoDisposition(contentPieceID: ContentPiece.ID) async {
    resetDoneTrackingIfNeeded(at: now)
    do {
      guard let entry = try await database.read({ db in
        try GmailDispositionOperations.activeDisposition(forContentPieceID: contentPieceID, in: db)
      }) else { return }
      try await dispositionService.undo(entry, in: database)
      doneByID.removeValue(forKey: contentPieceID)
      await reload()
      if let movedAwayFrom = selectedContentPieceID, movedAwayFrom != contentPieceID {
        skipSeriesTrashOnLeaveIDs.insert(movedAwayFrom)
      }
      selectedContentPieceID = contentPieceID
      if lastDisposition?.contentPieceID == contentPieceID {
        lastDisposition = nil
      }
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// Applies the explicit M6 S1 series policy when a followed-stream issue leaves the Reader.
  @discardableResult
  public func applySeriesTrashOnLeave(_ contentPieceID: ContentPiece.ID) async -> Bool {
    resetDoneTrackingIfNeeded(at: now)
    guard skipSeriesTrashOnLeaveIDs.remove(contentPieceID) == nil else { return false }
    guard let row = rows.first(where: { $0.id == contentPieceID }) else { return false }
    do {
      let didTrash = try await GmailSeriesDispositionOperations.applyTrashOnLeave(
        contentPieceID: contentPieceID, in: database, using: dispositionService)
      guard didTrash else { return false }
      recordDone(row)
      lastDisposition = LastDisposition(
        contentPieceID: contentPieceID, title: row.title, disposition: .trash)
      await reload()
      errorMessage = nil
      return true
    } catch is CancellationError {
      return false
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }

  /// Applies the Process-tab leave boundary. A declared series may trash the selected piece; when it
  /// does, selection advances to the neighbour that was visible before the queue changed.
  public func leaveProcess() async {
    guard let selectedContentPieceID,
      rows.contains(where: { $0.id == selectedContentPieceID })
    else { return }

    let nextSelection = ReadingQueueSelection.neighbour(of: selectedContentPieceID, in: rows)
    guard await applySeriesTrashOnLeave(selectedContentPieceID) else { return }

    // Setting selection after the trash can fire ProcessView's selection-change hook. Consume that
    // duplicate leave callback instead of attempting the series policy twice.
    skipSeriesTrashOnLeaveIDs.insert(selectedContentPieceID)
    self.selectedContentPieceID = nextSelection
  }

  /// Records a successful Edition Dismiss in the same in-memory progress ledger as Gmail
  /// dispositions. EditionModel still owns the canonical state transition.
  public func recordDismissed(_ contentPieceID: ContentPiece.ID) async {
    resetDoneTrackingIfNeeded(at: now)
    guard let row = rows.first(where: { $0.id == contentPieceID }) else { return }
    let shouldAdvance = selectedContentPieceID == contentPieceID
    let nextSelection = shouldAdvance
      ? ReadingQueueSelection.neighbour(of: contentPieceID, in: rows)
      : nil
    recordDone(row)
    if shouldAdvance { selectedContentPieceID = nextSelection }
    await reload()
  }

  /// Internal so deterministic core tests can prove the local-day rollover without waiting on wall
  /// clock time. Production callers use the dependency-backed checks above.
  func resetDoneTrackingIfNeeded(at date: Date) {
    let day = Calendar.autoupdatingCurrent.startOfDay(for: date)
    guard doneTrackingDay != day else { return }
    doneTrackingDay = day
    doneByID.removeAll()
  }

  private func applyDisposition(_ disposition: GmailSourceDisposition, to id: ContentPiece.ID) async {
    resetDoneTrackingIfNeeded(at: now)
    guard let row = rows.first(where: { $0.id == id }), row.isGmailSource else { return }
    let shouldAdvance = selectedContentPieceID == id
    let nextSelection = shouldAdvance ? ReadingQueueSelection.neighbour(of: id, in: rows) : nil
    do {
      _ = try await dispositionService.apply(disposition, toContentPieceID: id, in: database)
      recordDone(row)
      lastDisposition = LastDisposition(
        contentPieceID: row.id, title: row.title, disposition: disposition)
      if shouldAdvance { selectedContentPieceID = nextSelection }
      await reload()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func recordDone(_ row: TodayReadingQueueRequest.Row) {
    doneByID[row.id] = row.role
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
