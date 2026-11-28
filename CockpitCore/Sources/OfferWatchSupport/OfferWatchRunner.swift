import Foundation
import CockpitCore
import GmailDesktopAuth

public enum OfferWatchStatusKind: String, Sendable {
  case revokedGrant
  case rejectedToken
  case accountChanged
  case missingConfiguration
  case unreadableList
  case unreadableState

  public var title: String { "Offer Watch needs attention" }
  public var message: String {
    switch self {
    case .revokedGrant: "Gmail access was revoked. Run offerwatch auth."
    case .rejectedToken: "Gmail rejected its access token. Run offerwatch auth."
    case .accountChanged: "The authorized Gmail account changed. Review Offer Watch setup."
    case .missingConfiguration: "Offer Watch is missing setup configuration. Check the Mac logs."
    case .unreadableList: "watched.txt couldn't be read; using the last good copy."
    case .unreadableState: "Offer Watch state is unreadable. Check the Mac logs before restarting."
    }
  }
}

public struct OfferWatchRunnerConfiguration: Sendable {
  public let hasClientPath: Bool
  public let hasAPNsKey: Bool
  public let hasAPNsIdentity: Bool
  public init(hasClientPath: Bool, hasAPNsKey: Bool, hasAPNsIdentity: Bool) {
    self.hasClientPath = hasClientPath
    self.hasAPNsKey = hasAPNsKey
    self.hasAPNsIdentity = hasAPNsIdentity
  }
}

public struct OfferWatchRuntimeDependencies: Sendable {
  public var accessToken: @Sendable () async throws -> String
  public var accountID: @Sendable (String) async throws -> String
  public var watchedAddresses: @Sendable () async throws -> WatchedAddressList
  public var listIDs: @Sendable (String, Date, String) async throws -> [String]
  public var fetchMessage: @Sendable (String, String) async throws -> WatchedMail
  public var send: @Sendable (OfferWatchAlert, OfferWatchPairing, Bool) async throws -> APNsDelivery
  public var loadState: @Sendable () async throws -> OfferWatchState
  public var saveState: @Sendable (OfferWatchState) async throws -> Void
  public var loadPairings: @Sendable () async throws -> [OfferWatchPairing]
  public var removePairings: @Sendable (Set<String>) async throws -> Void
  public var now: @Sendable () -> Date
  public var calendar: @Sendable () -> Calendar
  public var sleep: @Sendable (Duration) async throws -> Void
  public var log: @Sendable (String) -> Void

  public init(
    accessToken: @escaping @Sendable () async throws -> String,
    accountID: @escaping @Sendable (String) async throws -> String,
    watchedAddresses: @escaping @Sendable () async throws -> WatchedAddressList,
    listIDs: @escaping @Sendable (String, Date, String) async throws -> [String],
    fetchMessage: @escaping @Sendable (String, String) async throws -> WatchedMail,
    send: @escaping @Sendable (OfferWatchAlert, OfferWatchPairing, Bool) async throws -> APNsDelivery,
    loadState: @escaping @Sendable () async throws -> OfferWatchState,
    saveState: @escaping @Sendable (OfferWatchState) async throws -> Void,
    loadPairings: @escaping @Sendable () async throws -> [OfferWatchPairing],
    removePairings: @escaping @Sendable (Set<String>) async throws -> Void,
    now: @escaping @Sendable () -> Date = Date.init,
    calendar: @escaping @Sendable () -> Calendar = { .current },
    sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
    log: @escaping @Sendable (String) -> Void = { _ in }
  ) {
    self.accessToken = accessToken
    self.accountID = accountID
    self.watchedAddresses = watchedAddresses
    self.listIDs = listIDs
    self.fetchMessage = fetchMessage
    self.send = send
    self.loadState = loadState
    self.saveState = saveState
    self.loadPairings = loadPairings
    self.removePairings = removePairings
    self.now = now
    self.calendar = calendar
    self.sleep = sleep
    self.log = log
  }
}

public struct OfferWatchRunner: Sendable {
  public static let pollInterval: Duration = .seconds(120)
  public static let maximumBackoff: Duration = .seconds(30 * 60)
  private let configuration: OfferWatchRunnerConfiguration
  private let dependencies: OfferWatchRuntimeDependencies

