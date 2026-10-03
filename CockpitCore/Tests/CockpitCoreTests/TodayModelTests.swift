@testable import CockpitCore
import CustomDump
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Synchronization
import Testing

@Suite(.serialized, .dependencies {
  try $0.bootstrapDatabase()
  $0.date.now = Date(timeIntervalSince1970: 10_000)
})
@MainActor
struct TodayModelTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("Today keeps arrival order inside the role-oriented surface")
  func hierarchy() async throws {
    let personalEarly = UUID(7_001)
    let personalLate = UUID(7_002)
    let newsletter = UUID(7_003)
    let offer = UUID(7_004)
    let grabBag = UUID(7_005)
    let transactional = UUID(7_006)
    try await seed(personalEarly, treatment: .personal, receivedAt: 1)
    try await seed(personalLate, treatment: .personal, receivedAt: 2)
    try await seed(newsletter, treatment: .newsletter, receivedAt: 3)
    try await seed(offer, treatment: .offer, receivedAt: 4)
    try await seed(grabBag, treatment: .grabBag, receivedAt: 5)
    try await seed(transactional, treatment: .transactional, receivedAt: 6)

    let model = TodayModel()
    try await model.$content.load()
    try await model.$offers.load()

    expectNoDifference(model.sections.map(\.role), [.forYou, .transactional])
    expectNoDifference(
      model.sections[0].rows.map(\.id),
      [grabBag, newsletter, personalLate, personalEarly])
    expectNoDifference(model.offerDoors.map(\.count), [1])
    expectNoDifference(model.sections[1].rows.map(\.id), [transactional])
  }

  @Test("The Feeds door shows only new items and leaves Today's count alone")
  func feedsDoor() {
    let streamID = UUID(7_801)
    let now = Date(timeIntervalSince1970: 20_000)
    let source = ListedFeedsRequest.Source(id: streamID, name: "Travel", publisher: "NYT", newCount: 1)
    let emptySource = ListedFeedsRequest.Source(
      id: UUID(7_804), name: "Books", publisher: "NYT", newCount: 0)
    let secondSource = ListedFeedsRequest.Source(
      id: UUID(7_805), name: "Movies", publisher: "NYT", newCount: 2)
    let opened = ListedFeedsRequest.Item(
      id: UUID(7_802), title: "Opened", creator: nil, canonicalURL: nil,
      listedDate: now.addingTimeInterval(-100), streamID: streamID, streamName: "Travel",
      isOpened: true, description: "")
    let newest = ListedFeedsRequest.Item(
      id: UUID(7_803), title: "Newest headline", creator: nil, canonicalURL: nil,
      listedDate: now, streamID: streamID, streamName: "Travel", isOpened: false,
      description: "")
    let newestOverall = ListedFeedsRequest.Item(
      id: UUID(7_806), title: "Newest overall", creator: nil, canonicalURL: nil,
      listedDate: now.addingTimeInterval(10), streamID: secondSource.id, streamName: "Movies",
      isOpened: false, description: "")
    let anotherMovie = ListedFeedsRequest.Item(
      id: UUID(7_807), title: "Another movie", creator: nil, canonicalURL: nil,
      listedDate: now.addingTimeInterval(-10), streamID: secondSource.id, streamName: "Movies",
      isOpened: false, description: "")
    var feeds = ListedFeedsRequest.Value()
    #expect(TodayModel.FeedsDoor.make(from: feeds) == nil)
    feeds.sources = [source, emptySource, secondSource]
    feeds.items = [opened, newest, newestOverall, anotherMovie]
    feeds.totalNewCount = 3

    let door = TodayModel.FeedsDoor.make(from: feeds)
    #expect(door?.totalCount == 3)
    #expect(door?.sources.map(\.name) == ["Travel", "Movies"])
    #expect(door?.sources.map(\.count) == [1, 2])
    #expect(door?.newestTitle == "Newest overall")
    #expect(door?.newestDate == now.addingTimeInterval(10))

    feeds.items = [opened, ListedFeedsRequest.Item(
      id: newest.id, title: newest.title, creator: nil, canonicalURL: nil,
      listedDate: now, streamID: streamID, streamName: "Travel", isOpened: true,
      description: "")]
    feeds.totalNewCount = 0
    #expect(TodayModel.FeedsDoor.make(from: feeds) == nil)
    #expect(TodayModel().totalCount == 0)
  }

  @Test("Clear resolves only Cockpit attention and leaves Gmail evidence unchanged")
  func clearIsCockpitOnly() async throws {
    let pieceID = UUID(7_101)
    let artifactID = try await seed(pieceID, treatment: .personal, receivedAt: 1)
    let model = TodayModel()
    try await model.$content.load()
    let row = try #require(model.content.rows.first)
    model.selectedContentPieceID = pieceID
    let evidenceBefore = try await database.read { db in
      try Artifact.find(artifactID).fetchOne(db)
    }

    await model.clear(row)

    #expect(model.content.rows.isEmpty)
    #expect(model.selectedContentPieceID == nil)
    #expect(model.errorMessage == nil)
    let state = try await database.read { db in
      (
        try TodayAttention.find(pieceID).fetchOne(db),
        try Artifact.find(artifactID).fetchOne(db),
        try ContentPiece.find(pieceID).fetchOne(db)
      )
    }
    expectNoDifference(state.0?.clearedAt, Date(timeIntervalSince1970: 10_000))
    expectNoDifference(state.1, evidenceBefore)
    #expect(state.2?.kind == .email)
  }

  @Test("Clear rejects non-Gmail material without changing attention state")
  func clearRejectsNonGmailMaterial() async throws {
    let pieceID = UUID(7_201)
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          id: pieceID, kind: .article, title: "Article", publisher: "Publisher", createdAt: .distantPast)
      }.execute(db)
    }

    #expect(throws: TodayAttentionOperations.Failure.self) {
      try database.read { db in
        try TodayAttentionOperations.clear(pieceID, at: .distantPast, in: db)
      }
    }
    let attention = try await database.read { db in try TodayAttention.find(pieceID).fetchOne(db) }
    #expect(attention == nil)
  }

  @Test("Moving a Today sender writes a locator role without changing email treatment")
  func movingSectionPreservesTreatment() async throws {
    let pieceID = UUID(7_401)
    try await seed(
      pieceID, treatment: .newsletter, receivedAt: 9_990,
      publisher: "Ministry of Supply <offers@ministry.example>",
      providerProvenance: "{\"accountID\":\"jon@example.com\",\"messageID\":\"move-test\",\"threadID\":\"thread\",\"senderAddress\":\"offers@ministry.example\",\"toRecipientCount\":1,\"ccRecipientCount\":0}")

    let model = TodayModel()
    try await model.$content.load()
    let row = try #require(model.content.rows.first)
    #expect(row.treatment == .newsletter)

    await model.moveToSection(row.id, to: .wine)

    #expect(model.content.rows.first?.treatment == .newsletter)
    #expect(model.content.rows.first?.role == .wine)
    #expect(model.errorMessage == nil)
    let persisted = try await database.read { db in
      (
        try ContentRoleRoutingRule.find("offers@ministry.example").fetchOne(db),
        try EmailSenderTreatmentOverride.fetchCount(db)
      )
    }
    #expect(persisted.0?.role == .wine)
    #expect(persisted.1 == 0)
  }

  @Test("Moving a sender into Transactional corrects its existing Today mail")
  func moveSenderIntoTransactional() async throws {
    let pieceID = UUID(7_402)
    try await seed(
      pieceID, treatment: .personal, receivedAt: 9_991,
      publisher: "Maya <maya@example.com>",
      providerProvenance: "{\"accountID\":\"jon@example.com\",\"messageID\":\"transactional-move\",\"threadID\":\"thread\",\"senderAddress\":\"maya@example.com\",\"toRecipientCount\":1,\"ccRecipientCount\":0}")

    let calls = TransactionalCorrectionCallLog()
    try await withDependencies { $0.gmailDispositionClient = calls.client } operation: {
      let model = TodayModel()
      try await model.$content.load()
      let row = try #require(model.content.rows.first)
      #expect(row.role == .forYou)
      #expect(row.treatment == .personal)

      await model.correctSenderAsTransactional(row.id)
      let corrected = try #require(model.content.rows.first { $0.id == pieceID })
      #expect(corrected.role == .transactional)
      #expect(corrected.treatment == .transactional)
      #expect(corrected.isTransactionalCorrection)
      #expect(model.errorMessage == nil)

      await model.removeTransactionalCorrection(for: corrected.senderHeader)
      let restored = try #require(model.content.rows.first { $0.id == pieceID })
      #expect(restored.role == .forYou)
      #expect(restored.treatment == .personal)
      #expect(!restored.isTransactionalCorrection)
    }
    #expect(calls.calls.isEmpty)
  }

  @Test("Detector transactionals cannot be routed or corrected by moveToSection")
  func detectorTransactionalMoveGuard() async throws {
    let pieceID = UUID(7_403)
    _ = try await seed(
      pieceID, treatment: .transactional, receivedAt: 9_992,
      publisher: "Confirmations <confirm@shop.example>",
      providerProvenance: "{\"accountID\":\"jon@example.com\",\"messageID\":\"detected-transactional\",\"threadID\":\"thread\",\"senderAddress\":\"confirm@shop.example\",\"toRecipientCount\":1,\"ccRecipientCount\":0}")
    try await database.write { db in
      _ = try EmailTreatmentOperations.classify(emailContentPieceIDs: [pieceID], in: db)
    }

    let model = TodayModel()
    try await model.$content.load()
    await model.moveToSection(pieceID, to: .wine)
    await model.moveToSection(pieceID, to: .transactional)

    #expect(model.content.rows.first?.treatment == .transactional)
    #expect(model.content.rows.first?.role == .transactional)
    let persisted = try await database.read { db in
      (
        try ContentRoleRoutingRule.find("confirm@shop.example").fetchOne(db),
        try EmailSenderTreatmentOverride.find("confirm@shop.example").fetchOne(db)
      )
    }
    #expect(persisted.0 == nil)
    #expect(persisted.1 == nil)
  }

  @discardableResult
  private func seed(
    _ pieceID: ContentPiece.ID,
    treatment: EmailTreatment,
    receivedAt: TimeInterval,
    publisher: String = "Sender",
    summary: String? = nil,
    providerProvenance: String = "{}"
  ) async throws -> Artifact.ID {
    let artifactID = UUID(Int(receivedAt) + 80_000)
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          id: pieceID, kind: .email, title: "\(treatment.rawValue) \(receivedAt)",
          publisher: publisher, publishedAt: Date(timeIntervalSince1970: receivedAt), summary: summary,
          emailTreatment: treatment, createdAt: .distantPast)
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(
          id: artifactID, transport: .gmail,
          providerID: "gmail:message:\(pieceID.uuidString)",
          acquiredAt: Date(timeIntervalSince1970: receivedAt), rawSourceText: "Body",
          providerProvenance: providerProvenance, contentPieceID: pieceID)
      }.execute(db)
    }
    return artifactID
  }
}

private final class TransactionalCorrectionCallLog: Sendable {
  private let entries = Mutex<[String]>([])
  var calls: [String] { entries.withLock { $0 } }

  var client: GmailDispositionClient {
    GmailDispositionClient(
      archive: { self.record("archive:\($0)") },
      trash: { self.record("trash:\($0)") },
      reAddInbox: { self.record("reAddInbox:\($0)") },
      untrash: { self.record("untrash:\($0)") }
    )
  }

  private func record(_ call: String) { entries.withLock { $0.append(call) } }
}
