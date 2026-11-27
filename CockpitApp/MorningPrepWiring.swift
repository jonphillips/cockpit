import CockpitCore
import Dependencies
import Foundation
import SQLiteData

@MainActor
enum MorningPrepWiring {
  static let shared = make()

  static func make() -> MorningPrep {
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.feedClient) var feedClient
    @Dependency(\.gmailDispositionClient) var dispositionClient
    let activeFeedClient = feedClient
    let activeDatabase = database

    let client = MorningPrepClient(
      lastMailSync: { try await GmailAutoSyncPolicy.lastSyncedAt(in: database) },
      syncMail: {
        let token: String
        do { token = try await GmailDispositionWiring.refreshedAccessToken() }
        catch { throw MorningPrepAuthorizationError.notAuthorized }
        do {
          let report = try await GmailInboxIngestor(
            client: .live(accessToken: token)
          ).ingest(into: database)
          return report.contentPieces.count
        } catch {
          if GmailInboxAuthorization.isRejected(error) {
            throw MorningPrepAuthorizationError.notAuthorized
          }
          throw error
        }
      },
      applyPolicies: {
        _ = try? await GmailDispositionPolicyService(client: dispositionClient)
          .applyEnabledPolicies(in: database)
      },
      lastFeedPoll: {
        let runs = MorningPrepRecordStore.live().records
        return runs.first(where: { run in
          if case let .completed(_, attempted)? = run.feeds { return attempted > 0 }
          return false
        })?.endedAt
      },
      pollFeeds: { maximumConcurrent, totalTimeout in
        await pollFeeds(
          maximumConcurrent: maximumConcurrent, totalTimeout: totalTimeout,
          client: activeFeedClient, database: activeDatabase)
      },
      processOffers: { limit in
        guard let value = try? await EmailTreatmentProcessor().processUnextractedPieces(
          limit: limit, in: database
        ) else { return (0, 0) }
        return value
      }
    )
    return MorningPrep(client: client)
  }

  private static func pollFeeds(
    maximumConcurrent: Int, totalTimeout: Duration, client: FeedClient,
    database: any DatabaseWriter
  ) async -> (succeeded: Int, attempted: Int) {
    try? await database.write { db in try StreamOperations.insertSeedsIfMissing(in: db) }
    let streams = (try? await database.read { db in try StreamOperations.activeStreams(in: db) }) ?? []
    var succeeded = 0
    var attempted = 0
    for start in stride(from: 0, to: streams.count, by: max(1, maximumConcurrent)) {
      let batch = Array(streams[start..<min(start + maximumConcurrent, streams.count)])
      let outcomes = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
        for stream in batch {
          group.addTask {
            do {
              try await withFeedTimeout(totalTimeout) {
                _ = try await FeedIngestor(client: client).ingest(stream: stream, into: database)
              }
              return true
            } catch is FeedRequestTimeout {
              await FeedIngestor.recordTimeout(stream: stream, in: database)
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
