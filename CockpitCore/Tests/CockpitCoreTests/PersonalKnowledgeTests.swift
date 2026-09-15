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
    $0.date.now = Date(timeIntervalSince1970: 123)
    try $0.bootstrapDatabase()
  }
)
@MainActor
struct PersonalKnowledgeTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("Direct teaching persists current Personal Knowledge with explicit provenance")
  func directTeaching() async throws {
    let model = PersonalKnowledgeModel()
    model.directTeaching = PersonalKnowledgeDraft(
      kind: .fact, claim: "Home airport is RDU.", scope: "Travel planning"
    )

    await model.teachButtonTapped()
    try await model.$knowledge.load()

    let row = try #require(model.claims.first)
    expectNoDifference(row.kind, .fact)
    expectNoDifference(row.claim, "Home airport is RDU.")
    expectNoDifference(row.scope, "Travel planning")
    expectNoDifference(row.provenance, .directTeaching)
    expectNoDifference(row.status, .current)
    #expect(model.errorMessage == nil)
  }

  @Test("A Jon Brain import keeps a materially new inference pending confirmation")
  func newInferenceRequiresConfirmation() async throws {
    let response = """
    {"proposals":[{
      "kind":"taste", "claim":"Dislikes cities.", "scope":"",
      "action":"new", "replacesClaimIDs":[], "semanticFidelity":true,
      "rationale":"This would be a broader statement."
    }]}
    """
    let model = withDependencies {
      $0.modelClient = StubModelClient.constant(response)
    } operation: {
      PersonalKnowledgeModel()
    }
    model.importText = "- [Taste] Prefers small countryside hotels."

    await model.reviewImportButtonTapped()

    let proposal = try #require(model.proposals.first)
    #expect(proposal.requiresConfirmation)
    #expect(model.selectedProposalIDs.isEmpty)
    let countBeforeConfirmation = try await database.read { db in
      try PersonalKnowledgeClaim.fetchCount(db)
    }
    expectNoDifference(countBeforeConfirmation, 0)

    model.selectedProposalIDs.insert(proposal.id)
    await model.importSelectedButtonTapped()
    let stored = try await database.read { db in
      try PersonalKnowledgeClaim.all.fetchAll(db)
    }
    expectNoDifference(stored.count, 1)
    expectNoDifference(stored[0].provenance, .jonBrainImport)
  }

  @Test("A semantic consolidation preserves history through supersession")
  func semanticConsolidation() async throws {
    let existingID = UUID(-1)
    try await database.write { db in
      try PersonalKnowledgeOperations.teach(
        id: existingID, kind: .taste, claim: "Prefers small luxury hotels.", scope: nil,
        at: .distantPast, in: db
      )
    }
    let response = """
    {"proposals":[{
      "kind":"taste",
      "claim":"Prefers smaller, characterful countryside luxury hotels over large corporate-feeling properties.",
      "scope":"Hotel selection",
      "action":"consolidate", "replacesClaimIDs":["\(existingID.uuidString)"],
      "semanticFidelity":true, "rationale":"Preserves and usefully scopes the existing explicit preference."
    }]}
    """
    let model = withDependencies {
      $0.modelClient = StubModelClient.constant(response)
    } operation: {
      PersonalKnowledgeModel()
    }
    try await model.$knowledge.load()
    model.importText = "- [Taste] Prefers smaller, characterful countryside luxury hotels over large corporate-feeling properties."

    await model.reviewImportButtonTapped()

    let proposal = try #require(model.proposals.first)
    #expect(!proposal.requiresConfirmation)
    #expect(model.selectedProposalIDs.contains(proposal.id))
    await model.importSelectedButtonTapped()
    let claims = try await database.read { db in
      try PersonalKnowledgeClaim.all.fetchAll(db)
    }
    let old = try #require(claims.first { $0.id == existingID })
    let current = try #require(claims.first { $0.id != existingID })
    expectNoDifference(old.status, .superseded)
    expectNoDifference(old.supersededByID, current.id)
    expectNoDifference(current.status, .current)
    expectNoDifference(current.provenance, .semanticConsolidation)
    expectNoDifference(current.provenance.displayName, "Synthesized from explicit claims")

    // The superseded row is retained but must not render as present understanding.
    try await model.$knowledge.load()
    expectNoDifference(model.claims.count, 2)
    expectNoDifference(model.currentClaims.map(\.id), [current.id])
  }

  @Test("Correction supersedes a current claim and retirement preserves its provenance")
  func correctionAndRetirement() async throws {
    let originalID = UUID(-1)
    try await database.write { db in
      try PersonalKnowledgeOperations.teach(
        id: originalID, kind: .taste, claim: "Likes city hotels.", scope: "Travel",
        at: .distantPast, in: db
      )
    }
    let model = PersonalKnowledgeModel()
    try await model.$knowledge.load()
    let original = try #require(model.currentClaims.first)

    model.correctButtonTapped(original)
    expectNoDifference(model.correctingClaimID, originalID)
    #expect(model.isCorrecting)
    model.correctionDraft.claim = "Prefers smaller countryside hotels."
    model.correctionDraft.scope = "Hotel selection"
    await model.saveCorrectionButtonTapped()

    try await model.$knowledge.load()
    let superseded = try #require(model.claims.first { $0.id == originalID })
    let correction = try #require(model.currentClaims.first)
    expectNoDifference(superseded.status, .superseded)
    expectNoDifference(superseded.supersededByID, correction.id)
    expectNoDifference(superseded.provenance, .directTeaching)
    expectNoDifference(correction.provenance, .correction)
    expectNoDifference(correction.claim, "Prefers smaller countryside hotels.")

    await model.retireButtonTapped(correction)
    try await model.$knowledge.load()
    let retired = try #require(model.claims.first { $0.id == correction.id })
    expectNoDifference(retired.status, .retired)
    expectNoDifference(retired.provenance, .correction)
    expectNoDifference(model.currentClaims, [])
    expectNoDifference(Set(model.historicalClaims.map(\.id)), Set([originalID, correction.id]))
  }

  @Test("Accumulated teaching offers a semantic consolidation before writing it")
  func accumulatedSemanticConsolidation() async throws {
    let firstID = UUID(-1)
    let secondID = UUID(-2)
    try await database.write { db in
      try PersonalKnowledgeOperations.teach(
        id: firstID, kind: .taste, claim: "Prefers small luxury hotels.", scope: "Hotels",
        at: .distantPast, in: db
      )
      try PersonalKnowledgeOperations.teach(
        id: secondID, kind: .taste, claim: "Dislikes corporate-feeling resorts.", scope: "Hotels",
        at: .distantPast, in: db
      )
    }
    let response = """
    {"proposals":[{
      "kind":"taste",
      "claim":"Prefers smaller, characterful luxury hotels over corporate-feeling resorts.",
      "scope":"Hotels",
      "action":"consolidate", "replacesClaimIDs":["\(firstID.uuidString)","\(secondID.uuidString)"],
      "semanticFidelity":true, "rationale":"Combines two compatible preferences without broadening them."
    }]}
    """
    let model = withDependencies {
      $0.modelClient = StubModelClient.constant(response)
    } operation: {
      PersonalKnowledgeModel()
    }
    try await model.$knowledge.load()

    await model.reviewConsolidationButtonTapped()

    expectNoDifference(model.proposalReview, .accumulatedClaims)
    let proposal = try #require(model.proposals.first)
    #expect(!proposal.requiresConfirmation)
    #expect(model.selectedProposalIDs.contains(proposal.id))
    let countBeforeApply = try await database.read { db in
      try PersonalKnowledgeClaim.fetchCount(db)
    }
    expectNoDifference(countBeforeApply, 2)

    await model.importSelectedButtonTapped()
    let claims = try await database.read { db in
      try PersonalKnowledgeClaim.all.fetchAll(db)
    }
    let consolidated = try #require(claims.first { $0.provenance == .semanticConsolidation })
    expectNoDifference(claims.first { $0.id == firstID }?.supersededByID, consolidated.id)
    expectNoDifference(claims.first { $0.id == secondID }?.supersededByID, consolidated.id)
  }

  @Test("A materially new consolidation is surfaced and cannot write itself")
  func accumulatedMaterialInferenceRequiresConfirmation() async throws {
    let firstID = UUID(-1)
    let secondID = UUID(-2)
    try await database.write { db in
      try PersonalKnowledgeOperations.teach(
        id: firstID, kind: .taste, claim: "Prefers small luxury hotels.", scope: "Hotels",
        at: .distantPast, in: db
      )
      try PersonalKnowledgeOperations.teach(
        id: secondID, kind: .taste, claim: "Prefers countryside locations.", scope: "Hotels",
        at: .distantPast, in: db
      )
    }
    let response = """
    {"proposals":[{
      "kind":"taste", "claim":"Dislikes cities.", "scope":"",
      "action":"consolidate", "replacesClaimIDs":["\(firstID.uuidString)","\(secondID.uuidString)"],
      "semanticFidelity":false, "rationale":"This would be a broader inference."
    }]}
    """
    let model = withDependencies {
      $0.modelClient = StubModelClient.constant(response)
    } operation: {
      PersonalKnowledgeModel()
    }
    try await model.$knowledge.load()

    await model.reviewConsolidationButtonTapped()

    let proposal = try #require(model.proposals.first)
    #expect(proposal.requiresConfirmation)
    expectNoDifference(model.selectedProposalIDs, [])
    let claims = try await database.read { db in
      try PersonalKnowledgeClaim.all.fetchAll(db)
    }
    expectNoDifference(claims.map(\.id).sorted { $0.uuidString < $1.uuidString }, [firstID, secondID].sorted { $0.uuidString < $1.uuidString })
    #expect(claims.allSatisfy { $0.status == .current })
  }

  @Test("Projection contains only current labelled claims and records its subset")
  func projection() {
    let current = PersonalKnowledgeClaim(
      id: UUID(-1), kind: .interest, claim: "Burgundy travel and wine.",
      provenance: .jonBrainImport, createdAt: .distantPast
    )
    let superseded = PersonalKnowledgeClaim(
      id: UUID(-2), kind: .taste, claim: "Old preference.",
      provenance: .directTeaching, status: .superseded, createdAt: .distantPast
    )
    let full = PersonalKnowledgeProjector.project([current, superseded])
    expectNoDifference(full.text, "Interest:\n- Burgundy travel and wine.")
    expectNoDifference(full.includedClaimIDs, [current.id])
    #expect(full.isFullSet)

    let many = (0...150).map { index in
      PersonalKnowledgeClaim(
        id: UUID(-index - 10), kind: .interest,
        claim: index == 0 ? "Burgundy travel." : "Other interest \(index).",
        provenance: .jonBrainImport, createdAt: .distantPast
      )
    }
    let subset = PersonalKnowledgeProjector.project(many, relevantTo: ["Burgundy wine"])
    expectNoDifference(subset.includedClaimIDs, [many[0].id])
    #expect(!subset.isFullSet)
    #expect(!subset.text.contains("Other interest"))
  }
}

