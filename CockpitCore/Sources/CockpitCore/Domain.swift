import Foundation
import SQLiteData

public enum StreamTransport: String, Codable, QueryBindable, Sendable {
  case rss
  case atom
}

public enum StreamHandling: String, Codable, QueryBindable, Sendable {
  case following
}

public enum StreamFollowState: String, Codable, QueryBindable, Sendable {
  case active
}

public enum StreamHealth: String, Codable, QueryBindable, Sendable {
  case unknown
  case healthy
  case failed
}

public enum ContentKind: String, Codable, QueryBindable, Sendable {
  case article
  case newsletter
  case video
  case podcast
  case report
  case pdf
  case post
}

@Table("interestAreas")
public struct InterestArea: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public var name: String
  public var guidance: String
  public var sortOrder: Int

  public init(id: UUID, name: String, guidance: String = "", sortOrder: Int = 0) {
    self.id = id
    self.name = name
    self.guidance = guidance
    self.sortOrder = sortOrder
  }
}

@Table("streams")
public struct Stream: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public var name: String
  public var publisher: String
  public var interestAreaID: InterestArea.ID?
  public var transport: StreamTransport
  public var locator: String
  public var handling: StreamHandling
  public var isEssential: Bool
  public var followState: StreamFollowState
  public var health: StreamHealth
  public var lastReceivedAt: Date?
  public var autoLibrary: Bool

  public init(
    id: UUID,
    name: String,
    publisher: String,
    interestAreaID: InterestArea.ID? = nil,
    transport: StreamTransport,
    locator: String,
    handling: StreamHandling = .following,
    isEssential: Bool = false,
    followState: StreamFollowState = .active,
    health: StreamHealth = .unknown,
    lastReceivedAt: Date? = nil,
    autoLibrary: Bool = false
  ) {
    self.id = id
    self.name = name
    self.publisher = publisher
    self.interestAreaID = interestAreaID
    self.transport = transport
    self.locator = locator
    self.handling = handling
    self.isEssential = isEssential
    self.followState = followState
    self.health = health
    self.lastReceivedAt = lastReceivedAt
    self.autoLibrary = autoLibrary
  }
}

@Table("artifacts")
public struct Artifact: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public var streamID: Stream.ID?
  public var transport: StreamTransport
  public var providerID: String?
  public var canonicalURL: String?
  public var acquiredAt: Date
  public var payloadRef: String?
  public var rawSourceText: String?
  public var contentPieceID: ContentPiece.ID?

  public init(
    id: UUID,
    streamID: Stream.ID? = nil,
    transport: StreamTransport,
    providerID: String? = nil,
    canonicalURL: String? = nil,
    acquiredAt: Date,
    payloadRef: String? = nil,
    rawSourceText: String? = nil,
    contentPieceID: ContentPiece.ID? = nil
  ) {
    self.id = id
    self.streamID = streamID
    self.transport = transport
    self.providerID = providerID
    self.canonicalURL = canonicalURL
    self.acquiredAt = acquiredAt
    self.payloadRef = payloadRef
    self.rawSourceText = rawSourceText
    self.contentPieceID = contentPieceID
  }
}

@Table("contentPieces")
public struct ContentPiece: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public var kind: ContentKind
  public var title: String
  public var creator: String?
  public var publisher: String
  public var publishedAt: Date?
  public var canonicalURL: String?
  public var summary: String?
  public var normalizedText: String?
  public var subjects: String?
  public var isSubstantivePrimary: Bool?
  public var createdAt: Date

  public init(
    id: UUID,
    kind: ContentKind,
    title: String,
    creator: String? = nil,
    publisher: String,
    publishedAt: Date? = nil,
    canonicalURL: String? = nil,
    summary: String? = nil,
    normalizedText: String? = nil,
    subjects: String? = nil,
    isSubstantivePrimary: Bool? = nil,
    createdAt: Date
  ) {
    self.id = id
    self.kind = kind
    self.title = title
    self.creator = creator
    self.publisher = publisher
    self.publishedAt = publishedAt
    self.canonicalURL = canonicalURL
    self.summary = summary
    self.normalizedText = normalizedText
    self.subjects = subjects
    self.isSubstantivePrimary = isSubstantivePrimary
    self.createdAt = createdAt
  }
}
