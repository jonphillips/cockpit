import Foundation
import SQLiteData

public enum StreamTransport: String, Codable, QueryBindable, Sendable { case rss, atom, gmail }

public enum StreamHandling: String, Codable, QueryBindable, Sendable { case following }

public enum StreamFollowState: String, Codable, QueryBindable, Sendable {
  case active
  case paused
  case stopped
}

public enum StreamHealth: String, Codable, QueryBindable, Sendable {
  case unknown
  case healthy
  case failed
}

public enum ContentKind: String, Codable, QueryBindable, Sendable {
  case article, newsletter, video, podcast, report, pdf, post, email
}

public enum PersonalKnowledgeKind: String, Codable, QueryBindable, CaseIterable, Hashable, Sendable {
  case fact
  case taste
  case interest

  public var displayName: String { rawValue.capitalized }
}

public enum PersonalKnowledgeClaimStatus: String, Codable, QueryBindable, Hashable, Sendable {
  case current
  case superseded
  case retired
}

public enum PersonalKnowledgeProvenance: String, Codable, QueryBindable, Hashable, Sendable {
  case directTeaching
  case readerTeaching
  case confirmedHypothesis
  case correction
  case jonBrainImport
  case semanticConsolidation

  public var displayName: String {
    switch self {
    case .directTeaching: "Direct teaching"
    case .readerTeaching: "Taught from Reader"
    case .confirmedHypothesis: "Confirmed Cockpit hypothesis"
    case .correction: "Correction"
    case .jonBrainImport: "Jon Brain import"
    case .semanticConsolidation: "Synthesized from explicit claims"
    }
  }
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
  public var handlingGuidance: String
  public var isEssential: Bool
  public var followState: StreamFollowState
  public var autoLibrary: Bool
  /// An explicit, per-Stream editorial setting for the rare mail digest that deserves within-issue
  /// extraction. It has no effect for non-Gmail Artifacts.
  public var isGrabBag: Bool

  public init(
    id: UUID,
    name: String,
    publisher: String,
    interestAreaID: InterestArea.ID? = nil,
    transport: StreamTransport,
    locator: String,
    handling: StreamHandling = .following,
    handlingGuidance: String = "",
    isEssential: Bool = false,
    followState: StreamFollowState = .active,
    autoLibrary: Bool = false,
    isGrabBag: Bool = false
  ) {
    self.id = id
    self.name = name
    self.publisher = publisher
    self.interestAreaID = interestAreaID
    self.transport = transport
    self.locator = locator
    self.handling = handling
    self.handlingGuidance = handlingGuidance
    self.isEssential = isEssential
    self.followState = followState
    self.autoLibrary = autoLibrary
    self.isGrabBag = isGrabBag
  }
}

/// Per-device acquisition observations. Poll health is regenerable and deliberately not synced.
@Table
public struct StreamPollState: Equatable, Identifiable, Sendable {
  @Column(primaryKey: true) public let streamID: Stream.ID
  public var health: StreamHealth
  public var lastReceivedAt: Date?
  public var consecutiveFailureCount: Int
  public var lastFailureDescription: String?
  public var id: Stream.ID { streamID }

  public init(
    streamID: Stream.ID,
    health: StreamHealth = .unknown,
    lastReceivedAt: Date? = nil,
    consecutiveFailureCount: Int = 0,
    lastFailureDescription: String? = nil
  ) {
    self.streamID = streamID
    self.health = health
    self.lastReceivedAt = lastReceivedAt
    self.consecutiveFailureCount = consecutiveFailureCount
    self.lastFailureDescription = lastFailureDescription
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
  /// Device-local, provider-specific evidence needed to explain later treatment. Gmail stores the
  /// raw classification headers and message/thread/account identifiers here; it is deliberately
  /// not a new cross-provider entity or a synced field.
  public var providerProvenance: String?
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
    providerProvenance: String? = nil,
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
    self.providerProvenance = providerProvenance
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
  public var subjects: String?
  public var isSubstantivePrimary: Bool?
  public var bodyCompleteness: BodyCompleteness?
  /// The deterministic treatment used by Today for Gmail-backed mail. It is nil for non-email
  /// ContentPieces and legacy email until S5 classification has run.
  public var emailTreatment: EmailTreatment?
  /// A deterministic sub-kind for transactional email. It is nil for every other treatment and
  /// lets a later explicit policy target stale verification mail without deriving authority from
  /// this classification.
  public var emailTransactionalKind: EmailTransactionalKind?
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
    subjects: String? = nil,
    isSubstantivePrimary: Bool? = nil,
    bodyCompleteness: BodyCompleteness? = nil,
    emailTreatment: EmailTreatment? = nil,
    emailTransactionalKind: EmailTransactionalKind? = nil,
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
    self.subjects = subjects
    self.isSubstantivePrimary = isSubstantivePrimary
    self.bodyCompleteness = bodyCompleteness
    self.emailTreatment = emailTreatment
    self.emailTransactionalKind = emailTransactionalKind
    self.createdAt = createdAt
  }
}

@Table("personalKnowledgeClaims")
public struct PersonalKnowledgeClaim: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public var kind: PersonalKnowledgeKind
  public var claim: String
  public var scope: String?
  public var provenance: PersonalKnowledgeProvenance
  /// Present only when this claim was explicitly taught from a Reader. The linked teaching owns
  /// the raw reason and originating ContentPiece; claims never infer this relationship.
  public var teachingID: PersonalKnowledgeTeaching.ID?
  public var status: PersonalKnowledgeClaimStatus
  public var supersededByID: UUID?
  public var createdAt: Date

  public init(
    id: UUID,
    kind: PersonalKnowledgeKind,
    claim: String,
    scope: String? = nil,
    provenance: PersonalKnowledgeProvenance,
    teachingID: PersonalKnowledgeTeaching.ID? = nil,
    status: PersonalKnowledgeClaimStatus = .current,
    supersededByID: UUID? = nil,
    createdAt: Date
  ) {
    self.id = id
    self.kind = kind
    self.claim = claim
    self.scope = scope
    self.provenance = provenance
    self.teachingID = teachingID
    self.status = status
    self.supersededByID = supersededByID
    self.createdAt = createdAt
  }
}
