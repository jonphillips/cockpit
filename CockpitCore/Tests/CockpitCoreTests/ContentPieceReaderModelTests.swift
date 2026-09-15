@testable import CockpitCore
import CustomDump
import Dependencies
import DependenciesTestSupport
import Foundation
import LLMClientKit
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

  @Test("Reader teaching persists its explicit reason and ContentPiece provenance only after confirmation")
  func readerTeachingPersistsProvenance() async throws {
    let pieceID = UUID(9002)
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          id: pieceID, kind: .article, title: "A reuse hotel", publisher: "Publisher",
          summary: "A hotel adapted from a former factory.", createdAt: .distantPast)
      }.execute(db)
    }
    let response = """
    {"proposals":[{
      "kind":"interest",
      "claim":"Cares about adaptive reuse in hotels.",
      "scope":"Travel and hotel selection",
      "action":"new",
      "replacesClaimIDs":[],
      "semanticFidelity":true,
      "rationale":"Uses Jon's explicit reason without treating the one hotel as the interest."
    }]}
    """
    let model = withDependencies {
      $0.modelClient = StubModelClient.constant(response)
      $0.uuid = .incrementing
    } operation: {
      ContentPieceReaderModel(contentPieceID: pieceID)
    }
    try await model.$content.load()

    model.beginTeaching()
    model.teachingReason = "I'm not interested in this specific hotel, but I care about this kind of adaptive reuse."
    await model.reviewTeachingButtonTapped()

    let proposal: PersonalKnowledgeProposal
    guard case let .proposal(value) = model.teachingStage else {
      Issue.record("expected Reader teaching to present a proposal")
      return
    }
    proposal = value
    #expect(proposal.requiresConfirmation)
    let beforeConfirmation = try await database.read { db in
      (
        try PersonalKnowledgeClaim.fetchCount(db),
        try PersonalKnowledgeTeaching.fetchCount(db)
      )
    }
    expectNoDifference(beforeConfirmation.0, 0)
    expectNoDifference(beforeConfirmation.1, 0)

    await model.saveTeachingButtonTapped()

    let stored = try await database.read { db in
      (try PersonalKnowledgeClaim.fetchOne(db), try PersonalKnowledgeTeaching.fetchOne(db))
    }
    let claim = try #require(stored.0)
    let teaching = try #require(stored.1)
    expectNoDifference(claim.provenance, .readerTeaching)
    expectNoDifference(claim.teachingID, teaching.id)
    expectNoDifference(claim.claim, "Cares about adaptive reuse in hotels.")
    expectNoDifference(claim.scope, "Travel and hotel selection")
    expectNoDifference(teaching.contentPieceID, pieceID)
    expectNoDifference(teaching.reason, "I'm not interested in this specific hotel, but I care about this kind of adaptive reuse.")
    #expect(model.teachingStage == nil)
  }

  @Test("A broad Reader synthesis remains a proposal until Jon explicitly confirms it")
  func broadReaderSynthesisRequiresConfirmation() async throws {
    let pieceID = UUID(9003)
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          id: pieceID, kind: .article, title: "A Riesling", publisher: "Publisher", createdAt: .distantPast)
      }.execute(db)
    }
    let response = """
    {"proposals":[{
      "kind":"taste", "claim":"Likes fruity wines.", "scope":"",
      "action":"new", "replacesClaimIDs":[], "semanticFidelity":true,
      "rationale":"This is broader than the supplied teaching."
    }]}
    """
    let model = withDependencies {
      $0.modelClient = StubModelClient.constant(response)
    } operation: {
      ContentPieceReaderModel(contentPieceID: pieceID)
    }
    try await model.$content.load()
    model.beginTeaching()
    model.teachingReason = "When drinking dry Riesling, I generally prefer some fruit over severe austerity."

    await model.reviewTeachingButtonTapped()

    guard case let .proposal(proposal) = model.teachingStage else {
      Issue.record("expected the broad synthesis to remain a proposal")
      return
    }
    expectNoDifference(proposal.claim, "Likes fruity wines.")
    #expect(proposal.requiresConfirmation)
    let storedCounts = try await database.read { db in
      (try PersonalKnowledgeClaim.fetchCount(db), try PersonalKnowledgeTeaching.fetchCount(db))
    }
    expectNoDifference(storedCounts.0, 0)
    expectNoDifference(storedCounts.1, 0)
  }
}
