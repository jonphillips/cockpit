import Foundation

/// Reusable Desktop OAuth flow for the fixture utility and the local Offer Watch client.
public enum GmailDesktopAuthorization {
  /// Authorizes the selected mailbox and returns a short-lived access token. The refresh token remains
  /// in the login keychain and is keyed by this Desktop client's ID.
  public static func accessToken(clientFile: URL, scope: String) async throws -> String {
    let client = try DesktopClient.load(from: clientFile)
    let exchange = OAuthExchange(client: client, scope: scope)
    if let refreshToken = RefreshTokenKeychain.load(clientID: client.clientID) {
      return try await exchange.refresh(refreshToken: refreshToken).accessToken
    }
    let pkce = PKCE()
    let state = PKCE.randomState()
    let receiver = try LoopbackReceiver()
    let redirectURI = "http://127.0.0.1:\(receiver.port)"
    let authorizationURL = exchange.authorizationURL(
      redirectURI: redirectURI, challenge: pkce.challenge, state: state)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = [authorizationURL.absoluteString]
    try process.run()
    let code = try await receiver.waitForCode(expectedState: state)
    let response = try await exchange.exchange(
      code: code, verifier: pkce.verifier, redirectURI: redirectURI)
    guard let refreshToken = response.refreshToken else { throw OAuthError.missingRefreshToken }
    try RefreshTokenKeychain.store(clientID: client.clientID, refreshToken: refreshToken)
    return response.accessToken
  }
}
