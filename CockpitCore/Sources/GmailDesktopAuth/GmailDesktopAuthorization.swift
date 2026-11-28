import Foundation

public struct GmailAccessToken: Sendable, Equatable {
  public let value: String
  public let expiresAt: Date
  public init(value: String, expiresAt: Date) { self.value = value; self.expiresAt = expiresAt }
}

public enum GmailDesktopAuthorizationError: Error, LocalizedError {
  case notAuthorized
  case revokedGrant
  case invalidConfiguration
  public var errorDescription: String? {
    switch self {
    case .notAuthorized: return "Gmail authorization is missing or expired. Run offerwatch auth in a logged-in Terminal session."
    case .revokedGrant: return "Gmail authorization was revoked. Run offerwatch auth in a logged-in Terminal session."
    case .invalidConfiguration: return "The Gmail OAuth client configuration is missing or unreadable. Check OFFERWATCH_CLIENT_JSON."
    }
  }
}

/// Reusable Desktop OAuth flow for the fixture utility and the local Offer Watch client.
public enum GmailDesktopAuthorization {
  /// Performs the interactive first sign-in when necessary, then refreshes the access token.
  public static func accessToken(
    clientFile: URL, scope: String,
    log: @Sendable (String) -> Void = { _ in }
  ) async throws -> GmailAccessToken {
    let client = try DesktopClient.load(from: clientFile)
    let exchange = OAuthExchange(client: client, scope: scope)
    if let refreshToken = RefreshTokenKeychain.load(clientID: client.clientID) {
      log("Refreshing stored authorization…")
      return try await accessToken(from: exchange.refresh(refreshToken: refreshToken))
    }
    let pkce = PKCE()
    let state = PKCE.randomState()
    let receiver = try LoopbackReceiver()
    let redirectURI = "http://127.0.0.1:\(receiver.port)"
    let authorizationURL = exchange.authorizationURL(
      redirectURI: redirectURI, challenge: pkce.challenge, state: state)
    log("Opening the browser for Google sign-in (loopback redirect on \(redirectURI))…")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = [authorizationURL.absoluteString]
    try process.run()
    let code = try await receiver.waitForCode(expectedState: state)
    let response = try await exchange.exchange(
      code: code, verifier: pkce.verifier, redirectURI: redirectURI)
    guard let refreshToken = response.refreshToken else { throw OAuthError.missingRefreshToken }
    try RefreshTokenKeychain.store(clientID: client.clientID, refreshToken: refreshToken)
    log("Stored the refresh token in the login keychain. Later runs refresh silently.")
    return accessToken(from: response)
  }

  /// Refresh-only entry point for unattended work. It never opens a browser or creates a listener.
  public static func refreshOnly(
    clientFile: URL, scope: String,
    log: @Sendable (String) -> Void = { _ in }
  ) async throws -> GmailAccessToken {
    let client: DesktopClient
    do { client = try DesktopClient.load(from: clientFile) }
    catch { throw GmailDesktopAuthorizationError.invalidConfiguration }
    guard let refreshToken = RefreshTokenKeychain.load(clientID: client.clientID) else {
      throw GmailDesktopAuthorizationError.notAuthorized
    }
    log("Refreshing stored authorization…")
    do {
      return try await accessToken(from: OAuthExchange(client: client, scope: scope).refresh(refreshToken: refreshToken))
    } catch let error as OAuthError {
      if error.localizedDescription.localizedCaseInsensitiveContains("invalid_grant") {
        throw GmailDesktopAuthorizationError.revokedGrant
      }
      throw error
    }
  }

  private static func accessToken(from response: TokenResponse) -> GmailAccessToken {
    GmailAccessToken(
      value: response.accessToken,
      expiresAt: .now.addingTimeInterval(TimeInterval(response.expiresIn ?? 3_600)))
  }
}
