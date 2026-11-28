import CockpitCore
import Foundation
import GmailDesktopAuth
import OfferWatchSupport

@main
struct OfferWatch {
  private static let pollInterval: Duration = .seconds(120) // ADR-0003 D3's two-minute cadence.
  private static let maximumAlertBodyCharacters = 120 // Keep the subject a short single-line interruption.
  static func main() async {
    do { try await run(Array(CommandLine.arguments.dropFirst())) }
    catch { fputs("offerwatch: \(error.localizedDescription)\n", stderr); exit(1) }
  }

  static func run(_ args: [String]) async throws {
    guard let command = args.first else { throw Usage.error }
    let store = OfferWatchStore.standard
    switch command {
    case "auth":
      guard let i = args.firstIndex(of: "--client"), args.indices.contains(i + 1) else { throw Usage.error }
      _ = try await GmailDesktopAuthorization.accessToken(clientFile: URL(fileURLWithPath: args[i + 1]), scope: "https://www.googleapis.com/auth/gmail.readonly")
      print("Gmail read-only authorization stored in the login keychain.")
    case "apns-key":
      guard args.count == 2 else { throw Usage.error }
      try OfferWatchKeychain.store(Data(contentsOf: URL(fileURLWithPath: args[1])), account: "apns-p8")
      print("APNs key stored in the login keychain.")
    case "pair":
      guard args.count == 4, let environment = OfferWatchPairing.Environment(rawValue: args[3]) else { throw Usage.error }
      var state = try store.loadState()
      state.pairings.removeAll { $0.name == args[1] }
      state.pairings.append(.init(id: args[1], name: args[1], token: args[2], environment: environment))
      try store.save(state)
    case "pairs":
      for pair in try store.loadState().pairings { print("\(pair.name) (\(pair.environment.rawValue))") }
    case "run":
      try await runLoop(store: store)
    default: throw Usage.error
    }
  }

  private static func runLoop(store: OfferWatchStore) async throws {
    let scope = "https://www.googleapis.com/auth/gmail.readonly"
    guard let configuredClientPath = ProcessInfo.processInfo.environment["OFFERWATCH_CLIENT_JSON"], !configuredClientPath.isEmpty else { throw Usage.missingClientPath }
    let clientURL = URL(fileURLWithPath: configuredClientPath)
    var activeStore = store
    var state = try store.loadState()
    state.establishBaseline(at: .now)
    guard let keyData = OfferWatchKeychain.load(account: "apns-p8"), let pem = String(data: keyData, encoding: .utf8) else {
      throw OfferWatchConfigurationError.missingAPNsKey
    }
    guard let keyID = ProcessInfo.processInfo.environment["OFFERWATCH_APNS_KEY_ID"],
      let teamID = ProcessInfo.processInfo.environment["OFFERWATCH_TEAM_ID"] else {
      throw OfferWatchConfigurationError.missingAPNsIdentity
    }
    let jwtProvider = APNsJWTProvider(keyID: keyID, teamID: teamID, pem: pem)
    while !Task.isCancelled {
      do {
        let token = try await GmailDesktopAuthorization.accessToken(clientFile: clientURL, scope: scope)
        let addresses = try activeStore.watchedAddresses()
        if activeStore.didUseLastGoodCopy {
          fputs("iCloud Drive list unreadable; using the last-good local copy.\n", stderr)
          await reportStatus(state: &state, now: .now, jwtProvider: jwtProvider)
        }
        state.reconcile(addresses: addresses, now: .now)
        let api = GmailInboxAPI(accessToken: token)
        let accountID = try await api.accountEmail()
        if let previous = state.accountID, previous != accountID {
          throw OfferWatchRuntimeError.accountChanged(previous: previous, current: accountID)
        }
        state.accountID = accountID
        let processor = makeProcessor(api: api, jwtProvider: jwtProvider)
        try await processor.poll(state: &state, now: .now)
        let dayStart = Calendar.current.startOfDay(for: .now)
        let screenedCount = state.ledger.filter { $0.recordedAt >= dayStart }.count
        let alertCount = state.ledger.filter {
          $0.recordedAt >= dayStart && ($0.outcome == .sent || $0.outcome == .passive)
        }.count
        await processor.sendHeartbeat(
          state: &state, now: .now, screened: screenedCount, alerts: alertCount)
        try activeStore.save(state)
        try await Task.sleep(for: Self.pollInterval)
      } catch let error as OfferWatchRuntimeError {
        await reportStatus(state: &state, now: .now, jwtProvider: jwtProvider)
        try? activeStore.save(state)
        throw error
      } catch {
        fputs("Offer Watch poll failed; retrying: \(error.localizedDescription)\n", stderr)
        await reportStatus(state: &state, now: .now, jwtProvider: jwtProvider)
        try? activeStore.save(state)
        try await Task.sleep(for: Self.pollInterval)
      }
    }
  }

