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
  public enum Outcome: String, Codable, Sendable { case sent, passive, rejectedAddress, rejectedAuthentication, duplicate }
  public init(messageID: String, recordedAt: Date, outcome: Outcome) {
    self.messageID = messageID; self.recordedAt = recordedAt; self.outcome = outcome
  }
}

public struct OfferWatchState: Codable, Sendable {
  public var startedAt: Date
  public var baselineEstablished: Bool
  public var accountID: String?
  public var lastHeartbeatAt: Date?
  public var lastStatusAt: Date?
  public var senders: [String: Date]
  public var pairings: [OfferWatchPairing]
  public var ledger: [OfferWatchLedgerEntry]

  public init(now: Date) { startedAt = now; baselineEstablished = false; accountID = nil; lastHeartbeatAt = nil; lastStatusAt = nil; senders = [:]; pairings = []; ledger = [] }

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
    guard let left = fromHeader.lastIndex(of: "<"), let right = fromHeader[left...].firstIndex(of: ">"), left < right else {
      return fromHeader.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == address.lowercased()
    }
    return fromHeader[fromHeader.index(after: left)..<right].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == address.lowercased()
  }

  public static func authenticationPassed(_ value: String?) -> Bool {
    guard let value else { return false }
    let lower = value.lowercased()
    return lower.split(whereSeparator: { $0 == ";" || $0 == " " }).contains { $0 == "dkim=pass" || $0 == "spf=pass" }
  }

  public static let dailyInterruptingCap = 5
  public static let retention: TimeInterval = 90 * 24 * 60 * 60
}
