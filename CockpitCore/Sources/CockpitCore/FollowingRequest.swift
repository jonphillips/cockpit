import Foundation
import SQLiteData

public struct FollowingRequest: FetchKeyRequest {
  @Selection
  public struct Row: Equatable, Identifiable, Sendable {
    public let id: Stream.ID
    public let name: String
    public let publisher: String
    public let interestAreaName: String?
    public let transport: StreamTransport
    public let locator: String
    public let handlingGuidance: String
    public let isEssential: Bool
    public let followState: StreamFollowState
    public let health: StreamHealth?
    public let lastReceivedAt: Date?
    public let consecutiveFailureCount: Int?
    public let lastFailureDescription: String?

    public var effectiveHealth: StreamHealth { health ?? .unknown }
    public var failureCount: Int { consecutiveFailureCount ?? 0 }
  }

  public struct Value: Equatable, Sendable {
    public var rows: [Row] = []
    public init() {}
  }

  public init() {}

  public func fetch(_ db: Database) throws -> Value {
    var value = Value()
    value.rows = try Stream
      .leftJoin(InterestArea.all) { $0.interestAreaID.eq($1.id) }
      .order { ($1.name, $0.name, $0.id) }
      .leftJoin(StreamPollState.all) { $0.id.eq($2.streamID) }
      .select {
        Row.Columns(
          id: $0.id,
          name: $0.name,
          publisher: $0.publisher,
          interestAreaName: $1.name,
          transport: $0.transport,
          locator: $0.locator,
          handlingGuidance: $0.handlingGuidance,
          isEssential: $0.isEssential,
          followState: $0.followState,
          health: $2.health,
          lastReceivedAt: $2.lastReceivedAt,
          consecutiveFailureCount: $2.consecutiveFailureCount,
          lastFailureDescription: $2.lastFailureDescription
        )
      }
      .fetchAll(db)
    return value
  }
}
