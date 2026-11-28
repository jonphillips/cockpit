import Foundation
import Testing
import OfferWatchSupport

@Suite("Offer Watch watched senders")
struct OfferWatchTests {
  @Test("Gmail search hits require an exact sender address")
  func exactSender() {
    #expect(OfferWatchState.exactSender("Dinner Club <offers@example.com>", equals: "offers@example.com"))
    #expect(!OfferWatchState.exactSender("Dinner Club <spoof@example.com>", equals: "offers@example.com"))
    #expect(!OfferWatchState.exactSender("offers@example.com.attacker.test", equals: "offers@example.com"))
  }

  @Test("Only DKIM or SPF pass authenticates a watched message")
  func authentication() {
    #expect(OfferWatchState.authenticationPassed("mx.google; dkim=pass header.d=example.com; spf=fail"))
    #expect(OfferWatchState.authenticationPassed("mx.google; dkim=fail; spf=pass smtp.mailfrom=example.com"))
    #expect(!OfferWatchState.authenticationPassed("mx.google; dkim=fail; spf=fail"))
    #expect(!OfferWatchState.authenticationPassed(nil))
  }

  @Test("A newly added sender begins at its first-seen time and old ledger rows expire")
  func senderBaselineAndRetention() {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    var state = OfferWatchState(now: start)
    state.reconcile(addresses: ["first@example.com"], now: start)
    state.reconcile(addresses: ["first@example.com", "second@example.com"], now: start.addingTimeInterval(30))
    #expect(state.senders["first@example.com"] == start)
    #expect(state.senders["second@example.com"] == start.addingTimeInterval(30))
    state.ledger = [.init(messageID: "old", recordedAt: start, outcome: .sent)]
    state.reconcile(addresses: ["first@example.com", "second@example.com"], now: start.addingTimeInterval(OfferWatchState.retention + 1))
    #expect(state.ledger.isEmpty)
  }
}

import CryptoKit
import CockpitCore

extension OfferWatchTests {
  @Test("The sixth and later sends become passive after the five-alert cap")
  func capBecomesPassive() async throws {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    var state = OfferWatchState(now: start)
    state.senders["dinner@example.com"] = start
    state.pairings = [OfferWatchPairing(id: "phone", name: "Phone", token: "synthetic", environment: .sandbox)]
    let messages = (0..<7).map { index in
      WatchedMail(id: "m\(index)", from: "Dinner <dinner@example.com>", subject: "Dinner \(index)", authenticationResults: "dkim=pass")
    }
    let processor = OfferWatchProcessor(
      fetch: { _, _ in messages },
      send: { _, _, _ in APNsDelivery(statusCode: 200) })
    try await processor.poll(state: &state, now: start)
    #expect(state.ledger.filter { $0.outcome == .sent }.count == 5)
    #expect(state.ledger.filter { $0.outcome == .passive }.count == 2)
  }

  @Test("Authentication failures are logged and rereading a message does not send again")
  func failedAuthAndDeduplication() async throws {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    var state = OfferWatchState(now: start)
    state.senders["dinner@example.com"] = start
    state.pairings = [OfferWatchPairing(id: "phone", name: "Phone", token: "synthetic", environment: .sandbox)]
    let messages = [
      WatchedMail(id: "bad", from: "Dinner <dinner@example.com>", subject: "Bad", authenticationResults: "spf=fail; dkim=fail"),
      WatchedMail(id: "good", from: "Dinner <dinner@example.com>", subject: "Good", authenticationResults: "spf=pass")
    ]
    let processor = OfferWatchProcessor(fetch: { _, _ in messages }, send: { _, _, _ in APNsDelivery(statusCode: 200) })
    try await processor.poll(state: &state, now: start)
    try await processor.poll(state: &state, now: start.addingTimeInterval(120))
    #expect(state.ledger.filter { $0.outcome == .rejectedAuthentication }.count == 1)
    #expect(state.ledger.filter { $0.outcome == .sent }.count == 1)
  }

