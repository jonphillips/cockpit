@testable import CockpitCore
import CustomDump
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@Suite(.serialized, .dependencies {
  try $0.bootstrapDatabase()
  $0.date.now = Date(timeIntervalSince1970: 10_000)
})
@MainActor
struct TodayModelTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("Today uses the fixed treatment hierarchy and arrival order within each tier")
  func hierarchy() async throws {
    let personalEarly = UUID(7_001)
    let personalLate = UUID(7_002)
    let newsletter = UUID(7_003)
    let offer = UUID(7_004)
    let grabBag = UUID(7_005)
    let transactional = UUID(7_006)
    try await seed(personalEarly, treatment: .personal, receivedAt: 1)
    try await seed(personalLate, treatment: .personal, receivedAt: 2)
    try await seed(newsletter, treatment: .newsletter, receivedAt: 3)
    try await seed(offer, treatment: .offer, receivedAt: 4)
    try await seed(grabBag, treatment: .grabBag, receivedAt: 5)
    try await seed(transactional, treatment: .transactional, receivedAt: 6)

    let model = TodayModel()
    try await model.$content.load()

    expectNoDifference(
      model.tiers.map(\.treatment), [.personal, .newsletter, .offer, .grabBag, .transactional])
    expectNoDifference(model.tiers[0].rows.map(\.id), [personalLate, personalEarly])
    expectNoDifference(model.tiers[1].rows.map(\.id), [newsletter])
    expectNoDifference(model.tiers[2].rows.map(\.id), [offer])
    expectNoDifference(model.tiers[3].rows.map(\.id), [grabBag])
    expectNoDifference(model.tiers[4].rows.map(\.id), [transactional])
  }

  @Test("S4 projects counts, fresh arrivals, personal highlight, and compact offer groups")
  func orientationProjection() async throws {
    let personal = UUID(7_301)
    let newsletter = UUID(7_302)
    let offerOne = UUID(7_303)
    let offerTwo = UUID(7_304)
    let otherOffer = UUID(7_305)
    let transactional = UUID(7_306)
    try await seed(
      personal, treatment: .personal, receivedAt: 9_800, publisher: "Jon's family")
    try await seed(
      newsletter, treatment: .newsletter, receivedAt: 9_900, publisher: "Noahpinion")
    try await seed(
      offerOne, treatment: .offer, receivedAt: 9_700, publisher: "Wine Shop <offers@wine.example>", summary: "A Pinot release")
    try await seed(
      offerTwo, treatment: .offer, receivedAt: 9_600, publisher: "Wine Shop <offers@wine.example>", summary: "A Burgundy release")
    try await seed(
      otherOffer, treatment: .offer, receivedAt: 9_500, publisher: "Coffee Shop", summary: "A new roast")
    try await seed(
      transactional, treatment: .transactional, receivedAt: 9_950, publisher: "Carrier")

    let model = TodayModel()
    try await model.$content.load()

    #expect(model.totalCount == 6)
    #expect(model.count(for: .offer) == 3)
    #expect(model.count(for: .transactional) == 1)
    #expect(model.personalHighlight?.id == personal)
    #expect(model.promotedRows.map(\.id) == [newsletter, offerOne])
    #expect(model.offerGroups.map(\.label) == ["Wine Shop", "Coffee Shop"])
    #expect(model.offerGroups.map(\.count) == [2, 1])
    #expect(model.offerGroups[0].rows.map(\.id) == [offerOne, offerTwo])
  }

  @Test("Clear resolves only Cockpit attention and leaves Gmail evidence unchanged")
  func clearIsCockpitOnly() async throws {
    let pieceID = UUID(7_101)
    let artifactID = try await seed(pieceID, treatment: .personal, receivedAt: 1)
    let model = TodayModel()
    try await model.$content.load()
    let row = try #require(model.content.rows.first)
    model.selectedContentPieceID = pieceID
    let evidenceBefore = try await database.read { db in
      try Artifact.find(artifactID).fetchOne(db)
    }

    await model.clear(row)

    #expect(model.content.rows.isEmpty)
    #expect(model.selectedContentPieceID == nil)
    #expect(model.errorMessage == nil)
    let state = try await database.read { db in
      (
        try TodayAttention.find(pieceID).fetchOne(db),
        try Artifact.find(artifactID).fetchOne(db),
        try ContentPiece.find(pieceID).fetchOne(db)
      )
    }
    expectNoDifference(state.0?.clearedAt, Date(timeIntervalSince1970: 10_000))
    expectNoDifference(state.1, evidenceBefore)
    expectNoDifference(state.2?.kind, .email)
  }

  @Test("Clear rejects non-Gmail material without changing attention state")
  func clearRejectsNonGmailMaterial() async throws {
    let pieceID = UUID(7_201)
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          id: pieceID, kind: .article, title: "Article", publisher: "Publisher", createdAt: .distantPast)
      }.execute(db)
    }

    #expect(throws: TodayAttentionOperations.Failure.self) {
      try database.read { db in
        try TodayAttentionOperations.clear(pieceID, at: .distantPast, in: db)
      }
    }
    let attention = try await database.read { db in try TodayAttention.find(pieceID).fetchOne(db) }
    #expect(attention == nil)
  }

  @discardableResult
  private func seed(
    _ pieceID: ContentPiece.ID,
    treatment: EmailTreatment,
    receivedAt: TimeInterval,
    publisher: String = "Sender",
    summary: String? = nil
  ) async throws -> Artifact.ID {
    let artifactID = UUID(Int(receivedAt) + 80_000)
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          id: pieceID, kind: .email, title: "\(treatment.rawValue) \(receivedAt)",
          publisher: publisher, publishedAt: Date(timeIntervalSince1970: receivedAt), summary: summary,
          emailTreatment: treatment, createdAt: .distantPast)
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(
          id: artifactID, transport: .gmail, providerID: "gmail:message:\(pieceID.uuidString)",
          acquiredAt: Date(timeIntervalSince1970: receivedAt), rawSourceText: "Body",
          providerProvenance: "{}", contentPieceID: pieceID)
      }.execute(db)
    }
    return artifactID
  }
}
