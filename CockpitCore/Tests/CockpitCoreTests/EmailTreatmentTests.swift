@testable import CockpitCore
import CustomDump
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@Suite(
  .serialized,
  .dependencies {
    $0.uuid = .incrementing
    try $0.bootstrapDatabase()
  }
)
struct EmailTreatmentTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("S5 migrates a populated S4 database without changing prior Gmail evidence")
  func s5MigrationPreservesS4Evidence() throws {
    let database = try SQLiteData.defaultDatabase()
    let migrator = CockpitMigrations.makeMigrator()
    try migrator.migrate(database, upTo: "M4 S4 Gmail provider provenance")
    let streamID = UUID(9_001)
    let pieceID = UUID(9_002)
    let artifactID = UUID(9_003)
    try database.write { db in
      try #sql(
        """
        INSERT INTO "streams" (id, name, publisher, transport, locator, handling, handlingGuidance,
        isEssential, followState, autoLibrary)
        VALUES (\(bind: streamID), 'Feed Me', 'Feed Me', 'gmail', 'digest@example.com', 'following', '', 0, 'active', 0)
        """
      ).execute(db)
      try #sql(
        """
        INSERT INTO "contentPieces" (id, kind, title, publisher, createdAt)
        VALUES (\(bind: pieceID), 'email', 'Digest', 'Feed Me <digest@example.com>', '2026-09-17 00:00:00')
        """
      ).execute(db)
      try #sql(
        """
        INSERT INTO "artifacts" (id, streamID, transport, acquiredAt, rawSourceText, providerProvenance, contentPieceID)
        VALUES (\(bind: artifactID), \(bind: streamID), 'gmail', '2026-09-17 00:00:00', 'Body', '{"listID":"Feed Me"}', \(bind: pieceID))
        """
      ).execute(db)
    }

    try migrator.migrate(database)
    try database.read { db in
      let contentColumns = try #sql(
        "SELECT name FROM pragma_table_info('contentPieces')", as: String.self
      ).fetchAll(db)
      let streamColumns = try #sql(
        "SELECT name FROM pragma_table_info('streams')", as: String.self
      ).fetchAll(db)
      #expect(contentColumns.contains("emailTreatment"))
      #expect(streamColumns.contains("isGrabBag"))
      #expect(try ContentPiece.find(pieceID).fetchOne(db)?.emailTreatment == nil)
      #expect(try Stream.find(streamID).fetchOne(db)?.isGrabBag == false)
      #expect(try Artifact.find(artifactID).fetchOne(db)?.providerProvenance == "{\"listID\":\"Feed Me\"}")
      #expect(try EmailSenderTreatmentOverride.fetchCount(db) == 0)
    }
  }

  @Test("Gmail ingest routes every message with deterministic retained-header signals")
  func gmailIngestRoutesEveryMessage() async throws {
    let snapshot = GmailInboxSnapshot(
      accountID: "jon@example.com",
      messages: [
        message(id: "personal", from: "Maya <maya@example.com>", subject: "Dinner this week"),
        message(
          id: "unsub", from: "Letters <letters@example.com>", subject: "Weekly dispatch",
          extraHeaders: [GmailInboxHeader(name: "List-Unsubscribe", value: "<https://example.com/unsubscribe>")]
        ),
        message(
          id: "bulk", from: "Store <store@example.com>", subject: "Updates",
          extraHeaders: [GmailInboxHeader(name: "Precedence", value: "bulk")]
        ),
        message(
          id: "esp", from: "Updates <updates@mailchimpapp.net>", subject: "Monthly dispatch"
        ),
        message(
          id: "offer", from: "Wine Shop <offers@example.com>", subject: "Fall wine allocation offer",
          extraHeaders: [GmailInboxHeader(name: "List-ID", value: "Offers <offers.example.com>")]
        ),
      ])

    let report = try await GmailInboxIngestor(
      client: GmailInboxClient(currentInbox: { snapshot }), now: { .distantPast }
    ).ingest(into: database)
    let treatments = Dictionary(uniqueKeysWithValues: report.contentPieces.map { ($0.title, $0.emailTreatment) })

    expectNoDifference(treatments["Dinner this week"], .personal)
    expectNoDifference(treatments["Weekly dispatch"], .newsletter)
    expectNoDifference(treatments["Updates"], .newsletter)
    expectNoDifference(treatments["Monthly dispatch"], .newsletter)
    expectNoDifference(treatments["Fall wine allocation offer"], .offer)
    expectNoDifference(report.contentPieces.allSatisfy { $0.emailTreatment != nil }, true)

    try await database.read { db in
      let overrides = try EmailSenderTreatmentOverride.all.fetchAll(db)
      // Classification is a default, never a learned correction.
      expectNoDifference(overrides.isEmpty, true)
    }
  }

  @Test("A manually flagged Stream routes its Gmail issues to grab-bag")
  func grabBagIsAnExplicitStreamSetting() async throws {
    let snapshot = GmailInboxSnapshot(
      accountID: "jon@example.com",
      messages: [
        message(
          id: "digest", from: "Feed Me <digest@example.com>", subject: "This week's links",
          extraHeaders: [GmailInboxHeader(name: "List-ID", value: "Feed Me <digest.example.com>")]
        ),
      ])
    let piece = try #require(try await GmailInboxIngestor(
      client: GmailInboxClient(currentInbox: { snapshot }), now: { .distantPast }
    ).ingest(into: database).contentPieces.first)
    let stream = Stream(
      id: UUID(), name: "Feed Me", publisher: "Feed Me", transport: .gmail,
      locator: "digest@example.com", isGrabBag: true)

    let classified = try await database.write { db in
      try Stream.insert { Stream.Draft(stream) }.execute(db)
      try Artifact.where { $0.contentPieceID.eq(piece.id) }
        .update { $0.streamID = #bind(stream.id) }
        .execute(db)
      return try EmailTreatmentOperations.classify(emailContentPieceIDs: [piece.id], in: db)
    }

    expectNoDifference(classified.first?.emailTreatment, .grabBag)
  }

  @Test("Explicit sender corrections survive recomposition and no provider evidence changes")
  func senderOverrideWinsAndPersists() async throws {
    let snapshot = GmailInboxSnapshot(
      accountID: "jon@example.com",
      messages: [
        message(id: "correction", from: "Pat <pat@example.com>", subject: "A note"),
      ])
    let piece = try #require(try await GmailInboxIngestor(
      client: GmailInboxClient(currentInbox: { snapshot }), now: { .distantPast }
    ).ingest(into: database).contentPieces.first)
    let artifactsBefore = try await database.read { db in
      try Artifact.where { $0.contentPieceID.eq(piece.id) }.fetchAll(db)
    }

    let first = try await database.write { db in
      try EmailTreatmentOperations.setSenderOverride(.newsletter, for: "Pat <pat@example.com>", in: db)
    }
    let recomposed = try await database.write { db in
      try EmailTreatmentOperations.reclassifyAll(in: db)
    }
    let artifactsAfter = try await database.read { db in
      try Artifact.where { $0.contentPieceID.eq(piece.id) }.fetchAll(db)
    }

    expectNoDifference(first.first { $0.id == piece.id }?.emailTreatment, .newsletter)
    expectNoDifference(recomposed.first { $0.id == piece.id }?.emailTreatment, .newsletter)
    expectNoDifference(artifactsAfter, artifactsBefore)
    try await database.read { db in
      let override = try EmailSenderTreatmentOverride.find("pat@example.com").fetchOne(db)
      expectNoDifference(override?.treatment, .newsletter)
    }
  }

  private func message(
    id: String, from: String, subject: String, extraHeaders: [GmailInboxHeader] = []
  ) -> GmailInboxMessage {
    GmailInboxMessage(
      id: id, threadID: "thread-\(id)",
      headers: [
        GmailInboxHeader(name: "From", value: from),
        GmailInboxHeader(name: "Subject", value: subject),
        GmailInboxHeader(name: "To", value: "jon@example.com"),
      ] + extraHeaders,
      bodyPlainText: "A readable email body."
    )
  }
}
