import Foundation
import SQLiteData

public struct FeedRequestTimeout: LocalizedError, Sendable {
  public init() {}
  public var errorDescription: String? { "The feed request exceeded its 10-second time limit." }
}

extension FeedIngestor {
  public static func recordTimeout(stream: Stream, in database: any DatabaseWriter) async {
    let description = FeedRequestTimeout().localizedDescription
    try? await database.write { db in
      let previous = try StreamPollState.find(stream.id).fetchOne(db)
      try StreamPollState.upsert {
        StreamPollState.Draft(
          streamID: stream.id, health: .failed,
          lastReceivedAt: previous?.lastReceivedAt,
          consecutiveFailureCount: (previous?.consecutiveFailureCount ?? 0) + 1,
          lastFailureDescription: description
        )
      }.execute(db)
    }
  }
}
