@testable import CockpitCore
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Synchronization
import Testing

@Suite(.serialized, .dependencies {
  $0.uuid = .incrementing
  $0.date.now = Date(timeIntervalSince1970: 950_000)
  try $0.bootstrapDatabase()
})
@MainActor
struct ReaderFindHandoffTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("Reader declares a deterministic recipe Find and starts a jonDeclared referral")
  func createsJonDeclaredFindAndReferral() async throws {
    let pieceID = try await seedPiece(seed: 95_001)
    let messages = Mutex<[FindReferralMessage]>([])
    let model = ContentPieceReaderModel(contentPieceID: pieceID)
    let client = handoffClient { message in messages.withLock { $0.append(message) } }

    let policyMatches = await withDependencies {
      $0.findReferralHandoffClient = client
    } operation: {
      try? await model.$content.load()
      try? await model.$pendingFindContent.load()
      #expect(model.canSendToYesChefFromReader)
      return await model.sendToYesChefFromReader()
    }

    let expectedFindID = PendingFindOperations.id(
      kind: "recipe", name: "Recipe issue 95001", sourceURL: "https://example.com/95001",
      for: pieceID
    )
    let (find, referrals) = try await database.read { db in
      (
        try PendingFind.find(expectedFindID).fetchOne(db),
        try PendingFindReferral.where { $0.pendingFindID.eq(expectedFindID) }.fetchAll(db)
      )
    }
    #expect(!policyMatches)
    #expect(find?.kind == "recipe")
    #expect(find?.state == .referred)
    #expect(find?.rationale == "Jon sent this from the Reader.")
    #expect(referrals.count == 1)
    #expect(referrals.first?.hintSource == .jonDeclared)
    #expect(referrals.first?.resolvedAt == nil)
    #expect(model.yesChefReaderActionStatus == .sent)
    #expect(messages.withLock { $0.count } == 1)
  }

  @Test("Reader reuses extracted pending and confirmed recipe Finds")
  func reusesExtractedFinds() async throws {
    for (offset, initialState) in [(0, PendingFindState.pending), (10, .confirmed)] {
      let pieceID = try await seedPiece(seed: 95_100 + offset, findState: initialState)
      let findID = UUID(95_101 + offset)
      let messages = Mutex<[FindReferralMessage]>([])
      let model = ContentPieceReaderModel(contentPieceID: pieceID)

      await withDependencies {
        $0.findReferralHandoffClient = handoffClient { message in messages.withLock { $0.append(message) } }
      } operation: {
        try? await model.$content.load()
        try? await model.$pendingFindContent.load()
        _ = await model.sendToYesChefFromReader()
      }

      let (find, referrals) = try await database.read { db in
        (
          try PendingFind.find(findID).fetchOne(db),
          try PendingFindReferral.where { $0.pendingFindID.eq(findID) }.fetchAll(db)
        )
      }
      #expect(find?.state == .referred)
      #expect(referrals.count == 1)
      #expect(referrals.first?.hintSource == .extracted)
      #expect(messages.withLock { $0.count } == 1)
    }
  }

  @Test("A repeated Reader send while referred does not write another message")
  func repeatSendIsIgnored() async throws {
    let pieceID = try await seedPiece(seed: 95_201)
    let messages = Mutex<[FindReferralMessage]>([])
    let model = ContentPieceReaderModel(contentPieceID: pieceID)

    await withDependencies {
      $0.findReferralHandoffClient = handoffClient { message in messages.withLock { $0.append(message) } }
    } operation: {
      try? await model.$content.load()
      try? await model.$pendingFindContent.load()
      _ = await model.sendToYesChefFromReader()
      #expect(model.yesChefReaderActionStatus == .sent)
      let secondSend = await model.sendToYesChefFromReader()
      #expect(!secondSend)
    }

    #expect(messages.withLock { $0.count } == 1)
    #expect(try await database.read { db in try PendingFindReferral.fetchAll(db).filter { $0.pendingFindID == PendingFindOperations.id(
      kind: "recipe", name: "Recipe issue 95201", sourceURL: "https://example.com/95201", for: pieceID
    ) }.count } == 1)
  }

  @Test("A teaser leaves no Find or referral message")
  func teaserDoesNotCreateFindOrMessage() async throws {
    let pieceID = try await seedPiece(seed: 95_301, completeness: .teaser)
    let messages = Mutex<[FindReferralMessage]>([])
    let model = ContentPieceReaderModel(contentPieceID: pieceID)

    await withDependencies {
      $0.findReferralHandoffClient = handoffClient { message in messages.withLock { $0.append(message) } }
    } operation: {
      try? await model.$content.load()
      try? await model.$pendingFindContent.load()
      #expect(model.yesChefReaderActionStatus == .unavailable)
      let sent = await model.sendToYesChefFromReader()
      #expect(!sent)
    }

    #expect(messages.withLock { $0.isEmpty })
    #expect(try await database.read { db in
      try PendingFind.where { $0.contentPieceID.eq(pieceID) }.fetchCount(db) == 0
    })
    let findID = PendingFindOperations.id(
      kind: "recipe", name: "Recipe issue 95301", sourceURL: "https://example.com/95301", for: pieceID
    )
    #expect(try await database.read { db in
      try PendingFindReferral.where { $0.pendingFindID.eq(findID) }.fetchCount(db) == 0
    })
  }

  @Test("A failed Reader open restores confirmed and deletes the mailbox message")
  func failedReaderOpenMatchesFindsRecovery() async throws {
    let pieceID = try await seedPiece(seed: 95_401)
    let messages = Mutex<[FindReferralMessage]>([])
    let deleted = Mutex<[UUID]>([])
    let model = ContentPieceReaderModel(contentPieceID: pieceID)
    let client = FindReferralHandoffClient(
      writeReferral: { message in messages.withLock { $0.append(message) } },
      deleteReferral: { id in deleted.withLock { $0.append(id) }; return true },
      openReferral: { _ in false }
    )

    await withDependencies {
      $0.findReferralHandoffClient = client
    } operation: {
      try? await model.$content.load()
      try? await model.$pendingFindContent.load()
      let sent = await model.sendToYesChefFromReader()
      #expect(!sent)
    }

    let (find, referral) = try await database.read { db in
      let findID = PendingFindOperations.id(
        kind: "recipe", name: "Recipe issue 95401", sourceURL: "https://example.com/95401",
        for: pieceID
      )
      return (
        try PendingFind.find(findID).fetchOne(db),
        try PendingFindReferral.where { $0.pendingFindID.eq(findID) }.fetchOne(db)
      )
    }
    #expect(find?.state == .confirmed)
    #expect(referral?.hintSource == .jonDeclared)
    #expect(referral?.resolvedAt != nil)
    #expect(referral?.rawOutcomeSet == "{\"delivery\":\"openFailed\"}")
    #expect(deleted.withLock { $0 } == [try #require(messages.withLock { $0.first?.referralID })])
    #expect(model.errorMessage == FindReferralHandoffError.yesChefUnavailable.localizedDescription)
  }

  @Test("Finds list keeps readable-body errors for teasers and non-recipe Finds")
  func listSendUsesReadableBodyError() async throws {
    let teaserID = try await seedPiece(seed: 95_451, completeness: .teaser)
    let otherID = try await seedPiece(seed: 95_461)
    let teaserFindID = UUID(95_452)
    let otherFindID = UUID(95_462)
    try await database.write { db in
      for find in [
        PendingFind(
          id: teaserFindID, contentPieceID: teaserID, kind: "recipe", name: "Teaser",
          descriptor: "", rationale: ""
        ),
        PendingFind(
          id: otherFindID, contentPieceID: otherID, kind: "wine", name: "Wine",
          descriptor: "", rationale: ""
        )
      ] {
        try PendingFind.insert { PendingFind.Draft(find) }.execute(db)
      }
    }
    let messages = Mutex<[FindReferralMessage]>([])

    await withDependencies {
      $0.findReferralHandoffClient = handoffClient { message in messages.withLock { $0.append(message) } }
    } operation: {
      let model = PendingFindListModel()
      await model.sendToYesChef(teaserFindID)
      #expect(model.errorMessage == FindReferralHandoffError.readableBodyUnavailable.localizedDescription)
      await model.sendToYesChef(otherFindID)
      #expect(model.errorMessage == FindReferralHandoffError.readableBodyUnavailable.localizedDescription)
    }

    #expect(messages.withLock { $0.isEmpty })
    #expect(try await database.read { db in
      try PendingFindReferral.where { $0.pendingFindID.eq(teaserFindID) }.fetchCount(db) == 0
        && PendingFindReferral.where { $0.pendingFindID.eq(otherFindID) }.fetchCount(db) == 0
    })
  }

  @Test("Reader reports policy matches without applying Gmail disposition")
  func readerLeavesDispositionToItsSurface() async throws {
    let pieceID = try await seedPiece(seed: 95_501, treatment: .offer)
    try await database.write { db in
      try GmailDispositionPolicyOperations.establish(
        .offerWithFind, at: Date(timeIntervalSince1970: 1), in: db
      )
    }
    let messages = Mutex<[FindReferralMessage]>([])
    let dispositionCalls = Mutex<[String]>([])
    let dispositionClient = GmailDispositionClient(
      archive: { id in dispositionCalls.withLock { $0.append("archive:\(id)") } },
      trash: { id in dispositionCalls.withLock { $0.append("trash:\(id)") } },
      reAddInbox: { _ in }, untrash: { _ in }
    )
    let model = ContentPieceReaderModel(contentPieceID: pieceID)

    let shouldDispose = await withDependencies {
      $0.findReferralHandoffClient = handoffClient { message in messages.withLock { $0.append(message) } }
      $0.gmailDispositionClient = dispositionClient
    } operation: {
      try? await model.$content.load()
      try? await model.$pendingFindContent.load()
      return await model.sendToYesChefFromReader()
    }

    #expect(shouldDispose)
    #expect(dispositionCalls.withLock { $0.isEmpty })
    #expect(model.yesChefReaderActionStatus == .sent)
  }

  @Test("A dismissed deterministic Find is re-confirmed before referral")
  func dismissedFindIsRevived() async throws {
    let pieceID = try await seedPiece(seed: 95_601)
    let findID = PendingFindOperations.id(
      kind: "recipe", name: "Recipe issue 95601", sourceURL: "https://example.com/95601", for: pieceID
    )
    try await database.write { db in
      try PendingFind.insert {
        PendingFind.Draft(PendingFind(
          id: findID, contentPieceID: pieceID, kind: "recipe", name: "Recipe issue 95601",
          descriptor: "Old extracted descriptor", rationale: "Old rationale", state: .dismissed
        ))
      }.execute(db)
    }
    let model = ContentPieceReaderModel(contentPieceID: pieceID)

    await withDependencies {
      $0.findReferralHandoffClient = handoffClient { _ in }
    } operation: {
      try? await model.$content.load()
      try? await model.$pendingFindContent.load()
      _ = await model.sendToYesChefFromReader()
    }

    let (find, referral) = try await database.read { db in
      (try PendingFind.find(findID).fetchOne(db), try PendingFindReferral.where { $0.pendingFindID.eq(findID) }.fetchOne(db))
    }
    #expect(find?.state == .referred)
    #expect(find?.rationale == "Jon sent this from the Reader.")
    #expect(referral?.hintSource == .jonDeclared)
  }

  @Test("Reader send state is descriptive and never exposes the referral id")
  func readerStateDoesNotExposeReferralID() async throws {
    let pieceID = try await seedPiece(seed: 95_701)
    let sentID = Mutex<UUID?>(nil)
    let model = ContentPieceReaderModel(contentPieceID: pieceID)
    let client = FindReferralHandoffClient(
      writeReferral: { message in sentID.withLock { $0 = message.referralID } },
      deleteReferral: { _ in true }, openReferral: { _ in true }
    )

    await withDependencies {
      $0.findReferralHandoffClient = client
    } operation: {
      try? await model.$content.load()
      try? await model.$pendingFindContent.load()
      _ = await model.sendToYesChefFromReader()
    }

    let referralID = try #require(sentID.withLock { $0 })
    #expect(model.yesChefReaderActionStatus == .sent)
    #expect(model.yesChefReaderActionTitle == "Sent to Yes Chef")
    #expect(!String(describing: model.yesChefReaderActionStatus).contains(referralID.uuidString))
    #expect(model.errorMessage == nil)
  }

  @Test("Reader send disables itself while the referral is in flight")
  func inFlightSendPreventsSecondTap() async throws {
    let pieceID = try await seedPiece(seed: 95_801)
    let opens = Mutex(0)
    let messages = Mutex<[FindReferralMessage]>([])
    let model = ContentPieceReaderModel(contentPieceID: pieceID)
    let client = FindReferralHandoffClient(
      writeReferral: { message in messages.withLock { $0.append(message) } },
      deleteReferral: { _ in true },
      openReferral: { _ in
        opens.withLock { $0 += 1 }
        try? await Task.sleep(for: .milliseconds(100))
        return true
      }
    )

    await withDependencies {
      $0.findReferralHandoffClient = client
    } operation: {
      try? await model.$content.load()
      try? await model.$pendingFindContent.load()
      let firstSend = Task { await model.sendToYesChefFromReader() }
      while !model.isSendingToYesChef { await Task.yield() }
      #expect(model.yesChefReaderActionStatus == .sending)
      #expect(!model.canSendToYesChefFromReader)
      let secondSend = await model.sendToYesChefFromReader()
      #expect(!secondSend)
      #expect(await firstSend.value == false)
    }

    #expect(opens.withLock { $0 } == 1)
    #expect(messages.withLock { $0.count } == 1)
    #expect(!model.isSendingToYesChef)
    #expect(model.yesChefReaderActionStatus == .sent)
  }

  private func seedPiece(
    seed: Int,
    completeness: BodyCompleteness = .full,
    treatment: EmailTreatment? = nil,
    findState: PendingFindState? = nil
  ) async throws -> ContentPiece.ID {
    let pieceID = UUID(seed)
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          id: pieceID, kind: .email, title: "Recipe issue \(seed)", creator: "Test Kitchen",
          publisher: "Example Newsletter", publishedAt: Date(timeIntervalSince1970: 10),
          canonicalURL: "https://example.com/\(seed)", isSubstantivePrimary: true,
          bodyCompleteness: completeness, emailTreatment: treatment,
          createdAt: Date(timeIntervalSince1970: 10))
      }.execute(db)
      try LocalNormalizedText.insert {
        LocalNormalizedText.Draft(contentPieceID: pieceID, normalizedText: "Whole readable recipe issue")
      }.execute(db)
      if let findState {
        try PendingFind.insert {
          PendingFind.Draft(PendingFind(
            id: UUID(seed + 1), contentPieceID: pieceID, kind: "recipe", name: "Extracted recipe",
            descriptor: "A candidate", rationale: "Extracted from the issue", state: findState
          ))
        }.execute(db)
      }
    }
    return pieceID
  }

  private func handoffClient(
    write: @escaping @Sendable (FindReferralMessage) -> Void
  ) -> FindReferralHandoffClient {
    FindReferralHandoffClient(
      writeReferral: { message in write(message) },
      deleteReferral: { _ in true }, openReferral: { _ in true }
    )
  }
}
