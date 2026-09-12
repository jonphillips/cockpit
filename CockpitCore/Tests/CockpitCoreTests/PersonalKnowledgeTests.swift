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
