import Foundation

public struct FindReferralProvenance: Codable, Equatable, Sendable {
  public var sender: String?
  public var publisher: String?
  public var arrivalDate: Date?
  public var seriesID: String?
  public var contentPieceToken: String?
  public var note: String?
  public var hints: [String: String]

  public init(
    sender: String?, publisher: String?, arrivalDate: Date?, seriesID: String?,
    contentPieceToken: String?, note: String?, hints: [String: String] = [:]
  ) {
    self.sender = sender
    self.publisher = publisher
    self.arrivalDate = arrivalDate
    self.seriesID = seriesID
    self.contentPieceToken = contentPieceToken
    self.note = note
    self.hints = hints
  }

  private enum CodingKeys: String, CodingKey {
    case sender, publisher, arrivalDate, seriesID, contentPieceToken, note, hints
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    sender = try container.decodeIfPresent(String.self, forKey: .sender)
    publisher = try container.decodeIfPresent(String.self, forKey: .publisher)
    if let value = try container.decodeIfPresent(String.self, forKey: .arrivalDate) {
      arrivalDate = try Self.dateFormatter.date(from: value).unwrap(or: DecodingError.dataCorruptedError(
        forKey: .arrivalDate, in: container, debugDescription: "Expected an ISO-8601 date."
      ))
    } else {
      arrivalDate = nil
    }
    seriesID = try container.decodeIfPresent(String.self, forKey: .seriesID)
    contentPieceToken = try container.decodeIfPresent(String.self, forKey: .contentPieceToken)
    note = try container.decodeIfPresent(String.self, forKey: .note)
    hints = try container.decodeIfPresent([String: String].self, forKey: .hints) ?? [:]
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(sender, forKey: .sender)
    try container.encodeIfPresent(publisher, forKey: .publisher)
    if let arrivalDate { try container.encode(Self.dateFormatter.string(from: arrivalDate), forKey: .arrivalDate) }
    try container.encodeIfPresent(seriesID, forKey: .seriesID)
    try container.encodeIfPresent(contentPieceToken, forKey: .contentPieceToken)
    try container.encodeIfPresent(note, forKey: .note)
    try container.encode(hints, forKey: .hints)
  }

  fileprivate static var dateFormatter: ISO8601DateFormatter {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }
}

public struct FindReferralMessage: Codable, Equatable, Sendable {
  public var version: Int
  public var referralID: UUID
  public var rawText: String
  public var provenance: FindReferralProvenance

  public init(version: Int = 1, referralID: UUID, rawText: String, provenance: FindReferralProvenance) {
    self.version = version
    self.referralID = referralID
    self.rawText = rawText
    self.provenance = provenance
  }

  public static func make(
    referralID: UUID, find: PendingFind, readerRow: ContentPieceReaderRequest.Row,
    gmailProvenance: GmailArtifactProvenance?
  ) throws -> Self {
    guard RecipeCandidateKind.matches(find.kind) else {
      throw FindReferralHandoffError.readableBodyUnavailable
    }
    guard readerRow.bodyCompleteness != .teaser else {
      throw FindReferralHandoffError.readableBodyUnavailable
    }
    guard let rawText = readerRow.localNormalizedText, !rawText.isEmpty else {
      throw FindReferralHandoffError.readableBodyUnavailable
    }
    var hints = find.hints.flatMap {
      try? JSONDecoder().decode([String: String].self, from: Data($0.utf8))
    } ?? [:]
    if let sourceURL = find.sourceURL { hints["sourceURL"] = sourceURL }
    return Self(
      referralID: referralID, rawText: rawText,
      provenance: FindReferralProvenance(
        sender: readerRow.sender, publisher: readerRow.publisher, arrivalDate: readerRow.receivedAt,
        seriesID: gmailProvenance?.listID, contentPieceToken: readerRow.id.uuidString.lowercased(),
        note: find.rationale, hints: hints
      )
    )
  }

