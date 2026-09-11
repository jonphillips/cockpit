@testable import CockpitCore
import CustomDump
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@DatabaseFunction("sqlitedata_icloud_syncEngineIsSynchronizingChanges")
private func receivingForTest() -> Bool { true }

@Suite(.dependencies { try $0.bootstrapDatabase() })
struct NormalizedTextReceiveTests {
  @Dependency(\.defaultDatabase) var database

  @Test("Reference-violation recovery preserves a member's body; later removal still clears it")
  func referenceRecoveryIsNotMembershipRemoval() throws {
    let id = UUID(-1)
    try database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(id: id, kind: .article, title: "Piece", publisher: "Publisher", createdAt: .distantPast)
      }.execute(db)
      try NormalizedTextOperations.store("Body text", for: id, in: db)
      try DestinationOperations.addToLibrary(id, at: .distantPast, in: db)
      // SQLiteData's .referenceViolation recovery executes this with synchronization off.
      try #sql("""
        UPDATE "libraryNormalizedTexts" SET "libraryMembershipID" = NULL
        WHERE "contentPieceID" = \(bind: id)
        """).execute(db)
      expectNoDifference(try LibraryMembership.fetchCount(db), 1)
      expectNoDifference(try LibraryNormalizedText.find(id).fetchOne(db)?.utf8, Data("Body text".utf8))
      expectNoDifference(try NormalizedTextOperations.text(for: id, in: db), "Body text")
      // The FK is already detached, so deletion must also handle a row it cannot reach.
      try DestinationOperations.removeFromLibrary(id, in: db)
      #expect(try LibraryNormalizedText.find(id).fetchOne(db)?.utf8 == nil)
      expectNoDifference(try NormalizedTextOperations.text(for: id, in: db), "Body text")
    }
  }

  @Test("Incoming membership does not promote stale local text over the following server body")
  func receiveDoesNotEchoStaleText() throws {
    let id = UUID(-1)
    try database.write { db in
      try NormalizedTextOperations.store("Stale local text", for: id, in: db)
      // Exercise the documented SQL trigger mode used by SQLiteData's receive transactions.
      db.add(function: $receivingForTest)
      defer { db.add(function: SyncEngine.$isSynchronizing) }
      try LibraryMembership.insert {
        LibraryMembership.Draft(contentPieceID: id, addedAt: .distantPast, admittedBy: "explicit")
      }.execute(db)
      expectNoDifference(try LibraryNormalizedText.fetchCount(db), 0)
      try LibraryNormalizedText.insert {
        LibraryNormalizedText.Draft(contentPieceID: id, libraryMembershipID: id, utf8: Data("Server body".utf8))
      }.execute(db)
      expectNoDifference(try NormalizedTextOperations.text(for: id, in: db), "Server body")
      try LibraryMembership.find(id).delete().execute(db)
      #expect(try LibraryNormalizedText.find(id).fetchOne(db)?.utf8 == nil)
      expectNoDifference(try NormalizedTextOperations.text(for: id, in: db), "Server body")
    }
  }

  @Test("Ingest can supply local text for a received membership without replacing an existing body")
  func ingestSuppliesMissingBody() throws {
    let id = UUID(-1)
    try database.write { db in
      try NormalizedTextOperations.store("Local body", for: id, in: db)
      db.add(function: $receivingForTest)
      try LibraryMembership.insert {
        LibraryMembership.Draft(contentPieceID: id, addedAt: .distantPast, admittedBy: "explicit")
      }.execute(db)
      db.add(function: SyncEngine.$isSynchronizing)
      try NormalizedTextOperations.supplyLibraryTextIfMissing(for: id, in: db)
      expectNoDifference(try LibraryNormalizedText.find(id).fetchOne(db)?.utf8, Data("Local body".utf8))
      try NormalizedTextOperations.supplyLibraryTextIfMissing(for: id, in: db)
      expectNoDifference(try LibraryNormalizedText.fetchCount(db), 1)
    }
  }
}
