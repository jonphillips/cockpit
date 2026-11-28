import CryptoKit
import Foundation
import Security

public enum OfferWatchKeychain {
  private static let service = "com.jonphillips.cockpit.offerwatch"
  public static func store(_ value: Data, account: String) throws {
    let identity: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    SecItemDelete(identity as CFDictionary)
    var item = identity
    item[kSecValueData as String] = value
    let status = SecItemAdd(item as CFDictionary, nil)
    guard status == errSecSuccess else { throw KeychainFailure(status: status) }
  }
  public static func load(account: String) -> Data? {
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
    return result as? Data
  }
}

private struct KeychainFailure: Error { let status: OSStatus }

public struct APNsAlertSender: Sendable {
  public init() {}

  public func send(alert: OfferWatchAlert, pairing: OfferWatchPairing, jwt: String, passive: Bool = false) async throws -> APNsDelivery {
    let host = pairing.environment == .production ? "api.push.apple.com" : "api.sandbox.push.apple.com"
    var request = URLRequest(url: URL(string: "https://\(host)/3/device/\(pairing.token)")!)
    request.httpMethod = "POST"
    request.setValue("bearer \(jwt)", forHTTPHeaderField: "authorization")
    request.setValue("alert", forHTTPHeaderField: "apns-push-type")
    request.setValue(passive ? "5" : "10", forHTTPHeaderField: "apns-priority")
    request.setValue("com.jonphillips.cockpit", forHTTPHeaderField: "apns-topic")
    if let collapseID = alert.collapseID { request.setValue(collapseID, forHTTPHeaderField: "apns-collapse-id") }
    request.httpBody = try Self.payload(alert: alert, passive: passive)
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let response = response as? HTTPURLResponse else { throw APNsError.noResponse }
    let reason = (try? JSONSerialization.jsonObject(with: data) as? [String: String])?["reason"]
    return APNsDelivery(statusCode: response.statusCode, reason: reason)
  }

  public static func payload(alert: OfferWatchAlert, passive: Bool) throws -> Data {
    var result: [String: Any] = ["aps": ["alert": ["title": alert.title, "body": alert.body], "interruption-level": passive ? "passive" : "time-sensitive"]]
    if let sourceID = alert.sourceID { result["source"] = sourceID; result["kind"] = "mail" }
    else { result["kind"] = "status" }
    return try JSONSerialization.data(withJSONObject: result)
  }

  static func jwt(keyID: String, teamID: String, pem: String, now: Date = .now) throws -> String {
    let header = try JSONSerialization.data(withJSONObject: ["alg": "ES256", "kid": keyID])
    let payload = try JSONSerialization.data(withJSONObject: ["iss": teamID, "iat": Int(now.timeIntervalSince1970)])
    let unsigned = "\(header.base64URL).\(payload.base64URL)"
    let key = try P256.Signing.PrivateKey(pemRepresentation: pem)
    let signature = try key.signature(for: Data(unsigned.utf8))
    return unsigned + "." + signature.rawRepresentation.base64URL
  }
}

public struct OfferWatchAlert: Sendable, Equatable {
  public let title: String
  public let body: String
  public let sourceID: String?
  public let collapseID: String?
  public init(title: String, body: String, sourceID: String? = nil, collapseID: String? = nil) {
    self.title = title; self.body = body; self.sourceID = sourceID; self.collapseID = collapseID
  }
}

public struct APNsDelivery: Sendable, Equatable {
  public let statusCode: Int
  public let reason: String?
  public var accepted: Bool { (200..<300).contains(statusCode) }
  public var isDeadToken: Bool { statusCode == 410 || reason == "BadDeviceToken" }
  public init(statusCode: Int, reason: String? = nil) { self.statusCode = statusCode; self.reason = reason }
}

public actor APNsJWTProvider {
  // The brief allows 20–60 minutes; the lower bound minimizes stale-token risk on a long-running client.
  private static let reuseWindow: TimeInterval = 20 * 60
  private let keyID: String
  private let teamID: String
  private let pem: String
  private var cached: (token: String, issuedAt: Date)?

  public init(keyID: String, teamID: String, pem: String) {
    self.keyID = keyID; self.teamID = teamID; self.pem = pem
  }

  public func token(now: Date = .now) throws -> String {
    if let cached, now.timeIntervalSince(cached.issuedAt) >= 0, now.timeIntervalSince(cached.issuedAt) < Self.reuseWindow {
      return cached.token
    }
    let value = try APNsAlertSender.jwt(keyID: keyID, teamID: teamID, pem: pem, now: now)
    cached = (value, now)
    return value
  }
}

private extension Data {
  var base64URL: String { base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
}

private enum APNsError: Error { case noResponse }
