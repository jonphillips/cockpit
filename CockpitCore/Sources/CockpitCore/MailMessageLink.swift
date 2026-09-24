import Foundation

/// Builds the opaque message URL understood by Mail.app for an RFC 5322 Message-ID.
public enum MailMessageLink {
  public static func url(rfcMessageID: String?) -> URL? {
    guard var messageID = rfcMessageID?.trimmingCharacters(in: .whitespacesAndNewlines),
          !messageID.isEmpty
    else { return nil }

    if messageID.first == "<", messageID.last == ">" {
      messageID.removeFirst()
      messageID.removeLast()
    }
    guard !messageID.isEmpty,
          !messageID.unicodeScalars.contains(where: CharacterSet.whitespacesAndNewlines.contains)
    else { return nil }

    let encoded = messageID.utf8.map { byte -> String in
      if isUnreserved(byte) || byte == 0x40 { return String(UnicodeScalar(byte)) }
      return String(format: "%%%02X", byte)
    }.joined()
    return URL(string: "message:%3C\(encoded)%3E")
  }

  private static func isUnreserved(_ byte: UInt8) -> Bool {
    (0x41...0x5A).contains(byte) || (0x61...0x7A).contains(byte)
      || (0x30...0x39).contains(byte) || [0x2D, 0x2E, 0x5F, 0x7E].contains(byte)
  }
}
