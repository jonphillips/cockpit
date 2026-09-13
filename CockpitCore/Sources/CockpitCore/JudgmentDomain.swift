import Foundation
import LLMClientKit

/// Cockpit's fixed model choice for the first judgment pass. This is configuration at the
/// `ModelClient` construction boundary, rather than an axis on each `ModelRequest`.
public enum JudgmentModel {
  public static let modelID = "claude-sonnet-5"
  public static let displayName = "Claude Sonnet 5"

  public static func makeClient() -> any ModelClient {
    TieredModelClient.live(modelForProvider: { provider in
      switch provider {
      case .anthropic: modelID
      case .openai: provider.defaultModel
      }
    })
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
  public let stream: StreamContext
  public let interestArea: InterestAreaContext
  public let carriedEntry: CarriedEntryContext?

  public init(
    id: UUID, kind: String, title: String, creator: String? = nil, publisher: String,
    publishedAt: Date? = nil, canonicalURL: String? = nil, normalizedText: String,
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

/// A proposed judgment. It is not a persistence command: S3 performs canonical Edition and
/// ContentPiece writes, and S5 decides whether to persist its `finds`.
public struct JudgmentOutcome: Equatable, Sendable, Identifiable {
  public let contentPieceID: UUID
  public let admit: Bool
  public let isSubstantivePrimary: Bool?
  public let section: JudgmentSection?
  public let rank: Int?
  public let rationale: String?
  public let subjects: [String]?
  public let summary: String?
  public let finds: [JudgmentFind]?
  /// A decode or response-contract error. Such an outcome is always fail-closed (`admit == false`)
  /// and remains in the batch so no ContentPiece silently disappears.
  public let errorDescription: String?

  public var id: UUID { contentPieceID }

  public init(
    contentPieceID: UUID, admit: Bool, isSubstantivePrimary: Bool?, section: JudgmentSection?,
    rank: Int?, rationale: String?, subjects: [String]?, summary: String?, finds: [JudgmentFind]?,
    errorDescription: String? = nil
  ) {
    self.contentPieceID = contentPieceID
    self.admit = admit
    self.isSubstantivePrimary = isSubstantivePrimary
    self.section = section
    self.rank = rank
    self.rationale = rationale
    self.subjects = subjects
    self.summary = summary
    self.finds = finds
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
}

extension JudgmentRun {
  static let empty = JudgmentRun(
    outcomes: [], usage: nil, estimatedCost: 0, latency: 0,
    requestedProvider: .anthropic, modelName: JudgmentModel.displayName
  )

  static func failed(candidates: [JudgmentCandidate], error: String, latency: TimeInterval) -> Self {
    .init(
      outcomes: candidates.map { .failed(contentPieceID: $0.id, error: error) },
      usage: nil, estimatedCost: nil, latency: latency,
      requestedProvider: .anthropic, modelName: JudgmentModel.displayName
    )
  }
}

extension JudgmentOutcome {
  /// A fail-closed outcome for one candidate: never admitted, carrying the recorded
  /// error, kept in the batch so no ContentPiece silently disappears (JUDGMENT-CONTRACT §3).
  static func failed(contentPieceID: UUID, error: String) -> Self {
    .init(
      contentPieceID: contentPieceID, admit: false, isSubstantivePrimary: nil, section: nil,
      rank: nil, rationale: nil, subjects: nil, summary: nil, finds: nil, errorDescription: error
    )
  }
}
