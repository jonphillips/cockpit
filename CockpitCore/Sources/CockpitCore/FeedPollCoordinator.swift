import Foundation
import SQLiteData

/// Seeds and polls active Streams through the same injectable FeedClient used by Following.
public enum FeedPollCoordinator {
  public static func poll(
    maximumConcurrent: Int, totalTimeout: Duration,
    client: FeedClient, database: any DatabaseWriter
  ) async -> (succeeded: Int, attempted: Int) {
    do {
      try await database.write { db in try StreamOperations.insertSeedsIfMissing(in: db) }
      let streams = try await database.read { db in try StreamOperations.activeStreams(in: db) }
      var succeeded = 0
      var attempted = 0
      let batchSize = max(1, maximumConcurrent)
      for start in stride(from: 0, to: streams.count, by: batchSize) {
        let batch = Array(streams[start..<min(start + batchSize, streams.count)])
        let outcomes = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
          for stream in batch {
            group.addTask {
              let before = try? await database.read { db in
                try StreamPollState.find(stream.id).fetchOne(db)
              }
              do {
                try await withFeedTimeout(totalTimeout) {
                  _ = try await FeedIngestor(client: client).ingest(stream: stream, into: database)
                }
                return true
              } catch is FeedRequestTimeout {
                await FeedIngestor.recordTimeout(
                  stream: stream, ifUnchangedFrom: before, in: database)
                return false
              } catch {
                return false
              }
            }
          }
          var results: [Bool] = []
          for await result in group { results.append(result) }
          return results
        }
        attempted += outcomes.count
        succeeded += outcomes.filter { $0 }.count
      }
      return (succeeded, attempted)
    } catch {
      return (0, 0)
    }
  }

  private static func withFeedTimeout<T: Sendable>(
    _ duration: Duration, operation: @escaping @Sendable () async throws -> T
  ) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
      group.addTask { try await operation() }
      group.addTask {
        try await Task.sleep(for: duration)
        throw FeedRequestTimeout()
      }
      guard let result = try await group.next() else { throw FeedRequestTimeout() }
      group.cancelAll()
      return result
    }
  }
}
