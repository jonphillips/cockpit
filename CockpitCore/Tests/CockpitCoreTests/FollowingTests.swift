@testable import CockpitCore
import CustomDump
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@Suite(
  .serialized,
  .dependencies {
    $0.uuid = .incrementing
    try $0.bootstrapDatabase()
  }
)
@MainActor
struct FollowingTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("All five recorded S3 feed fixtures exist and parse")
  func recordedFeedsParse() throws {
    for name in StreamFixture.allNames {
      let feed = try FeedParser.parse(StreamFixture.data(named: name))
      #expect(!feed.title.isEmpty, "\(name) has a title")
      #expect(!feed.entries.isEmpty, "\(name) has entries")
    }

    // Techmeme's entity-rich syndicated body is deliberately unlike S1's synthetic feeds.
    let techmeme = try FeedParser.parse(StreamFixture.data(named: "techmeme"))
    #expect(techmeme.entries.contains { $0.normalizedText?.contains("&") == true })
  }

  @Test("Real-feed re-polling preserves identity, provenance, and entries that turn over")
  func realFeedRepollAndTurnover() async throws {
    let stream = Stream(
      id: UUID(-1), name: "Slow Boring", publisher: "Matthew Yglesias", transport: .rss,
      locator: "https://www.slowboring.com/feed"
    )
    try await database.write { db in
      try Stream.insert { Stream.Draft(stream) }.execute(db)
    }
    let original = StreamFixture.data(named: "slow-boring")
    let turnover = try StreamFixture.removingFirstItem(from: original)
    let sequence = FeedSequence(feeds: [original, original, turnover])
    let ingestor = FeedIngestor(
      client: FeedClient(load: { _ in await sequence.next() }),
      now: { Date(timeIntervalSince1970: 123) }
    )

    let first = try await ingestor.ingest(stream: stream, into: database)
    let countsAfterFirst = try await database.read { db in
      (try ContentPiece.fetchCount(db), try Artifact.fetchCount(db))
    }
    _ = try await ingestor.ingest(stream: stream, into: database)
    let countsAfterRepeat = try await database.read { db in
      (try ContentPiece.fetchCount(db), try Artifact.fetchCount(db))
    }
    expectNoDifference(countsAfterRepeat.0, countsAfterFirst.0)
    expectNoDifference(countsAfterRepeat.1, countsAfterFirst.1)

    let turnedOver = try #require(first.first)
    _ = try await ingestor.ingest(stream: stream, into: database)
    try await database.read { db in
      let piece = try ContentPiece.find(turnedOver.id).fetchOne(db)
      let artifacts = try Artifact.where { $0.contentPieceID.eq(turnedOver.id) }.fetchAll(db)
      #expect(piece != nil)
      #expect(artifacts.contains { $0.rawSourceText != nil })
      #expect(artifacts.allSatisfy { $0.id != $0.contentPieceID })
    }
  }

  @Test("Add Stream proposes deterministic feed metadata and persists an Interest Area")
  func addStream() async throws {
    let data = StreamFixture.data(named: "slow-boring")
    let model = withDependencies {
      $0.feedClient = FeedClient(load: { _ in data })
    } operation: {
      FollowingModel()
    }
    model.addURL = "https://example.com/writer"
    await model.discoverButtonTapped()
    var proposal = try #require(model.proposedStream)
    expectNoDifference(proposal.name, "Slow Boring")
    expectNoDifference(proposal.publisher, "Slow Boring")
    expectNoDifference(proposal.interestAreaName, "General")
    proposal.handlingGuidance = "Keep the writer's original argument available."
    model.proposedStream = proposal
    await model.followButtonTapped()

    try await database.read { db in
      let matchingStream = try Stream.where { $0.locator.eq("https://example.com/writer") }.fetchOne(db)
      let stream = try #require(matchingStream)
      let interestArea = try InterestArea.find(try #require(stream.interestAreaID)).fetchOne(db)
      expectNoDifference(stream.handlingGuidance, "Keep the writer's original argument available.")
      expectNoDifference(interestArea?.name, "General")
      let row = try #require(FollowingRequest().fetch(db).rows.first { $0.id == stream.id })
      expectNoDifference(row.effectiveHealth, .unknown)
    }
    #expect(model.proposedStream == nil)
  }

  @Test("One launch and refresh entry point seeds five streams and skips paused and stopped streams")
  func launchAndRefreshRespectFollowState() async throws {
    let recorder = URLRecorder()
    let data = StreamFixture.data(named: "point-free")
    let model = withDependencies {
      $0.feedClient = FeedClient(load: { url in
        await recorder.record(url)
        return data
      })
    } operation: {
      FollowingModel()
    }

    await model.acquireOnLaunchOrRefresh()
    try await model.$following.load()
    expectNoDifference(model.rows.count, 5)
    let initialPollCount = await recorder.count()
    expectNoDifference(initialPollCount, 5)
    let paused = try #require(model.rows.first)
    let stopped = try #require(model.rows.dropFirst().first)
    await model.followStateButtonTapped(.paused, for: paused.id)
    await model.followStateButtonTapped(.stopped, for: stopped.id)
    await recorder.reset()

    await model.acquireOnLaunchOrRefresh()
    let refreshPollCount = await recorder.count()
    expectNoDifference(refreshPollCount, 3)
    let states = try await database.read { db in
      try Stream.all.fetchAll(db).map { ($0.name, $0.followState) }
    }
    #expect(states.contains { $0.0 == paused.name && $0.1 == .paused })
    #expect(states.contains { $0.0 == stopped.name && $0.1 == .stopped })
  }
}

private enum StreamFixture {
  static let allNames = ["slow-boring", "astral-codex-ten", "techmeme", "point-free", "benedict-evans"]

  static func data(named name: String) -> Data {
    let url = Bundle.module.url(forResource: name, withExtension: "xml", subdirectory: "Fixtures/streams")!
    return try! Data(contentsOf: url)
  }

  static func removingFirstItem(from data: Data) throws -> Data {
    var source = String(decoding: data, as: UTF8.self)
    guard let start = source.range(of: "<item>"),
      let end = source.range(of: "</item>", range: start.lowerBound..<source.endIndex)
    else { throw FeedParsingError.malformedDocument }
    source.removeSubrange(start.lowerBound..<end.upperBound)
    return Data(source.utf8)
  }
}

private actor FeedSequence {
  private var feeds: [Data]

  init(feeds: [Data]) { self.feeds = feeds }

  func next() -> Data { feeds.removeFirst() }
}

private actor URLRecorder {
  private var urls: [URL] = []

  func record(_ url: URL) { urls.append(url) }
  func reset() { urls.removeAll() }
  func count() -> Int { urls.count }
}
