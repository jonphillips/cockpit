import Foundation

/// The reply-time subset of a Gmail message's RFC 5322 headers. These are fetched when the Reader
/// opens Reply and are deliberately not added to persisted Gmail provenance.
public struct GmailReplyHeaders: Equatable, Sendable {
  public let from: String
  public let replyTo: String?
  public let subject: String
  public let messageID: String
  public let references: String?

  public init(from: String, replyTo: String?, subject: String, messageID: String, references: String?) {
    self.from = from
    self.replyTo = replyTo
    self.subject = subject
    self.messageID = messageID
    self.references = references
  }

  public var recipient: String { replyTo ?? from }
  public var replySubject: String {
    subject.range(of: #"^\s*Re\s*:"#, options: [.caseInsensitive, .regularExpression]) == nil
      ? "Re: \(subject)" : subject
  }
}

/// Builds the one supported outgoing message shape: plain text, addressed to the sender, and
/// threaded with Gmail's original Message-ID and thread ID.
public enum GmailReplyMessage {
  public static func make(original: GmailReplyHeaders, fromAddress: String, body: String) -> String {
    let subject = encodedHeader(original.replySubject)
    let references = [original.references?.trimmingCharacters(in: .whitespacesAndNewlines), original.messageID]
      .compactMap { $0 }
      .filter { !$0.isEmpty }
      .joined(separator: " ")
    let normalizedBody = body
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .replacingOccurrences(of: "\n", with: "\r\n")
    let encodedBody = Data(normalizedBody.utf8).base64EncodedString(options: [.lineLength76Characters, .endLineWithLineFeed])
      .replacingOccurrences(of: "\n", with: "\r\n")
    return [
      "From: \(safeHeader(fromAddress))",
      "To: \(safeHeader(original.recipient))",
      "Subject: \(subject)",
      "In-Reply-To: \(safeHeader(original.messageID))",
      "References: \(safeHeader(references))",
      "MIME-Version: 1.0",
      "Content-Type: text/plain; charset=UTF-8",
      "Content-Transfer-Encoding: base64",
      "",
      encodedBody,
    ].joined(separator: "\r\n")
  }

  private static func encodedHeader(_ value: String) -> String {
    guard value.unicodeScalars.contains(where: { $0.value > 127 }) else { return safeHeader(value) }
    let chunks = utf8Chunks(value, maximumBytes: 45)
    return chunks.map { "=?UTF-8?B?\(Data($0.utf8).base64EncodedString())?=" }
      .joined(separator: "\r\n ")
  }

  private static func utf8Chunks(_ value: String, maximumBytes: Int) -> [String] {
    var chunks: [String] = []
    var current = ""
    var currentBytes = 0
    for character in value {
      let characterBytes = String(character).utf8.count
      if currentBytes + characterBytes > maximumBytes, !current.isEmpty {
        chunks.append(current)
        current = ""
        currentBytes = 0
      }
      current.append(character)
      currentBytes += characterBytes
    }
    if !current.isEmpty { chunks.append(current) }
    return chunks
  }

  private static func safeHeader(_ value: String) -> String {
    value.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
  }
}
