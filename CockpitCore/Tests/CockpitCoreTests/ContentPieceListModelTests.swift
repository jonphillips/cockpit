@testable import CockpitCore
import CustomDump
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@Suite(.dependencies {
  try $0.bootstrapDatabase()
  $0.date.now = Date(timeIntervalSince1970: 123)
})
@MainActor
struct ContentPieceListModelTests {
  @Dependency(\.defaultDatabase) var database

  @Test("UI actions add and remove both destinations and observed rows follow writes")
  func destinations() async throws {
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(id: UUID(-1), kind: .article, title: "Piece", publisher: "Publisher", createdAt: .distantPast)
      }.execute(db)
      for artifactID in [UUID(-2), UUID(-3)] {
        try Artifact.insert {
          Artifact.Draft(id: artifactID, transport: .rss, acquiredAt: .distantPast, contentPieceID: UUID(-1))
        }.execute(db)
      }
    }
    let model = ContentPieceListModel()
    try await model.$content.load()
    expectNoDifference(model.rows.count, 1)
    let initialRow = try #require(model.rows.first)
    await model.laterButtonTapped(initialRow)
    await model.libraryButtonTapped(initialRow)
    try await model.$content.load()
    model.destination = .later
    let retainedRow = try #require(model.rows.first)
    expectNoDifference(retainedRow.laterAddedAt, Date(timeIntervalSince1970: 123))
    #expect(retainedRow.libraryAddedAt != nil)
    await model.laterButtonTapped(retainedRow)
    try await model.$content.load()
    #expect(model.rows.isEmpty)
    model.destination = .library
    expectNoDifference(model.rows.count, 1)
    await model.libraryButtonTapped(try #require(model.rows.first))
    try await model.$content.load()
    #expect(model.rows.isEmpty)
    model.destination = .all
    expectNoDifference(model.rows.count, 1)
    #expect(model.errorMessage == nil)
  }
}
