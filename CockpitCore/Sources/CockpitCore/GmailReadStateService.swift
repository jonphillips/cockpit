import Dependencies
import Foundation
import os
import SQLiteData

/// Provider read-state mutations are deliberately separate from Gmail dispositions. They neither
/// pass through the disposition barrier nor create disposition history entries.
public struct GmailReadStateClient: Sendable {
  public var markRead: @Sendable (String) async throws -> Void
  public var markUnread: @Sendable (String) async throws -> Void

  public init(
    markRead: @escaping @Sendable (String) async throws -> Void,
    markUnread: @escaping @Sendable (String) async throws -> Void
  ) {
    self.markRead = markRead
    self.markUnread = markUnread
  }

  public static func live(accessToken: String) -> Self {
    let api = GmailDispositionAPI(accessToken: accessToken)
    return Self(
      markRead: { try await api.markRead(messageID: $0) },
      markUnread: { try await api.markUnread(messageID: $0) }
    )
  }
}

extension GmailReadStateClient: DependencyKey {
  public static let liveValue = GmailReadStateClient(
    markRead: { _ in throw GmailDispositionConfigurationError.notConfigured },
    markUnread: { _ in throw GmailDispositionConfigurationError.notConfigured }
  )
  public static let testValue = liveValue
}

extension DependencyValues {
  public var gmailReadStateClient: GmailReadStateClient {
    get { self[GmailReadStateClient.self] }
    set { self[GmailReadStateClient.self] = newValue }
  }
}

public struct GmailReadStateService: Sendable {
  private static let logger = Logger(subsystem: "com.jonphillips.cockpit", category: "GmailReadState")
  private let client: GmailReadStateClient

  public init(client: GmailReadStateClient) { self.client = client }

  /// Marks each unread Gmail message backing this ContentPiece as read. A failure leaves its local
  /// mirror untouched, so a later Reader open retries naturally.
  public func markReadOnOpen(
    contentPieceID: ContentPiece.ID, in database: any DatabaseWriter
  ) async {
    await update(contentPieceID: contentPieceID, toUnread: false, onlyUnread: true, in: database)
  }

  /// Explicitly marks each Gmail message backing this ContentPiece unread.
  public func markUnread(
    contentPieceID: ContentPiece.ID, in database: any DatabaseWriter
  ) async {
    await update(contentPieceID: contentPieceID, toUnread: true, onlyUnread: false, in: database)
  }

  private func update(
    contentPieceID: ContentPiece.ID, toUnread: Bool, onlyUnread: Bool,
    in database: any DatabaseWriter
  ) async {
    let artifacts: [Artifact]
    do {
      artifacts = try await database.read { db in
        let matching = try Artifact.where { $0.contentPieceID.eq(contentPieceID) }.fetchAll(db)
        return matching.filter {
          $0.transport == .gmail && (!onlyUnread || $0.providerIsUnread == true)
        }
      }
    } catch {
      return
    }
    for artifact in artifacts {
      guard let messageID = Self.messageID(from: artifact.providerID) else { continue }
      do {
        if toUnread { try await client.markUnread(messageID) }
        else { try await client.markRead(messageID) }
        try await database.write { db in
          try Artifact.find(artifact.id).update { $0.providerIsUnread = #bind(toUnread) }.execute(db)
        }
      } catch {
        Self.logger.warning("Gmail read-state update failed for message \(messageID, privacy: .private): \(error.localizedDescription, privacy: .public)")
      }
    }
  }

  static func messageID(from providerID: String?) -> String? {
    guard let providerID, providerID.hasPrefix("gmail:"),
      let marker = providerID.range(of: ":message:")
    else { return nil }
    return String(providerID[marker.upperBound...])
  }
}
