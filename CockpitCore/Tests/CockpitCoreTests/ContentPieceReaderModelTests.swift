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
struct ContentPieceReaderModelTests {
  @Dependency(\.defaultDatabase) var database

  @Test("A bare ContentPiece Reader writes Later and Library memberships idempotently")
  func bareReaderMemberships() async throws {
    let pieceID = UUID(9001)
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          id: pieceID, kind: .article, title: "Piece", publisher: "Publisher", createdAt: .distantPast)
      }.execute(db)
    }

    let model = ContentPieceReaderModel(contentPieceID: pieceID)
    try await model.$content.load()
    await model.saveForLater()
    await model.saveForLater()
    await model.addToLibrary()
    await model.addToLibrary()

    #expect(model.errorMessage == nil)
    let memberships = try await database.read { db in
      (
        try LaterMembership.find(pieceID).fetchOne(db),
        try LibraryMembership.find(pieceID).fetchOne(db)
      )
    }
    expectNoDifference(memberships.0?.addedAt, Date(timeIntervalSince1970: 123))
    expectNoDifference(memberships.1?.admittedBy, "explicit")
  }
}
