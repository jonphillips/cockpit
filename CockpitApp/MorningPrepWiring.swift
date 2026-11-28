import CockpitCore
import BackgroundTasks
import Dependencies
import Foundation
import SQLiteData

@MainActor
enum MorningPrepWiring {
  // Must match project.yml's permitted scheduler identifier and Scene's registered task.
  static let backgroundTaskIdentifier = "com.jonphillips.cockpit.morning-prep"
  static let shared = make()

  static func make() -> MorningPrep {
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.feedClient) var feedClient
    @Dependency(\.gmailDispositionClient) var dispositionClient
    let activeFeedClient = feedClient
    let activeDatabase = database
    let emailTreatmentProcessor = EmailTreatmentProcessor()

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
          if case let .completed(succeeded, _)? = run.feeds { return succeeded > 0 }
          return false
        })?.endedAt
      },
      pollFeeds: { maximumConcurrent, totalTimeout in
        await FeedPollCoordinator.poll(
          maximumConcurrent: maximumConcurrent, totalTimeout: totalTimeout,
          client: activeFeedClient, database: activeDatabase)
      },
      processOffers: { limit in
        guard let value = try? await emailTreatmentProcessor.processUnextractedPieces(
          limit: limit, in: database
        ) else { return (0, 0) }
        return value
      }
    )
    let scheduler = MorningPrepSchedulerClient { date in
      let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
      request.earliestBeginDate = date
      try await BGTaskScheduler.shared.submitTaskRequest(request)
    }
    return MorningPrep(client: client, scheduler: scheduler)
  }

  static func handleBackgroundRefresh() async {
    _ = await shared.run(.init(trigger: .backgroundRefresh, timeBudget: MorningPrep.unattendedBudget))
  }

}
