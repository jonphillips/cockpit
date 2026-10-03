import Foundation
import Observation
import Dependencies
import SQLiteData

@Table("listedPieceStates")
public struct ListedPieceState: Equatable, Identifiable, Sendable {
  @Column(primaryKey: true) public let contentPieceID: ContentPiece.ID
  public var openedAt: Date?
  public var dismissedAt: Date?
  public var id: ContentPiece.ID { contentPieceID }

  public init(contentPieceID: ContentPiece.ID, openedAt: Date? = nil, dismissedAt: Date? = nil) {
    self.contentPieceID = contentPieceID
    self.openedAt = openedAt
    self.dismissedAt = dismissedAt
  }
}

public enum ListedFeedPolicy {
  public static let window = DateComponents(day: 7)
}

public enum ListedFeeds {
  public static func contentPieceIDs(in db: Database) throws -> Set<ContentPiece.ID> {
    let listedStreamIDs = Set(try Stream.where { $0.handling.eq(StreamHandling.listed) }
      .select(\.id).fetchAll(db))
    guard !listedStreamIDs.isEmpty else { return [] }
    let optionalStreamIDs = listedStreamIDs.map(Optional.some)
    return Set(try Artifact.where { $0.streamID.in(optionalStreamIDs) }
      .select(\.contentPieceID).fetchAll(db).compactMap { $0 })
  }
}

public struct ListedFeedsRequest: FetchKeyRequest {
  @Selection
  public struct Source: Equatable, Identifiable, Sendable {
    public let id: Stream.ID
    public let name: String
    public let publisher: String
    public var newCount: Int
  }

  @Selection
  public struct Item: Equatable, Identifiable, Sendable {
    public let id: ContentPiece.ID
    public let title: String
    public let creator: String?
    public let canonicalURL: String?
    public let listedDate: Date
    public let streamID: Stream.ID
    public let streamName: String
    public let isOpened: Bool
    public let description: String
  }

  public struct Value: Equatable, Sendable {
    public var sources: [Source] = []
    public var items: [Item] = []
    public var totalNewCount = 0
    public var showsPublisherLabel = false
    public var hasListedStreams = false
    public init() {}
  }

  public var now: Date
  public var calendar: Calendar

  public init(now: Date = .now, calendar: Calendar = .current) {
    self.now = now
    self.calendar = calendar
  }

  public func fetch(_ db: Database) throws -> Value {
    let hasListedStreams = try !Stream.where { $0.handling.eq(StreamHandling.listed) }
      .fetchAll(db).isEmpty
    var result = Value()
    result.hasListedStreams = hasListedStreams
    let streams = try orderedListedStreams(in: db)
    let streamByID = Dictionary(uniqueKeysWithValues: streams.map { ($0.id, $0) })
    let streamOrder = Dictionary(uniqueKeysWithValues: streams.enumerated().map { ($1.id, $0) })
    guard !streams.isEmpty else { return result }
    let optionalStreamIDs = streams.map { Optional($0.id) }
    let listedArtifacts = try Artifact.where { $0.streamID.in(optionalStreamIDs) }
      .fetchAll(db).filter { $0.contentPieceID != nil && $0.streamID.flatMap { streamByID[$0] } != nil }
    let artifactsByPiece = Dictionary(grouping: listedArtifacts, by: { $0.contentPieceID! })
    guard !artifactsByPiece.isEmpty else {
      result.sources = streams.map { Source(id: $0.id, name: $0.name, publisher: $0.publisher, newCount: 0) }
      result.showsPublisherLabel = Set(result.sources.map(\.publisher)).count > 1
      return result
    }
    let pieceIDs = Set(artifactsByPiece.keys)
    let pieces = Dictionary(uniqueKeysWithValues: try ContentPiece.where { $0.id.in(pieceIDs) }
      .fetchAll(db).map { ($0.id, $0) })
    let states = Dictionary(uniqueKeysWithValues: try ListedPieceState.where { $0.contentPieceID.in(pieceIDs) }
      .fetchAll(db).map { ($0.contentPieceID, $0) })
    let cutoff = calendar.date(
      byAdding: .day, value: -(ListedFeedPolicy.window.day ?? 7), to: now
    ) ?? now.addingTimeInterval(-7 * 86_400)
    var itemsByStream: [Stream.ID: [Item]] = [:]

    for (pieceID, artifacts) in artifactsByPiece {
      guard let piece = pieces[pieceID] else { continue }
      let listedDate = piece.publishedAt ?? artifacts.map(\.acquiredAt).min()!
      guard listedDate >= cutoff else { continue }
      let state = states[pieceID]
      guard state?.dismissedAt == nil else { continue }
      let orderedArtifacts = artifacts.sorted {
        let l = (streamOrder[$0.streamID!]!, $0.acquiredAt, $0.id.uuidString)
        let r = (streamOrder[$1.streamID!]!, $1.acquiredAt, $1.id.uuidString)
        return l < r
      }
      guard let artifact = orderedArtifacts.first, let streamID = artifact.streamID,
        let stream = streamByID[streamID]
      else { continue }
      let plainDescription = (HTMLText.normalizedText(from: artifact.rawSourceText) ?? "")
        .components(separatedBy: .newlines).joined(separator: " ")
      let item = Item(
        id: pieceID, title: piece.title, creator: piece.creator, canonicalURL: piece.canonicalURL,
        listedDate: listedDate, streamID: streamID, streamName: stream.name,
        isOpened: state?.openedAt != nil, description: plainDescription)
      itemsByStream[streamID, default: []].append(item)
    }

    result.items = itemsByStream.values.flatMap { $0 }.sorted {
      if $0.listedDate != $1.listedDate { return $0.listedDate > $1.listedDate }
      return $0.id.uuidString < $1.id.uuidString
    }
    result.sources = streams.map { stream in
      let count = itemsByStream[stream.id, default: []].filter { !$0.isOpened }.count
      return Source(id: stream.id, name: stream.name, publisher: stream.publisher, newCount: count)
    }
    result.totalNewCount = result.items.filter { !$0.isOpened }.count
    result.showsPublisherLabel = Set(result.sources.map(\.publisher)).count > 1
    return result
  }

