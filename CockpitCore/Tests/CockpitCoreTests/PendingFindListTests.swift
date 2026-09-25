@testable import CockpitCore
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@Suite(.serialized, .dependencies {
  $0.uuid = .incrementing
  $0.date.now = Date(timeIntervalSince1970: 1_800_000_000)
  try $0.bootstrapDatabase()
})
@MainActor
struct PendingFindListTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("Find list groups states, sorts by source date with created fallback, and hides dismissed")
  func groupsAndSortsRows() async throws {
    let base = Date(timeIntervalSince1970: 1_800_000_000)
    let entries: [(UInt64, String, Date?, Date, PendingFindState)] = [
      (91_001, "Older", base.addingTimeInterval(-100), base, .pending),
      (91_002, "Fallback", nil, base.addingTimeInterval(100), .pending),
      (91_003, "Alpha", base, base, .pending),
      (91_004, "Beta", base, base, .pending),
      (91_005, "Saved", base.addingTimeInterval(150), base, .confirmed),
      (91_006, "Referred", base.addingTimeInterval(-300), base, .referred),
      (91_007, "Added", base.addingTimeInterval(-400), base, .handedOff),
      (91_008, "Declined", base.addingTimeInterval(-500), base, .declined),
      (91_009, "Hidden", base.addingTimeInterval(200), base, .dismissed)
    ]
    try await seed(entries)

    let visible = try await database.read { db in try PendingFindListRequest().fetch(db).rows }
    #expect(visible.map(\.name) == ["Saved", "Fallback", "Alpha", "Beta", "Older", "Referred", "Added", "Declined"])
    #expect(!visible.contains { $0.state == .dismissed })
    #expect(visible.first?.section == .saved)

    let model = PendingFindListModel()
    await model.load()
    #expect(model.needsDecisionRows.map(\.name) == ["Fallback", "Alpha", "Beta", "Older"])
    #expect(model.savedRows.map(\.name) == ["Saved", "Referred"])
    #expect(model.resolvedRows.map(\.name) == ["Added", "Declined"])
    #expect(model.dismissedRows.isEmpty)

    let includingDismissed = try await database.read { db in
      try PendingFindListRequest(showDismissed: true).fetch(db).rows
    }
    #expect(includingDismissed.first?.name == "Hidden")
    #expect(includingDismissed.first?.section == .dismissed)
  }

  @Test("Saving a dismissed Find restores it to Saved")
  func savesDismissedFind() async throws {
    let pieceID = UUID(92_001)
    let findID = UUID(92_002)
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(ContentPiece(
          id: pieceID, kind: .article, title: "Source", publisher: "Publisher", createdAt: date))
      }.execute(db)
      try PendingFind.insert {
        PendingFind.Draft(PendingFind(
          id: findID, contentPieceID: pieceID, kind: "restaurant", name: "Place",
          descriptor: "", rationale: "", state: .dismissed))
      }.execute(db)
    }

    let model = PendingFindListModel()
    model.setShowDismissed(true)
    await model.load()
    #expect(model.dismissedRows.map(\.id) == [findID])
    await model.confirm(findID)
    #expect(model.savedRows.map(\.id) == [findID])
    #expect(model.dismissedRows.isEmpty)
  }

  private func seed(
    _ entries: [(UInt64, String, Date?, Date, PendingFindState)]
  ) async throws {
    try await database.write { db in
      for (rawID, name, publishedAt, createdAt, state) in entries {
        let pieceID = UUID(Int(rawID))
        try ContentPiece.insert {
          ContentPiece.Draft(ContentPiece(
            id: pieceID, kind: .article, title: "Source", publisher: "Publisher",
            publishedAt: publishedAt, createdAt: createdAt))
        }.execute(db)
        try PendingFind.insert {
          PendingFind.Draft(PendingFind(
            id: UUID(Int(rawID + 100)), contentPieceID: pieceID, kind: "restaurant", name: name,
            descriptor: "", rationale: "", state: state))
        }.execute(db)
      }
    }
  }
}