  private static func makeProcessor(api: GmailInboxAPI, jwtProvider: APNsJWTProvider) -> OfferWatchProcessor {
    OfferWatchProcessor(
      fetch: { address, date in
        try await api.messages(from: address, after: date).map { message in
          WatchedMail(id: message.id, from: message.header(named: "From"), subject: message.header(named: "Subject") ?? "New message", authenticationResults: message.header(named: "Authentication-Results"))
        }
      },
      send: { alert, pair, passive in
        let noURLs = alert.body.replacingOccurrences(of: "https?://\\S+|www\\.\\S+", with: "", options: .regularExpression)
        let safeAlert = OfferWatchAlert(
          title: alert.title, body: String(noURLs.filter { !$0.isNewline }.prefix(Self.maximumAlertBodyCharacters)),
          sourceID: alert.sourceID, collapseID: alert.collapseID)
        let jwt = try await jwtProvider.token()
        return try await APNsAlertSender().send(alert: safeAlert, pairing: pair, jwt: jwt, passive: passive)
      })
  }

  private static func reportStatus(state: inout OfferWatchState, now: Date, jwtProvider: APNsJWTProvider) async {
    if let last = state.lastStatusAt, Calendar.current.isDate(last, inSameDayAs: now) { return }
    let report = OfferWatchAlert(
      title: "Offer Watch needs attention", body: "The watcher hit an error. Check its Mac logs.",
      collapseID: "offer-watch-status")
    var delivered = false
    for pairing in state.pairings {
      if let jwt = try? await jwtProvider.token(),
        let response = try? await APNsAlertSender().send(alert: report, pairing: pairing, jwt: jwt, passive: true),
        response.accepted { delivered = true }
    }
    if delivered { state.lastStatusAt = now }
  }
}

enum Usage: LocalizedError {
  case error
  case missingClientPath
  var errorDescription: String? {
    switch self {
    case .error: return "usage: offerwatch auth --client <secret.json> | apns-key <path> | pair <name> <token> <production|sandbox> | pairs | run"
    case .missingClientPath: return "Set OFFERWATCH_CLIENT_JSON to the Desktop OAuth client JSON path before loading the LaunchAgent."
    }
  }
}

enum OfferWatchRuntimeError: LocalizedError {
  case accountChanged(previous: String, current: String)
  var errorDescription: String? {
    switch self {
    case let .accountChanged(previous, current):
      return "authorized Gmail account changed from \(previous) to \(current); stopping the watcher."
    }
  }
}

enum OfferWatchConfigurationError: LocalizedError {
  case missingAPNsKey
  case missingAPNsIdentity
  var errorDescription: String? {
    switch self {
    case .missingAPNsKey: return "APNs .p8 key is not stored in the login keychain. Run offerwatch apns-key <path>."
    case .missingAPNsIdentity: return "Set OFFERWATCH_APNS_KEY_ID and OFFERWATCH_TEAM_ID in the LaunchAgent."
    }
  }
}
