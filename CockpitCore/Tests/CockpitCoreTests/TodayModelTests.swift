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

  @Test("Today keeps arrival order inside the role-oriented surface")
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

    expectNoDifference(model.sections.map(\.role), [.forYou])
    expectNoDifference(
      model.sections[0].rows.map(\.id),
      [transactional, grabBag, offer, newsletter, personalLate, personalEarly])
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
    #expect(state.2?.kind == .email)
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

  @Test("Sender correction reloads Today and moves every piece from that sender")
  func senderCorrectionReloadsProjection() async throws {
    let pieceID = UUID(7_401)
    try await seed(
      pieceID, treatment: .newsletter, receivedAt: 9_990,
      publisher: "Ministry of Supply <offers@ministry.example>",
      providerProvenance: "{\"listID\":\"Ministry of Supply\"}")

    let model = TodayModel()
    try await model.$content.load()
    let row = try #require(model.content.rows.first)
    #expect(row.treatment == .newsletter)
    let overrideCount = try await database.read { db in
      try EmailSenderTreatmentOverride.fetchCount(db)
    }
    #expect(overrideCount == 0)

    await model.setSenderOverride(.offer, for: row)

    #expect(model.content.rows.first?.treatment == .offer)
    #expect(model.content.rows.filter { $0.treatment == .offer }.count == 1)
    #expect(model.content.rows.filter { $0.treatment == .newsletter }.isEmpty)
    #expect(model.errorMessage == nil)
    let overrideTreatment = try await database.read { db in
      try EmailSenderTreatmentOverride.find("offers@ministry.example").fetchOne(db)?.treatment
    }
    #expect(overrideTreatment == .offer)
  }

  @discardableResult
  private func seed(
    _ pieceID: ContentPiece.ID,
    treatment: EmailTreatment,
    receivedAt: TimeInterval,
    publisher: String = "Sender",
    summary: String? = nil,
    providerProvenance: String = "{}"
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
          id: artifactID, transport: .gmail,
          providerID: "gmail:message:\(pieceID.uuidString)",
          acquiredAt: Date(timeIntervalSince1970: receivedAt), rawSourceText: "Body",
          providerProvenance: providerProvenance, contentPieceID: pieceID)
      }.execute(db)
    }
    return artifactID
  }
}
