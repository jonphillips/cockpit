import Foundation

public struct OfferWatchPairing: Codable, Equatable, Sendable, Identifiable {
  public let id: String
  public let name: String
  public let token: String
  public let environment: Environment
  public init(id: String, name: String, token: String, environment: Environment) {
    self.id = id; self.name = name; self.token = token; self.environment = environment
  }
  public enum Environment: String, Codable, Sendable { case production, sandbox }
}

public struct OfferWatchLedgerEntry: Codable, Equatable, Sendable {
  public let messageID: String
  public let recordedAt: Date
  public let outcome: Outcome
  public enum Outcome: String, Codable, Sendable {
    case sent, passive, rejectedAddress, rejectedAuthentication, undeliverable, stale

    public init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      let value = try container.decode(String.self)
      if value == "duplicate" { self = .stale; return }
      guard let outcome = Outcome(rawValue: value) else {
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown Offer Watch ledger outcome: \(value)")
      }
      self = outcome
    }
  }
  public init(messageID: String, recordedAt: Date, outcome: Outcome) {
    self.messageID = messageID; self.recordedAt = recordedAt; self.outcome = outcome
  }
}

public struct OfferWatchState: Codable, Sendable {
  public var startedAt: Date
  public var baselineEstablished: Bool
  public var accountID: String?
  public var lastHeartbeatAt: Date?
  public var lastStatusAt: [String: Date]
  public var senders: [String: Date]
  public var ledger: [OfferWatchLedgerEntry]

  public init(now: Date) {
    startedAt = now
    baselineEstablished = false
    accountID = nil
    lastHeartbeatAt = nil
    lastStatusAt = [:]
    senders = [:]
    ledger = []
  }

  private enum CodingKeys: String, CodingKey {
    case startedAt, baselineEstablished, accountID, lastHeartbeatAt, lastStatusAt, senders, ledger
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    startedAt = try container.decode(Date.self, forKey: .startedAt)
    baselineEstablished = try container.decodeIfPresent(Bool.self, forKey: .baselineEstablished) ?? false
    accountID = try container.decodeIfPresent(String.self, forKey: .accountID)
    lastHeartbeatAt = try container.decodeIfPresent(Date.self, forKey: .lastHeartbeatAt)
    senders = try container.decodeIfPresent([String: Date].self, forKey: .senders) ?? [:]
    ledger = try container.decodeIfPresent([OfferWatchLedgerEntry].self, forKey: .ledger) ?? []
    if let statuses = try? container.decode([String: Date].self, forKey: .lastStatusAt) {
      lastStatusAt = statuses
    } else if let legacyDate = try? container.decode(Date.self, forKey: .lastStatusAt) {
      lastStatusAt = Dictionary(uniqueKeysWithValues: [
        "revokedGrant", "rejectedToken", "accountChanged", "missingConfiguration",
        "unreadableList", "unreadableState",
      ].map { ($0, legacyDate) })
    } else {
      lastStatusAt = [:]
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(startedAt, forKey: .startedAt)
    try container.encode(baselineEstablished, forKey: .baselineEstablished)
    try container.encodeIfPresent(accountID, forKey: .accountID)
    try container.encodeIfPresent(lastHeartbeatAt, forKey: .lastHeartbeatAt)
    try container.encode(lastStatusAt, forKey: .lastStatusAt)
    try container.encode(senders, forKey: .senders)
    try container.encode(ledger, forKey: .ledger)
  }

  public mutating func establishBaseline(at date: Date) {
    guard !baselineEstablished else { return }
    startedAt = date
    baselineEstablished = true
  }

  public mutating func reconcile(addresses: [String], now: Date) {
    let wanted = Set(addresses.map { $0.lowercased() })
    for address in wanted where senders[address] == nil { senders[address] = now }
    senders = senders.filter { wanted.contains($0.key) }
    ledger.removeAll { now.timeIntervalSince($0.recordedAt) > Self.retention }
  }

  /// Gmail's `from:` is a search hint only. The fetched header must contain the exact address.
  public static func exactSender(_ fromHeader: String, equals address: String) -> Bool {
    guard let parsed = self.address(from: fromHeader) else { return false }
    return parsed.caseInsensitiveCompare(address) == .orderedSame
  }

  public static func address(from header: String?) -> String? {
    guard let header else { return nil }
    if let left = header.lastIndex(of: "<"), let right = header[left...].firstIndex(of: ">"), left < right {
      return header[header.index(after: left)..<right].trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return header.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  public static func displayName(from header: String) -> String? {
    guard let left = header.lastIndex(of: "<") else { return nil }
    let value = header[..<left].trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    return value.isEmpty ? nil : value
  }

  public static func authenticationPassed(_ value: String?, from fromHeader: String?) -> Bool {
    guard let value, let fromDomain = domain(inMailbox: address(from: fromHeader) ?? "") else { return false }
    let unfolded = value.replacingOccurrences(of: "\\r?\\n[ \\t]+", with: " ", options: .regularExpression)
    let clauses = unfolded.split(separator: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    guard clauses.first == "mx.google.com" else { return false }
    if clauses.dropFirst().contains(where: { $0.hasPrefix("dmarc=pass") }) { return true }
    for clause in clauses.dropFirst() {
      if clause.hasPrefix("dkim=pass"),
        let signer = parameter(in: clause, names: ["header.i", "header.d"]),
        let signerDomain = domain(inMailbox: signer), aligned(fromDomain, signerDomain) { return true }
      if clause.hasPrefix("spf=pass"),
        let signer = parameter(in: clause, names: ["smtp.mailfrom"]),
        let signerDomain = domain(inMailbox: signer), aligned(fromDomain, signerDomain) { return true }
    }
    return false
  }

  private static func parameter(in clause: String, names: [String]) -> String? {
    for token in clause.split(whereSeparator: \.isWhitespace) {
      for name in names where token.hasPrefix(name + "=") {
        return token.dropFirst(name.count + 1).trimmingCharacters(in: CharacterSet(charactersIn: "<>\""))
      }
    }
    return nil
  }

  private static func domain(inMailbox value: String) -> String? {
    let mailbox = value.trimmingCharacters(in: CharacterSet(charactersIn: "<>\""))
    let domain = mailbox.split(separator: "@").last.map(String.init) ?? mailbox
    let normalized = domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))
    return normalized.contains(".") ? normalized : nil
  }

  private static func aligned(_ lhs: String, _ rhs: String) -> Bool {
    lhs == rhs || lhs.hasSuffix("." + rhs) || rhs.hasSuffix("." + lhs)
  }

  public static let dailyInterruptingCap = 5
  public static let retention: TimeInterval = 90 * 24 * 60 * 60
}
