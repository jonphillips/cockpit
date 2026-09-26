import Foundation

/// A read-only snapshot of Gmail's current Inbox. The client is injected so persistence and
/// normalization are deterministic in tests; the live constructor issues GET requests only.
public struct GmailInboxClient: Sendable {
  public var currentInbox: @Sendable () async throws -> GmailInboxSnapshot
  /// Fetches only messages that changed since the persisted Gmail history cursor. The account is
  /// supplied so the live transport can reject an accidental account switch before any writes.
  public var inboxChanges: @Sendable (_ accountID: String, _ startHistoryID: String) async throws -> GmailInboxSnapshot
  /// Refreshes labels for existing Gmail messages, using minimal bounded reads in the live client.
  public var refreshUnreadStates: (@Sendable ([String]) async throws -> [String: Bool])?

  public init(
    currentInbox: @escaping @Sendable () async throws -> GmailInboxSnapshot,
    inboxChanges: (@Sendable (_ accountID: String, _ startHistoryID: String) async throws -> GmailInboxSnapshot)? = nil,
    refreshUnreadStates: (@Sendable ([String]) async throws -> [String: Bool])? = nil
  ) {
    self.currentInbox = currentInbox
    // Keeping this fallback makes existing read-only callers deterministic while a dedicated
    // delta closure is introduced. The live client always supplies the real history endpoint.
    self.inboxChanges = inboxChanges ?? { @Sendable _, _ in try await currentInbox() }
    self.refreshUnreadStates = refreshUnreadStates
  }

  public static func live(accessToken: String) -> Self {
    let api = GmailInboxAPI(accessToken: accessToken)
    return Self(
      currentInbox: { try await api.currentInbox() },
      inboxChanges: { accountID, historyID in
        try await api.inboxChanges(accountID: accountID, since: historyID)
      },
      refreshUnreadStates: { try await api.unreadStates(messageIDs: $0) }
    )
  }
}

public struct GmailInboxSnapshot: Equatable, Sendable {
  public let accountID: String
  public let historyID: String?
  public let pageCount: Int
  public let messages: [GmailInboxMessage]
  public let failures: [GmailInboxMessageFailure]
  /// The Gmail message ids that a delta report saw *change* but that are no longer in the Primary
  /// Inbox — archived, trashed, or otherwise moved out of Primary directly in Gmail. The ingestor
  /// reconciles these out of Today so the surface reflects the provider (§Gmail boundary), rather
  /// than growing without bound. A full read carries none: departure is only knowable against a
  /// prior cursor.
  public let departedMessageIDs: [String]

  public init(
    accountID: String,
    historyID: String? = nil,
    pageCount: Int = 1,
    messages: [GmailInboxMessage],
    failures: [GmailInboxMessageFailure] = [],
    departedMessageIDs: [String] = []
  ) {
    self.accountID = accountID
    self.historyID = historyID
    self.pageCount = pageCount
    self.messages = messages
    self.failures = failures
    self.departedMessageIDs = departedMessageIDs
  }
}

/// A per-message read or persistence failure. This report is deliberately not a retry queue: the
/// sync cursor remains unchanged, so Gmail returns the same history range on the next attempt.
public struct GmailInboxMessageFailure: Equatable, Sendable {
  public let messageID: String
  public let description: String

  public init(messageID: String, description: String) {
    self.messageID = messageID
    self.description = description
  }
}

public struct GmailInboxMessage: Equatable, Sendable {
  public let id: String
  public let threadID: String
  public let headers: [GmailInboxHeader]
  public let bodyHTML: String?
  public let bodyPlainText: String?
  public let labelIDs: [String]

  public init(
    id: String,
    threadID: String,
    headers: [GmailInboxHeader],
    bodyHTML: String? = nil,
    bodyPlainText: String? = nil,
    labelIDs: [String] = []
  ) {
    self.id = id
    self.threadID = threadID
    self.headers = headers
    self.bodyHTML = bodyHTML
    self.bodyPlainText = bodyPlainText
    self.labelIDs = labelIDs
  }

  public func header(named name: String) -> String? {
    headers.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
  }

  var normalizedText: String? {
    if let bodyPlainText, !bodyPlainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return HTMLText.normalizedText(from: bodyPlainText)
    }
    return HTMLText.normalizedText(from: bodyHTML)
  }

  var sourceText: String? { bodyHTML ?? bodyPlainText }
}

public struct GmailInboxHeader: Codable, Equatable, Sendable {
  public let name: String
  public let value: String

  public init(name: String, value: String) {
    self.name = name
    self.value = value
  }
}

public struct GmailInboxIngestReport: Equatable, Sendable {
  public let accountID: String
  public let historyID: String?
  public let pageCount: Int
  public let messageCount: Int
  public let contentPieces: [ContentPiece]
  public let failures: [GmailInboxMessageFailure]

  public init(snapshot: GmailInboxSnapshot, contentPieces: [ContentPiece]) {
    accountID = snapshot.accountID
    historyID = snapshot.historyID
    pageCount = snapshot.pageCount
    messageCount = snapshot.messages.count
    self.contentPieces = contentPieces
    failures = snapshot.failures
  }
}
