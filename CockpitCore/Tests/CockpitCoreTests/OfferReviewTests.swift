@testable import CockpitCore
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Synchronization
import Testing

@Suite(.serialized, .dependencies {
  $0.uuid = .incrementing
  $0.date.now = Date(timeIntervalSince1970: 10_000)
  try $0.bootstrapDatabase()
})
@MainActor
struct OfferReviewTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("Offer predicate matches extraction treatment across roles and treatments")
  func sharedOfferPredicate() {
    for role in ContentRole.allCases + [nil] {
      for treatment in EmailTreatment.allCases {
        let expected: EmailTreatment? = switch role {
        case .grabBag: nil
        case .offers: .offer
        default: treatment == .offer ? .offer : nil
        }
        #expect(OfferPieces.isOffer(role: role, treatment: treatment) == (expected != nil))
      }
    }
  }

  @Test("Offer projection follows Today membership and returns newest first with card details")
  func projectionAndMembership() async throws {
    let older = UUID(30_001)
    let newer = UUID(30_002)
    let cleared = UUID(30_003)
    let muted = UUID(30_004)
    let disposed = UUID(30_005)
    let wineNewsletter = UUID(30_006)
    try await seed(
      older, messageID: "older", role: .offers, treatment: .offer, receivedAt: 10,
      heroHTML: #"<img src="https://img.example/older.jpg" width="640">"#)
    try await seed(
      newer, messageID: "newer", role: .offers, treatment: .offer, receivedAt: 20,
      unread: true, findID: UUID(30_007), heroHTML: #"<img src="https://img.example/newer.jpg" width="640">"#)
    try await seed(
      cleared, messageID: "cleared", role: .offers, treatment: .offer, receivedAt: 30,
      heroHTML: #"<img src="https://img.example/older.jpg" width="640">"#)
    try await seed(muted, messageID: "muted", role: .offers, treatment: .offer, receivedAt: 40)
    try await seed(disposed, messageID: "disposed", role: .offers, treatment: .offer, receivedAt: 50)
    try await seed(wineNewsletter, messageID: "wine-news", role: .wine, treatment: .newsletter, receivedAt: 60)
    try await database.write { db in
      try TodayAttention.insert {
        TodayAttention.Draft(contentPieceID: cleared, clearedAt: .distantPast)
      }.execute(db)
      try StreamOperations.saveRoutingRule(
        ContentRoleRoutingRule(locator: "mail-muted@example.com", role: .offers, isMuted: true), in: db)
      try PendingFind.insert {
        PendingFind.Draft(PendingFind(
          id: UUID(30_008), contentPieceID: newer, kind: "wine", name: "Confirmed find",
          descriptor: "Confirmed.", rationale: "Confirmed.", state: .confirmed))
      }.execute(db)
      try PendingFind.insert {
        PendingFind.Draft(PendingFind(
          id: UUID(30_009), contentPieceID: older, kind: "wine", name: "Dismissed find",
          descriptor: "Dismissed.", rationale: "Dismissed.", state: .dismissed))
      }.execute(db)
      _ = try GmailDispositionOperations.recordApplied(
        id: UUID(30_050), providerID: "gmail:jon@example.com:message:disposed", operation: .trash,
        at: .distantPast, in: db)
    }

    let rows = try await database.read { db in try OfferReviewRequest(role: .offers).fetch(db).rows }
    #expect(rows.map(\.id) == [newer, older])
    #expect(rows.first?.sender == "Sender")
    #expect(rows.first?.isUnread == true)
    #expect(rows.first?.pendingFind?.name == "Confirmed find")
    #expect(rows.last?.pendingFind == nil)
    #expect(rows.first?.summary == "An offer summary.")
    let doorRows = try await database.read { db in
      try OfferReviewRequest(role: .offers, heroLimit: 1).fetch(db).rows
    }
    #expect(doorRows.count == 2)
    #expect(doorRows.first?.heroURL == URL(string: "https://img.example/newer.jpg"))
    #expect(doorRows.last?.heroURL == nil)
    let reviewRows = try await database.read { db in
      try OfferReviewRequest(role: .offers, heroLimit: nil).fetch(db).rows
    }
    #expect(reviewRows.allSatisfy { $0.heroURL != nil })
    let queueRows = try await database.read { db in try TodayReadingQueueRequest().fetch(db).rows }
    #expect(queueRows.map(\.id).contains(wineNewsletter))
    #expect(!queueRows.contains { $0.id == newer || $0.id == older })
  }

  @Test("Keep and unkeep only move pending and confirmed Finds, without applying disposition policy")
  func keepAndUnkeep() async throws {
    let pieceID = UUID(30_101)
    let findID = UUID(30_102)
    try await seed(pieceID, messageID: "keep", role: .offers, treatment: .offer, receivedAt: 1, findID: findID)
    let calls = OfferCallLog()
    try await database.write { db in
      try GmailDispositionPolicyOperations.establish(.offerWithFind, at: .distantPast, in: db)
    }
    await withDependencies { $0.gmailDispositionClient = calls.client } operation: {
      let model = OfferReviewModel(role: .offers)
      await model.reload()
      await model.keep(findID)
      #expect(model.rows.first?.pendingFind?.state == .confirmed)
      await model.unkeep(findID)
      #expect(model.rows.first?.pendingFind?.state == .pending)
    }
    #expect(calls.calls.isEmpty)
    try await database.write { db in
      try PendingFind.find(findID).update { $0.state = #bind(PendingFindState.referred) }.execute(db)
    }
    #expect(throws: PendingFindOperations.Failure.cannotUnconfirm) {
      try database.write { db in try PendingFindOperations.unconfirm(findID, in: db) }
    }
    try await database.write { db in
      try PendingFind.find(findID).update { $0.state = #bind(PendingFindState.handedOff) }.execute(db)
    }
    #expect(throws: PendingFindOperations.Failure.cannotUnconfirm) {
      try database.write { db in try PendingFindOperations.unconfirm(findID, in: db) }
    }
  }

  @Test("Trash all preserves kept Finds and Undo restores every email")
  func trashAndUndo() async throws {
    let first = UUID(30_201), second = UUID(30_202)
    let keptFind = UUID(30_203), pendingFind = UUID(30_204)
    try await seed(first, messageID: "batch-a", role: .offers, treatment: .offer, receivedAt: 2, findID: keptFind)
    try await seed(
      second, messageID: "batch-b", role: .offers, treatment: .offer, receivedAt: 1,
      findID: pendingFind)
    let calls = OfferCallLog()
    try await withDependencies { $0.gmailDispositionClient = calls.client } operation: {
      let model = OfferReviewModel(role: .offers)
      await model.reload()
      await model.keep(keptFind)
      await model.trashAll()
      #expect(model.rows.isEmpty)
      #expect(model.lastBatch.count == 2)
      #expect(model.isClear)
      let today = TodayModel()
      try await today.$offers.load()
      #expect(today.offerDoors.isEmpty)
      await model.undoLastBatch()
      #expect(model.rows.count == 2)
      #expect(model.rows.first(where: { $0.pendingFind?.id == keptFind })?.pendingFind?.state == .confirmed)
      #expect(model.rows.first(where: { $0.pendingFind?.id == pendingFind })?.pendingFind?.state == .pending)
    }
    #expect(calls.calls.filter { $0.hasPrefix("trash:") }.count == 2)
    #expect(calls.calls.filter { $0.hasPrefix("untrash:") }.count == 2)
  }

  @Test("Today Undo restores the offer review batch and brings its door back")
  func todayUndoRestoresOfferBatch() async throws {
    let first = UUID(30_251), second = UUID(30_252)
    try await seed(first, messageID: "today-batch-a", role: .offers, treatment: .offer, receivedAt: 2)
    try await seed(second, messageID: "today-batch-b", role: .offers, treatment: .offer, receivedAt: 1)
    let calls = OfferCallLog()
    try await withDependencies { $0.gmailDispositionClient = calls.client } operation: {
      let review = OfferReviewModel(role: .offers)
      await review.reload()
      await review.trashAll()
      #expect(review.lastBatch.count == 2)

      let today = TodayModel()
      today.rememberOfferBatch(review.lastBatch)
      try await today.$offers.load()
      #expect(today.offerDoors.isEmpty)
      await today.undoLastOfferBatch()

      #expect(today.lastOfferBatch.isEmpty)
      #expect(today.offerUndoMessage == nil)
      #expect(today.offerDoors.map(\.count) == [2])
      #expect(Set(today.offers.rows.map(\.id)) == Set([first, second]))
    }
    #expect(calls.calls.filter { $0.hasPrefix("trash:") }.count == 2)
    #expect(calls.calls.filter { $0.hasPrefix("untrash:") }.count == 2)
  }

  @Test("A partial Trash leaves failed offers visible and reports the batch result")
  func partialTrash() async throws {
    let first = UUID(30_301), failed = UUID(30_302), last = UUID(30_303)
    try await seed(first, messageID: "partial-a", role: .offers, treatment: .offer, receivedAt: 3)
    try await seed(failed, messageID: "partial-fail", role: .offers, treatment: .offer, receivedAt: 2)
    try await seed(last, messageID: "partial-c", role: .offers, treatment: .offer, receivedAt: 1)
    let calls = OfferCallLog()
    await withDependencies {
      $0.gmailDispositionClient = calls.client(failingTrashMessageID: "partial-fail")
    } operation: {
      let model = OfferReviewModel(role: .offers)
      await model.reload()
      await model.trashAll()
      #expect(model.rows.map(\.id) == [failed])
      #expect(model.lastBatch.count == 2)
      #expect(model.statusMessage == "Trashed 2 of 3. 1 couldn't be trashed.")
    }
    #expect(calls.calls.filter { $0.hasPrefix("trash:") }.count == 3)
  }

  @discardableResult
  private func seed(
    _ id: ContentPiece.ID,
    messageID: String,
    role: ContentRole,
    treatment: EmailTreatment,
    receivedAt: TimeInterval,
    unread: Bool = false,
    findID: PendingFind.ID? = nil,
    heroHTML: String? = nil
  ) async throws -> ContentPiece.ID {
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          id: id, kind: .email, title: "Subject \(messageID)", creator: "Sender <mail-\(messageID)@example.com>",
          publisher: "Sender", publishedAt: Date(timeIntervalSince1970: receivedAt),
          emailTreatment: treatment, createdAt: .distantPast)
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(), transport: .gmail,
          providerID: "gmail:jon@example.com:message:\(messageID)",
          acquiredAt: Date(timeIntervalSince1970: receivedAt), rawSourceText: heroHTML,
          providerProvenance: "{\"accountID\":\"jon@example.com\",\"messageID\":\"\(messageID)\",\"threadID\":\"thread-\(messageID)\",\"senderAddress\":\"mail-\(messageID)@example.com\",\"toRecipientCount\":1,\"ccRecipientCount\":0}",
          providerIsUnread: unread, contentPieceID: id))
      }.execute(db)
      try StreamOperations.saveRoutingRule(
        ContentRoleRoutingRule(locator: "mail-\(messageID)@example.com", role: role), in: db)
      if treatment == .offer {
        try EmailTreatmentDetails.insert {
          EmailTreatmentDetails.Draft(EmailTreatmentDetails(contentPieceID: id, offerSummary: "An offer summary."))
        }.execute(db)
        if let findID {
          try PendingFind.insert {
            PendingFind.Draft(PendingFind(
              id: findID, contentPieceID: id, kind: "wine", name: "Find \(messageID)",
              descriptor: "A descriptive detail.", rationale: "From the email."))
          }.execute(db)
        }
      }
    }
    return id
  }
}

private final class OfferCallLog: Sendable {
  private let entries = Mutex<[String]>([])
  var calls: [String] { entries.withLock { $0 } }

  var client: GmailDispositionClient { client(failingTrashMessageID: nil) }

  func client(failingTrashMessageID: String?) -> GmailDispositionClient {
    GmailDispositionClient(
      archive: { self.record("archive:\($0)") },
      trash: { id in
        self.record("trash:\(id)")
        if id == failingTrashMessageID { throw URLError(.timedOut) }
      },
      reAddInbox: { self.record("reAddInbox:\($0)") },
      untrash: { self.record("untrash:\($0)") })
  }

  private func record(_ value: String) { entries.withLock { $0.append(value) } }
}
