import Dependencies
import Foundation
import SQLiteData

public struct FeedClient: Sendable {
  public var load: @Sendable (URL) async throws -> Data

  public init(load: @escaping @Sendable (URL) async throws -> Data) {
    self.load = load
  }

  public static let live = Self { url in
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let response = response as? HTTPURLResponse else {
      throw FeedDiscoveryError.invalidResponse(url)
    }
    guard (200..<300).contains(response.statusCode) else {
      throw FeedDiscoveryError.unsuccessfulResponse(url, response.statusCode)
    }
    return data
  }
}

public enum FeedDiscoveryError: Error, Equatable, Sendable {
  case invalidURL(String)
  case invalidResponse(URL)
  case unsuccessfulResponse(URL, Int)
  case noAlternateFeed(URL)
}

public enum FeedDiscovery {
  public static func discover(
    from url: URL,
    using client: FeedClient
  ) async throws -> (url: URL, feed: ParsedFeed) {
    let initialDocument = try await client.load(url)
    if let feed = try? FeedParser.parse(initialDocument) {
      return (url, feed)
    }
    guard let alternateURL = alternateFeedURL(in: initialDocument, relativeTo: url) else {
      throw FeedDiscoveryError.noAlternateFeed(url)
    }
    let alternateDocument = try await client.load(alternateURL)
    return (alternateURL, try FeedParser.parse(alternateDocument))
  }

  static func alternateFeedURL(in html: Data, relativeTo sourceURL: URL) -> URL? {
    guard let source = String(data: html, encoding: .utf8) else { return nil }
    let links = source.matches(for: "(?is)<link\\b[^>]*>")
    for link in links {
      let attributes = Dictionary(uniqueKeysWithValues: link.attributePairs)
      guard attributes["rel"]?.lowercased().split(separator: " ").contains("alternate") == true,
        let type = attributes["type"]?.lowercased(),
        ["application/rss+xml", "application/atom+xml"].contains(type),
        let href = attributes["href"],
        let url = URL(string: href, relativeTo: sourceURL)?.absoluteURL
      else { continue }
      return url
    }
    return nil
  }
}

public struct FeedIngestor {
  @Dependency(\.uuid) private var uuid

  public let client: FeedClient
  public let identityNamespace: UUID
  public let now: @Sendable () -> Date

  public init(
    client: FeedClient = .live,
    identityNamespace: UUID = ContentIdentity.cockpitNamespace,
    now: @escaping @Sendable () -> Date = Date.init
  ) {
    self.client = client
    self.identityNamespace = identityNamespace
    self.now = now
  }

  @discardableResult
  public func ingest(
    stream: Stream,
    into database: any DatabaseWriter
  ) async throws -> [ContentPiece] {
    guard let streamURL = URL(string: stream.locator) else {
      throw FeedDiscoveryError.invalidURL(stream.locator)
    }
    let discovery: (url: URL, feed: ParsedFeed)
    do {
      discovery = try await FeedDiscovery.discover(from: streamURL, using: client)
    } catch {
      await markFailed(stream: stream, in: database)
      throw error
    }
    let acquiredAt = now()
    let artifactIDs = discovery.feed.entries.map { _ in uuid() }
    let namespace = identityNamespace
    let transport = discovery.feed.transport
    let entries = discovery.feed.entries
    do {
      return try await database.write { db in
        let pieces = try zip(entries, artifactIDs).map { entry, artifactID in
          try Self.record(
            entry: entry,
            artifactID: artifactID,
            stream: stream,
            transport: transport,
            acquiredAt: acquiredAt,
            namespace: namespace,
            in: db
          )
        }
        try Stream.find(stream.id)
          .update {
            $0.lastReceivedAt = #bind(acquiredAt)
            $0.health = #bind(StreamHealth.healthy)
          }
          .execute(db)
        return pieces
      }
    } catch {
      await markFailed(stream: stream, in: database)
      throw error
    }
  }

