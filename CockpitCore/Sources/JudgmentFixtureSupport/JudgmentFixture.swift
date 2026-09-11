import Foundation

/// The frozen, judgment-visible projection of one historical ContentPiece.
/// This test/tool-only type deliberately lives outside CockpitCore so harvested material is never
/// on the shipping app's ingestion path.
public struct JudgmentFixture: Codable, Equatable, Sendable, Identifiable {
  public let id: UUID
  public let kind: String
  public let title: String
  public let creator: String?
  public let publisher: String
  public let publishedAt: Date?
  public let normalizedText: String
  public let stream: StreamContext
  public let interestArea: InterestAreaContext
  public let carriedEntry: CarriedEntryContext?

  public init(
    id: UUID,
    kind: String,
    title: String,
    creator: String? = nil,
    publisher: String,
    publishedAt: Date? = nil,
    normalizedText: String,
    stream: StreamContext,
    interestArea: InterestAreaContext,
    carriedEntry: CarriedEntryContext? = nil
  ) {
    self.id = id
    self.kind = kind
    self.title = title
    self.creator = creator
    self.publisher = publisher
    self.publishedAt = publishedAt
    self.normalizedText = normalizedText
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

public enum JudgmentLabel: String, Codable, CaseIterable, Sendable {
  case surface
  case quiet
  case never
}

/// A behavioral hint used solely to prioritize human review. It is never part of JudgmentFixture
/// and therefore cannot reach a future judgment prompt or Personal Knowledge write.
public enum DispositionPrior: String, Codable, Sendable {
  case surface
  case quiet
  case never
  case uncertain
}

/// Current Gmail state recorded with the label-side evidence, never in a JudgmentFixture.
public enum GmailDisposition: String, Codable, Sendable {
  case inbox
  case archived
  case trashed
}

public enum GmailReadState: String, Codable, Sendable {
  case read
  case unread
}

public struct JudgmentFixtureLabel: Codable, Equatable, Sendable, Identifiable {
  public let id: UUID
  public var label: JudgmentLabel?
  public var isSubstantivePrimary: Bool?
  public let dispositionPrior: DispositionPrior
  public let gmailDisposition: GmailDisposition?
  public let gmailReadState: GmailReadState?

  public init(
    id: UUID,
    label: JudgmentLabel? = nil,
    isSubstantivePrimary: Bool? = nil,
    dispositionPrior: DispositionPrior,
    gmailDisposition: GmailDisposition? = nil,
    gmailReadState: GmailReadState? = nil
  ) {
    self.id = id
    self.label = label
    self.isSubstantivePrimary = isSubstantivePrimary
    self.dispositionPrior = dispositionPrior
    self.gmailDisposition = gmailDisposition
    self.gmailReadState = gmailReadState
  }
}

public struct JudgmentFixtureExport: Codable, Equatable, Sendable {
  public let fixtures: [JudgmentFixture]

  public init(fixtures: [JudgmentFixture]) {
    self.fixtures = fixtures.sorted { $0.id.uuidString < $1.id.uuidString }
  }
}

public struct JudgmentLabelExport: Codable, Equatable, Sendable {
  public let labels: [JudgmentFixtureLabel]

  public init(labels: [JudgmentFixtureLabel]) {
    self.labels = labels.sorted { $0.id.uuidString < $1.id.uuidString }
  }
}
