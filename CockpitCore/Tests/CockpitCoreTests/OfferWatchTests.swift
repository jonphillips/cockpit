import CockpitCore
import CryptoKit
import Foundation
import GmailDesktopAuth
@testable import OfferWatchSupport
import Testing

@Suite("Offer Watch")
struct OfferWatchTests {
  private final class LockedBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value
    init(_ value: Value) { storage = value }
    func get() -> Value { lock.lock(); defer { lock.unlock() }; return storage }
    func set(_ value: Value) { lock.lock(); defer { lock.unlock() }; storage = value }
    func update(_ body: (inout Value) -> Void) { lock.lock(); defer { lock.unlock() }; body(&storage) }
  }
  private let start = Date(timeIntervalSince1970: 1_800_000_000)
  private var phone: OfferWatchPairing {
    .init(id: "phone", name: "Phone", token: "synthetic", environment: .sandbox)
  }

  @Test("Authentication requires Google's result and an aligned passing domain")
  func authentication() {
    #expect(OfferWatchState.authenticationPassed(
      "mx.google.com; dkim=pass header.d=mail.example.com; spf=fail", from: "offers@example.com"))
    #expect(OfferWatchState.authenticationPassed(
      "mx.google.com; dmarc=pass header.from=example.com", from: "offers@example.com"))
    #expect(OfferWatchState.authenticationPassed(
      "mx.google.com; spf=pass smtp.mailfrom=sub.example.com", from: "offers@example.com"))
    #expect(!OfferWatchState.authenticationPassed(
      "mx.google.com; dkim=pass header.d=attacker.test; spf=fail", from: "offers@example.com"))
    #expect(!OfferWatchState.authenticationPassed(
      "forged.test; dkim=pass header.d=example.com", from: "offers@example.com"))
    #expect(OfferWatchState.authenticationPassed(
      "mx.google.com;\r\n\tdkim=pass header.i=@example.com", from: "offers@example.com"))
  }

  @Test("New sender old mail is rejected and known message IDs are never fetched")
  func recentWindowAndKnownIDs() async throws {
    var state = OfferWatchState(now: start)
    state.senders["offers@example.com"] = start.addingTimeInterval(-3600)
    state.ledger = [.init(messageID: "known", recordedAt: start, outcome: .sent)]
    let fetched = LockedBox<[String]>([])
    let ids = ["known", "old", "fresh"]
    let processor = OfferWatchProcessor(
      listIDs: { _, cutoff in
        #expect(cutoff == start.addingTimeInterval(-3600))
        return ids
      },
      fetchMessage: { id in
        fetched.update { $0.append(id) }
        return WatchedMail(
          id: id, from: "Club <offers@example.com>", subject: "Offer",
          authenticationResults: "mx.google.com; dkim=pass header.d=example.com",
          internalDate: id == "old" ? start.addingTimeInterval(-OfferWatchProcessor.lookbackWindow - 1) : start)
      },
      send: { _, _, _ in APNsDelivery(statusCode: 200) })
    _ = try await processor.poll(state: &state, pairings: [phone], now: start)
    #expect(fetched.get() == ["old", "fresh"])
    #expect(state.ledger.map(\.messageID) == ["known", "old", "fresh"])
    #expect(state.ledger.first(where: { $0.messageID == "old" })?.outcome == .stale)
  }

  @Test("A fresh sender baseline prevents old mail from being listed")
  func newSenderBaseline() async throws {
    let firstSeen = start.addingTimeInterval(-60)
    var state = OfferWatchState(now: start)
    state.senders["offers@example.com"] = firstSeen
    let processor = OfferWatchProcessor(
      listIDs: { _, cutoff in #expect(cutoff == firstSeen); return [] },
      fetchMessage: { _ in Issue.record("No IDs should be fetched"); throw CancellationError() },
      send: { _, _, _ in APNsDelivery(statusCode: 200) })
    _ = try await processor.poll(state: &state, pairings: [phone], now: start)
  }

  @Test("The 90-day ledger prune cannot make a 91-day-old message alert again")
  func prunedMessageDoesNotRealert() async throws {
    let now = start.addingTimeInterval(91 * 24 * 60 * 60)
    var state = OfferWatchState(now: start)
    state.senders["offers@example.com"] = start
    state.ledger = [.init(messageID: "old-mail", recordedAt: start, outcome: .sent)]
    state.reconcile(addresses: ["offers@example.com"], now: now)
    let queriedAfter = LockedBox<Date?>(nil)
    let sends = LockedBox(0)
    let processor = OfferWatchProcessor(
      listIDs: { _, cutoff in queriedAfter.set(cutoff); return ["old-mail"] },
      fetchMessage: { _ in
        WatchedMail(id: "old-mail", from: "offers@example.com", subject: "Old",
          authenticationResults: "mx.google.com; dkim=pass header.d=example.com", internalDate: start)
      },
      send: { _, _, _ in sends.update { $0 += 1 }; return APNsDelivery(statusCode: 200) })
    _ = try await processor.poll(state: &state, pairings: [phone], now: now)
    #expect(queriedAfter.get() == now.addingTimeInterval(-OfferWatchProcessor.lookbackWindow))
    #expect(sends.get() == 0)
    #expect(state.ledger.contains { $0.messageID == "old-mail" && $0.outcome == .stale })
  }

  @Test("Authentication also requires the exact sender address")
  func exactSender() {
    #expect(OfferWatchState.exactSender("Dinner Club <offers@example.com>", equals: "offers@example.com"))
    #expect(!OfferWatchState.exactSender("Dinner Club <spoof@example.com>", equals: "offers@example.com"))
  }

  @Test("Payload sanitizes URL and newlines and applies title and body caps")
  func payloadBuilder() {
    let alert = OfferWatchPayload.alert(
      from: "A Very Long Club Name That Is More Than Sixty Characters <offers@example.com>",
      subject: "Reservations https://example.com\n" + String(repeating: "x", count: 150), messageID: "abc123")
    #expect(alert.title.count <= 60)
    #expect(alert.body.count <= 120)
    #expect(!alert.body.contains("http"))
    #expect(!alert.body.contains("\n"))
    #expect(OfferWatchPayload.alert(from: "offers@example.com", subject: "Offer", messageID: "1").title == "offers@example.com")
  }

  @Test("A lone dead pairing is removed and the message is ledgered undeliverable")
  func loneDeadPairing() async throws {
    var state = OfferWatchState(now: start)
    state.senders["offers@example.com"] = start
    let reads = LockedBox(0)
    let mail = WatchedMail(
      id: "mail-1", from: "offers@example.com", subject: "Offer",
      authenticationResults: "mx.google.com; dkim=pass header.d=example.com", internalDate: start)
    let processor = OfferWatchProcessor(
      listIDs: { _, _ in ["mail-1"] },
      fetchMessage: { _ in reads.update { $0 += 1 }; return mail },
      send: { _, _, _ in APNsDelivery(statusCode: 410) })
    let removed = try await processor.poll(state: &state, pairings: [phone], now: start)
    #expect(removed == ["phone"])
    #expect(state.ledger.last?.outcome == .undeliverable)
    _ = try await processor.poll(state: &state, pairings: [], now: start.addingTimeInterval(120))
    #expect(reads.get() == 1)
  }

  @Test("Heartbeat starts after 08:00, counts the prior 24 hours and sends once per day")
  func heartbeat() async {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let day = calendar.startOfDay(for: start)
    let beforeEight = calendar.date(byAdding: .minute, value: 2, to: day)!
    var state = OfferWatchState(now: start)
    let sent = LockedBox<[OfferWatchAlert]>([])
    let processor = OfferWatchProcessor(
      listIDs: { _, _ in [] }, fetchMessage: { _ in throw CancellationError() },
      send: { alert, _, _ in sent.update { $0.append(alert) }; return APNsDelivery(statusCode: 200) })
    await processor.sendHeartbeat(state: &state, pairings: [phone], now: beforeEight, calendar: calendar)
    #expect(sent.get().isEmpty)
    let eight = calendar.date(byAdding: .minute, value: 2, to: day.addingTimeInterval(8 * 3600))!
    state.ledger = [
      .init(messageID: "a", recordedAt: eight.addingTimeInterval(-60), outcome: .sent),
      .init(messageID: "b", recordedAt: eight.addingTimeInterval(-60), outcome: .rejectedAuthentication),
      .init(messageID: "old", recordedAt: eight.addingTimeInterval(-25 * 3600), outcome: .sent),
    ]
    await processor.sendHeartbeat(state: &state, pairings: [phone], now: eight, calendar: calendar)
    #expect(sent.get().count == 1)
    #expect(sent.get()[0].body.contains("2 screened, 1 alerts"))
    await processor.sendHeartbeat(state: &state, pairings: [phone], now: eight.addingTimeInterval(60), calendar: calendar)
    #expect(sent.get().count == 1)
  }

  @Test("JWT has APNs claims and a verifiable ES256 signature")
  func jwtClaimsAndSignature() throws {
    let key = P256.Signing.PrivateKey()
    let now = start
    let token = try APNsAlertSender.jwt(keyID: "KEY123", teamID: "TEAM123", pem: key.pemRepresentation, now: now)
    let parts = token.split(separator: ".")
    #expect(parts.count == 3)
    func decode(_ part: Substring) throws -> Data {
      let value = String(part).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
      return try #require(Data(base64Encoded: value + String(repeating: "=", count: (4 - value.count % 4) % 4)))
    }
    let header = try #require(JSONSerialization.jsonObject(with: decode(parts[0])) as? [String: String])
    let claims = try #require(JSONSerialization.jsonObject(with: decode(parts[1])) as? [String: Any])
    #expect(header["alg"] == "ES256")
    #expect(header["kid"] == "KEY123")
    #expect(claims["iss"] as? String == "TEAM123")
    #expect(claims["iat"] as? Int == Int(now.timeIntervalSince1970))
    let signature = try P256.Signing.ECDSASignature(rawRepresentation: decode(parts[2]))
    let publicKey = try P256.Signing.PublicKey(x963Representation: key.publicKey.x963Representation)
    #expect(publicKey.isValidSignature(signature, for: Data("\(parts[0]).\(parts[1])".utf8)))
  }

  @Test("Refresh-only OAuth reports missing authorization without opening a listener")
  func refreshOnlyWithoutCredential() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let clientFile = directory.appending(path: "client.json")
    let clientID = "offer-watch-test-\(UUID().uuidString)"
    let client = """
    {"installed":{"client_id":"\(clientID)","client_secret":"secret","auth_uri":"https://example.test/auth","token_uri":"https://example.test/token"}}
    """
    try Data(client.utf8).write(to: clientFile)
    do {
      _ = try await GmailDesktopAuthorization.refreshOnly(clientFile: clientFile, scope: "mail")
      Issue.record("Expected missing stored refresh-token error")
    } catch let error as GmailDesktopAuthorizationError {
      if case .notAuthorized = error {} else { Issue.record("Expected notAuthorized, got \(error)") }
    } catch {
      Issue.record("Expected notAuthorized, got \(error)")
    }
  }

  @Test("Gmail access tokens are reused until five minutes before expiry")
  func accessTokenReuse() async throws {
    let now = LockedBox(start)
    let calls = LockedBox(0)
    let provider = GmailAccessTokenProvider(refresh: {
      calls.update { $0 += 1 }
      return GmailAccessToken(value: "token-\(calls.get())", expiresAt: now.get().addingTimeInterval(3600))
    }, now: { now.get() })
    #expect(try await provider.token() == "token-1")
    now.set(start.addingTimeInterval(10 * 60))
    #expect(try await provider.token() == "token-1")
    now.set(start.addingTimeInterval(56 * 60))
    #expect(try await provider.token() == "token-2")
    #expect(calls.get() == 2)
  }

  @Test("Notification tap is stored before the view exists and invalid IDs are rejected")
  @MainActor
  func coldTapState() {
    let model = OfferAlertsModel(environment: "sandbox")
    model.notificationTapped(messageID: "a1b2")
    #expect(model.pendingMessageID == "a1b2")
    #expect(model.messageResolution == .resolving)
    model.notificationTapped(messageID: "bad/id")
    #expect(model.pendingMessageID == "a1b2")
    #expect(!OfferAlertsModel.isValidMessageID("../secret"))
  }

  @Test("Message resolution checks local data first, then syncs on initial and retry attempts")
  @MainActor
  func messageResolution() async {
    let id = UUID()
    let found = LockedBox(false)
    let syncCount = LockedBox(0)
    let model = OfferAlertsModel(environment: "sandbox", lookupContentPiece: { _ in found.get() ? id : nil })
    await model.resolveMessage(messageID: "abcdef", syncMail: { syncCount.update { $0 += 1 } }, retrySync: true)
    #expect(model.messageResolution == .absent)
    #expect(syncCount.get() == 1)
    found.set(false)
    await model.resolveMessage(messageID: "abcdef", syncMail: {
      syncCount.update { $0 += 1 }
      found.set(true)
    }, retrySync: true)
    #expect(model.messageResolution == .found(id))
    await model.resolveMessage(messageID: "abcdef", syncMail: { syncCount.update { $0 += 1 } }, retrySync: false)
    #expect(model.messageResolution == .found(id))
    #expect(syncCount.get() == 2)
  }

  @Test("Authorized notification settings restore the device token and register without prompting")
  @MainActor
  func restoresRegistration() async {
    let model = OfferAlertsModel(environment: "sandbox")
    let registrationCalls = LockedBox(0)
    await model.authorizationDidChange(
      authorized: true, loadPersistedToken: { "saved-token" },
      registerForRemoteNotifications: { registrationCalls.update { $0 += 1 } })
    #expect(model.registration == .enabled)
    #expect(model.deviceToken == "saved-token")
    #expect(registrationCalls.get() == 1)
    await model.authorizationDidChange(
      authorized: false, loadPersistedToken: { Issue.record("Must not read token"); return nil },
      registerForRemoteNotifications: { registrationCalls.update { $0 += 1 } })
    #expect(registrationCalls.get() == 1)
  }

  @Test("Pairings live in their own file and removal rereads concurrent additions")
  func pairingStoreIsIndependent() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: directory) }
    let watcher = OfferWatchStore(directory: directory)
    let command = OfferWatchStore(directory: directory)
    let old = OfferWatchPairing(id: "old", name: "Old", token: "old-token", environment: .sandbox)
    let added = OfferWatchPairing(id: "new", name: "New", token: "new-token", environment: .production)
    try watcher.savePairings([old])
    try watcher.save(OfferWatchState(now: start))
    try command.savePairings([old, added])
    try watcher.removePairings(ids: ["old"])
    #expect(try watcher.loadPairings() == [added])
  }

  @Test("State migrates the prior single status timestamp and duplicate ledger value")
  func stateMigration() throws {
    let encoded = """
    {"startedAt":"2026-11-28T00:00:00Z","baselineEstablished":true,"lastStatusAt":"2026-11-28T00:00:00Z","senders":{},"pairings":[],"ledger":[{"messageID":"old","recordedAt":"2026-11-28T00:00:00Z","outcome":"duplicate"}]}
    """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let state = try decoder.decode(OfferWatchState.self, from: Data(encoded.utf8))
    #expect(state.lastStatusAt[OfferWatchStatusKind.revokedGrant.rawValue] != nil)
    #expect(state.ledger.first?.outcome == .stale)
  }

  @Test("An unreadable iCloud watched list returns the labeled last-good copy")
  func watchedListFallback() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: directory) }
    let local = directory.appending(path: "support", directoryHint: .isDirectory)
    let cloud = directory.appending(path: "cloud", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: local, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: cloud.appending(path: "watched.txt", directoryHint: .isDirectory), withIntermediateDirectories: true)
    try Data("offers@example.com\n".utf8).write(to: local.appending(path: "watched.txt"))
    let list = try OfferWatchStore(directory: local, cloudFolder: cloud).watchedAddresses()
    #expect(list.addresses == ["offers@example.com"])
    #expect(list.source == .lastGoodCopy)
  }

  @Test("Terminal status is sent once per kind per local day")
  func statusRateLimit() async {
    let state = LockedBox(OfferWatchState(now: start))
    let sent = LockedBox<[OfferWatchAlert]>([])
    let dependencies = OfferWatchRuntimeDependencies(
      accessToken: { throw CancellationError() }, accountID: { _ in "account" },
      watchedAddresses: { WatchedAddressList(addresses: [], source: .local) },
      listIDs: { _, _, _ in [] }, fetchMessage: { _, _ in throw CancellationError() },
      send: { alert, _, _ in sent.update { $0.append(alert) }; return APNsDelivery(statusCode: 200) },
      loadState: { state.get() }, saveState: { state.set($0) }, loadPairings: { [phone] },
      removePairings: { _ in }, now: { start }, sleep: { _ in throw CancellationError() })
    let runner = OfferWatchRunner(
      configuration: .init(hasClientPath: false, hasAPNsKey: true, hasAPNsIdentity: true),
      dependencies: dependencies)
    await runner.run()
    await runner.run()
    #expect(sent.get().count == 1)
    #expect(sent.get().first?.collapseID == "offer-watch-status-missingConfiguration")
    #expect(state.get().lastStatusAt[OfferWatchStatusKind.missingConfiguration.rawValue] == start)
  }

  @Test("A revoked Gmail grant sends its typed status and stops the runner")
  func revokedGrantStatus() async {
    let now = self.start
    let pairing = self.phone
    let state = LockedBox(OfferWatchState(now: now))
    let sent = LockedBox<[OfferWatchAlert]>([])
    let dependencies = OfferWatchRuntimeDependencies(
      accessToken: { throw GmailDesktopAuthorizationError.revokedGrant },
      accountID: { _ in "account" },
      watchedAddresses: { WatchedAddressList(addresses: [], source: .local) },
      listIDs: { _, _, _ in [] }, fetchMessage: { _, _ in throw CancellationError() },
      send: { alert, _, _ in sent.update { $0.append(alert) }; return APNsDelivery(statusCode: 200) },
      loadState: { state.get() }, saveState: { state.set($0) }, loadPairings: { [pairing] },
      removePairings: { _ in }, now: { now }, sleep: { _ in Issue.record("Terminal grant error must stop") })
    await OfferWatchRunner(
      configuration: .init(hasClientPath: true, hasAPNsKey: true, hasAPNsIdentity: true),
      dependencies: dependencies).run()
    #expect(sent.get().count == 1)
    #expect(sent.get()[0].body.contains("Gmail access was revoked"))
    #expect(state.get().lastStatusAt[OfferWatchStatusKind.revokedGrant.rawValue] == now)
  }

  @Test("A changed Gmail account reports once and stops before reading the sender list")
  func accountChangeStopsRunner() async {
    let now = self.start
    let pairing = self.phone
    let previous = LockedBox(OfferWatchState(now: now))
    var accountState = previous.get()
    accountState.accountID = "old@example.com"
    previous.set(accountState)
    let senderReads = LockedBox(0)
    let sent = LockedBox<[OfferWatchAlert]>([])
    let dependencies = OfferWatchRuntimeDependencies(
      accessToken: { "token" }, accountID: { _ in "new@example.com" },
      watchedAddresses: { senderReads.update { $0 += 1 }; return WatchedAddressList(addresses: [], source: .local) },
      listIDs: { _, _, _ in [] }, fetchMessage: { _, _ in throw CancellationError() },
      send: { alert, _, _ in sent.update { $0.append(alert) }; return APNsDelivery(statusCode: 200) },
      loadState: { previous.get() }, saveState: { previous.set($0) }, loadPairings: { [pairing] },
      removePairings: { _ in }, now: { now }, sleep: { _ in Issue.record("Account change must stop") })
    await OfferWatchRunner(
      configuration: .init(hasClientPath: true, hasAPNsKey: true, hasAPNsIdentity: true),
      dependencies: dependencies).run()
    #expect(senderReads.get() == 0)
    #expect(sent.get().count == 1)
    #expect(sent.get()[0].body.contains("account changed"))
  }

  @Test("Transient errors back off without sending a generic status")
  func transientBackoff() async {
    let start = self.start
    let phone = self.phone
    let requestedSleep = LockedBox<Duration?>(nil)
    let sent = LockedBox<[OfferWatchAlert]>([])
    let dependencies = OfferWatchRuntimeDependencies(
      accessToken: { "token" }, accountID: { _ in "account" },
      watchedAddresses: { WatchedAddressList(addresses: ["offers@example.com"], source: .local) },
      listIDs: { _, _, _ in throw URLError(.timedOut) },
      fetchMessage: { _, _ in throw CancellationError() },
      send: { alert, _, _ in sent.update { $0.append(alert) }; return APNsDelivery(statusCode: 200) },
      loadState: { OfferWatchState(now: start) }, saveState: { _ in }, loadPairings: { [phone] },
      removePairings: { _ in }, now: { start }, sleep: { duration in
        requestedSleep.set(duration)
        throw CancellationError()
      })
    await OfferWatchRunner(
      configuration: .init(hasClientPath: true, hasAPNsKey: true, hasAPNsIdentity: true),
      dependencies: dependencies).run()
    #expect(requestedSleep.get() == .seconds(120))
    #expect(sent.get().isEmpty)
  }
}