  @Test("A rejected token is removed and reported through the remaining pairing")
  func deadToken() async throws {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    var state = OfferWatchState(now: start)
    state.senders["dinner@example.com"] = start
    let dead = OfferWatchPairing(id: "old", name: "Old phone", token: "dead", environment: .production)
    let live = OfferWatchPairing(id: "new", name: "New phone", token: "live", environment: .sandbox)
    state.pairings = [dead, live]
    let message = WatchedMail(id: "m1", from: "dinner@example.com", subject: "Dinner", authenticationResults: "dkim=pass")
    let processor = OfferWatchProcessor(
      fetch: { _, _ in [message] },
      send: { _, pairing, _ in
        if pairing.id == "old" { return APNsDelivery(statusCode: 410) }
        return APNsDelivery(statusCode: 200)
      })
    try await processor.poll(state: &state, now: start)
    #expect(state.pairings == [live])
  }

  @Test("Heartbeat is passive, uses a stable collapse ID, and is sent once per day")
  func heartbeat() async {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    var state = OfferWatchState(now: start)
    state.pairings = [OfferWatchPairing(id: "phone", name: "Phone", token: "synthetic", environment: .sandbox)]
    let processor = OfferWatchProcessor(fetch: { _, _ in [] }, send: { alert, _, passive in
      #expect(alert.collapseID == "offer-watch-heartbeat")
      #expect(alert.sourceID == nil)
      #expect(passive)
      return APNsDelivery(statusCode: 200)
    })
    await processor.sendHeartbeat(state: &state, now: start, screened: 4, alerts: 1)
    let sentAt = state.lastHeartbeatAt
    await processor.sendHeartbeat(state: &state, now: start.addingTimeInterval(60), screened: 6, alerts: 2)
    #expect(state.lastHeartbeatAt == sentAt)
  }

  @Test("An unreadable iCloud list uses the last-good local copy")
  func listFallback() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: root) }
    let local = root.appending(path: "support", directoryHint: .isDirectory)
    let cloud = root.appending(path: "cloud", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: local, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: cloud.appending(path: "watched.txt", directoryHint: .isDirectory), withIntermediateDirectories: true)
    try Data("chef@example.com\n".utf8).write(to: local.appending(path: "watched.txt"))
    var store = OfferWatchStore(directory: local, cloudFolder: cloud)
    #expect(try store.watchedAddresses() == ["chef@example.com"])
    #expect(store.didUseLastGoodCopy)
  }

  @Test("The payload is compact and uses the selected interruption level")
  func alertPayload() throws {
    let alert = OfferWatchAlert(title: "Dinner Club", body: "Reservations are open", sourceID: "message-1")
    let data = try APNsAlertSender.payload(alert: alert, passive: true)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let aps = try #require(object["aps"] as? [String: Any])
    #expect(aps["interruption-level"] as? String == "passive")
    #expect(object["source"] as? String == "message-1")
    #expect(data.count < 4096)
  }

  @Test("APNs JWTs are reused inside the 20-minute window and rotated at its boundary")
  func jwtReuse() async throws {
    let key = P256.Signing.PrivateKey()
    let provider = APNsJWTProvider(keyID: "KEY123", teamID: "TEAM123", pem: key.pemRepresentation)
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let first = try await provider.token(now: start)
    let reused = try await provider.token(now: start.addingTimeInterval(19 * 60))
    let rotated = try await provider.token(now: start.addingTimeInterval(20 * 60))
    #expect(first == reused)
    #expect(first != rotated)
    #expect(first.split(separator: ".").count == 3)
  }

  @Test("Notification permission is requested only by the explicit enable action")
  @MainActor
  func permissionOptIn() async {
    let model = OfferAlertsModel(environment: "sandbox")
    #expect(model.registration == .notRequested)
    await model.enableTapped(
      requestPermission: { false },
      registerForRemoteNotifications: {})
    #expect(model.registration == .denied)
  }
}
