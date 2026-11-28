import Foundation

/// The Google "Desktop app" OAuth client, read from the `client_secret_*.json` Google hands you
/// (the `installed` variant). Read locally and never written anywhere by this tool.
struct DesktopClient: Decodable {
  let clientID: String
  let clientSecret: String
  let authURI: URL
  let tokenURI: URL

  enum CodingKeys: String, CodingKey {
    case clientID = "client_id"
    case clientSecret = "client_secret"
    case authURI = "auth_uri"
    case tokenURI = "token_uri"
  }

  static func load(from url: URL) throws -> DesktopClient {
    try JSONDecoder().decode(Wrapper.self, from: Data(contentsOf: url)).installed
  }

  private struct Wrapper: Decodable {
    let installed: DesktopClient
  }
}
