import Foundation

/// A Mac-only helper that mints a short-lived Gmail access token for the fixture harvest.
///
/// First run: authorization-code + PKCE flow over a loopback redirect, requesting offline access,
/// and stores the resulting refresh token in the login keychain. Later runs: refresh silently.
/// Either way it prints *only* a fresh access token to stdout, so callers can do:
///
///   GMAIL_ACCESS_TOKEN=$(swift run GmailFixtureToken --client secret.json) swift run JudgmentFixtureHarvest …
@main
struct GmailFixtureToken {
  static let defaultScope = "https://www.googleapis.com/auth/gmail.readonly"

  static func main() async {
    do {
      try await run(Array(CommandLine.arguments.dropFirst()))
    } catch {
      fputs("error: \(error.localizedDescription)\n", stderr)
      exit(1)
    }
  }

  static func run(_ arguments: [String]) async throws {
    guard let clientPath = value(named: "--client", in: arguments) else { throw OAuthError.usage }
    let client = try DesktopClient.load(from: URL(fileURLWithPath: clientPath))
    let scope = value(named: "--scope", in: arguments) ?? defaultScope
    let exchange = OAuthExchange(client: client, scope: scope)

    let accessToken: String
    if let refreshToken = RefreshTokenKeychain.load(clientID: client.clientID) {
      log("Refreshing stored authorization…")
      accessToken = try await exchange.refresh(refreshToken: refreshToken).accessToken
    } else {
      accessToken = try await authorize(exchange: exchange, client: client)
    }
    print(accessToken)  // stdout carries the token and nothing else.
  }

  private static func authorize(exchange: OAuthExchange, client: DesktopClient) async throws -> String {
    let pkce = PKCE()
    let state = PKCE.randomState()
    let receiver = try LoopbackReceiver()
    let port = try await receiver.start()
    let redirectURI = "http://127.0.0.1:\(port)"
    let authURL = exchange.authorizationURL(
      redirectURI: redirectURI, challenge: pkce.challenge, state: state)
    log("Opening the browser for Google sign-in (loopback redirect on \(redirectURI))…")
    Browser.open(authURL)
    let code = try await receiver.waitForCode(expectedState: state)
    let response = try await exchange.exchange(
      code: code, verifier: pkce.verifier, redirectURI: redirectURI)
    guard let refreshToken = response.refreshToken else { throw OAuthError.missingRefreshToken }
    try RefreshTokenKeychain.store(clientID: client.clientID, refreshToken: refreshToken)
    log("Stored the refresh token in the login keychain. Later runs refresh silently.")
    return response.accessToken
  }

  private static func value(named name: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
    let value = arguments[index + 1]
    return value.isEmpty ? nil : value
  }

  private static func log(_ message: String) {
    fputs(message + "\n", stderr)
  }
}

/// Opens a URL in the user's default browser via `/usr/bin/open` (macOS only).
enum Browser {
  static func open(_ url: URL) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = [url.absoluteString]
    try? process.run()
  }
}
