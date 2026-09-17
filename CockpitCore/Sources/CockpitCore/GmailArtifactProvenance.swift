import Foundation

/// Raw, device-local provenance S5 will read deterministically. This intentionally preserves
/// header values rather than assigning a treatment or building a reputation system.
public struct GmailArtifactProvenance: Codable, Equatable, Sendable {
  public let accountID: String
  public let messageID: String
  public let threadID: String
  public let rfcMessageID: String?
  public let listUnsubscribe: String?
  public let listID: String?
  public let precedence: String?
  /// The exact sender mailbox is retained only to resolve an explicit Gmail Stream locator. It is
  /// not used as a learned reputation signal or synchronized identity.
  public let senderAddress: String?
  public let sendingDomain: String?
  public let dkimDomain: String?
  public let toRecipientCount: Int
  public let ccRecipientCount: Int

  static func make(accountID: String, message: GmailInboxMessage) -> Self {
    Self(
      accountID: GmailInboxIngestor.canonicalAccountID(accountID),
      messageID: message.id,
      threadID: message.threadID,
      rfcMessageID: message.header(named: "Message-ID"),
      listUnsubscribe: message.header(named: "List-Unsubscribe"),
      listID: message.header(named: "List-ID"),
      precedence: message.header(named: "Precedence"),
      senderAddress: GmailHeaderParser.senderKey(from: message.header(named: "From")),
      sendingDomain: GmailHeaderParser.sendingDomain(from: message.header(named: "From")),
      dkimDomain: GmailHeaderParser.dkimDomain(from: message.header(named: "DKIM-Signature")),
      toRecipientCount: GmailHeaderParser.recipientCount(in: message.header(named: "To")),
      ccRecipientCount: GmailHeaderParser.recipientCount(in: message.header(named: "Cc"))
    )
  }
}