  private func orderedListedStreams(in db: Database) throws -> [Stream] {
    let areaNames = Dictionary(uniqueKeysWithValues: try InterestArea.all.fetchAll(db).map { ($0.id, $0.name) })
    return try Stream.where { $0.followState.eq(StreamFollowState.active) }
      .fetchAll(db)
      .filter { $0.handling == .listed && $0.transport != .gmail }
      .sorted {
        let left = (areaNames[$0.interestAreaID ?? UUID()] ?? "", $0.name, $0.id.uuidString)
        let right = (areaNames[$1.interestAreaID ?? UUID()] ?? "", $1.name, $1.id.uuidString)
        return left < right
      }
  }
}

@Observable
@MainActor
public final class ListedFeedsModel {
  @ObservationIgnored @Fetch public var content = ListedFeedsRequest.Value()
  @ObservationIgnored private var lastDismissedIDs: Set<ContentPiece.ID> = []
  @ObservationIgnored private let database: any DatabaseWriter
  @ObservationIgnored private let now: () -> Date

  public init(database: (any DatabaseWriter)? = nil, now: @escaping () -> Date = Date.init) {
    @Dependency(\.defaultDatabase) var defaultDatabase
    self.database = database ?? defaultDatabase
    self.now = now
    _content = Fetch(wrappedValue: .init(), ListedFeedsRequest(now: now()), database: self.database)
  }

  public var sources: [ListedFeedsRequest.Source] { content.sources }
  public var items: [ListedFeedsRequest.Item] { content.items }
  public var totalNewCount: Int { content.totalNewCount }
  public var showsPublisherLabel: Bool { content.showsPublisherLabel }
  public var hasListedStreams: Bool { content.hasListedStreams }

  public func reload() async throws {
    try await $content.load(ListedFeedsRequest(now: now()), database: database)
  }

  public func recordOpened(id: ContentPiece.ID) async throws {
    try await setState(id: id, open: true, dismiss: false)
  }

  public func saveForLater(id: ContentPiece.ID) async throws {
    let date = now()
    try await database.write { db in
      try DestinationOperations.saveForLater(id, at: date, in: db)
    }
  }

  public func addToLibrary(id: ContentPiece.ID) async throws {
    let date = now()
    try await database.write { db in
      try DestinationOperations.addToLibrary(id, at: date, in: db)
    }
  }

  public func dismiss(id: ContentPiece.ID) async throws {
    try await dismiss(ids: [id])
  }

  public func dismissAll(streamID: Stream.ID? = nil) async throws {
    let ids = Set(content.items.filter { streamID == nil || $0.streamID == streamID }.map(\.id))
    try await dismiss(ids: ids)
  }

  public func undo() async throws {
    let ids = lastDismissedIDs
    guard !ids.isEmpty else { return }
    try await database.write { db in
      for id in ids {
        try ListedPieceState.find(id).update { $0.dismissedAt = #bind(nil as Date?) }.execute(db)
      }
    }
    lastDismissedIDs = []
  }

  private func dismiss(ids: Set<ContentPiece.ID>) async throws {
    let stamp = now()
    let changed = try await database.write { db -> Set<ContentPiece.ID> in
      var changed: Set<ContentPiece.ID> = []
      for id in ids {
        if let state = try ListedPieceState.find(id).fetchOne(db) {
          guard state.dismissedAt == nil else { continue }
          try ListedPieceState.find(id).update { $0.dismissedAt = #bind(stamp) }.execute(db)
        } else {
          try ListedPieceState.insert { ListedPieceState(contentPieceID: id, dismissedAt: stamp) }.execute(db)
        }
        changed.insert(id)
      }
      return changed
    }
    if !changed.isEmpty { lastDismissedIDs = changed }
  }

  private func setState(id: ContentPiece.ID, open: Bool, dismiss: Bool) async throws {
    let stamp = now()
    try await database.write { db in
      if let state = try ListedPieceState.find(id).fetchOne(db) {
        if open && state.openedAt == nil {
          try ListedPieceState.find(id).update { $0.openedAt = #bind(stamp) }.execute(db)
        } else if dismiss && state.dismissedAt == nil {
          try ListedPieceState.find(id).update { $0.dismissedAt = #bind(stamp) }.execute(db)
        }
      } else {
        try ListedPieceState.insert {
          ListedPieceState(contentPieceID: id, openedAt: open ? stamp : nil, dismissedAt: dismiss ? stamp : nil)
        }.execute(db)
      }
    }
  }
}
