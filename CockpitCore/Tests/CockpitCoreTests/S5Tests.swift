@testable import CockpitCore
import Dependencies
import DependenciesTestSupport
import Foundation
import JudgmentFixtureSupport
import LLMClientKit
import SQLiteData
import Synchronization
import Testing

@Suite(.serialized, .dependencies {
  $0.uuid = .incrementing
  try $0.bootstrapDatabase()
})
@MainActor
struct S5Tests {
  @Dependency(\.defaultDatabase) private var database

  private let base = Date(timeIntervalSince1970: 1_700_000_000)

  @Test("S5 migration round-trips the completeness column and PendingFind table")
  func s5SchemaIsInstalled() async throws {
    let columns = try await database.read { db in
      (
        try #sql("SELECT name FROM pragma_table_info('contentPieces')", as: String.self).fetchAll(db),
        try #sql("SELECT name FROM pragma_table_info('pendingFinds')", as: String.self).fetchAll(db)
      )
    }
    #expect(columns.0.contains("bodyCompleteness"))
    #expect(columns.1 == ["id", "contentPieceID", "kind", "name", "descriptor", "rationale", "sourceURL", "hints", "state"])
  }

  @Test("Completeness detection uses source markers and does not confuse subscription promotion with a cutoff")
  func detectsCompletenessDeterministically() {
    let body = String(repeating: "A substantive sentence about the original article. ", count: 12)
    #expect(
      BodyCompletenessDetector.detect(
        bodyHTML: "<p>\(body)</p><p>Continue reading</p>", descriptionHTML: nil) == .truncated)
    #expect(
      BodyCompletenessDetector.detect(
        bodyHTML: "<p>Introduction only.</p><p>This post is for paid subscribers.</p>",
        descriptionHTML: nil) == .teaser)
    #expect(
      BodyCompletenessDetector.detect(
        bodyHTML: "<p>\(body)</p><p>This post is for paid subscribers.</p>",
        descriptionHTML: nil) == .truncated)
    #expect(
      BodyCompletenessDetector.detect(
        bodyHTML: "<p>Subscribe now</p><p>\(body)</p>", descriptionHTML: nil) == .full)
    #expect(BodyCompletenessDetector.detect(bodyHTML: nil, descriptionHTML: "<p>Summary</p>") == .teaser)
  }

  @Test("Feed ingest stores completeness before any judgment pass")
  func ingestStoresCompleteness() async throws {
    let streamID = UUID(5301)
    try await seedStream(id: streamID)
    let body = String(repeating: "A substantive sentence from the source. ", count: 12)
    let feed = Data("""
      <rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/"><channel>
      <title>Publisher</title><item><title>Incomplete article</title>
      <guid>incomplete-article</guid>
      <content:encoded><![CDATA[<p>\(body)</p><p>Continue reading</p>]]></content:encoded>
      </item></channel></rss>
      """.utf8)
    let stream = try #require(
      try await database.read { db in try Stream.find(streamID).fetchOne(db) })
    let ingestor = FeedIngestor(client: FeedClient(load: { _ in feed }), now: { self.base })

    let pieces = try await ingestor.ingest(stream: stream, into: database)

    let pieceID = try #require(pieces.first?.id)
    let piece = try #require(
      try await database.read { db in try ContentPiece.find(pieceID).fetchOne(db) })
    #expect(piece.bodyCompleteness == .truncated)
  }

  @Test("The harvested corpus contains deterministic teaser markers and full Substack bodies")
  func checksHarvestedSamples() throws {
    let url = try #require(
      Bundle.module.url(forResource: "fixtures", withExtension: "json", subdirectory: "Fixtures/judgment"))
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let export = try decoder.decode(
      JudgmentFixtureExport.self, from: try Data(contentsOf: url))
    let dispatchTeasers = export.fixtures.filter {
      $0.publisher == "The Dispatch" && ($0.normalizedText.range(of: "continue reading", options: .caseInsensitive) != nil)
    }
    #expect(dispatchTeasers.count == 12)
    #expect(dispatchTeasers.allSatisfy { BodyCompletenessDetector.detect(normalizedText: $0.normalizedText) == .truncated })

    let fullSubstack = try #require(
      export.fixtures.first { $0.title == "You can’t blame housing shortages for literally everything" })
    #expect(BodyCompletenessDetector.detect(normalizedText: fullSubstack.normalizedText) == .full)
  }

  @Test("Judgment completeness is only a fallback when ingest left it unresolved")
  func judgmentCompletenessFallbackPreservesDeterministicValue() async throws {
    let streamID = UUID(5101)
    let unresolvedID = UUID(5102)
    let deterministicID = UUID(5103)
    try await seedStream(id: streamID)
    try await seedPiece(id: unresolvedID, streamID: streamID, completeness: nil)
    try await seedPiece(id: deterministicID, streamID: streamID, completeness: .full)

    let stub = StubModelClient { request in
      let ids = [unresolvedID, deterministicID].filter { request.messages.last?.text.contains($0.uuidString) == true }
      let objects = ids.map {
        "{\"contentPieceID\":\"\($0.uuidString)\",\"admit\":true,\"isSubstantivePrimary\":true,\"section\":\"forYou\",\"rank\":1,\"rationale\":\"why\",\"subjects\":[\"one\",\"two\",\"three\"],\"summary\":\"summary\",\"bodyCompleteness\":\"teaser\",\"finds\":[]}"
      }.joined(separator: ",")
      return ModelResponse(text: "{\"judgments\":[\(objects)]}")
    }
    let composer = EditionComposer(engine: JudgmentEngine(modelClient: stub))
    _ = try await composer.composeIfNeeded(now: base, in: database)

    let pieces = try await database.read { db in
      try [unresolvedID, deterministicID].map { try ContentPiece.find($0).fetchOne(db) }
    }
    #expect(try #require(pieces[0]).bodyCompleteness == .teaser)
    #expect(try #require(pieces[1]).bodyCompleteness == .full)
  }

  @Test("Finds persist from the single judgment outcome and list through the observable model")
  func persistsAndListsPendingFinds() async throws {
    let streamID = UUID(5201)
    let pieceID = UUID(5202)
    try await seedStream(id: streamID)
    try await seedPiece(id: pieceID, streamID: streamID, completeness: .full)
    let callCount = Mutex(0)
    let stub = StubModelClient { _ in
      callCount.withLock { $0 += 1 }
      return ModelResponse(
        text: "{\"judgments\":[{\"contentPieceID\":\"\(pieceID.uuidString)\",\"admit\":true,\"isSubstantivePrimary\":true,\"section\":\"forYou\",\"rank\":1,\"rationale\":\"Relevant to your interests.\",\"subjects\":[\"travel\",\"food\",\"cities\"],\"summary\":\"summary\",\"finds\":[{\"kind\":\"restaurant\",\"name\":\"Chez Example\",\"descriptor\":\"A small neighborhood restaurant.\",\"rationale\":\"Worth investigating for the trip.\",\"sourceURL\":\"https://example.com/chez-example\",\"hints\":{\"city\":\"Paris\"}}]}]}")
    }
    let composer = EditionComposer(engine: JudgmentEngine(modelClient: stub))
    _ = try await composer.composeIfNeeded(now: base, in: database)

    #expect(callCount.withLock { $0 } == 1)
    let find = try await database.read { db in try PendingFind.fetchOne(db) }
    let persisted = try #require(find)
    #expect(persisted.contentPieceID == pieceID)
    #expect(persisted.kind == "restaurant")
    #expect(persisted.name == "Chez Example")
    #expect(persisted.hints == "{\"city\":\"Paris\"}")

    let model = PendingFindListModel()
    try await model.$content.load()
    let row = try #require(model.rows.first)
    #expect(row.name == "Chez Example")
    #expect(row.descriptor == "A small neighborhood restaurant.")
  }

  private func seedStream(id: UUID) async throws {
    let areaID = UUID(5199)
    try await database.write { db in
      if try InterestArea.find(areaID).fetchOne(db) == nil {
        try InterestArea.insert {
          InterestArea(id: areaID, name: "General")
        }.execute(db)
      }
      try Stream.insert {
        Stream.Draft(
          Stream(
            id: id, name: "Stream", publisher: "Publisher", interestAreaID: areaID,
            transport: .rss, locator: "https://example.com/feed"))
      }.execute(db)
    }
  }

  private func seedPiece(
    id: UUID, streamID: UUID, completeness: BodyCompleteness?
  ) async throws {
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          ContentPiece(
            id: id, kind: .article, title: "Piece", publisher: "Publisher",
            bodyCompleteness: completeness, createdAt: self.base))
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(
          Artifact(
            id: UUID(id.hashValue), streamID: streamID, transport: .rss, acquiredAt: self.base,
            contentPieceID: id))
      }.execute(db)
      try NormalizedTextOperations.store("A concrete article body.", for: id, in: db)
    }
  }
}