  private func markFailed(stream: Stream, in database: any DatabaseWriter) async {
    try? await database.write { db in
      try Stream.find(stream.id)
        .update { $0.health = #bind(StreamHealth.failed) }
        .execute(db)
    }
  }
}

/// The ingest core: pure static steps over one feed entry, kept out of the ingestor's own
/// body so the type stays a thin orchestrator (swift-style §2).
extension FeedIngestor {
  /// Upserts the ContentPiece for one feed entry and records its Artifact, preserving
  /// everything the feed does not own: judgment output, readable text, and first-seen time.
  private static func record(
    entry: FeedEntry,
    artifactID: UUID,
    stream: Stream,
    transport: StreamTransport,
    acquiredAt: Date,
    namespace: UUID,
    in db: Database
  ) throws -> ContentPiece {
    let input = ContentIdentityInput(
      canonicalURL: entry.canonicalURL,
      providerStableID: entry.providerID,
      feedGUID: entry.guid,
      feedGUIDIsPermanent: entry.guidIsPermanent,
      title: entry.title,
      publisher: stream.publisher,
      publishedAt: entry.publishedAt
    )
    let id = ContentIdentity.derive(for: input, namespace: namespace)
    let canonicalURL = entry.canonicalURL.flatMap(ContentIdentity.normalizedURLString)
    let existing = try ContentPiece.find(id).fetchOne(db)
    let piece = ContentPiece(
      id: id,
      kind: FeedContentKind.infer(from: entry.canonicalURL),
      title: entry.title,
      creator: entry.creator ?? existing?.creator,
      publisher: stream.publisher,
      publishedAt: entry.publishedAt ?? existing?.publishedAt,
      canonicalURL: canonicalURL,
      summary: existing?.summary,
      normalizedText: entry.normalizedText ?? existing?.normalizedText,
      subjects: existing?.subjects,
      isSubstantivePrimary: existing?.isSubstantivePrimary,
      createdAt: existing?.createdAt ?? acquiredAt
    )
    try ContentPiece.upsert { ContentPiece.Draft(piece) }.execute(db)
    try insertArtifactIfNew(
      entry: entry,
      artifactID: artifactID,
      stream: stream,
      transport: transport,
      canonicalURL: canonicalURL,
      contentPieceID: id,
      acquiredAt: acquiredAt,
      in: db
    )
    return piece
  }

  /// An Artifact is one acquisition event. Re-polling a Stream that still lists an entry is
  /// not a new acquisition, so an existing row for this (Stream, entry) is left untouched.
  private static func insertArtifactIfNew(
    entry: FeedEntry,
    artifactID: UUID,
    stream: Stream,
    transport: StreamTransport,
    canonicalURL: String?,
    contentPieceID: ContentPiece.ID,
    acquiredAt: Date,
    in db: Database
  ) throws {
    let providerID = (entry.providerID ?? entry.guid)?.nilIfEmpty
    let existing: Artifact?
    if let providerID {
      existing = try Artifact.where {
        $0.streamID.eq(stream.id) && $0.providerID.eq(providerID)
      }.fetchOne(db)
    } else if let canonicalURL {
      existing = try Artifact.where {
        $0.streamID.eq(stream.id) && $0.providerID.is(nil) && $0.canonicalURL.eq(canonicalURL)
      }.fetchOne(db)
    } else {
      existing = nil
    }
    guard existing == nil else { return }
    let artifact = Artifact(
      id: artifactID,
      streamID: stream.id,
      transport: transport,
      providerID: providerID,
      canonicalURL: canonicalURL,
      acquiredAt: acquiredAt,
      rawSourceText: entry.bodyHTML ?? entry.descriptionHTML,
      contentPieceID: contentPieceID
    )
    try Artifact.insert { Artifact.Draft(artifact) }.execute(db)
  }
}

enum FeedContentKind {
  static func infer(from url: URL?) -> ContentKind {
    guard let host = url?.host?.lowercased() else { return .article }
    if host.contains("youtube.com") || host == "youtu.be" { return .video }
    return .article
  }
}

extension String {
  fileprivate func matches(for pattern: String) -> [String] {
    guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(startIndex..., in: self)
    return expression.matches(in: self, range: range).compactMap { match in
      Range(match.range, in: self).map { String(self[$0]) }
    }
  }

  fileprivate var attributePairs: [(String, String)] {
    let pattern = "(?i)([a-z][a-z0-9:_-]*)\\s*=\\s*([\\\"'])(.*?)\\2"
    guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(startIndex..., in: self)
    return expression.matches(in: self, range: range).compactMap { match in
      guard let keyRange = Range(match.range(at: 1), in: self),
        let valueRange = Range(match.range(at: 3), in: self)
      else { return nil }
      return (String(self[keyRange]).lowercased(), String(self[valueRange]))
    }
  }

  fileprivate var nilIfEmpty: Self? { isEmpty ? nil : self }
}
