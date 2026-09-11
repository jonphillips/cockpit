import CryptoKit
import Foundation

public struct ContentIdentityInput: Equatable, Sendable {
  public var canonicalURL: URL?
  public var providerStableID: String?
  public var feedGUID: String?
  public var feedGUIDIsPermanent: Bool
  public var title: String
  public var publisher: String
  public var publishedAt: Date?

  public init(
    canonicalURL: URL? = nil,
    providerStableID: String? = nil,
    feedGUID: String? = nil,
    feedGUIDIsPermanent: Bool = false,
    title: String,
    publisher: String,
    publishedAt: Date? = nil
  ) {
    self.canonicalURL = canonicalURL
    self.providerStableID = providerStableID
    self.feedGUID = feedGUID
    self.feedGUIDIsPermanent = feedGUIDIsPermanent
    self.title = title
    self.publisher = publisher
    self.publishedAt = publishedAt
  }
}

public enum ContentIdentity {
  /// The fixed Cockpit UUIDv5 namespace. Changing this would fork identity across devices.
  public static let cockpitNamespace = UUID(uuidString: "4577b834-26f2-58c0-bed6-e73143426dff")!

  public static func canonicalIdentityString(for input: ContentIdentityInput) -> String {
    if let canonicalURL = input.canonicalURL.flatMap(normalizedURLString) {
      return canonicalURL
    }
    if let providerStableID = nonEmpty(input.providerStableID) {
      return providerStableID
    }
    if input.feedGUIDIsPermanent, let feedGUID = nonEmpty(input.feedGUID) {
      return feedGUID
    }
    return sha256Hex(of: fallbackFingerprint(for: input))
  }

  public static func derive(
    for input: ContentIdentityInput,
    namespace: UUID = cockpitNamespace
  ) -> UUID {
    uuidV5(namespace: namespace, name: canonicalIdentityString(for: input))
  }

  public static func normalizedURLString(_ url: URL) -> String? {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
    components.fragment = nil
    components.host = components.host?.lowercased()
    components.queryItems = components.queryItems?.filter { item in
      let name = item.name.lowercased()
      return !name.hasPrefix("utm_") && name != "fbclid" && name != "ref"
    }
    if components.queryItems?.isEmpty == true {
      components.queryItems = nil
    }
    while components.path.hasSuffix("/") {
      components.path.removeLast()
    }
    return components.url?.absoluteString
  }

  static func fallbackFingerprint(for input: ContentIdentityInput) -> String {
    let publicationDate = input.publishedAt.map { $0.formatted(.iso8601) } ?? ""
    return [normalizeText(input.title), normalizeText(input.publisher), publicationDate]
      .joined(separator: "\u{001F}")
  }

  static func uuidV5(namespace: UUID, name: String) -> UUID {
    let digest = Insecure.SHA1.hash(data: uuidBytes(namespace) + Data(name.utf8))
    var bytes = Array(digest)
    bytes[6] = (bytes[6] & 0x0F) | 0x50
    bytes[8] = (bytes[8] & 0x3F) | 0x80
    return UUID(uuid: (
      bytes[0], bytes[1], bytes[2], bytes[3],
      bytes[4], bytes[5], bytes[6], bytes[7],
      bytes[8], bytes[9], bytes[10], bytes[11],
      bytes[12], bytes[13], bytes[14], bytes[15]
    ))
  }

  static func uuidBytes(_ uuid: UUID) -> Data {
    let hex = uuid.uuidString.replacing("-", with: "")
    return Data(stride(from: 0, to: hex.count, by: 2).map { offset in
      UInt8(hex.dropFirst(offset).prefix(2), radix: 16)!
    })
  }

  static func sha256Hex(of value: String) -> String {
    SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
  }

  static func normalizeText(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
      .split(whereSeparator: \.isWhitespace)
      .joined(separator: " ")
      .lowercased()
  }

  static func nonEmpty(_ value: String?) -> String? {
    value?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
  }
}

private extension String {
  var nilIfEmpty: Self? { isEmpty ? nil : self }
}