  private enum CodingKeys: String, CodingKey { case version, referralID, rawText, provenance }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    version = try container.decode(Int.self, forKey: .version)
    guard version == 1 else {
      throw DecodingError.dataCorruptedError(
        forKey: .version, in: container, debugDescription: "Unsupported Find referral version."
      )
    }
    referralID = try UUID(uuidString: container.decode(String.self, forKey: .referralID))
      .unwrap(or: DecodingError.dataCorruptedError(
        forKey: .referralID, in: container, debugDescription: "Expected a UUID string."
      ))
    rawText = try container.decode(String.self, forKey: .rawText)
    provenance = try container.decode(FindReferralProvenance.self, forKey: .provenance)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(version, forKey: .version)
    try container.encode(referralID.uuidString.lowercased(), forKey: .referralID)
    try container.encode(rawText, forKey: .rawText)
    try container.encode(provenance, forKey: .provenance)
  }
}

public enum FindReferralOutcome: Equatable, Sendable {
  case admitted(recipeRef: String)
  case declined(reason: FindDeclineReason, detail: String? = nil)
}

public enum FindDeclineReason: String, Codable, Equatable, Sendable {
  case noRecipeFound
  case duplicate
  case dismissed
  case extractionFailed
}

extension FindReferralOutcome: Codable {
  private enum CodingKeys: String, CodingKey { case kind, recipeRef, reason, detail }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(String.self, forKey: .kind) {
    case "admitted": self = .admitted(recipeRef: try container.decode(String.self, forKey: .recipeRef))
    case "declined":
      let reason = try container.decode(FindDeclineReason.self, forKey: .reason)
      let detail = try container.decodeIfPresent(String.self, forKey: .detail)
      guard reason == .extractionFailed || detail == nil else {
        throw DecodingError.dataCorruptedError(
          forKey: .detail, in: container, debugDescription: "Only extraction failures include detail."
        )
      }
      self = .declined(
        reason: reason, detail: detail
      )
    case let kind:
      throw DecodingError.dataCorruptedError(
        forKey: .kind, in: container, debugDescription: "Unknown outcome kind: \(kind)."
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case let .admitted(recipeRef):
      try container.encode("admitted", forKey: .kind)
      try container.encode(recipeRef, forKey: .recipeRef)
    case let .declined(reason, detail):
      try container.encode("declined", forKey: .kind)
      try container.encode(reason, forKey: .reason)
      if reason == .extractionFailed { try container.encodeIfPresent(detail, forKey: .detail) }
    }
  }
}

public struct FindVerdictMessage: Codable, Equatable, Sendable {
  public var version: Int
  public var referralID: UUID
  public var outcomes: [FindReferralOutcome]

  public init(version: Int = 1, referralID: UUID, outcomes: [FindReferralOutcome]) {
    self.version = version
    self.referralID = referralID
    self.outcomes = outcomes
  }

  private enum CodingKeys: String, CodingKey { case version, referralID, outcomes }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    version = try container.decode(Int.self, forKey: .version)
    guard version == 1 else {
      throw DecodingError.dataCorruptedError(
        forKey: .version, in: container, debugDescription: "Unsupported Find verdict version."
      )
    }
    referralID = try UUID(uuidString: container.decode(String.self, forKey: .referralID))
      .unwrap(or: DecodingError.dataCorruptedError(
        forKey: .referralID, in: container, debugDescription: "Expected a UUID string."
      ))
    outcomes = try container.decode([FindReferralOutcome].self, forKey: .outcomes)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(version, forKey: .version)
    try container.encode(referralID.uuidString.lowercased(), forKey: .referralID)
    try container.encode(outcomes, forKey: .outcomes)
  }
}


private extension Optional {
  func unwrap(or error: @autoclosure () -> Error) throws -> Wrapped {
    guard let self else { throw error() }
    return self
  }
}
