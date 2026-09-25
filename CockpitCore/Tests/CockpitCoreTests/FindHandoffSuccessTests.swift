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
struct FindHandoffSuccessTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("Successful referral writes before opening and prevents a second send")
  func successfulReferralCanOnlyBeSentOnce() async throws {
    let (pieceID, findID) = try await seedCandidate()
    let events = Mutex<[String]>([])
    let messages = Mutex<[FindReferralMessage]>([])
    let client = FindReferralHandoffClient(
      writeReferral: { message in
        events.withLock { $0.append("write") }
        messages.withLock { $0.append(message) }
      },
      deleteReferral: { _ in true },
      openReferral: { _ in
        events.withLock { $0.append("open") }
        return true
      }
    )

    await withDependencies {
      $0.findReferralHandoffClient = client
    } operation: {
      let model = PendingFindListModel()
      await model.sendToYesChef(findID)
      #expect(model.errorMessage == nil)
      await model.sendToYesChef(findID)
      #expect(model.errorMessage == PendingFindOperations.Failure.cannotRefer.localizedDescription)
    }

    let persisted = try await database.read { db in
      (
        try PendingFind.find(findID).fetchOne(db)?.state,
        try PendingFindReferral.fetchAll(db).first { $0.pendingFindID == findID }
      )
    }
    #expect(persisted.0 == .referred)
    #expect(persisted.1 != nil)
    #expect(persisted.1?.id == messages.withLock { $0.first?.referralID })
    #expect(persisted.1?.sentAt == Date(timeIntervalSince1970: 200))
    #expect(persisted.1?.hintSource == .extracted)
    #expect(persisted.1?.resolvedAt == nil)
    #expect(persisted.1?.rawOutcomeSet == nil)
    #expect(events.withLock { $0 } == ["write", "open"])
    #expect(messages.withLock { $0.count } == 1)
    #expect(messages.withLock { $0.first?.rawText } == "Whole recipe issue, readable text")
    #expect(try await database.read { db in try ContentPiece.find(pieceID).fetchOne(db) != nil })
  }

  private func seedCandidate() async throws -> (ContentPiece.ID, PendingFind.ID) {
    let pieceID = UUID(94_201)
    let findID = UUID(94_202)
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
          id: UUID(94_203), transport: .gmail, acquiredAt: Date(timeIntervalSince1970: 101),
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
}
