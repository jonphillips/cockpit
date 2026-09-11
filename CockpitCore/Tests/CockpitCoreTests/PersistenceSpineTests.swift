import CockpitCore
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
struct PersistenceSpineTests {
  @Dependency(\.defaultDatabase) private var database

  @Test("Poll health is created only in the device-local StreamPollState table")
  func pollHealthSchemaIsDeviceLocal() async throws {
    let columns = try await database.read { db in
      (
        try #sql("SELECT name FROM pragma_table_info('streams')", as: String.self).fetchAll(db),
        try #sql("SELECT name FROM pragma_table_info('streamPollStates')", as: String.self).fetchAll(db)
      )
    }
    #expect(!columns.0.contains("health"))
    #expect(!columns.0.contains("lastReceivedAt"))
    #expect(columns.1.contains("health"))
    #expect(columns.1.contains("lastReceivedAt"))
    #expect(columns.1.contains("consecutiveFailureCount"))
    #expect(columns.1.contains("lastFailureDescription"))
  }

  @Test("Invariant 1: an Artifact has its own identity and references a ContentPiece")
  func artifactAndContentPieceHaveDistinctIdentities() async throws {
    let contentPieceID = UUID(-1)
    let artifactID = UUID(-2)
    let createdAt = Date(timeIntervalSince1970: 0)
    try await database.write { db in
      try ContentPiece.insert {
        ContentPiece.Draft(
          ContentPiece(
            id: contentPieceID,
            kind: .article,
            title: "A piece",
            publisher: "Publisher",
            createdAt: createdAt
          )
        )
      }.execute(db)
      try Artifact.insert {
        Artifact.Draft(
          Artifact(
            id: artifactID,
            transport: .rss,
            acquiredAt: createdAt,
            contentPieceID: contentPieceID
          )
        )
      }.execute(db)
    }

    #expect(artifactID != contentPieceID)
    let artifact = try await database.read { db in
      try Artifact.find(artifactID).fetchOne(db)
    }
    expectNoDifference(artifact?.contentPieceID, Optional(contentPieceID))
  }

  @Test("Invariant 2: derived ContentPiece identity survives title, summary, and subject edits")
  func contentPieceIdentityIsDerivedFromCanonicalIdentity() {
    let namespace = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!
    let initial = ContentIdentityInput(
      canonicalURL: URL(string: "https://Example.com/essay/?utm_source=feed#section"),
      title: "Initial title",
      publisher: "Publisher",
      publishedAt: Date(timeIntervalSince1970: 0)
    )
    let edited = ContentIdentityInput(
      canonicalURL: URL(string: "https://example.com/essay"),
      title: "Edited title",
      publisher: "Another publisher",
      publishedAt: Date(timeIntervalSince1970: 10)
    )

    expectNoDifference(
      ContentIdentity.derive(for: initial, namespace: namespace),
      ContentIdentity.derive(for: edited, namespace: namespace)
    )
  }

  @Test("UUIDv5 conforms to the RFC 4122 reference vector")
  func uuidV5ReferenceVector() {
    let namespace = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!
    expectNoDifference(
      ContentIdentity.derive(
        for: ContentIdentityInput(
          providerStableID: "www.widgets.com",
          title: "unused",
          publisher: "unused"
        ),
        namespace: namespace
      ).uuidString.lowercased(),
      "21f7f8de-8051-5b89-8680-0195ef798b6a"
    )
  }

  @Test("Cockpit identity uses its fixed cross-device namespace")
  func cockpitNamespaceIsFixed() {
    expectNoDifference(
      ContentIdentity.cockpitNamespace.uuidString.lowercased(),
      "4577b834-26f2-58c0-bed6-e73143426dff"
    )
  }

  @Test("Identity convergence: tracking parameters produce one ContentPiece identity")
  func trackingParametersConverge() {
    let namespace = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!
    let tracked = ContentIdentityInput(
      canonicalURL: URL(string: "https://example.com/work/?fbclid=token&utm_campaign=digest&ref=home"),
      title: "One",
      publisher: "Publisher"
    )
    let clean = ContentIdentityInput(
      canonicalURL: URL(string: "https://example.com/work"),
      title: "Two",
      publisher: "Publisher"
    )
    expectNoDifference(
      ContentIdentity.derive(for: tracked, namespace: namespace),
      ContentIdentity.derive(for: clean, namespace: namespace)
    )
  }

