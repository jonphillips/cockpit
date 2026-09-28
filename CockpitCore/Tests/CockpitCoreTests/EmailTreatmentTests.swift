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
      #expect(contentColumns.contains("emailTransactionalKind"))
      #expect(streamColumns.contains("isGrabBag"))
      #expect(try ContentPiece.find(pieceID).fetchOne(db)?.emailTreatment == nil)
      #expect(try ContentPiece.find(pieceID).fetchOne(db)?.emailTransactionalKind == nil)
      #expect(try Stream.find(streamID).fetchOne(db)?.isGrabBag == false)
      #expect(try Artifact.find(artifactID).fetchOne(db)?.providerProvenance == "{\"listID\":\"Feed Me\"}")
      #expect(try EmailSenderTreatmentOverride.fetchCount(db) == 0)
    }
  }

  @Test("M6 migrates old section-shaped sender corrections without overwriting explicit routing")
  func senderTreatmentCorrectionsBecomeRoleRules() throws {
    let database = try SQLiteData.defaultDatabase()
    let migrator = CockpitMigrations.makeMigrator()
    try migrator.migrate(database, upTo: "M6 S-d0d editable sub-feed routing")
    try database.write { db in
      try EmailSenderTreatmentOverride.insert {
        EmailSenderTreatmentOverride.Draft(
          EmailSenderTreatmentOverride(senderKey: "digest@example.com", treatment: .grabBag))
      }.execute(db)
      try EmailSenderTreatmentOverride.insert {
        EmailSenderTreatmentOverride.Draft(
          EmailSenderTreatmentOverride(senderKey: "offers@example.com", treatment: .offer))
      }.execute(db)
      try ContentRoleRoutingRule.insert {
        ContentRoleRoutingRule.Draft(
          ContentRoleRoutingRule(locator: "offers@example.com", role: .opinion))
      }.execute(db)
    }

    try migrator.migrate(database)
    let migrated = try database.read { db in
      (
        try ContentRoleRoutingRule.find("digest@example.com").fetchOne(db)?.role,
        try ContentRoleRoutingRule.find("offers@example.com").fetchOne(db)?.role,
        try EmailSenderTreatmentOverride.fetchCount(db)
      )
    }
    #expect(migrated.0 == .grabBag)
    #expect(migrated.1 == .opinion)
    #expect(migrated.2 == 2)
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
          id: "noreply-newsletter", from: "Dispatch <no-reply@letters.example>",
          subject: "No-reply weekly dispatch",
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
        message(id: "ups", from: "UPS <no-reply@ups.com>", subject: "Your shipment is on the way"),
        message(
          id: "apple", from: "Apple <do_not_reply@apple.com>",
          subject: "Your trade-in is being processed"
        ),
        message(
          id: "code", from: "Kickstarter <noreply@kickstarter.com>",
          subject: "Your sign-in code"
        ),
        message(
          id: "hotel", from: "Hotel <reservations@hotel.example>",
          subject: "Your hotel confirmation"
        ),
      ])

    let report = try await GmailInboxIngestor(
      client: GmailInboxClient(currentInbox: { snapshot }), now: { .distantPast }
    ).ingest(into: database)
    let treatments = Dictionary(uniqueKeysWithValues: report.contentPieces.map { ($0.title, $0.emailTreatment) })

    expectNoDifference(treatments["Dinner this week"], .personal)
    expectNoDifference(treatments["Weekly dispatch"], .newsletter)
    expectNoDifference(treatments["No-reply weekly dispatch"], .newsletter)
    expectNoDifference(treatments["Updates"], .newsletter)
    expectNoDifference(treatments["Monthly dispatch"], .newsletter)
    expectNoDifference(treatments["Fall wine allocation offer"], .offer)
    expectNoDifference(treatments["Your shipment is on the way"], .transactional)
    expectNoDifference(treatments["Your trade-in is being processed"], .transactional)
    expectNoDifference(treatments["Your sign-in code"], .transactional)
    expectNoDifference(treatments["Your hotel confirmation"], .transactional)
    expectNoDifference(report.contentPieces.allSatisfy { $0.emailTreatment != nil }, true)
    let transactionalKinds = Dictionary(
      uniqueKeysWithValues: report.contentPieces.map { ($0.title, $0.emailTransactionalKind) })
    expectNoDifference(transactionalKinds["Your sign-in code"], .ephemeral)
    expectNoDifference(transactionalKinds["Your hotel confirmation"], .reference)
    let dinner = try #require(report.contentPieces.first { $0.title == "Dinner this week" })
    expectNoDifference(dinner.emailTransactionalKind, nil)

    try await database.read { db in
      let overrides = try EmailSenderTreatmentOverride.all.fetchAll(db)
      // Classification is a default, never a learned correction.
      expectNoDifference(overrides.isEmpty, true)
    }
  }

  @Test("S3b keeps typed transactional mail ahead of publication sender overrides")
  func classificationQualityUsesMarkersAndSenderShape() async throws {
    let snapshot = GmailInboxSnapshot(
      accountID: "jon@example.com",
      messages: [
        message(
          id: "online-bill", from: "Bank of America <billpay@bankofamerica.com>",
          subject: "You have a new online bill…"
        ),
        message(
          id: "mobile-deposit", from: "Bank of America <ealerts@bankofamerica.com>",
          subject: "We received your mobile check deposit"
        ),
        message(
          id: "att-bill", from: "AT&T <billing@att.com>",
          subject: "Your Home Phone bill is ready"
        ),
        message(
          id: "unknown-statement", from: "Regional Utility <receipts@regional-utility.example>",
          subject: "Your statement is ready",
          to: "jon@example.com, household@example.com, archive@example.com"
        ),
        message(
          id: "unknown-payment", from: "Regional Utility <receipts@regional-utility.example>",
          subject: "Your payment is ready",
          to: "jon@example.com, household@example.com, archive@example.com"
        ),
        message(
          id: "apple-shipment", from: "Apple <shipping_notification@orders.apple.com>",
          subject: "Your shipment is on its way. Order No. W1234"
        ),
        message(
          id: "ups-delivery", from: "UPS Update <delivery@ups.com>",
          subject: "UPS Update: Package Scheduled for Delivery"
        ),
        message(
          id: "weck-order", from: "Weck Jars <orders@weckjars.com>",
          subject: "Your Weck Jars order has been received!"
        ),
        message(
          id: "weck-publication", from: "Weck Jars <orders@weckjars.com>",
          subject: "A note from Weck Jars",
          extraHeaders: [GmailInboxHeader(name: "List-ID", value: "Weck Jars <weck.example>")]
        ),
        message(
          id: "unc-estimate", from: "Health Services <notifications@care.example>",
          subject: "Jon, you have a new estimate for your visit"
        ),
        message(
          id: "automated-unknown", from: "Updates <notifications@example.com>",
          subject: "Your account needs attention"
        ),
        message(
          id: "human", from: "Domenico <domenico@tenutaterrenere.com>",
          subject: "Dinner next week"
        ),
      ])

    let report = try await GmailInboxIngestor(
      client: GmailInboxClient(currentInbox: { snapshot }), now: { .distantPast }
    ).ingest(into: database)
    let pieces = Dictionary(uniqueKeysWithValues: report.contentPieces.map { ($0.title, $0) })

    for title in [
      "You have a new online bill…", "We received your mobile check deposit",
      "Your Home Phone bill is ready",
    ] {
      expectNoDifference(pieces[title]?.emailTreatment, .transactional)
      expectNoDifference(pieces[title]?.emailTransactionalKind, .finance)
    }
    expectNoDifference(pieces["Your statement is ready"]?.emailTransactionalKind, .finance)
    expectNoDifference(pieces["Your payment is ready"]?.emailTreatment, .newsletter)
    expectNoDifference(pieces["Your payment is ready"]?.emailTransactionalKind, nil)
    for title in [
      "Your shipment is on its way. Order No. W1234",
      "UPS Update: Package Scheduled for Delivery", "Your Weck Jars order has been received!",
    ] {
      expectNoDifference(pieces[title]?.emailTreatment, .transactional)
      expectNoDifference(pieces[title]?.emailTransactionalKind, .shipment)
    }
    expectNoDifference(
      pieces["Jon, you have a new estimate for your visit"]?.emailTransactionalKind, .reference)
    expectNoDifference(pieces["Your account needs attention"]?.emailTransactionalKind, .reference)
    expectNoDifference(pieces["Dinner next week"]?.emailTreatment, .personal)
    expectNoDifference(pieces["Dinner next week"]?.emailTransactionalKind, nil)

    let corrected = try await database.write { db in
      try EmailTreatmentOperations.setSenderOverride(.offer, for: "orders@weckjars.com", in: db)
    }
    let correctedByTitle = Dictionary(uniqueKeysWithValues: corrected.map { ($0.title, $0) })
    // Invariant A: a publication override cannot demote a clearly typed transactional message.
    expectNoDifference(correctedByTitle["Your Weck Jars order has been received!"]?.emailTreatment, .transactional)
    expectNoDifference(
      correctedByTitle["Your Weck Jars order has been received!"]?.emailTransactionalKind, .shipment)
    // The same explicit correction still decides the genuinely ambiguous publication residue.
    expectNoDifference(correctedByTitle["A note from Weck Jars"]?.emailTreatment, .offer)
    expectNoDifference(correctedByTitle["A note from Weck Jars"]?.emailTransactionalKind, nil)
  }

  @Test("Order confirmations classify transactionally without misclassifying people or newsletters")
  func orderConfirmationsUseSenderAndSpecificSubjectMarkers() async throws {
    let snapshot = GmailInboxSnapshot(
      accountID: "jon@example.com",
      messages: [
        message(
          id: "amazon-order", from: "Amazon <auto-confirm@amazon.com>", subject: "Ordered: 1 item"),
        message(
          id: "amazon-listed-order", from: "Amazon <auto-confirm@amazon.com>", subject: "Ordered: 1 item",
          extraHeaders: [GmailInboxHeader(name: "List-Unsubscribe", value: "<https://example.com/unsubscribe>")]
        ),
        message(
          id: "shop-receipt", from: "Example Shop <confirmations@shop.example>",
          subject: "Your receipt from Example Shop"),
        message(
          id: "human-ordered", from: "Dana <dana@example.com>", subject: "I ordered: the blue tiles"),
        message(
          id: "newsletter-order", from: "Operations Weekly <weekly@newsletter.example>",
          subject: "Order of operations",
          extraHeaders: [GmailInboxHeader(name: "List-ID", value: "Operations Weekly <weekly.example>")]
        ),
        message(
          id: "summary-order-newsletter", from: "Daily News <brief@daily.example>",
          subject: "Daily Brief",
          extraHeaders: [GmailInboxHeader(name: "List-ID", value: "Daily News <daily.example>")]
        ),
      ])

    let report = try await GmailInboxIngestor(
      client: GmailInboxClient(currentInbox: { snapshot }), now: { .distantPast }
    ).ingest(into: database)
    let amazonOrders = report.contentPieces.filter { $0.title == "Ordered: 1 item" }
    #expect(amazonOrders.count == 2)
    for piece in amazonOrders {
      #expect(piece.emailTreatment == .transactional)
      #expect(piece.emailTransactionalKind == .reference)
    }
    let humanMessage = report.contentPieces.first { $0.title == "I ordered: the blue tiles" }
    #expect(humanMessage?.emailTreatment == .personal)
    #expect(humanMessage?.emailTransactionalKind == nil)
    let newsletter = report.contentPieces.first { $0.title == "Order of operations" }
    #expect(newsletter?.emailTreatment == .newsletter)
    #expect(newsletter?.emailTransactionalKind == nil)
    let summaryNewsletter = try #require(
      report.contentPieces.first { $0.title == "Daily Brief" })
    let reclassifiedSummary = try await database.write { db in
      try ContentPiece.find(summaryNewsletter.id).update {
        $0.summary = #bind("A gag order placed on Tuesday was described in the article.")
      }.execute(db)
      return try EmailTreatmentOperations.classify(
        emailContentPieceIDs: [summaryNewsletter.id], in: db).first
    }
    #expect(reclassifiedSummary?.emailTreatment == .newsletter)
    #expect(reclassifiedSummary?.emailTransactionalKind == nil)
    let receipt = report.contentPieces.first { $0.title == "Your receipt from Example Shop" }
    #expect(receipt?.emailTreatment == .transactional)
    #expect(receipt?.emailTransactionalKind == .reference)
  }

  @Test("S-t8 detector revision reclassifies existing order mail once")
  func transactionalDetectorRevisionReclassifiesExistingMailOnce() async throws {
    let migrator = CockpitMigrations.makeMigrator()
    try migrator.migrate(database)

    let pieceID = UUID(9_101)
    let artifactID = UUID(9_102)
    let provenance = GmailArtifactProvenance(
      accountID: "jon@example.com", messageID: "amazon-order", threadID: "thread-amazon-order",
      rfcMessageID: nil, listUnsubscribe: nil, listID: nil, precedence: nil,
      senderAddress: "auto-confirm@amazon.com", sendingDomain: "amazon.com", dkimDomain: nil,
      toRecipientCount: 1, ccRecipientCount: 0
    )
    let provenanceJSON = String(decoding: try JSONEncoder().encode(provenance), as: UTF8.self)
    try await database.write { db in
      try #sql(
        """
        INSERT INTO "contentPieces" (id, kind, title, publisher, createdAt, emailTreatment)
        VALUES (\(bind: pieceID), 'email', 'Ordered: 1 item', 'Amazon <auto-confirm@amazon.com>', '2026-09-28 00:00:00', 'personal')
        """
      ).execute(db)
      try #sql(
        """
        INSERT INTO "artifacts" (id, transport, acquiredAt, providerProvenance, contentPieceID)
        VALUES (\(bind: artifactID), 'gmail', '2026-09-28 00:00:00', \(bind: provenanceJSON), \(bind: pieceID))
        """
      ).execute(db)
      try #sql(
        """
        INSERT INTO "emailTreatmentClassifierState" ("singletonID", "revision")
        VALUES (1, 1)
        ON CONFLICT ("singletonID") DO UPDATE SET "revision" = excluded."revision"
        """
      ).execute(db)
    }

    let didReclassify = try await database.write { db in
      try EmailTreatmentOperations.applyClassifierRevisionIfNeeded(in: db)
    }
    #expect(didReclassify)

    let migrated = try await database.read { db in try ContentPiece.find(pieceID).fetchOne(db) }
    #expect(migrated?.emailTreatment == .transactional)
    #expect(migrated?.emailTransactionalKind == .reference)

    try await database.write { db in
      try ContentPiece.find(pieceID).update {
        $0.emailTreatment = #bind(.personal)
        $0.emailTransactionalKind = #bind(nil as EmailTransactionalKind?)
      }.execute(db)
    }
    let didReclassifyAgain = try await database.write { db in
      try EmailTreatmentOperations.applyClassifierRevisionIfNeeded(in: db)
    }
    #expect(!didReclassifyAgain)
    let secondOpen = try await database.read { db in try ContentPiece.find(pieceID).fetchOne(db) }
    #expect(secondOpen?.emailTreatment == .personal)
    #expect(secondOpen?.emailTransactionalKind == nil)
    let overrides = try await database.read { db in
      try EmailSenderTreatmentOverride.all.fetchAll(db)
    }
    #expect(overrides.isEmpty)
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

  @Test("Explicit sender corrections re-tier mail and survive recomposition")
  func senderOverrideWinsAndPersists() async throws {
    let snapshot = GmailInboxSnapshot(
      accountID: "jon@example.com",
      messages: [
        message(
          id: "correction", from: "Service <offers@example.com>", subject: "A note from Service",
          extraHeaders: [GmailInboxHeader(name: "List-ID", value: "Service <service.example>")]
        ),
      ])
    let piece = try #require(try await GmailInboxIngestor(
      client: GmailInboxClient(currentInbox: { snapshot }), now: { .distantPast }
    ).ingest(into: database).contentPieces.first)
    let artifactsBefore = try await database.read { db in
      try Artifact.where { $0.contentPieceID.eq(piece.id) }.fetchAll(db)
    }

    let defaultReclassified = try await database.write { db in
      try EmailTreatmentOperations.reclassifyAll(in: db)
    }
    expectNoDifference(
      defaultReclassified.first { $0.id == piece.id }?.emailTreatment, .newsletter)
    try await database.read { db in
      expectNoDifference(try EmailSenderTreatmentOverride.fetchCount(db), 0)
    }

    let first = try await database.write { db in
      try EmailTreatmentOperations.setSenderOverride(
        .offer, for: "Service <offers@example.com>", in: db)
    }
    let recomposed = try await database.write { db in
      try EmailTreatmentOperations.reclassifyAll(in: db)
    }
    let artifactsAfter = try await database.read { db in
      try Artifact.where { $0.contentPieceID.eq(piece.id) }.fetchAll(db)
    }

    expectNoDifference(first.first { $0.id == piece.id }?.emailTreatment, .offer)
    expectNoDifference(recomposed.first { $0.id == piece.id }?.emailTreatment, .offer)
    expectNoDifference(artifactsAfter, artifactsBefore)
    try await database.read { db in
      let override = try EmailSenderTreatmentOverride.find("offers@example.com").fetchOne(db)
      expectNoDifference(override?.treatment, .offer)
    }
  }

  @Test("A human one-to-one message is never made transactional by a confirmation subject")
  func humanOneToOneWinsOverTypeMarkers() async throws {
    let snapshot = GmailInboxSnapshot(
      accountID: "jon@example.com",
      messages: [message(id: "forward", from: "Maya <maya@example.com>", subject: "Hotel confirmation")])

    let piece = try #require(try await GmailInboxIngestor(
      client: GmailInboxClient(currentInbox: { snapshot }), now: { .distantPast }
    ).ingest(into: database).contentPieces.first)

    expectNoDifference(piece.emailTreatment, .personal)
    expectNoDifference(piece.emailTransactionalKind, nil)
  }

  private func message(
    id: String, from: String, subject: String, to: String = "jon@example.com",
    extraHeaders: [GmailInboxHeader] = []
  ) -> GmailInboxMessage {
    GmailInboxMessage(
      id: id, threadID: "thread-\(id)",
      headers: [
        GmailInboxHeader(name: "From", value: from),
        GmailInboxHeader(name: "Subject", value: subject),
        GmailInboxHeader(name: "To", value: to),
      ] + extraHeaders,
      bodyPlainText: "A readable email body."
    )
  }
}
