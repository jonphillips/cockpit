import Dependencies
import Foundation
import LLMClientKit

/// Cockpit's fixed model choice for the first judgment pass. This is configuration at the
/// `ModelClient` construction boundary, rather than an axis on each `ModelRequest`.
public enum JudgmentModel {
  public static let modelID = "claude-sonnet-5"
  public static let displayName = "Claude Sonnet 5"

  /// A judgment call batches every one of the day's candidates into a single non-streaming
  /// request (JUDGMENT-CONTRACT: "the single structured LLM pass"), so its generation time scales
  /// with the candidate count — 122s was measured on the S2 fixture set, and a live Following
  /// corpus is bigger. `LLMClientKit`'s shared `URLSession.frontier` budgets 300s of *idle* time
  /// (no bytes received) before giving up, which a non-streaming call can exceed just waiting for
  /// the one response body — observed live as "Fail-closed piece ...: The request timed out." on
  /// every candidate at once. That shared session is used by every LLMClientKit consumer
  /// (Galavant, Yes Chef), so rather than widen it there, Cockpit builds its own longer-timeout
  /// session for this one call site (jon-platform rule: app-local until a neutral seam is proven).
  static let session: URLSession = {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 900
    configuration.timeoutIntervalForResource = 1_200
    return URLSession(configuration: configuration)
  }()

  public static func makeClient() -> any ModelClient {
    @Dependency(\.apiKeyStore) var keyStore
    return TieredModelClient(onDevice: OnDeviceModelClient.live) { provider in
      guard let key = keyStore.key(provider) else { return nil }
      return switch provider {
      case .anthropic: AnthropicModelClient(apiKey: key, model: modelID, session: session)
      case .openai: OpenAIModelClient(apiKey: key, model: provider.defaultModel, session: session)
      }
    }
  }
}

public enum JudgmentSection: String, Codable, CaseIterable, Sendable {
  case essentials
  case forYou
  case interestArea
  case essentialBacklog
}

public struct JudgmentCandidate: Codable, Equatable, Sendable, Identifiable {
  public let id: UUID
  public let kind: String
  public let title: String
  public let creator: String?
  public let publisher: String
  public let publishedAt: Date?
  public let canonicalURL: String?
  public let normalizedTextExcerpt: String
  public let bodyCompleteness: BodyCompleteness?
  public let stream: StreamContext
  public let interestArea: InterestAreaContext
  public let carriedEntry: CarriedEntryContext?

  public init(
    id: UUID, kind: String, title: String, creator: String? = nil, publisher: String,
    publishedAt: Date? = nil, canonicalURL: String? = nil, normalizedText: String,
    bodyCompleteness: BodyCompleteness? = nil,
    stream: StreamContext, interestArea: InterestAreaContext, carriedEntry: CarriedEntryContext? = nil
  ) {
    self.id = id
    self.kind = kind
    self.title = title
    self.creator = creator
    self.publisher = publisher
    self.publishedAt = publishedAt
    self.canonicalURL = canonicalURL
    self.normalizedTextExcerpt = String(normalizedText.prefix(1_500))
    self.bodyCompleteness = bodyCompleteness
    self.stream = stream
    self.interestArea = interestArea
    self.carriedEntry = carriedEntry
  }
}

public struct StreamContext: Codable, Equatable, Sendable {
  public let name: String
  public let handling: String
  public let handlingGuidance: String
  public let isEssential: Bool

  public init(name: String, handling: String, handlingGuidance: String, isEssential: Bool) {
    self.name = name
    self.handling = handling
    self.handlingGuidance = handlingGuidance
    self.isEssential = isEssential
  }
}

public struct InterestAreaContext: Codable, Equatable, Sendable {
  public let name: String
  public let guidance: String

  public init(name: String, guidance: String) {
    self.name = name
    self.guidance = guidance
  }
}

public struct CarriedEntryContext: Codable, Equatable, Sendable {
  public let timesCarried: Int
  public let entryState: String

  public init(timesCarried: Int, entryState: String) {
    self.timesCarried = timesCarried
    self.entryState = entryState
  }
}

public struct JudgmentFind: Codable, Equatable, Sendable {
  public let kind: String
  public let name: String
  public let descriptor: String
  public let rationale: String
  public let sourceURL: String?
  public let hints: [String: JSONValue]
}

/// The PK-free, per-piece result of Cockpit's mechanical type pass. This is deliberately
/// separate from editorial selection: whether a piece is its Stream's primary authored work is a
/// property of the material, not of the reader's current tastes or interests.
public struct JudgmentClassification: Equatable, Sendable, Identifiable {
  public let contentPieceID: UUID
  public let isSubstantivePrimary: Bool?
  public let subjects: [String]?
  public let summary: String?
  public let bodyCompleteness: BodyCompleteness?
  public let errorDescription: String?

  public var id: UUID { contentPieceID }

  public init(
    contentPieceID: UUID, isSubstantivePrimary: Bool?, subjects: [String]?, summary: String?,
    bodyCompleteness: BodyCompleteness? = nil, errorDescription: String? = nil
  ) {
    self.contentPieceID = contentPieceID
    self.isSubstantivePrimary = isSubstantivePrimary
    self.subjects = subjects
    self.summary = summary
    self.bodyCompleteness = bodyCompleteness
    self.errorDescription = errorDescription
  }
}

