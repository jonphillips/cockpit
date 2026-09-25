@testable import CockpitCore
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Synchronization
import Testing

@Suite(.serialized, .dependencies {
  $0.uuid = .incrementing
  $0.date.now = Date(timeIntervalSince1970: 300)
  try $0.bootstrapDatabase()
})
@MainActor
struct FindReferralResolutionTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("Verdict outcomes resolve the Find and retain the full outcome set")
  func outcomeClassificationAndCustody() async throws {
    let (pieceID, findID, referralID) = try await seedReferral(seed: 94_301)
    let outcomes: [FindReferralOutcome] = [
      .declined(reason: .duplicate),
      .admitted(recipeRef: "33333333-3333-4333-8333-333333333333"),
      .declined(reason: .extractionFailed, detail: "diagnostic only")
    ]
    let verdict = FindVerdictMessage(referralID: referralID, outcomes: outcomes)

    let resolution = try await database.write { db in
      try FindReferralOperations.resolve(verdict, at: Date(timeIntervalSince1970: 301), in: db)
    }
    let (find, referral, pieceExists) = try await database.read { db in
      (
        try PendingFind.find(findID).fetchOne(db),
        try PendingFindReferral.find(referralID).fetchOne(db),
        try ContentPiece.find(pieceID).fetchOne(db) != nil
      )
    }

    #expect(resolution == .applied(findID: findID, state: .handedOff))
    #expect(find?.state == .handedOff)
    #expect(referral?.resolvedAt == Date(timeIntervalSince1970: 301))
    let record = try JSONDecoder().decode(
      PendingFindReferralOutcomeRecord.self,
      from: Data(try #require(referral?.rawOutcomeSet).utf8)
    )
    #expect(record.outcomes == outcomes)
    #expect(pieceExists)
  }

  @Test("Dismiss and extraction failure return to confirmed, while quality declines are recorded")
  func outcomeClassification() async throws {
    let cases: [([FindReferralOutcome], PendingFindState)] = [
      ([.declined(reason: .noRecipeFound)], .declined),
      ([.declined(reason: .duplicate)], .declined),
      ([.declined(reason: .dismissed)], .confirmed),
      ([.declined(reason: .extractionFailed, detail: "diagnostic")], .confirmed),
      ([], .confirmed)
    ]

    for (index, testCase) in cases.enumerated() {
      let seed = 94_310 + index * 10
      let (_, findID, referralID) = try await seedReferral(seed: seed)
      let resolution = try await database.write { db in
        try FindReferralOperations.resolve(
          FindVerdictMessage(referralID: referralID, outcomes: testCase.0),
          at: Date(timeIntervalSince1970: 310 + Double(index)), in: db
        )
      }
      #expect(resolution == .applied(findID: findID, state: testCase.1))
      #expect(try await database.read { db in try PendingFind.find(findID).fetchOne(db)?.state } == testCase.1)
    }
  }

  @Test("Resolved referrals ignore duplicate verdicts without applying them twice")
  func duplicateVerdictIsIdempotent() async throws {
    let (_, findID, referralID) = try await seedReferral(seed: 94_401)
    let dismissed = FindVerdictMessage(
      referralID: referralID, outcomes: [.declined(reason: .dismissed)]
    )
    let lateAdmission = FindVerdictMessage(
      referralID: referralID, outcomes: [.admitted(recipeRef: "late")]
    )
    let first = try await database.write { db in
      try FindReferralOperations.resolve(dismissed, at: Date(timeIntervalSince1970: 401), in: db)
    }
    let duplicate = try await database.write { db in
      try FindReferralOperations.resolve(lateAdmission, at: Date(timeIntervalSince1970: 402), in: db)
    }
    let state = try await database.read { db in try PendingFind.find(findID).fetchOne(db)?.state }

    #expect(first == .applied(findID: findID, state: .confirmed))
    #expect(duplicate == .alreadyResolved)
    #expect(state == .confirmed)
  }

  @Test("Only unresolved local referral log entries are surfaced as strands")
  func strandDetectionUsesLocalReferralLog() async throws {
    let (_, findID, referralID) = try await seedReferral(seed: 94_501)
    let unrelatedMailboxID = UUID(94_509)
    let client = FindReferralHandoffClient(
      writeReferral: { _ in }, deleteReferral: { _ in true }, openReferral: { _ in true },
      unconsumedReferralIDs: { [referralID, unrelatedMailboxID] }
    )

    await withDependencies {
      $0.findReferralHandoffClient = client
    } operation: {
      let model = PendingFindListModel()
      await model.refreshHandoffState()
    #expect(model.strandedReferrals == [findID: .unconsumed(referralID)])
    }
  }

  @Test("Verdict drain deletes applied, already-resolved, and unknown referrals")
  func verdictDrainDeletesEveryConsumedVerdict() async throws {
    let (_, _, appliedID) = try await seedReferral(seed: 94_551)
    let (_, _, resolvedID) = try await seedReferral(seed: 94_561)
    let applied = FindVerdictMessage(referralID: appliedID, outcomes: [.declined(reason: .dismissed)])
    let duplicateAdmission = FindVerdictMessage(
      referralID: resolvedID, outcomes: [.admitted(recipeRef: "late-admission")]
    )
    _ = try await database.write { db in
      try FindReferralOperations.resolve(
        FindVerdictMessage(referralID: resolvedID, outcomes: []),
        at: Date(timeIntervalSince1970: 299), in: db
      )
    }
    let unknown = FindVerdictMessage(referralID: UUID(94_579), outcomes: [])
    let deleted = Mutex<[UUID]>([])
    let client = FindReferralHandoffClient(
      writeReferral: { _ in }, deleteReferral: { _ in true }, openReferral: { _ in true },
      listVerdicts: { .init(verdicts: [applied, duplicateAdmission, unknown]) },
      deleteVerdict: { id in deleted.withLock { $0.append(id) }; return true }
    )

    await withDependencies {
      $0.findReferralHandoffClient = client
    } operation: {
      await PendingFindListModel().refreshHandoffState()
    }

    #expect(deleted.withLock { $0 } == [appliedID, resolvedID, unknown.referralID])
  }

  @Test("Unreadable mailbox replies strand the local Find with a recoverable action")
  func unreadableReplyIsSurfaced() async throws {
    let (_, findID, referralID) = try await seedReferral(seed: 94_581)
    let client = FindReferralHandoffClient(
      writeReferral: { _ in }, deleteReferral: { _ in true }, openReferral: { _ in true },
      listVerdicts: { .init(unreadableReferralIDs: [referralID]) }
    )

    await withDependencies {
      $0.findReferralHandoffClient = client
    } operation: {
      let model = PendingFindListModel()
      await model.refreshHandoffState()
      #expect(model.strandedReferrals[findID] == .unreadableReply(referralID))
    }
  }

  @Test("Returning a referral is refused once Yes Chef has consumed its file")
  func consumedReferralCannotBeReturnedAndResent() async throws {
    let (_, findID, referralID) = try await seedReferral(seed: 94_591)
    let client = FindReferralHandoffClient(
      writeReferral: { _ in }, deleteReferral: { _ in false }, openReferral: { _ in true },
      unconsumedReferralIDs: { [referralID] }
    )

    await withDependencies {
      $0.findReferralHandoffClient = client
    } operation: {
      let model = PendingFindListModel()
      await model.refreshHandoffState()
      await model.returnStrandedReferralToConfirmed(for: findID)
      #expect(model.errorTitle == "Waiting for Yes Chef")
      #expect(model.strandedReferrals[findID] == .unconsumed(referralID))
    }

    let (find, referral) = try await database.read { db in
      (try PendingFind.find(findID).fetchOne(db), try PendingFindReferral.find(referralID).fetchOne(db))
    }
    #expect(find?.state == .referred)
    #expect(referral?.resolvedAt == nil)
  }

  @Test("Returning a stranded referral restores confirmation and closes the local log")
  func returnStrandedReferralToConfirmed() async throws {
    let (pieceID, findID, referralID) = try await seedReferral(seed: 94_601)
    let deleted = Mutex<[UUID]>([])
    let client = FindReferralHandoffClient(
      writeReferral: { _ in },
      deleteReferral: { id in deleted.withLock { $0.append(id) }; return true },
      openReferral: { _ in true },
      unconsumedReferralIDs: { [referralID] }
    )

    await withDependencies {
      $0.findReferralHandoffClient = client
    } operation: {
      let model = PendingFindListModel()
      await model.refreshHandoffState()
      await model.returnStrandedReferralToConfirmed(for: findID)
      #expect(model.strandedReferrals[findID] == nil)
    }

    let (find, referral, pieceExists) = try await database.read { db in
      (
        try PendingFind.find(findID).fetchOne(db),
        try PendingFindReferral.find(referralID).fetchOne(db),
        try ContentPiece.find(pieceID).fetchOne(db) != nil
      )
    }
    #expect(find?.state == .confirmed)
    #expect(referral?.resolvedAt != nil)
    let record = try JSONDecoder().decode(
      PendingFindReferralOutcomeRecord.self,
      from: Data(try #require(referral?.rawOutcomeSet).utf8)
    )
    #expect(record.delivery == .returnedToConfirmed)
    #expect(deleted.withLock { $0 } == [referralID])
    #expect(pieceExists)
  }

  private func seedReferral(seed: Int) async throws -> (ContentPiece.ID, PendingFind.ID, UUID) {
    let pieceID = UUID(seed)
    let findID = UUID(seed + 1)
    let referralID = UUID(seed + 2)
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          id: pieceID, kind: .email, title: "Recipe issue", publisher: "Test Kitchen",
          createdAt: Date(timeIntervalSince1970: 100))
      }.execute(db)
      try PendingFind.insert {
        PendingFind.Draft(PendingFind(
          id: findID, contentPieceID: pieceID, kind: "recipe", name: "Pasta",
          descriptor: "Recipe candidate", rationale: "Worth a closer look", state: .referred))
      }.execute(db)
      try PendingFindReferral.insert {
        PendingFindReferral.Draft(PendingFindReferral(
          id: referralID, pendingFindID: findID, sentAt: Date(timeIntervalSince1970: 100)))
      }.execute(db)
    }
    return (pieceID, findID, referralID)
  }
}
