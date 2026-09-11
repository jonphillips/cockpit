@testable import CockpitCore
import CustomDump
import Dependencies
import Foundation
import SQLiteData
import Testing

struct DestinationMigrationTests {
  @Test("S1 populated database migrates losslessly, including empty, null, Unicode, and large text")
  func populatedMigration() throws {
    let database = try SQLiteData.defaultDatabase()
    let migrator = CockpitMigrations.makeMigrator()
    try migrator.migrate(database, upTo: "Deduplicate feed artifacts")
    let samples: [String?] = [nil, "", "é 👨‍👩‍👧‍👦\nparagraph\u{0}tail", String(repeating: "読", count: 400_000)]
    try database.write { db in
      for (index, text) in samples.enumerated() {
        let id = UUID(-index - 1)
        try #sql("""
          INSERT INTO "contentPieces"
          (id, kind, title, publisher, summary, normalizedText, subjects, isSubstantivePrimary, createdAt)
          VALUES (\(bind: id), 'article', 'Title', 'Publisher', 'Judgment', \(bind: text), '["swift"]', 1, '2026-09-11')
          """).execute(db)
        try #sql("""
          INSERT INTO "artifacts" (id, transport, acquiredAt, rawSourceText, contentPieceID)
          VALUES (\(bind: UUID(-index - 100)), 'rss', '2026-09-11', 'Raw provenance', \(bind: id))
          """).execute(db)
      }
    }
    try migrator.migrate(database)
    try migrator.migrate(database)
    try database.read { db in
      for (index, expected) in samples.enumerated() {
        expectNoDifference(try NormalizedTextOperations.text(for: UUID(-index - 1), in: db), expected)
      }
      expectNoDifference(try ContentPiece.fetchCount(db), samples.count)
      expectNoDifference(try Artifact.fetchCount(db), samples.count)
      expectNoDifference(try ContentPiece.select(\.summary).fetchAll(db), Array(repeating: "Judgment", count: samples.count))
      expectNoDifference(try Artifact.select(\.rawSourceText).fetchAll(db), Array(repeating: "Raw provenance", count: samples.count))
      expectNoDifference(try LibraryNormalizedText.fetchCount(db), 0)
      expectNoDifference(try LibraryMembership.fetchCount(db), 0)
      let columns = try #sql("SELECT name FROM pragma_table_info('contentPieces')", as: String.self).fetchAll(db)
      #expect(!columns.contains("normalizedText"))
      #expect(try #sql("PRAGMA foreign_key_check", as: String.self).fetchAll(db).isEmpty)
    }
  }
}