extension JudgmentClassification {
  static func failed(contentPieceID: UUID, error: String) -> Self {
    .init(
      contentPieceID: contentPieceID, isSubstantivePrimary: nil, subjects: nil, summary: nil,
      errorDescription: error)
  }
}

/// Model-use accounting for one of the two judgment passes. Keeping the figures separate makes
/// the M4 split's cost and latency visible rather than hiding a second call in a single total.
public struct JudgmentPassMetrics: Equatable, Sendable {
  public let usage: ModelUsage?
  public let estimatedCost: Decimal?
  public let latency: TimeInterval
  public let modelName: String

  public init(
    usage: ModelUsage?, estimatedCost: Decimal?, latency: TimeInterval, modelName: String
  ) {
    self.usage = usage
    self.estimatedCost = estimatedCost
    self.latency = latency
    self.modelName = modelName
  }

  static let empty = Self(
    usage: nil, estimatedCost: 0, latency: 0, modelName: JudgmentModel.displayName)
}

public struct JudgmentClassificationRun: Equatable, Sendable {
  public let classifications: [JudgmentClassification]
  public let metrics: JudgmentPassMetrics

  public init(classifications: [JudgmentClassification], metrics: JudgmentPassMetrics) {
    self.classifications = classifications
    self.metrics = metrics
  }
}

/// A proposed judgment. It is not a persistence command: S3 performs canonical Edition and
/// ContentPiece writes, and S5 decides whether to persist its `finds`.
public struct JudgmentOutcome: Equatable, Sendable, Identifiable {
  public let contentPieceID: UUID
  public let admit: Bool
  public let isSubstantivePrimary: Bool?
  public let section: JudgmentSection?
  public let rank: Int?
  public let rationale: String?
  /// The one explicit current claim judgment says drove this item's admission or rank. This is
  /// explanation context, not a score or a command; deterministic code validates it against the
  /// projection before materialising the Edition entry.
  public let matchedPersonalKnowledgeClaimID: PersonalKnowledgeClaim.ID?
  public let subjects: [String]?
  public let summary: String?
  public let bodyCompleteness: BodyCompleteness?
  public let finds: [JudgmentFind]?
  /// A type-pass error. Classification can fail independently of editorial selection, and only a
  /// valid classification is persisted back to the ContentPiece.
  public let classificationErrorDescription: String?
  /// A decode or response-contract error. Such an outcome is always fail-closed (`admit == false`)
  /// and remains in the batch so no ContentPiece silently disappears.
  public let errorDescription: String?

  public var id: UUID { contentPieceID }

  public init(
    contentPieceID: UUID, admit: Bool, isSubstantivePrimary: Bool?, section: JudgmentSection?,
    rank: Int?, rationale: String?, matchedPersonalKnowledgeClaimID: PersonalKnowledgeClaim.ID? = nil,
    subjects: [String]?, summary: String?,
    bodyCompleteness: BodyCompleteness? = nil, finds: [JudgmentFind]?,
    classificationErrorDescription: String? = nil, errorDescription: String? = nil
  ) {
    self.contentPieceID = contentPieceID
    self.admit = admit
    self.isSubstantivePrimary = isSubstantivePrimary
    self.section = section
    self.rank = rank
    self.rationale = rationale
    self.matchedPersonalKnowledgeClaimID = matchedPersonalKnowledgeClaimID
    self.subjects = subjects
    self.summary = summary
    self.bodyCompleteness = bodyCompleteness
    self.finds = finds
    self.classificationErrorDescription = classificationErrorDescription
    self.errorDescription = errorDescription
  }
}

public struct JudgmentRun: Equatable, Sendable {
  public let outcomes: [JudgmentOutcome]
  public let usage: ModelUsage?
  /// A Gate 1 estimate from provider-reported token usage, not a billed-invoice assertion.
  public let estimatedCost: Decimal?
  public let latency: TimeInterval
  public let requestedProvider: FrontierProvider
  public let modelName: String
  public let typePass: JudgmentPassMetrics
  public let editorialPass: JudgmentPassMetrics
}

extension JudgmentRun {
  static let empty = JudgmentRun(
    outcomes: [], usage: nil, estimatedCost: 0, latency: 0,
    requestedProvider: .anthropic, modelName: JudgmentModel.displayName,
    typePass: .empty, editorialPass: .empty
  )

  static func failed(candidates: [JudgmentCandidate], error: String, latency: TimeInterval) -> Self {
    .init(
      outcomes: candidates.map { .failed(contentPieceID: $0.id, error: error) },
      usage: nil, estimatedCost: nil, latency: latency,
      requestedProvider: .anthropic, modelName: JudgmentModel.displayName,
      typePass: .empty,
      editorialPass: .init(
        usage: nil, estimatedCost: nil, latency: latency, modelName: JudgmentModel.displayName)
    )
  }
}

extension JudgmentOutcome {
  /// A fail-closed outcome for one candidate: never admitted, carrying the recorded
  /// error, kept in the batch so no ContentPiece silently disappears (JUDGMENT-CONTRACT §3).
  static func failed(contentPieceID: UUID, error: String) -> Self {
    .init(
      contentPieceID: contentPieceID, admit: false, isSubstantivePrimary: nil, section: nil,
      rank: nil, rationale: nil, matchedPersonalKnowledgeClaimID: nil,
      subjects: nil, summary: nil, bodyCompleteness: nil, finds: nil,
      classificationErrorDescription: error, errorDescription: error
    )
  }
}
