import Foundation

/// The token-endpoint half of the flow: builds the authorization URL and exchanges either an
/// authorization code (first run) or a refresh token (later runs) for a fresh access token.
struct OAuthExchange {
  let client: DesktopClient
  let scope: String

  func authorizationURL(redirectURI: String, challenge: String, state: String) -> URL {
    var components = URLComponents(url: client.authURI, resolvingAgainstBaseURL: false)!
    components.queryItems = [
      .init(name: "client_id", value: client.clientID),
      .init(name: "redirect_uri", value: redirectURI),
      .init(name: "response_type", value: "code"),
      .init(name: "scope", value: scope),
      .init(name: "code_challenge", value: challenge),
      .init(name: "code_challenge_method", value: "S256"),
      .init(name: "state", value: state),
      // offline + consent are what actually mint a refresh token on the first authorization.
      .init(name: "access_type", value: "offline"),
      .init(name: "prompt", value: "consent"),
    ]
    return components.url!
  }

  func exchange(code: String, verifier: String, redirectURI: String) async throws -> TokenResponse {
    try await post([
      "grant_type": "authorization_code", "code": code, "code_verifier": verifier,
      "redirect_uri": redirectURI, "client_id": client.clientID,
      "client_secret": client.clientSecret,
    ])
  }

  func refresh(refreshToken: String) async throws -> TokenResponse {
    try await post([
      "grant_type": "refresh_token", "refresh_token": refreshToken,
      "client_id": client.clientID, "client_secret": client.clientSecret,
    ])
  }

  private func post(_ form: [String: String]) async throws -> TokenResponse {
    var request = URLRequest(url: client.tokenURI)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpBody = Data(form.map { "\($0.key)=\(Self.encode($0.value))" }
      .joined(separator: "&").utf8)
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
      let status = (response as? HTTPURLResponse)?.statusCode ?? -1
      throw OAuthError.tokenExchange(status, String(decoding: data, as: UTF8.self))
    }
    return try JSONDecoder().decode(TokenResponse.self, from: data)
  }

  private static func encode(_ value: String) -> String {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~")
    return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
  }
}

struct TokenResponse: Decodable {
  let accessToken: String
  let refreshToken: String?

  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case refreshToken = "refresh_token"
  }
}

enum OAuthError: LocalizedError {
  case usage
  case listenerFailed
  case noCode
  case stateMismatch
  case authorizationDenied(String)
  case missingRefreshToken
  case tokenExchange(Int, String)
  case keychain(OSStatus)

  var errorDescription: String? {
    switch self {
    case .usage:
      return "usage: swift run GmailFixtureToken --client <desktop-client.json> [--scope <scope>]"
    case .listenerFailed:
      return "Could not open a loopback listener for the OAuth redirect."
    case .noCode:
      return "The redirect did not carry an authorization code."
    case .stateMismatch:
      return "OAuth state did not match; discarding the redirect."
    case let .authorizationDenied(reason):
      return "Authorization was denied: \(reason)"
    case .missingRefreshToken:
      return "Google returned no refresh token. Revoke the app at myaccount.google.com/permissions and retry so it re-prompts for offline consent."
    case let .tokenExchange(status, body):
      return "Token exchange failed (HTTP \(status)): \(body)"
    case let .keychain(status):
      return "Keychain error (OSStatus \(status))."
    }
  }
}
