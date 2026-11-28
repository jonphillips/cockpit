import CockpitCore
import Foundation

public struct WatchedMail: Sendable, Equatable {
  public let id: String
  public let from: String?
  public let subject: String
  public let authenticationResults: String?
  public let internalDate: Date?

  public init(
    id: String, from: String?, subject: String,
    authenticationResults: String?, internalDate: Date?
  ) {
    self.id = id
    self.from = from
    self.subject = subject
    self.authenticationResults = authenticationResults
    self.internalDate = internalDate
  }
}

public struct OfferWatchProcessor: Sendable {
  public var listIDs: @Sendable (String, Date) async throws -> [String]
  public var fetchMessage: @Sendable (String) async throws -> WatchedMail
  public var send: @Sendable (OfferWatchAlert, OfferWatchPairing, Bool) async throws -> APNsDelivery
  public var log: @Sendable (String) -> Void

  public init(
    listIDs: @escaping @Sendable (String, Date) async throws -> [String],
    fetchMessage: @escaping @Sendable (String) async throws -> WatchedMail,
    send: @escaping @Sendable (OfferWatchAlert, OfferWatchPairing, Bool) async throws -> APNsDelivery,
    log: @escaping @Sendable (String) -> Void = { _ in }
  ) {
    self.listIDs = listIDs
    self.fetchMessage = fetchMessage
    self.send = send
    self.log = log
  }

  /// Lists are bounded to the recent window, then known IDs are excluded before any full message read.
  public func poll(
    state: inout OfferWatchState,
    pairings: [OfferWatchPairing],
    now: Date,
    calendar: Calendar = .current
  ) async throws -> Set<String> {
    let dayStart = calendar.startOfDay(for: now)
    var sendsToday = state.ledger.filter {
      ($0.outcome == .sent || $0.outcome == .passive) && $0.recordedAt >= dayStart
    }.count
    var knownIDs = Set(state.ledger.map(\.messageID))
    var deadPairingIDs = Set<String>()

    for (address, firstSeenAt) in state.senders.sorted(by: { $0.key < $1.key }) {
      let recentWindowStart = now.addingTimeInterval(-Self.lookbackWindow)
      let cutoff = max(firstSeenAt, recentWindowStart)
      let ids = try await listIDs(address, cutoff)
      for id in ids where !knownIDs.contains(id) {
        let message = try await fetchMessage(id)
        guard let internalDate = message.internalDate, internalDate >= cutoff else {
          knownIDs.insert(message.id)
          state.ledger.append(.init(messageID: message.id, recordedAt: now, outcome: .stale))
          continue
        }
        knownIDs.insert(message.id)
        guard OfferWatchState.exactSender(message.from ?? "", equals: address) else {
          state.ledger.append(.init(messageID: message.id, recordedAt: now, outcome: .rejectedAddress))
          continue
        }
        guard OfferWatchState.authenticationPassed(message.authenticationResults, from: message.from) else {
          state.ledger.append(.init(messageID: message.id, recordedAt: now, outcome: .rejectedAuthentication))
          continue
        }

        let passive = sendsToday >= OfferWatchState.dailyInterruptingCap
        let alert = OfferWatchPayload.alert(from: message.from, subject: message.subject, messageID: message.id)
        var didSend = false
        for pairing in pairings where !deadPairingIDs.contains(pairing.id) {
          let result = try await send(alert, pairing, passive)
          if result.isDeadToken { deadPairingIDs.insert(pairing.id) }
          else if result.accepted { didSend = true }
        }
        let outcome: OfferWatchLedgerEntry.Outcome = if didSend {
          passive ? .passive : .sent
        } else {
          .undeliverable
        }
        state.ledger.append(.init(messageID: message.id, recordedAt: now, outcome: outcome))
        if didSend { sendsToday += 1 }
        else { log("Offer Watch could not deliver message \(message.id): no active pairing.") }
      }
    }

    if !deadPairingIDs.isEmpty {
      let deadNames = pairings.filter { deadPairingIDs.contains($0.id) }.map(\.name)
      let remaining = pairings.filter { !deadPairingIDs.contains($0.id) }
      let report = OfferWatchAlert(
        title: "Offer Watch", body: "A paired device token was rejected. Pair that device again.",
        collapseID: "offer-watch-status")
      for pairing in remaining { _ = try? await send(report, pairing, true) }
      if remaining.isEmpty { log("Offer Watch removed dead pairing(s): \(deadNames.formatted()).") }
    }
    return deadPairingIDs
  }

  public func sendHeartbeat(
    state: inout OfferWatchState,
    pairings: [OfferWatchPairing],
    now: Date,
    calendar: Calendar
  ) async {
    let alreadySentToday = state.lastHeartbeatAt.map { calendar.isDate($0, inSameDayAs: now) } ?? false
    guard calendar.component(.hour, from: now) >= 8, !alreadySentToday else { return }
    let since = now.addingTimeInterval(-24 * 60 * 60)
    let recent = state.ledger.filter { $0.recordedAt >= since }
    let screened = recent.count
    let alerts = recent.filter { $0.outcome == .sent || $0.outcome == .passive }.count
    var timeFormat = Date.FormatStyle.dateTime.hour().minute()
    timeFormat.calendar = calendar
    let checkedAt = now.formatted(timeFormat)
    let alert = OfferWatchPayload.status(
      title: "Offer Watch",
      body: "Offer watch: checked \(checkedAt), \(screened) screened, \(alerts) alerts.",
      collapseID: "offer-watch-heartbeat")
    var delivered = false
    for pairing in pairings {
      if let result = try? await send(alert, pairing, true), result.accepted { delivered = true }
    }
    if delivered { state.lastHeartbeatAt = now }
  }

  public static let lookbackWindow: TimeInterval = 7 * 24 * 60 * 60
}

public enum OfferWatchPayload {
  public static let maximumTitleCharacters = 60
  public static let maximumBodyCharacters = 120

  public static func alert(from header: String?, subject: String, messageID: String) -> OfferWatchAlert {
    let senderAddress = OfferWatchState.address(from: header) ?? "Unknown sender"
    let senderName = header.flatMap(OfferWatchState.displayName(from:))
    return OfferWatchAlert(
      title: sanitized(senderName ?? senderAddress, maximumCharacters: maximumTitleCharacters),
      body: sanitized(subject, maximumCharacters: maximumBodyCharacters),
      sourceID: messageID)
  }

  public static func status(title: String, body: String, collapseID: String) -> OfferWatchAlert {
    OfferWatchAlert(
      title: sanitized(title, maximumCharacters: maximumTitleCharacters),
      body: sanitized(body, maximumCharacters: maximumBodyCharacters), collapseID: collapseID)
  }

  private static func sanitized(_ value: String, maximumCharacters: Int) -> String {
    let noURLs = value.replacingOccurrences(
      of: "https?://\\S+|www\\.\\S+", with: "", options: .regularExpression)
    let oneLine = noURLs.split(whereSeparator: \.isNewline).joined(separator: " ")
    return String(oneLine.prefix(maximumCharacters)).trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
