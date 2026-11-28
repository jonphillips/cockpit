import CockpitCore
import Foundation
import GmailDesktopAuth
import OfferWatchSupport

@main
struct OfferWatch {
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
      _ = try await GmailDesktopAuthorization.accessToken(
        clientFile: URL(fileURLWithPath: args[i + 1]), scope: scope, log: { fputs($0 + "\n", stderr) })
      print("Gmail read-only authorization stored in the login keychain.")
    case "apns-key":
      guard args.count == 2 else { throw Usage.error }
      try OfferWatchKeychain.store(Data(contentsOf: URL(fileURLWithPath: args[1])), account: "apns-p8")
      print("APNs key stored in the login keychain.")
    case "pair":
      guard args.count == 4, let environment = OfferWatchPairing.Environment(rawValue: args[3]) else { throw Usage.error }
      var pairings = try store.loadPairings()
      pairings.removeAll { $0.id == args[1] }
      pairings.append(.init(id: args[1], name: args[1], token: args[2], environment: environment))
      try store.savePairings(pairings)
    case "pairs":
      for pair in try store.loadPairings() { print("\(pair.name) (\(pair.environment.rawValue))") }
    case "run":
      await runLoop(store: store)
    default: throw Usage.error
    }
  }

  private static let scope = "https://www.googleapis.com/auth/gmail.readonly"

  private static func runLoop(store: OfferWatchStore) async {
    let environment = ProcessInfo.processInfo.environment
    let path = environment["OFFERWATCH_CLIENT_JSON"] ?? ""
    let hasClient = !path.isEmpty
    let keyData = OfferWatchKeychain.load(account: "apns-p8")
    let pem = keyData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    let keyID = environment["OFFERWATCH_APNS_KEY_ID"] ?? ""
    let teamID = environment["OFFERWATCH_TEAM_ID"] ?? ""
    let jwtProvider = APNsJWTProvider(keyID: keyID, teamID: teamID, pem: pem)
    let tokenProvider = GmailAccessTokenProvider {
      try await GmailDesktopAuthorization.refreshOnly(clientFile: URL(fileURLWithPath: path), scope: scope)
    }
    let dependencies = OfferWatchRuntimeDependencies(
      accessToken: { try await tokenProvider.token() },
      accountID: { try await GmailInboxAPI(accessToken: $0).accountEmail() },
      watchedAddresses: { try store.watchedAddresses() },
      listIDs: { address, after, token in try await GmailInboxAPI(accessToken: token).messageIDs(from: address, after: after) },
      fetchMessage: { id, token in
        let message = try await GmailInboxAPI(accessToken: token).message(id: id)
        return WatchedMail(
          id: message.id, from: message.header(named: "From"),
          subject: message.header(named: "Subject") ?? "New message",
          authenticationResults: message.header(named: "Authentication-Results"),
          internalDate: message.internalDate)
      },
      send: { alert, pairing, passive in
        try await APNsAlertSender().send(alert: alert, pairing: pairing, jwt: jwtProvider.token(), passive: passive)
      },
      loadState: { try store.loadState() }, saveState: { try store.save($0) },
      loadPairings: { try store.loadPairings() }, removePairings: { try store.removePairings(ids: $0) },
      log: { fputs($0 + "\n", stderr) })
    let runner = OfferWatchRunner(
      configuration: .init(hasClientPath: hasClient, hasAPNsKey: !pem.isEmpty,
        hasAPNsIdentity: !keyID.isEmpty && !teamID.isEmpty), dependencies: dependencies)
    await runner.run()
  }
}

enum Usage: LocalizedError {
  case error
  var errorDescription: String? {
    "usage: offerwatch auth --client <secret.json> | apns-key <path> | pair <name> <token> <production|sandbox> | pairs | run"
  }
}
