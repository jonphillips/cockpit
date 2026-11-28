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
      try await scheduleBackgroundRefresh(at: date)
    }
    return MorningPrep(client: client, scheduler: scheduler)
  }

  static func handleBackgroundRefresh() async {
    _ = await shared.run(.init(trigger: .backgroundRefresh, timeBudget: MorningPrep.unattendedBudget))
  }

  /// Performs Cockpit's existing Gmail ingestion once for a tapped Offer Watch message. It does not
  /// apply disposition policies; the tap path only needs to make the source available to Reader.
  static func syncMailOnce() async throws {
    @Dependency(\.defaultDatabase) var database
    let token = try await GmailDispositionWiring.refreshedAccessToken()
    _ = try await GmailInboxIngestor(client: .live(accessToken: token)).ingest(into: database)
  }

  private static func scheduleBackgroundRefresh(at date: Date) async throws {
    let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
    request.earliestBeginDate = date
    do {
      try await BGTaskScheduler.shared.submitTaskRequest(request)
    } catch let error as BGTaskScheduler.Error {
      switch error.code {
      case .unavailable:
        throw MorningPrepSchedulerMessage(
          "Background App Refresh is off for Cockpit, or iPadOS can't schedule it right now.")
      case .tooManyPendingTaskRequests:
        throw MorningPrepSchedulerMessage("Too many Cockpit background refresh requests are pending.")
      case .notPermitted:
        throw MorningPrepSchedulerMessage(
          "Cockpit's background refresh identifier or mode is missing from Info.plist.")
      default:
        throw error
      }
    }
  }
}

private struct MorningPrepSchedulerMessage: LocalizedError {
  let message: String
  var errorDescription: String? { message }

  init(_ message: String) { self.message = message }
}
