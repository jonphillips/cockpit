@testable import CockpitCore
import CustomDump
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@Suite(.serialized, .dependencies {
  $0.date.now = Date(timeIntervalSince1970: 123)
  $0.uuid = .incrementing
  try $0.bootstrapDatabase()
})
@MainActor
struct PersonalKnowledgeHypothesisTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("Only recurring explicit actions raise a transient subject hypothesis")
  func explicitActionRecurrence() async throws {
    let savedID = UUID(7001)
    let libraryID = UUID(7002)
    let passiveID = UUID(7003)
    try await database.write { db in
      try Self.seed(savedID, subjects: ["Burgundy travel"], in: db)
      try Self.seed(libraryID, subjects: ["burgundy travel", "wine"], in: db)
      try Self.seed(passiveID, subjects: ["burgundy travel"], in: db)
      try DestinationOperations.saveForLater(savedID, at: .distantPast, in: db)
      try DestinationOperations.addToLibrary(libraryID, at: .distantPast, in: db)
    }

    let model = PersonalKnowledgeModel()
    await model.loadHypothesis()

    expectNoDifference(
      model.hypothesis,
      .init(subject: "burgundy travel", explicitActionCount: 2)
    )
    let claimCount = try await database.read { db in try PersonalKnowledgeClaim.fetchCount(db) }
    expectNoDifference(claimCount, 0)
  }

  @Test("Confirming a hypothesis writes a scoped Interest with explicit provenance")
  func confirmationWritesTheOnlyDurableResult() async throws {
    let firstID = UUID(7011)
    let secondID = UUID(7012)
    try await database.write { db in
      try Self.seed(firstID, subjects: ["adaptive reuse"], in: db)
      try Self.seed(secondID, subjects: ["adaptive reuse"], in: db)
      try DestinationOperations.saveForLater(firstID, at: .distantPast, in: db)
      try DestinationOperations.addToLibrary(secondID, at: .distantPast, in: db)
    }
    let model = PersonalKnowledgeModel()
    await model.loadHypothesis()
    await model.confirmHypothesisButtonTapped()

    let claim = try await database.read { db in try PersonalKnowledgeClaim.fetchOne(db) }
    let stored = try #require(claim)
    expectNoDifference(stored.kind, .interest)
    expectNoDifference(stored.claim, "Wants Cockpit to notice adaptive reuse.")
    expectNoDifference(stored.scope, "adaptive reuse")
    expectNoDifference(stored.provenance, .confirmedHypothesis)
    #expect(model.hypothesis == nil)

    await model.loadHypothesis()
    #expect(model.hypothesis == nil)
  }

  @Test("Reader teaching is a deliberate recurrence signal, not a passive Reader open")
  func readerTeachingRecurrence() async throws {
    let savedID = UUID(7031)
    let taughtID = UUID(7032)
    try await database.write { db in
      try Self.seed(savedID, subjects: ["wine"], in: db)
      try Self.seed(taughtID, subjects: ["wine"], in: db)
      try DestinationOperations.saveForLater(savedID, at: .distantPast, in: db)
      try PersonalKnowledgeOperations.applyReaderTeaching(
        .init(
          id: UUID(7033), kind: .taste, claim: "Prefers generous dry Riesling.", scope: "Wine",
          action: .newClaim, requiresConfirmation: true, rationale: "Explicit Reader teaching."
        ),
        reason: "I prefer some fruit in dry Riesling.",
        contentPieceID: taughtID,
        teachingID: UUID(7034),
        claimID: UUID(7035),
        at: .distantPast,
        in: db
      )
    }

    let model = PersonalKnowledgeModel()
    await model.loadHypothesis()
    expectNoDifference(model.hypothesis, .init(subject: "wine", explicitActionCount: 2))
  }

  @Test("One piece saved and added to Library counts once, not as recurrence")
  func dualTreatmentOfOnePieceIsNotRecurrence() async throws {
    let onlyID = UUID(7041)
    let secondPieceID = UUID(7042)
    try await database.write { db in
      try Self.seed(onlyID, subjects: ["glassblowing"], in: db)
      try Self.seed(secondPieceID, subjects: ["glassblowing"], in: db)
      // One piece treated two ways: this must not, on its own, raise a hypothesis.
      try DestinationOperations.saveForLater(onlyID, at: .distantPast, in: db)
      try DestinationOperations.addToLibrary(onlyID, at: .distantPast, in: db)
    }
    let model = PersonalKnowledgeModel()
    await model.loadHypothesis()
    #expect(model.hypothesis == nil)

    // A genuinely distinct second piece on the same subject crosses into recurrence, counting
    // the first piece only once despite its two actions.
    try await database.write { db in
      try DestinationOperations.saveForLater(secondPieceID, at: .distantPast, in: db)
    }
    await model.loadHypothesis()
    expectNoDifference(
      model.hypothesis,
      .init(subject: "glassblowing", explicitActionCount: 2)
    )
  }

  @Test("Dismissing a hypothesis leaves no durable trace")
  func dismissalWritesNothing() async throws {
    let firstID = UUID(7021)
    let secondID = UUID(7022)
    try await database.write { db in
      try Self.seed(firstID, subjects: ["kitchen design"], in: db)
      try Self.seed(secondID, subjects: ["kitchen design"], in: db)
      try DestinationOperations.saveForLater(firstID, at: .distantPast, in: db)
      try DestinationOperations.addToLibrary(secondID, at: .distantPast, in: db)
    }
    let model = PersonalKnowledgeModel()
    await model.loadHypothesis()
    model.dismissHypothesisButtonTapped()

    #expect(model.hypothesis == nil)
    let claims = try await database.read { db in try PersonalKnowledgeClaim.fetchAll(db) }
    expectNoDifference(claims, [])
  }

  private nonisolated static func seed(_ id: UUID, subjects: [String], in db: Database) throws {
    let encoded = String(data: try JSONEncoder().encode(subjects), encoding: .utf8)
    try ContentPiece.insert {
      ContentPiece.Draft(
        id: id, kind: .article, title: "Piece", publisher: "Publisher", subjects: encoded,
        createdAt: .distantPast
      )
    }.execute(db)
  }
}
