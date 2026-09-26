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
struct TechRoleTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("Tech sorts after Daily news and routing persists into Today")
  func techRoleOrderingAndRouting() async throws {
    let roles = ContentRole.allCases.sorted { $0.sortOrder < $1.sortOrder }
    let dailyNewsIndex = try #require(roles.firstIndex(of: .dailyNews))
    #expect(roles[dailyNewsIndex + 1] == .tech)
    #expect(Set(ContentRole.allCases.map(\.sortOrder)).count == ContentRole.allCases.count)
    #expect(ContentRole.tech.rawValue == "tech")

    let rules = [
      ContentRoleRoutingRule(locator: "news.example.com", role: .dailyNews),
      ContentRoleRoutingRule(locator: "tech.example.com", role: .tech),
      ContentRoleRoutingRule(locator: "opinion.example.com", role: .opinion),
    ]
    for (index, rule) in rules.enumerated() {
      try await seed(UUID(7_500 + index), rule: rule)
    }

    let persistedTech = try await database.read { db in
      let savedRule = try ContentRoleRoutingRule.find("tech.example.com").fetchOne(db)
      let snapshot = try CurationRouting.snapshot(in: db)
      return (savedRule, snapshot.role(for: UUID(7_501)))
    }
    #expect(persistedTech.0?.role == .tech)
    #expect(persistedTech.1 == .tech)

    let model = TodayModel()
    try await model.$content.load()
    #expect(model.sections.map(\.role) == [.dailyNews, .tech, .opinion])
    #expect(model.rows(for: .tech).map(\.id) == [UUID(7_501)])
  }

  private func seed(_ pieceID: UUID, rule: ContentRoleRoutingRule) async throws {
    let provenance = GmailArtifactProvenance(
      accountID: "jon@example.com", messageID: pieceID.uuidString, threadID: "thread",
      rfcMessageID: nil, listUnsubscribe: nil, listID: "\(rule.role.displayName) <\(rule.locator)>",
      precedence: "bulk", senderAddress: "publisher@example.com", sendingDomain: "example.com",
      dkimDomain: nil, toRecipientCount: 1, ccRecipientCount: 0)
    let provenanceJSON = String(data: try JSONEncoder().encode(provenance), encoding: .utf8)
    try await database.write { db in
      try StreamOperations.saveRoutingRule(rule, in: db)
      try ContentPiece.insert {
        ContentPiece.Draft(ContentPiece(
          id: pieceID, kind: .email, title: rule.role.displayName,
          publisher: "Tech publisher", emailTreatment: .newsletter, createdAt: .distantPast))
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(Artifact(
          id: UUID(), transport: .gmail, acquiredAt: Date(timeIntervalSince1970: 9_999),
          providerProvenance: provenanceJSON, contentPieceID: pieceID))
      }.execute(db)
    }
  }
}
