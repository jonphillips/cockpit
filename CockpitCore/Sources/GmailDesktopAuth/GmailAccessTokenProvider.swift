import Foundation

public actor GmailAccessTokenProvider {
  private let refresh: @Sendable () async throws -> GmailAccessToken
  private let now: @Sendable () -> Date
  private let refreshLeadTime: TimeInterval = 5 * 60
  private var cached: GmailAccessToken?

  public init(
    refresh: @escaping @Sendable () async throws -> GmailAccessToken,
    now: @escaping @Sendable () -> Date = Date.init
  ) {
    self.refresh = refresh
    self.now = now
  }

  public func token() async throws -> String {
    if let cached, cached.expiresAt.timeIntervalSince(now()) > refreshLeadTime {
      return cached.value
    }
    let fresh = try await refresh()
    cached = fresh
    return fresh.value
  }
}