  @Test("Invariant 11: textual feed content is stored as normalized text at ingest")
  func normalizedTextIsStoredAtIngest() async throws {
    let stream = CockpitCore.Stream(
      id: UUID(-1), name: "Test", publisher: "Test Publisher", transport: .rss,
      locator: "https://example.com/feed.xml"
    )
    try await insert(stream: stream)
    let feed = Data(
      """
      <rss version="2.0"><channel><title>Test</title><item>
      <title>A title</title><link>https://example.com/article</link>
      <description><![CDATA[<p>Readable <strong>body</strong>.</p>]]></description>
      </item></channel></rss>
      """.utf8
    )
    let ingestor = FeedIngestor(
      client: FeedClient(load: { _ in feed }),
      identityNamespace: UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!,
      now: { Date(timeIntervalSince1970: 0) }
    )

    let pieces = try await ingestor.ingest(stream: stream, into: database)

    let text = try await database.read { db in
      try NormalizedTextOperations.text(for: pieces[0].id, in: db)
    }
    expectNoDifference(text, "Readable body.")
    let pollState = try await database.read { db in
      try StreamPollState.find(stream.id).fetchOne(db)
    }
    expectNoDifference(pollState?.health, .healthy)
    expectNoDifference(pollState?.lastReceivedAt, Date(timeIntervalSince1970: 0))
    expectNoDifference(pollState?.consecutiveFailureCount, 0)
  }

  @Test("Ingest preserves judgment and prior normalized text when a later poll has no body")
  func reingestPreservesJudgmentAndText() async throws {
    let stream = CockpitCore.Stream(
      id: UUID(-1), name: "Test", publisher: "Test Publisher", transport: .rss,
      locator: "https://example.com/feed.xml"
    )
    try await insert(stream: stream)
    let firstFeed = Data(
      """
      <rss version="2.0"><channel><title>Test</title><item>
      <title>A title</title><guid>stable-id</guid><link>https://example.com/article</link>
      <description><![CDATA[<p>Readable body</p>]]></description>
      </item></channel></rss>
      """.utf8
    )
    let bodylessFeed = Data(
      """
      <rss version="2.0"><channel><title>Test</title><item>
      <title>A changed title</title><guid>stable-id</guid><link>https://example.com/article</link>
      </item></channel></rss>
      """.utf8
    )
    let source = FeedSequence(feeds: [firstFeed, bodylessFeed])
    let ingestor = FeedIngestor(
      client: FeedClient(load: { _ in await source.next() }),
      now: { Date(timeIntervalSince1970: 0) }
    )

    let firstPiece = try await ingestor.ingest(stream: stream, into: database).first!
    try await database.write { db in
      try ContentPiece.find(firstPiece.id)
        .update {
          $0.summary = #bind("Judged summary")
          $0.subjects = #bind("[\"swift\"]")
          $0.isSubstantivePrimary = #bind(true)
        }
        .execute(db)
    }
    let piece = try await ingestor.ingest(stream: stream, into: database).first!
    expectNoDifference(piece.summary, "Judged summary")
    expectNoDifference(piece.subjects, "[\"swift\"]")
    expectNoDifference(piece.isSubstantivePrimary, true)
    let text = try await database.read { db in
      try NormalizedTextOperations.text(for: piece.id, in: db)
    }
    expectNoDifference(text, "Readable body")
  }

  @Test("Identity convergence: repeat and cross-Stream ingest create one ContentPiece")
  func repeatedAndCrossStreamIngestConverges() async throws {
    let firstStream = CockpitCore.Stream(
      id: UUID(-1), name: "First", publisher: "Publisher", transport: .rss,
      locator: "https://example.com/first.xml"
    )
    let secondStream = CockpitCore.Stream(
      id: UUID(-2), name: "Second", publisher: "Publisher", transport: .rss,
      locator: "https://example.com/second.xml"
    )
    try await insert(stream: firstStream)
    try await insert(stream: secondStream)
    let feed = Data(
      """
      <rss version="2.0"><channel><title>Publisher</title><item>
      <title>A shared item</title><link>https://example.com/shared?utm_medium=rss</link>
      <description>Body</description></item></channel></rss>
      """.utf8
    )
    let ingestor = FeedIngestor(
      client: FeedClient(load: { _ in feed }),
      identityNamespace: UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!,
      now: { Date(timeIntervalSince1970: 0) }
    )

    _ = try await ingestor.ingest(stream: firstStream, into: database)
    _ = try await ingestor.ingest(stream: firstStream, into: database)
    _ = try await ingestor.ingest(stream: secondStream, into: database)

    let counts = try await database.read { db in
      (
        try ContentPiece.all.fetchCount(db),
        try Artifact.all.fetchCount(db)
      )
    }
    expectNoDifference(counts.0, 1)
    expectNoDifference(counts.1, 2)
  }

