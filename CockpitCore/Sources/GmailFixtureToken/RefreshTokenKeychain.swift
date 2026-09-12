import Foundation
import Security

/// The refresh token's only durable home is the macOS login keychain, keyed by client id. It is
/// never written to the repo, a fixture, or any file — satisfying the "no token on disk" contract.
enum RefreshTokenKeychain {
  private static let service = "com.cockpit.GmailFixtureToken"

  static func load(clientID: String) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: clientID,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data
    else { return nil }
    return String(data: data, encoding: .utf8)
  }

  static func store(clientID: String, refreshToken: String) throws {
    let identity: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: clientID,
    ]
    SecItemDelete(identity as CFDictionary)
    var attributes = identity
    attributes[kSecValueData as String] = Data(refreshToken.utf8)
    let status = SecItemAdd(attributes as CFDictionary, nil)
    guard status == errSecSuccess else { throw OAuthError.keychain(status) }
  }
}
