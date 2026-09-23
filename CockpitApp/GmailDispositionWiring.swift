import CockpitCore
import GoogleSignIn

/// Supplies the authorized live `GmailDispositionClient` the app injects for real provider writes.
/// Each label operation refreshes the Gmail access token first, so a long-running session never
/// mutates with a stale credential. The barrier and Undo logic live in `GmailDispositionService`
/// (CockpitCore); this file is only the auth glue, and is verified on device.
enum GmailDispositionWiring {
  static var liveClient: GmailDispositionClient {
    GmailDispositionClient(
      archive: { try await client().archive($0) },
      trash: { try await client().trash($0) },
      reAddInbox: { try await client().reAddInbox($0) },
      untrash: { try await client().untrash($0) }
    )
  }

  private static func client() async throws -> GmailDispositionClient {
    .live(accessToken: try await accessToken())
  }

  fileprivate static func accessTokenForReply() async throws -> String { try await accessToken() }

  @MainActor
  private static func accessToken() async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
      GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
        guard let user else {
          continuation.resume(throwing: error ?? GmailDispositionAuthError.missingAuthorization)
          return
        }
        user.refreshTokensIfNeeded { refreshedUser, refreshError in
          if let refreshedUser {
            continuation.resume(returning: refreshedUser.accessToken.tokenString)
          } else {
            continuation.resume(throwing: refreshError ?? GmailDispositionAuthError.missingToken)
          }
        }
      }
    }
  }
}

/// Supplies the reply client using the same refreshed Gmail token as source disposition. Unlike
/// the idempotent disposition API, this client never retries send.
enum GmailReplyWiring {
  static var liveClient: GmailReplyClient {
    GmailReplyClient(
      replyHeaders: { messageID in
        let client = GmailReplyClient.live(
          accessToken: try await GmailDispositionWiring.accessTokenForReply())
        return try await client.replyHeaders(messageID)
      },
      send: { raw, threadID in
        let client = GmailReplyClient.live(
          accessToken: try await GmailDispositionWiring.accessTokenForReply())
        try await client.send(raw, threadID)
      }
    )
  }
}

private enum GmailDispositionAuthError: LocalizedError {
  case missingAuthorization
  case missingToken

  var errorDescription: String? {
    switch self {
    case .missingAuthorization: "No stored Google authorization was found."
    case .missingToken: "Google returned no refreshed Gmail access token."
    }
  }
}