  @Test("RSS, RDF, Atom author, and named timezone formats parse correctly")
  func feedParserHandlesCommonFormatVariants() throws {
    let atom = try FeedParser.parse(
      Data(
        """
        <feed xmlns="http://www.w3.org/2005/Atom"><title>Publisher</title><entry>
        <title>A title</title><id>entry-id</id><author><name>Jon</name></author>
        <updated>2026-09-11T12:00:00Z</updated></entry></feed>
        """.utf8
      )
    )
    expectNoDifference(atom.entries.first?.creator, "Jon")

    let rdf = try FeedParser.parse(
      Data(
        """
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        <channel><title>Publisher</title></channel><item><title>A title</title>
        <link>https://example.com/article</link></item></rdf:RDF>
        """.utf8
      )
    )
    expectNoDifference(rdf.transport, .rss)

    let rss = try FeedParser.parse(
      Data(
        """
        <rss version="2.0"><channel><title>Publisher</title><item><title>A title</title>
        <pubDate>Fri, 11 Sep 2026 08:10:00 EST</pubDate></item></channel></rss>
        """.utf8
      )
    )
    #expect(rss.entries.first?.publishedAt != nil)
  }

  @Test("An entry with no provider ID or URL records one Artifact across re-polls")
  func keylessArtifactIsIdempotent() async throws {
    let stream = CockpitCore.Stream(
      id: UUID(-1), name: "Test", publisher: "Test Publisher", transport: .rss,
      locator: "https://example.com/feed.xml"
    )
    try await insert(stream: stream)
    let feed = Data(
      """
      <rss version="2.0"><channel><title>Test</title><item>
      <title>A title without a stable source key</title><description>Body</description>
      </item></channel></rss>
      """.utf8
    )
    let ingestor = FeedIngestor(client: FeedClient(load: { _ in feed }))

    _ = try await ingestor.ingest(stream: stream, into: database)
    _ = try await ingestor.ingest(stream: stream, into: database)
    let counts = try await database.read { db in
      (try ContentPiece.fetchCount(db), try Artifact.fetchCount(db))
    }
    expectNoDifference(counts.0, 1)
    expectNoDifference(counts.1, 1)
  }

  @Test("An ingest failure records device-local health and preserves the original error")
  func failedIngestMarksStreamUnhealthy() async throws {
    let stream = CockpitCore.Stream(
      id: UUID(-1), name: "Test", publisher: "Test Publisher", transport: .rss,
      locator: "https://example.com/feed.xml"
    )
    try await insert(stream: stream)
    let ingestor = FeedIngestor(
      client: FeedClient(load: { _ in throw FeedDiscoveryError.noAlternateFeed(URL(string: "https://example.com")!) })
    )

    await #expect(throws: FeedDiscoveryError.self) {
      try await ingestor.ingest(stream: stream, into: database)
    }
    let failedPollState = try await database.read { db in
      try StreamPollState.find(stream.id).fetchOne(db)
    }
    expectNoDifference(failedPollState?.health, .failed)
    expectNoDifference(failedPollState?.consecutiveFailureCount, 1)
    expectNoDifference(
      failedPollState?.lastFailureDescription,
      "Cockpit couldn't find an RSS or Atom feed at this URL."
    )
  }

  private func insert(stream: CockpitCore.Stream) async throws {
    try await database.write { db in
      try CockpitCore.Stream.insert { CockpitCore.Stream.Draft(stream) }.execute(db)
    }
  }
}

private actor FeedSequence {
  private var feeds: [Data]

  init(feeds: [Data]) {
    self.feeds = feeds
  }

  func next() -> Data {
    feeds.removeFirst()
  }
}
