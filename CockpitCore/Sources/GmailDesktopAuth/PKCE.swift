import CryptoKit
import Foundation

/// PKCE (RFC 7636) parameters for the authorization-code flow: a high-entropy verifier and its
/// S256 challenge, plus a CSRF `state`. The verifier never leaves this process.
struct PKCE {
  let verifier: String
  let challenge: String

  init() {
    verifier = Self.base64URL(Self.randomBytes(64))
    challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
  }

  static func randomState() -> String {
    base64URL(randomBytes(32))
  }

  private static func randomBytes(_ count: Int) -> Data {
    var generator = SystemRandomNumberGenerator()
    return Data((0..<count).map { _ in UInt8.random(in: .min ... .max, using: &generator) })
  }

  private static func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