  public init(configuration: OfferWatchRunnerConfiguration, dependencies: OfferWatchRuntimeDependencies) {
    self.configuration = configuration
    self.dependencies = dependencies
  }

  /// Terminal conditions report once by kind and exit successfully so launchd does not restart-loop.
  public func run() async {
    var state: OfferWatchState
    do {
      state = try await dependencies.loadState()
    } catch {
      dependencies.log("Offer Watch state could not be read: \(error.localizedDescription)")
      var reportingState = OfferWatchState(now: dependencies.now())
      await report(.unreadableState, state: &reportingState)
      return
    }
    state.establishBaseline(at: dependencies.now())
    guard configuration.hasClientPath, configuration.hasAPNsKey, configuration.hasAPNsIdentity else {
      await report(.missingConfiguration, state: &state)
      try? await dependencies.saveState(state)
      return
    }

    var backoff = Self.pollInterval
    while !Task.isCancelled {
      do {
        try await poll(state: &state)
        backoff = Self.pollInterval
        try await dependencies.sleep(Self.pollInterval)
      } catch is CancellationError {
        return
      } catch let error as OfferWatchRunnerFailure {
        switch error {
        case .accountChanged:
          await report(.accountChanged, state: &state)
          try? await dependencies.saveState(state)
          return
        }
      } catch {
        if let kind = Self.terminalStatus(for: error) {
          await report(kind, state: &state)
          try? await dependencies.saveState(state)
          return
        }
        dependencies.log("Offer Watch transient failure; retrying in \(backoff): \(error.localizedDescription)")
        do { try await dependencies.sleep(backoff) } catch { return }
        backoff = min(backoff * 2, Self.maximumBackoff)
      }
    }
  }

  private func poll(state: inout OfferWatchState) async throws {
    let token = try await dependencies.accessToken()
    let account = try await dependencies.accountID(token)
    if let current = state.accountID, current != account {
      throw OfferWatchRunnerFailure.accountChanged
    }
    state.accountID = account

    let list = try await dependencies.watchedAddresses()
    let now = dependencies.now()
    if list.usedFallback { await report(.unreadableList, state: &state) }
    state.reconcile(addresses: list.addresses, now: now)

    let pairings = try await dependencies.loadPairings()
    let calendar = dependencies.calendar()
    let processor = OfferWatchProcessor(
      listIDs: { address, after in try await dependencies.listIDs(address, after, token) },
      fetchMessage: { try await dependencies.fetchMessage($0, token) },
      send: dependencies.send,
      log: dependencies.log)
    let deadIDs = try await processor.poll(
      state: &state, pairings: pairings, now: now, calendar: calendar)
    if !deadIDs.isEmpty { try await dependencies.removePairings(deadIDs) }
    await processor.sendHeartbeat(
      state: &state, pairings: pairings.filter { !deadIDs.contains($0.id) },
      now: now, calendar: calendar)
    try await dependencies.saveState(state)
  }

  private func report(_ kind: OfferWatchStatusKind, state: inout OfferWatchState) async {
    let now = dependencies.now()
    if let previous = state.lastStatusAt[kind.rawValue],
      dependencies.calendar().isDate(previous, inSameDayAs: now) { return }
    let alert = OfferWatchPayload.status(
      title: kind.title, body: kind.message, collapseID: "offer-watch-status-\(kind.rawValue)")
    if let pairings = try? await dependencies.loadPairings() {
      for pairing in pairings {
        _ = try? await dependencies.send(alert, pairing, true)
      }
    }
    state.lastStatusAt[kind.rawValue] = now
  }

  private static func terminalStatus(for error: any Error) -> OfferWatchStatusKind? {
    if let error = error as? GmailDesktopAuthorizationError {
      switch error {
      case .notAuthorized, .revokedGrant: return .revokedGrant
      case .invalidConfiguration: return .missingConfiguration
      }
    }
    if GmailInboxAuthorization.isRejected(error) { return .rejectedToken }
    if error is WatchedListError { return .unreadableList }
    return nil
  }
}

public enum OfferWatchRunnerFailure: Error, Sendable { case accountChanged }
