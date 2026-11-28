import Dependencies
import Foundation
import Observation
import SQLiteData

@MainActor
@Observable
public final class FollowingModel {
  @ObservationIgnored @Dependency(\.defaultDatabase) private var database
  @ObservationIgnored @Dependency(\.feedClient) private var feedClient
  @ObservationIgnored @Dependency(\.uuid) private var uuid
  @ObservationIgnored private let morningPrep: MorningPrep?
  @ObservationIgnored @Fetch(FollowingRequest()) public var following = .init()
  @ObservationIgnored @Fetch(TransactionalCorrectionRequest())
  public var transactionalCorrections = TransactionalCorrectionRequest.Value()

  public var addURL = ""
  public var proposedStream: StreamDraft?
  public var editingStream: StreamDraft?
  public var routingRules: [ContentRoleRoutingRule] = []
  public var discoveredLocators: [DiscoveredLocator] = []
  public var errorMessage: String?

  public init(morningPrep: MorningPrep? = nil) { self.morningPrep = morningPrep }

  public var rows: [FollowingRequest.Row] { following.rows }

  /// Pull-to-refresh delegates to the shared acquisition operation.
  public func acquireOnLaunchOrRefresh() async {
    guard let morningPrep else { return }
    _ = await morningPrep.run(.init(trigger: .manual))
  }

  public func discoverButtonTapped() async {
    guard let url = URL(string: addURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      errorMessage = FeedDiscoveryError.invalidURL(addURL).localizedDescription
      return
    }
    do {
      let discovery = try await FeedDiscovery.discover(from: url, using: feedClient)
      proposedStream = StreamDraft(
        name: discovery.feed.title,
        publisher: discovery.feed.publisher,
        transport: discovery.feed.transport,
        locator: discovery.url.absoluteString
      )
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  @discardableResult
  public func followButtonTapped() async -> Bool {
    guard let proposedStream else { return false }
    if await save(proposedStream) {
      self.proposedStream = nil
      addURL = ""
      return true
    }
    return false
  }

  public func editButtonTapped(_ row: FollowingRequest.Row) {
    editingStream = StreamDraft(
      id: row.id,
      name: row.name,
      publisher: row.publisher,
      transport: row.transport,
      locator: row.locator,
      interestAreaName: row.interestAreaName ?? "General",
      handling: row.handling,
      handlingGuidance: row.handlingGuidance,
      isEssential: row.isEssential
    )
  }

  public func saveEditingButtonTapped() async {
    guard let editingStream else { return }
    if await save(editingStream) {
      self.editingStream = nil
    }
  }

  public func followStateButtonTapped(_ state: StreamFollowState, for id: Stream.ID) async {
    do {
      try await database.write { db in try StreamOperations.setFollowState(state, for: id, in: db) }
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func save(_ draft: StreamDraft) async -> Bool {
    let streamID = draft.id ?? uuid()
    let interestAreaID = uuid()
    do {
      try await database.write { db in
        try StreamOperations.save(
          draft, streamID: streamID, interestAreaID: interestAreaID, in: db
        )
      }
      errorMessage = nil
      return true
    } catch is CancellationError {
      return false
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }
}

extension FollowingModel {
  public func loadRoutingRules() async {
    do {
      let snapshot = try await database.read { db in
        try CurationRouting.snapshot(in: db)
      }
      routingRules = snapshot.routingRules.values.sorted { $0.locator < $1.locator }
      discoveredLocators = snapshot.discoveredLocators
      try await $transactionalCorrections.load()
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func removeTransactionalCorrection(for sender: String) async {
    do {
      try await database.write { db in
        _ = try EmailTreatmentOperations.removeSenderOverride(for: sender, in: db)
      }
      try await $transactionalCorrections.load()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func saveRoutingRule(_ rule: ContentRoleRoutingRule) async {
    do {
      try await database.write { db in
        try StreamOperations.saveRoutingRule(rule, in: db)
      }
      await loadRoutingRules()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
