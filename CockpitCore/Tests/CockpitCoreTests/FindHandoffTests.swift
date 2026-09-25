@testable import CockpitCore
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Synchronization
import Testing

@Suite(.serialized, .dependencies {
  $0.uuid = .incrementing
  $0.date.now = Date(timeIntervalSince1970: 200)
  try $0.bootstrapDatabase()
})
@MainActor
struct FindHandoffTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("S0 referral golden fixture decodes and re-encodes with ISO-8601 provenance")
  func referralGoldenFixture() throws {
    let data = try fixture("referral")
    let value = try JSONDecoder().decode(FindReferralMessage.self, from: data)
    #expect(value.version == 1)
    #expect(value.referralID == UUID(uuidString: "11111111-1111-4111-8111-111111111111"))
    #expect(value.rawText == "A newsletter with two recipes.\nIngredients and method follow.")
    #expect(value.provenance.arrivalDate == ISO8601DateFormatter().date(from: "2026-09-24T12:00:00Z"))
    try expectSameJSON(data, JSONEncoder().encode(value))
  }

  @Test("S0 set-valued verdict golden fixture decodes without synthesized enum encoding")
  func verdictGoldenFixture() throws {
    let data = try fixture("verdict")
    let value = try JSONDecoder().decode(FindVerdictMessage.self, from: data)
    #expect(value.outcomes.count == 3)
    #expect(value.outcomes[0] == .admitted(recipeRef: "33333333-3333-4333-8333-333333333333"))
    #expect(value.outcomes[1] == .declined(reason: .noRecipeFound))
    #expect(value.outcomes[2] == .declined(reason: .extractionFailed, detail: "diagnostic only"))
    try expectSameJSON(data, JSONEncoder().encode(value))
  }

  @Test("Recipe candidate convention is normalized exact kind, not a substring")
  func recipeCandidateConvention() {
    #expect(RecipeCandidateKind.matches("recipe"))
    #expect(RecipeCandidateKind.matches(" Recipe \n"))
    #expect(!RecipeCandidateKind.matches("recipes"))
    #expect(!RecipeCandidateKind.matches("wine recipe"))
    #expect(!RecipeCandidateKind.matches("restaurant"))
  }

  @Test("Referral builder ships stored readable text, not raw email HTML")
  func referralBuilderPreservesReaderBody() async throws {
    let pieceID = UUID(94_001)
    let findID = UUID(94_002)
    let body = "<html><body><h1>Recipe one</h1><p>Recipe two</p><footer>Newsletter chrome</footer></body></html>"
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          id: pieceID, kind: .email, title: "Recipes", creator: "Test Kitchen",
          publisher: "Example Newsletter", publishedAt: Date(timeIntervalSince1970: 100),
          canonicalURL: "https://example.com/issue", isSubstantivePrimary: true,
          bodyCompleteness: .full, createdAt: Date(timeIntervalSince1970: 100))
      }.execute(db)
      try LocalNormalizedText.insert {
        LocalNormalizedText.Draft(contentPieceID: pieceID, normalizedText: "Recipe one\nRecipe two")
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(94_003), transport: .gmail, providerID: "message-1",
          canonicalURL: nil, acquiredAt: Date(timeIntervalSince1970: 101),
          rawSourceText: body, providerProvenance: "{\"accountID\":\"jon@example.com\",\"messageID\":\"m1\",\"threadID\":\"t1\",\"listID\":\"recipes.example.com\",\"senderAddress\":\"test@example.com\",\"toRecipientCount\":1,\"ccRecipientCount\":0}",
          contentPieceID: pieceID))
      }.execute(db)
      try PendingFind.insert {
        PendingFind.Draft(PendingFind(
          id: findID, contentPieceID: pieceID, kind: " Recipe ", name: "Pasta",
          descriptor: "A pasta recipe", rationale: "Worth saving", sourceURL: "https://example.com/recipe"))
      }.execute(db)
    }

    let (find, row, provenance) = try await database.read { db in
      (
        try #require(try PendingFind.find(findID).fetchOne(db)),
        try #require(ContentPieceReaderRequest(contentPieceID: pieceID).fetch(db).row),
        try GmailArtifactProvenance.latest(forContentPiece: pieceID, in: db)
      )
    }
    let message = try FindReferralMessage.make(
      referralID: UUID(94_004), find: find, readerRow: row, gmailProvenance: provenance)
    #expect(message.rawText == "Recipe one\nRecipe two")
    #expect(message.rawText != body)
    #expect(message.provenance.seriesID == "recipes.example.com")
    #expect(message.provenance.contentPieceToken == pieceID.uuidString.lowercased())
    #expect(message.provenance.hints["sourceURL"] == "https://example.com/recipe")
  }

  @Test("A teaser body is unavailable for handoff even when local text exists")
  func referralBuilderRejectsTeaserBody() async throws {
    let pieceID = UUID(94_051)
    let findID = UUID(94_052)
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          id: pieceID, kind: .email, title: "Recipe teaser", publisher: "Example",
          isSubstantivePrimary: true, bodyCompleteness: .teaser,
          createdAt: Date(timeIntervalSince1970: 100))
      }.execute(db)
      try LocalNormalizedText.insert {
        LocalNormalizedText.Draft(contentPieceID: pieceID, normalizedText: "Try our new recipe")
      }.execute(db)
      try PendingFind.insert {
        PendingFind.Draft(PendingFind(
          id: findID, contentPieceID: pieceID, kind: "recipe", name: "Teaser recipe",
          descriptor: "Recipe", rationale: "A teaser"))
      }.execute(db)
    }
    let (find, row) = try await database.read { db in
      let find = try #require(try PendingFind.find(findID).fetchOne(db))
      let readerValue = try ContentPieceReaderRequest(contentPieceID: pieceID).fetch(db)
      let row = try #require(readerValue.row)
      return (find, row)
    }

    #expect(throws: FindReferralHandoffError.readableBodyUnavailable) {
      try FindReferralMessage.make(
        referralID: UUID(94_053), find: find, readerRow: row, gmailProvenance: nil
      )
    }
  }

  @Test("Gate 5 referral log migration is app-local persistence")
  func referralLogSchema() async throws {
    let columns = try await database.read { db in
      try #sql("SELECT name FROM pragma_table_info('pendingFindReferrals')", as: String.self).fetchAll(db)
    }
    #expect(columns == ["id", "pendingFindID", "sentAt", "resolvedAt", "rawOutcomeSet"])
  }

  @Test("Failed URL open deletes the referral, restores confirmation, and tells Jon Yes Chef is unavailable")
  func failedOpenReturnsToConfirmed() async throws {
    let (pieceID, findID) = try await seedCandidate(id: 94_101)
    let written = Mutex<[FindReferralMessage]>([])
    let deleted = Mutex<[UUID]>([])
    let client = FindReferralHandoffClient(
      writeReferral: { message in written.withLock { $0.append(message) } },
      deleteReferral: { id in deleted.withLock { $0.append(id) }; return true },
      openReferral: { _ in false }
    )

    await withDependencies {
      $0.findReferralHandoffClient = client
    } operation: {
      let model = PendingFindListModel()
      await model.sendToYesChef(findID)
      #expect(model.errorMessage == FindReferralHandoffError.yesChefUnavailable.localizedDescription)
    }

    let persisted = try await database.read { db in
      (
        try PendingFind.find(findID).fetchOne(db)?.state,
        try PendingFindReferral.fetchAll(db).first { $0.pendingFindID == findID }
      )
    }
    #expect(persisted.0 == .confirmed)
    #expect(persisted.1?.resolvedAt != nil)
    #expect(persisted.1?.rawOutcomeSet == "{\"delivery\":\"openFailed\"}")
    #expect(written.withLock { $0.count } == 1)
    #expect(deleted.withLock { $0 } == [try #require(persisted.1?.id)])
    #expect(try await database.read { db in try ContentPiece.find(pieceID).fetchOne(db) != nil })
  }

  private func seedCandidate(id seed: Int) async throws -> (ContentPiece.ID, PendingFind.ID) {
    let pieceID = UUID(seed)
    let findID = UUID(seed + 1)
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          id: pieceID, kind: .email, title: "Recipe issue", creator: "Test Kitchen",
          publisher: "Example Newsletter", publishedAt: Date(timeIntervalSince1970: 100),
          isSubstantivePrimary: true, bodyCompleteness: .full, createdAt: Date(timeIntervalSince1970: 100))
      }.execute(db)
      try LocalNormalizedText.insert {
        LocalNormalizedText.Draft(contentPieceID: pieceID, normalizedText: "Whole recipe issue, readable text")
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(seed + 2), transport: .gmail, acquiredAt: Date(timeIntervalSince1970: 101),
          rawSourceText: "<html><body>Whole recipe issue</body></html>", contentPieceID: pieceID))
      }.execute(db)
      try PendingFind.insert {
        PendingFind.Draft(PendingFind(
          id: findID, contentPieceID: pieceID, kind: "recipe", name: "Pasta",
          descriptor: "Recipe", rationale: "Useful"))
      }.execute(db)
    }
    return (pieceID, findID)
  }

  private func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/find-handoff"))
    return try Data(contentsOf: url)
  }

  private func expectSameJSON(_ lhs: Data, _ rhs: Data) throws {
    let left = try JSONSerialization.jsonObject(with: lhs, options: [.fragmentsAllowed])
    let right = try JSONSerialization.jsonObject(with: rhs, options: [.fragmentsAllowed])
    #expect(NSDictionary(dictionary: left as? [String: Any] ?? [:]).isEqual(to: right as? [String: Any] ?? [:]))
  }
}
