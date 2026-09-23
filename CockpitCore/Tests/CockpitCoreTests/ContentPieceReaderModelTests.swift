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
  $0.uuid = .incrementing
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

  @Test("Reader routing edits change the next CurationRouting snapshot")
  func readerRoutingRuleReroutesPiece() async throws {
    let pieceID = UUID(9008)
    let locator = "list.example.com/morning"
    let provenance = GmailArtifactProvenance(
      accountID: "jon@example.com", messageID: "reader-routing", threadID: "thread",
      rfcMessageID: nil, listUnsubscribe: nil, listID: "Morning <\(locator)>",
      precedence: "bulk", senderAddress: "Newsletter <news@example.com>",
      sendingDomain: "example.com", dkimDomain: nil, toRecipientCount: 1, ccRecipientCount: 0)
    let provenanceJSON = String(
      data: try JSONEncoder().encode(provenance), encoding: .utf8)

    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(ContentPiece(
          id: pieceID, kind: .email, title: "Morning", creator: "Newsletter <news@example.com>",
          publisher: "Newsletter", emailTreatment: .newsletter, createdAt: .distantPast))
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(9009), transport: .gmail, acquiredAt: .distantPast,
          providerProvenance: provenanceJSON, contentPieceID: pieceID))
      }.execute(db)
    }

    let model = ContentPieceReaderModel(contentPieceID: pieceID)
    try await model.$content.load()
    await model.loadRoutingResolution()
    let resolvedLocator = try #require(model.resolvedRoutingLocator)
    expectNoDifference(resolvedLocator, CurationRouting.canonicalLocator(locator))
    expectNoDifference(model.currentTreatment, .newsletter)

    await model.saveRoutingRule(
      ContentRoleRoutingRule(locator: resolvedLocator, role: .opinion))

    let snapshot = try await database.read { db in
      try CurationRouting.snapshot(in: db)
    }
    expectNoDifference(snapshot.role(for: pieceID), .opinion)
    expectNoDifference(model.currentRoutingRule?.role, .opinion)
  }

  @Test("Reader renders a locally held full body inline")
  func fullBodyPresentation() async throws {
    let pieceID = UUID(9010)
    try await seedReaderPiece(
      id: pieceID, isSubstantivePrimary: true, bodyCompleteness: .full,
      localNormalizedText: "The complete held article.")

    let model = ContentPieceReaderModel(contentPieceID: pieceID)
    try await model.$content.load()

    expectNoDifference(
      model.bodyPresentation,
      .inline(text: "The complete held article.", isTruncated: false)
    )
  }

  @Test("Email Reader renders the newest held original HTML rather than normalized text")
  func emailOriginalHTMLPresentation() async throws {
    let pieceID = UUID(9015)
    try await seedReaderPiece(
      id: pieceID, kind: .email, isSubstantivePrimary: true, bodyCompleteness: .full,
      localNormalizedText: "Flattened email text", rawSourceText: "<p>Designed <strong>email</strong></p>",
      acquiredAt: Date(timeIntervalSince1970: 20))
    try await database.write { db in
      try Artifact.insert {
        Artifact.Draft(
          id: UUID(9017), transport: .gmail, acquiredAt: Date(timeIntervalSince1970: 30),
          rawSourceText: "<p>Newest <em>email</em></p>", contentPieceID: pieceID)
      }.execute(db)
    }

    let model = ContentPieceReaderModel(contentPieceID: pieceID)
    try await model.$content.load()

    expectNoDifference(model.bodyPresentation, .html(rawHTML: "<p>Newest <em>email</em></p>"))
  }

  @Test("A teaser email with source material keeps the Open Original fallback")
  func teaserEmailDoesNotRenderOriginalHTML() async throws {
    let pieceID = UUID(9016)
    try await seedReaderPiece(
      id: pieceID, kind: .email, isSubstantivePrimary: true, bodyCompleteness: .teaser,
      localNormalizedText: nil, rawSourceText: "<p>Teaser only</p>",
      acquiredAt: Date(timeIntervalSince1970: 20))

    let model = ContentPieceReaderModel(contentPieceID: pieceID)
    try await model.$content.load()

    expectNoDifference(model.bodyPresentation, .preview)
  }

  @Test("Reader renders a locally held truncated body inline with a source remainder")
  func truncatedBodyPresentation() async throws {
    let pieceID = UUID(9011)
    try await seedReaderPiece(
      id: pieceID, isSubstantivePrimary: true, bodyCompleteness: .truncated,
      localNormalizedText: "The opening Cockpit holds.")

    let model = ContentPieceReaderModel(contentPieceID: pieceID)
    try await model.$content.load()

    expectNoDifference(
      model.bodyPresentation,
      .inline(text: "The opening Cockpit holds.", isTruncated: true)
    )
  }

  @Test("Reader renders a teaser as a preview rather than asserting a body")
  func teaserPresentation() async throws {
    let pieceID = UUID(9012)
    try await seedReaderPiece(
      id: pieceID, isSubstantivePrimary: true, bodyCompleteness: .teaser,
      localNormalizedText: nil)

    let model = ContentPieceReaderModel(contentPieceID: pieceID)
    try await model.$content.load()

    expectNoDifference(model.bodyPresentation, .preview)
  }

  @Test("A synced full-body signal without local text stays custody-honest")
  func fullBodyWithoutLocalTextIsUnavailable() async throws {
    let pieceID = UUID(9013)
    try await seedReaderPiece(
      id: pieceID, isSubstantivePrimary: true, bodyCompleteness: .full,
      localNormalizedText: nil)

    let model = ContentPieceReaderModel(contentPieceID: pieceID)
    try await model.$content.load()

    expectNoDifference(model.bodyPresentation, .unavailable)
  }

  @Test("A digest remains a compact contents preview even when this device holds its text")
  func accessoryPresentationStaysCompact() async throws {
    let pieceID = UUID(9014)
    try await seedReaderPiece(
      id: pieceID, isSubstantivePrimary: false, bodyCompleteness: .full,
      localNormalizedText: "A digest may carry source text, but it is a skim surface.")

    let model = ContentPieceReaderModel(contentPieceID: pieceID)
    try await model.$content.load()

    expectNoDifference(model.bodyPresentation, .compactPreview)
  }

  @Test("An empty inline teaching submit is a no-op")
  func emptyTeachingSubmitIsNoOp() async throws {
    let pieceID = UUID(9018)
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          id: pieceID, kind: .article, title: "Piece", publisher: "Publisher", createdAt: .distantPast)
      }.execute(db)
    }
    let model = ContentPieceReaderModel(contentPieceID: pieceID)
    try await model.$content.load()
    model.teachingReason = "  \n\t"

    await model.submitTeachingReason()

    #expect(model.teachingStage == nil)
    #expect(!model.isReviewingTeaching)
    #expect(model.errorMessage == nil)
    expectNoDifference(model.teachingReason, "  \n\t")
  }

  @Test("Cancel clears the inline teaching text and proposal")
  func cancelTeachingClearsTextAndProposal() async throws {
    let pieceID = UUID(9019)
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
      "scope":"Travel",
      "action":"new",
      "replacesClaimIDs":[],
      "semanticFidelity":true,
      "rationale":"Faithful to the explicit teaching."
    }]}
    """
    let model = withDependencies {
      $0.modelClient = StubModelClient.constant(response)
    } operation: {
      ContentPieceReaderModel(contentPieceID: pieceID)
    }
    try await model.$content.load()
    model.teachingReason = "  I care about adaptive reuse.  "

    await model.submitTeachingReason()

    guard case .proposal = model.teachingStage else {
      Issue.record("expected inline teaching to present a proposal")
      return
    }
    expectNoDifference(model.teachingReason, "I care about adaptive reuse.")

    model.cancelTeaching()

    #expect(model.teachingStage == nil)
    expectNoDifference(model.teachingReason, "")
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
    } operation: {
      ContentPieceReaderModel(contentPieceID: pieceID)
    }
    try await model.$content.load()

    model.teachingReason = "I'm not interested in this specific hotel, but I care about this kind of adaptive reuse."
    await model.submitTeachingReason()

    let proposal: PersonalKnowledgeProposal
    guard case let .proposal(value) = model.teachingStage else {
      Issue.record("expected Reader teaching to present a proposal")
      return
    }
    proposal = value
    expectNoDifference(proposal.id, UUID(0))
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
    expectNoDifference(model.readerTaughtClaim?.id, claim.id)
    #expect(model.teachingStage == nil)
  }

  private func seedReaderPiece(
    id: ContentPiece.ID,
    kind: ContentKind = .article,
    isSubstantivePrimary: Bool,
    bodyCompleteness: BodyCompleteness,
    localNormalizedText: String?,
    rawSourceText: String? = nil,
    acquiredAt: Date = .distantPast
  ) async throws {
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          id: id, kind: kind, title: "Piece", publisher: "Publisher", summary: "A preview.",
          isSubstantivePrimary: isSubstantivePrimary, bodyCompleteness: bodyCompleteness,
          createdAt: .distantPast)
      }.execute(db)
      if let localNormalizedText {
        try NormalizedTextOperations.store(localNormalizedText, for: id, in: db)
      }
      if rawSourceText != nil {
        try Artifact.insert {
          Artifact.Draft(
            id: id.seededArtifactID, transport: .gmail, acquiredAt: acquiredAt,
            rawSourceText: rawSourceText, contentPieceID: id)
        }.execute(db)
      }
    }
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
    model.teachingReason = "When drinking dry Riesling, I generally prefer some fruit over severe austerity."

    await model.submitTeachingReason()

    guard case let .proposal(proposal) = model.teachingStage else {
      Issue.record("expected the broad synthesis to remain a proposal")
      return
    }
    expectNoDifference(proposal.claim, "Likes fruity wines.")
    #expect(proposal.requiresConfirmation)
    let storedCounts = try await database.read { db in
      (try PersonalKnowledgeClaim.fetchCount(db),
       try PersonalKnowledgeTeaching.fetchCount(db))
    }
    expectNoDifference(storedCounts.0, 0)
    expectNoDifference(storedCounts.1, 0)
  }

  @Test("Reader teaching rejects consolidation rather than rewriting existing understanding")
  func readerTeachingRejectsConsolidation() async throws {
    let pieceID = UUID(9004)
    let existingID = UUID(9005)
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          id: pieceID, kind: .article, title: "A hotel", publisher: "Publisher", createdAt: .distantPast)
      }.execute(db)
      try PersonalKnowledgeOperations.teach(
        id: existingID, kind: .interest, claim: "Likes boutique hotels.", scope: "Travel",
        at: .distantPast, in: db
      )
    }
    let response = """
    {"proposals":[{
      "kind":"interest", "claim":"Cares about adaptive reuse hotels.", "scope":"Travel",
      "action":"consolidate", "replacesClaimIDs":["\(existingID.uuidString)"],
      "semanticFidelity":true, "rationale":"An unauthorized rewrite."
    }]}
    """
    let model = withDependencies {
      $0.modelClient = StubModelClient.constant(response)
    } operation: {
      ContentPieceReaderModel(contentPieceID: pieceID)
    }
    try await model.$content.load()
    model.teachingReason = "I care about adaptive reuse."

    await model.submitTeachingReason()

    #expect(model.teachingStage == nil)
    expectNoDifference(model.errorMessage, "The model proposed an action Cockpit does not support.")
    let teachings = try await database.read { db in try PersonalKnowledgeTeaching.fetchCount(db) }
    expectNoDifference(teachings, 0)
  }

  @Test("Reader teaching rejects a Fact even if a model ignores its Taste and Interest schema")
  func readerTeachingRejectsFact() async throws {
    let pieceID = UUID(9006)
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          id: pieceID, kind: .article, title: "A profile", publisher: "Publisher", createdAt: .distantPast)
      }.execute(db)
    }
    let response = """
    {"proposals":[{
      "kind":"fact", "claim":"Lives in Durham.", "scope":"",
      "action":"new", "replacesClaimIDs":[], "semanticFidelity":false,
      "rationale":"This violates Reader teaching's kind boundary."
    }]}
    """
    let model = withDependencies {
      $0.modelClient = StubModelClient.constant(response)
    } operation: {
      ContentPieceReaderModel(contentPieceID: pieceID)
    }
    try await model.$content.load()
    model.teachingReason = "This profile matters."

    await model.submitTeachingReason()

    #expect(model.teachingStage == nil)
    expectNoDifference(model.errorMessage, "The model proposed an action Cockpit does not support.")
    let storedCounts = try await database.read { db in
      (try PersonalKnowledgeClaim.fetchCount(db), try PersonalKnowledgeTeaching.fetchCount(db))
    }
    expectNoDifference(storedCounts.0, 0)
    expectNoDifference(storedCounts.1, 0)
  }
}
