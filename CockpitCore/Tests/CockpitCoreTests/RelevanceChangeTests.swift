@testable import CockpitCore
import CustomDump
import Dependencies
import DependenciesTestSupport
import Foundation
import LLMClientKit
import SQLiteData
import Testing

@Suite(
  .serialized,
  .dependencies {
    $0.uuid = .incrementing
    $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
    try $0.bootstrapDatabase()
  }
)
@MainActor
struct RelevanceChangeTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("A judgment-matched rationale persists to the Reader and routes correction to S2")
  func rationalePersistsAndCorrectsMatchedClaim() async throws {
    let areaID = UUID(7001)
    let streamID = UUID(7002)
    let pieceID = UUID(7003)
    let claimID = UUID(7004)
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    try await database.write { db in
      try InterestArea.insert {
        InterestArea.Draft(InterestArea(id: areaID, name: "Travel"))
      }.execute(db)
      try Stream.insert {
        Stream.Draft(
          Stream(
            id: streamID, name: "Hotel openings", publisher: "Publisher", interestAreaID: areaID,
            transport: .rss, locator: "https://example.com/feed"))
      }.execute(db)
      try ContentPiece.insert {
        ContentPiece.Draft(
          ContentPiece(
            id: pieceID, kind: .article, title: "An adaptive-reuse hotel", publisher: "Publisher",
            createdAt: date))
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(
          Artifact(
            id: UUID(7005), streamID: streamID, transport: .rss, acquiredAt: date,
            contentPieceID: pieceID))
      }.execute(db)
      try NormalizedTextOperations.store("A substantive article about a new hotel.", for: pieceID, in: db)
      try PersonalKnowledgeOperations.teach(
        id: claimID, kind: .interest, claim: "Cares about adaptive-reuse hotels.",
        scope: "Travel and hotel selection", at: date, in: db)
    }

    let rationale = "Because you explicitly care about adaptive-reuse hotels, this opening appears unusually relevant."
    let engine = JudgmentEngine(
      modelClient: StubModelClient.constant(
        """
        {"judgments":[{
          "contentPieceID":"\(pieceID.uuidString)","admit":true,
          "isSubstantivePrimary":true,"section":"forYou","rank":1,
          "rationale":"\(rationale)","matchedPersonalKnowledgeClaimID":"\(claimID.uuidString)",
          "subjects":["hotels","adaptive reuse","travel"],"summary":"A hotel opening.","finds":[]
        }]}
        """
      )
    )
    _ = try await EditionComposer(engine: engine).composeIfNeeded(now: date, in: database)

    let edition = try await database.read { db in try CurrentEditionRequest().fetch(db) }
    let entry = try #require(edition.entries.first)
    expectNoDifference(entry.rationale, rationale)
    expectNoDifference(entry.matchedPersonalKnowledgeClaimID, claimID)

    let reader = ContentPieceReaderModel(
      contentPieceID: pieceID, matchedPersonalKnowledgeClaimID: entry.matchedPersonalKnowledgeClaimID)
    try await reader.$matchedPersonalKnowledge.load()
    let matchedClaim = try #require(reader.matchedClaim)
    expectNoDifference(matchedClaim.id, claimID)
    expectNoDifference(matchedClaim.claim, "Cares about adaptive-reuse hotels.")

    let stewardship = PersonalKnowledgeModel()
    try await stewardship.$knowledge.load()
    stewardship.correctButtonTapped(matchedClaim)
    stewardship.correctionDraft.claim = "Cares about adaptive reuse in hotels, not any one hotel."
    await stewardship.saveCorrectionButtonTapped()

    try await reader.$matchedPersonalKnowledge.load()
    #expect(reader.matchedClaim == nil)
    let claims = try await database.read { db in try PersonalKnowledgeClaim.all.fetchAll(db) }
    let original = try #require(claims.first { $0.id == claimID })
    #expect(original.status == .superseded)
    #expect(claims.contains {
      $0.status == .current && $0.claim == "Cares about adaptive reuse in hotels, not any one hotel."
    })
  }
}
