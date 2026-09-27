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

  @ObservationIgnored @Dependency(\.defaultDatabase) var database
  @ObservationIgnored @Dependency(\.date.now) var now
  @ObservationIgnored @Dependency(\.gmailDispositionClient) var dispositionClient
  @ObservationIgnored @Fetch(TodayReadingQueueRequest()) public var content = .init()
  @ObservationIgnored var skipSeriesTrashOnLeaveIDs: Set<ContentPiece.ID> = []
  var doneByID: [ContentPiece.ID: ContentRole] = [:]
  var doneTrackingDay: Date?

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

  /// Internal so deterministic core tests can prove the local-day rollover without waiting on wall
  /// clock time. Production callers reach it through reload and disposition entry points.
  func resetDoneTrackingIfNeeded(at date: Date) {
    let day = Calendar.autoupdatingCurrent.startOfDay(for: date)
    guard doneTrackingDay != day else { return }
    doneTrackingDay = day
    doneByID.removeAll()
  }

  func recordDone(_ row: TodayReadingQueueRequest.Row) {
    doneByID[row.id] = row.role
  }

  var dispositionService: GmailDispositionService {
    let date = now
    return GmailDispositionService(client: dispositionClient, now: { date })
  }
}
