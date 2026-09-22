@testable import CockpitCore
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@Suite(.serialized, .dependencies {
  try $0.bootstrapDatabase()
  $0.date.now = Date(timeIntervalSince1970: 10_000)
})
@MainActor
struct TodayOrientationTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("Orientation exposes role sections and pointer-only Highlights")
  func roleSections() async throws {
    let dailyNews = UUID(7_301)
    let opinion = UUID(7_302)
    let digest = UUID(7_303)
    let offer = UUID(7_304)
    let loose = UUID(7_305)

    try await seed(
      dailyNews, treatment: .newsletter, receivedAt: 9_995, publisher: "Washington Post",
      listID: "Morning <list.washingtonpost.com/morning>")
    try await seed(
      opinion, treatment: .newsletter, receivedAt: 9_994, publisher: "Matthew Yglesias",
      listID: "Slow Boring <substack.com/slowboring>")
    try await seed(
      digest, treatment: .grabBag, receivedAt: 9_993, publisher: "Feed Me",
      listID: "Feed Me <substack.com/emilysundberg>",
      grabBagItems: [
        GrabBagItem(id: UUID(7_311), title: "A useful bag", summary: "A description."),
        GrabBagItem(id: UUID(7_312), title: "A good restaurant", summary: "Another description."),
      ])
    try await seed(
      offer, treatment: .offer, receivedAt: 9_992, publisher: "Nordstrom",
      listID: "Promos <e.nordstrom.com>")
    try await seed(loose, treatment: .personal, receivedAt: 9_991, publisher: "Mom")

    let model = TodayModel()
    try await model.$content.load()

    #expect(model.sections.map(\.role) == [.forYou, .dailyNews, .opinion, .grabBag, .offers])
    #expect(model.rows(for: .dailyNews).map(\.id) == [dailyNews])
    #expect(model.rows(for: .forYou).map(\.id) == [loose])
    #expect(model.offerGroups.map(\.label) == ["Nordstrom"])
    #expect(model.grabBagGroups.map(\.itemCount) == [2])

    let sectionIDs = Set(model.sections.flatMap(\.rows).map(\.id))
    #expect(Set(model.highlightRows.map(\.id)).isSubset(of: sectionIDs))
  }

  @Test("A muted routed feed never reaches a Today role section")
  func mutedFeedIsAbsent() async throws {
    let muted = UUID(7_401)
    try await seed(
      muted, treatment: .newsletter, receivedAt: 9_900, publisher: "Washington Post",
      listID: "Food <list.washingtonpost.com/food>")

    let model = TodayModel()
    try await model.$content.load()

    #expect(model.content.rows.isEmpty)
    #expect(model.sections.isEmpty)
  }

  private func seed(
    _ pieceID: ContentPiece.ID,
    treatment: EmailTreatment,
    receivedAt: TimeInterval,
    publisher: String,
    listID: String? = nil,
    grabBagItems: [GrabBagItem] = []
  ) async throws {
    let provenanceJSON: String?
    if let listID {
      let provenance = GmailArtifactProvenance(
        accountID: "jon@example.com", messageID: pieceID.uuidString, threadID: "thread",
        rfcMessageID: nil, listUnsubscribe: nil, listID: listID, precedence: "bulk",
        senderAddress: publisher, sendingDomain: nil, dkimDomain: nil,
        toRecipientCount: 1, ccRecipientCount: 0)
      provenanceJSON = String(data: try JSONEncoder().encode(provenance), encoding: .utf8)
    } else {
      provenanceJSON = nil
    }
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(ContentPiece(
          id: pieceID, kind: .email, title: pieceID.uuidString, publisher: publisher,
          publishedAt: Date(timeIntervalSince1970: receivedAt), emailTreatment: treatment,
          createdAt: .distantPast))
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(), transport: .gmail, acquiredAt: Date(timeIntervalSince1970: receivedAt),
          providerProvenance: provenanceJSON, contentPieceID: pieceID))
      }.execute(db)
      if !grabBagItems.isEmpty {
        let itemsJSON = String(data: try JSONEncoder().encode(grabBagItems), encoding: .utf8)
        try EmailTreatmentDetails.insert {
          EmailTreatmentDetails.Draft(
            EmailTreatmentDetails(contentPieceID: pieceID, grabBagItems: itemsJSON))
        }.execute(db)
      }
    }
  }
}
