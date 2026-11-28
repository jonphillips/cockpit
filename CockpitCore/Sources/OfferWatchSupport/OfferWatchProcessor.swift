import CockpitCore
import Foundation

public struct WatchedMail: Sendable {
  public let id: String
  public let from: String?
  public let subject: String
  public let authenticationResults: String?
  public init(id: String, from: String?, subject: String, authenticationResults: String?) {
    self.id = id; self.from = from; self.subject = subject; self.authenticationResults = authenticationResults
  }
}

public struct OfferWatchProcessor: Sendable {
  public var fetch: @Sendable (String, Date) async throws -> [WatchedMail]
  public var send: @Sendable (OfferWatchAlert, OfferWatchPairing, Bool) async throws -> APNsDelivery
  public init(fetch: @escaping @Sendable (String, Date) async throws -> [WatchedMail], send: @escaping @Sendable (OfferWatchAlert, OfferWatchPairing, Bool) async throws -> APNsDelivery) {
    self.fetch = fetch; self.send = send
  }

  public func poll(state: inout OfferWatchState, now: Date) async throws {
    let dayStart = Calendar(identifier: .gregorian).startOfDay(for: now)
    var sendsToday = state.ledger.filter { ($0.outcome == .sent || $0.outcome == .passive) && $0.recordedAt >= dayStart }.count
    var knownIDs = Set(state.ledger.map(\.messageID))
    var deadPairingIDs = Set<String>()
    for (address, addedAt) in state.senders.sorted(by: { $0.key < $1.key }) {
      let messages = try await fetch(address, max(addedAt, state.startedAt))
      for message in messages {
        guard !knownIDs.contains(message.id) else { continue }
        guard OfferWatchState.exactSender(message.from ?? "", equals: address) else {
          state.ledger.append(.init(messageID: message.id, recordedAt: now, outcome: .rejectedAddress))
          knownIDs.insert(message.id)
          continue
        }
        guard OfferWatchState.authenticationPassed(message.authenticationResults) else {
          state.ledger.append(.init(messageID: message.id, recordedAt: now, outcome: .rejectedAuthentication))
          knownIDs.insert(message.id)
          continue
        }
        let passive = sendsToday >= OfferWatchState.dailyInterruptingCap
        let alert = OfferWatchAlert(title: address, body: message.subject, sourceID: message.id)
        var didSend = false
        for pairing in state.pairings where !deadPairingIDs.contains(pairing.id) {
          let result = try await send(alert, pairing, passive)
          if result.isDeadToken { deadPairingIDs.insert(pairing.id) }
          else if result.accepted { didSend = true }
        }
        if didSend {
          state.ledger.append(.init(messageID: message.id, recordedAt: now, outcome: passive ? .passive : .sent))
          knownIDs.insert(message.id)
          sendsToday += 1
        }
      }
    }
    if !deadPairingIDs.isEmpty {
      state.pairings.removeAll { deadPairingIDs.contains($0.id) }
      let report = OfferWatchAlert(
        title: "Offer Watch", body: "A paired device token was rejected. Pair that device again.", collapseID: "offer-watch-status")
      for pairing in state.pairings {
        _ = try? await send(report, pairing, true)
      }
    }
  }

  public func sendHeartbeat(state: inout OfferWatchState, now: Date, screened: Int, alerts: Int) async {
    if let previous = state.lastHeartbeatAt,
      Calendar.current.isDate(previous, inSameDayAs: now) { return }
    let alert = OfferWatchAlert(
      title: "Offer Watch",
      body: "Checked \(now.formatted(date: .omitted, time: .shortened)), \(screened) screened, \(alerts) alerts.",
      collapseID: "offer-watch-heartbeat")
    var delivered = false
    for pairing in state.pairings {
      if let result = try? await send(alert, pairing, true), result.accepted { delivered = true }
    }
    if delivered { state.lastHeartbeatAt = now }
  }
}
