@testable import CockpitCore
import CustomDump
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@Suite(.serialized, .dependencies { try $0.bootstrapDatabase() })
struct DestinationTests {
  @Dependency(\.defaultDatabase) var database
  let id = UUID(-1)
  let date = Date(timeIntervalSince1970: 0)

  @Test("Explicit memberships are independent, idempotent, and preserve original admission")
  func memberships() throws {
    try database.write { db in
      try seed(in: db)
      expectNoDifference(try LaterMembership.fetchCount(db), 0)
      expectNoDifference(try LibraryMembership.fetchCount(db), 0)
      try DestinationOperations.saveForLater(id, at: date, in: db)
      try DestinationOperations.addToLibrary(id, at: date, in: db)
      try DestinationOperations.saveForLater(id, at: date.addingTimeInterval(10), in: db)
      try DestinationOperations.addToLibrary(id, at: date.addingTimeInterval(10), in: db)
      expectNoDifference(try LaterMembership.fetchCount(db), 1)
      expectNoDifference(try LibraryMembership.fetchCount(db), 1)
      expectNoDifference(try LaterMembership.find(id).fetchOne(db)?.addedAt, date)
      expectNoDifference(try LibraryMembership.find(id).fetchOne(db)?.admittedBy, "explicit")
      try DestinationOperations.removeFromLater(id, in: db)
      expectNoDifference(try LibraryMembership.fetchCount(db), 1)
    }
  }

  @Test("Invariant 3: removal preserves ContentPieces, Artifacts, provenance, and text")
  func removalPreservesEvidence() throws {
    try database.write { db in
      try seed(in: db)
      try DestinationOperations.saveForLater(id, at: date, in: db)
      try DestinationOperations.addToLibrary(id, at: date, in: db)
      let piece = try ContentPiece.find(id).fetchOne(db)
      let artifacts = try Artifact.fetchAll(db)
      try DestinationOperations.removeFromLibrary(id, in: db)
      expectNoDifference(try LaterMembership.fetchCount(db), 1)
      try DestinationOperations.removeFromLater(id, in: db)
      expectNoDifference(try ContentPiece.find(id).fetchOne(db), piece)
      expectNoDifference(try Artifact.fetchAll(db), artifacts)
      expectNoDifference(try NormalizedTextOperations.text(for: id, in: db), "Readable substance 🐦")
      let projection = try #require(try LibraryNormalizedText.find(id).fetchOne(db))
      #expect(projection.libraryMembershipID == nil)
      #expect(projection.utf8 == nil)
      let cascades = try #sql("""
        SELECT COUNT(*) FROM pragma_foreign_key_list('laterMemberships') WHERE on_delete = 'CASCADE'
        UNION ALL
        SELECT COUNT(*) FROM pragma_foreign_key_list('libraryMemberships') WHERE on_delete = 'CASCADE'
        """, as: Int.self).fetchAll(db)
      expectNoDifference(cascades, [0, 0])
    }
  }

  @Test("Invariant 12: admission rejects IDs that identify no ContentPiece")
  func libraryContainsContentPiecesOnly() throws {
    try database.write { db in
      try seed(in: db)
      #expect(throws: DestinationOperations.Failure.self) {
        try DestinationOperations.addToLibrary(UUID(-2), at: date, in: db)
      }
      #expect(throws: DestinationOperations.Failure.self) {
        try DestinationOperations.saveForLater(UUID(-2), at: date, in: db)
      }
      expectNoDifference(try LibraryMembership.fetchCount(db), 0)
    }
  }

  @Test("D6: text projects only for Library, updates on ingest, and survives removal/re-admission")
  func textLifecycle() throws {
    try database.write { db in
      try seed(in: db)
      try DestinationOperations.saveForLater(id, at: date, in: db)
      expectNoDifference(try LibraryNormalizedText.fetchCount(db), 0)
      try DestinationOperations.addToLibrary(id, at: date, in: db)
      expectNoDifference(try LibraryNormalizedText.find(id).fetchOne(db)?.utf8, Data("Readable substance 🐦".utf8))
      try NormalizedTextOperations.store("Updated body", for: id, in: db)
      expectNoDifference(try LibraryNormalizedText.find(id).fetchOne(db)?.utf8, Data("Updated body".utf8))
      try DestinationOperations.removeFromLibrary(id, in: db)
      try NormalizedTextOperations.store("Now local only", for: id, in: db)
      #expect(try LibraryNormalizedText.find(id).fetchOne(db)?.utf8 == nil)
      try DestinationOperations.addToLibrary(id, at: date, in: db)
      expectNoDifference(try LibraryNormalizedText.find(id).fetchOne(db)?.utf8, Data("Now local only".utf8))
    }
  }

  @Test("Received Library text is retained locally when the membership is removed")
  func receivedTextSurvivesRemoval() throws {
    try database.write { db in
      try seed(in: db)
      try DestinationOperations.addToLibrary(id, at: date, in: db)
      try LibraryNormalizedText.find(id).update { $0.utf8 = #bind(Data("Received text".utf8)) }.execute(db)
      expectNoDifference(try NormalizedTextOperations.text(for: id, in: db), "Received text")
      try LibraryMembership.find(id).delete().execute(db)
      expectNoDifference(try NormalizedTextOperations.text(for: id, in: db), "Received text")
      #expect(try LibraryNormalizedText.find(id).fetchOne(db)?.utf8 == nil)
      try LibraryNormalizedText.find(id).update { $0.utf8 = #bind(Data("Stale unowned text".utf8)) }.execute(db)
      #expect(try LibraryNormalizedText.find(id).fetchOne(db)?.utf8 == nil)
      expectNoDifference(try NormalizedTextOperations.text(for: id, in: db), "Received text")
    }
  }

  @Test("Invariant 7 shape: deleting a payload reference cannot delete normalized text")
  func payloadReferenceIsIndependent() throws {
    try database.write { db in
      try seed(in: db)
      try Artifact.update { $0.payloadRef = #bind(nil) }.execute(db)
      expectNoDifference(try NormalizedTextOperations.text(for: id, in: db), "Readable substance 🐦")
    }
  }

  private func seed(in db: Database) throws {
    try ContentPiece.insert {
      ContentPiece.Draft(id: id, kind: .article, title: "Article", publisher: "Publisher", createdAt: date)
    }.execute(db)
    try Artifact.insert {
      Artifact.Draft(
        id: UUID(-2), transport: .rss, providerID: "provider-evidence", acquiredAt: date,
        payloadRef: "payload", rawSourceText: "<p>Source evidence</p>", contentPieceID: id
      )
    }.execute(db)
    try NormalizedTextOperations.store("Readable substance 🐦", for: id, in: db)
  }
}
