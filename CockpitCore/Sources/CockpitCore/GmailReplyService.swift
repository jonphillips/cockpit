import Dependencies
import Foundation
import Observation
import SQLiteData

/// Reply header reads may be retried by the API. Sending is intentionally a single attempt because
/// retrying an ambiguous provider failure could send the same reply twice.
public struct GmailReplyClient: Sendable {
  public var replyHeaders: @Sendable (_ messageID: String) async throws -> GmailReplyHeaders
  public var send: @Sendable (_ raw: String, _ threadID: String) async throws -> Void

  public init(
    replyHeaders: @escaping @Sendable (_ messageID: String) async throws -> GmailReplyHeaders,
    send: @escaping @Sendable (_ raw: String, _ threadID: String) async throws -> Void
  ) {
    self.replyHeaders = replyHeaders
    self.send = send
  }

  public static func live(accessToken: String) -> Self {
    let api = GmailReplyAPI(accessToken: accessToken)
    return Self(
      replyHeaders: { try await api.replyHeaders(messageID: $0) },
      send: { raw, threadID in try await api.send(raw: raw, threadID: threadID) }
    )
  }
}

public enum GmailReplyConfigurationError: LocalizedError, Equatable, Sendable {
  case notConfigured
  case missingProvenance

  public var errorDescription: String? {
    switch self {
    case .notConfigured: "Gmail reply is not configured for this account."
    case .missingProvenance: "This message is missing its Gmail reply identity."
    }
  }
}

extension GmailReplyClient: DependencyKey {
  public static let liveValue = GmailReplyClient(
    replyHeaders: { _ in throw GmailReplyConfigurationError.notConfigured },
    send: { _, _ in throw GmailReplyConfigurationError.notConfigured }
  )
  public static let testValue = liveValue
}

extension DependencyValues {
  public var gmailReplyClient: GmailReplyClient {
    get { self[GmailReplyClient.self] }
    set { self[GmailReplyClient.self] = newValue }
  }
}

/// Reply composer state for one Gmail ContentPiece. The Gmail identity is read from the existing
/// Artifact provenance; reply headers themselves are fetched on demand and never persisted.
@MainActor
@Observable
public final class ReaderReplyModel {
  @ObservationIgnored @Dependency(\.defaultDatabase) private var database
  @ObservationIgnored @Dependency(\.gmailReplyClient) private var client
  public let contentPieceID: ContentPiece.ID
  public private(set) var headers: GmailReplyHeaders?
  public private(set) var isLoading = false
  public private(set) var isSending = false
  public private(set) var didSend = false
  public var body = ""
  public var errorMessage: String?

  private var accountAddress: String?
  private var threadID: String?

  public init(contentPieceID: ContentPiece.ID) { self.contentPieceID = contentPieceID }

  public var recipientDisplay: String { SenderDisplayName.make(from: headers?.recipient) }
  public var recipientAddress: String { GmailHeaderParser.senderKey(from: headers?.recipient) ?? "" }
  public var recipientSummary: String {
    let display = recipientDisplay
    let address = recipientAddress
    guard !address.isEmpty else { return display }
    guard !display.isEmpty, display.caseInsensitiveCompare(address) != .orderedSame else { return address }
    return "\(display) <\(address)>"
  }
  public var subject: String { headers?.replySubject ?? "" }
  public var canSend: Bool {
    !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !isLoading && !isSending && !didSend && headers != nil
  }

  public func load() async {
    guard !isLoading else { return }
    isLoading = true
    defer { isLoading = false }
    errorMessage = nil
    do {
      let contentPieceID = self.contentPieceID
      let provenance = try await database.read { db -> GmailArtifactProvenance? in
        try GmailArtifactProvenance.latest(forContentPiece: contentPieceID, in: db)
      }
      guard let provenance else { throw GmailReplyConfigurationError.missingProvenance }
      let headers = try await client.replyHeaders(provenance.messageID)
      self.accountAddress = provenance.accountID
      self.threadID = provenance.threadID
      self.headers = headers
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// Sends once. `archive` is the caller's existing queue-aware disposition action.
  public func send(thenArchive: Bool, archive: @MainActor () async -> Void = {}) async {
    guard canSend, let headers, let accountAddress, let threadID else { return }
    isSending = true
    errorMessage = nil
    defer { isSending = false }
    do {
      let raw = GmailReplyMessage.make(original: headers, fromAddress: accountAddress, body: body)
      try await client.send(raw, threadID)
      didSend = true
      if thenArchive { await archive() }
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