@Suite
struct PersonalKnowledgeReconcilerTests {
  @Test("The output budget scales with the import so a large dump is not truncated")
  func outputBudgetScales() {
    let small = PersonalKnowledgeReconciler.outputBudget(importText: "- [Fact] One.", existingClaims: [])
    let bigImport = (1...100).map { "- [Fact] Claim \($0)." }.joined(separator: "\n")
    let large = PersonalKnowledgeReconciler.outputBudget(importText: bigImport, existingClaims: [])
    #expect(small == 4_000)
    #expect(large > small)
    #expect(large <= 16_000)
  }

  @Test("A response the decoder can't read fails with the raw text, not silently")
  func undecodableResponseSurfaces() async throws {
    let reconciler = PersonalKnowledgeReconciler(
      modelClient: StubModelClient { _ in
        ModelResponse(text: "- [Fact] Lives in Chapel Hill.", responseFormatStatus: .fellBack)
      }
    )
    do {
      _ = try await reconciler.reconcile(importText: "anything", existingClaims: [])
      Issue.record("expected the undecodable response to throw")
    } catch let error as ReconciliationError {
      expectNoDifference(
        error,
        .undecodableResponse(status: .fellBack, snippet: "- [Fact] Lives in Chapel Hill.")
      )
    }
  }

  @Test("Reader teaching rejects more than one proposal", .dependency(\.uuid, .incrementing))
  func readerTeachingRejectsMultipleProposals() async throws {
    let response = """
    {"proposals":[
      {"kind":"taste","claim":"Prefers local hotels.","scope":"Travel","action":"new","replacesClaimIDs":[],"semanticFidelity":true,"rationale":"Explicit teaching."},
      {"kind":"interest","claim":"Cares about adaptive reuse.","scope":"Travel","action":"new","replacesClaimIDs":[],"semanticFidelity":true,"rationale":"Explicit teaching."}
    ]}
    """
    let reconciler = PersonalKnowledgeReconciler(modelClient: StubModelClient.constant(response))

    await #expect(throws: ReconciliationError.invalidAction) {
      try await reconciler.teachFromReader(
        reason: "I care about adaptive reuse in hotels.", contentTitle: "A hotel", publisher: "Publisher",
        summary: nil, existingClaims: []
      )
    }
  }
}
