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
  @ObservationIgnored @Fetch(FollowingRequest()) public var following = .init()

  public var addURL = ""
  public var proposedStream: StreamDraft?
  public var editingStream: StreamDraft?
  public var errorMessage: String?

  public init() {}

  public var rows: [FollowingRequest.Row] { following.rows }

  /// The sole launch and pull-to-refresh acquisition entry point. Seeding precedes the first
  /// poll so a fresh installation immediately starts accumulating the S4 fixture pool.
  public func acquireOnLaunchOrRefresh() async {
    await insertSeedsIfNeeded()
    let streams: [Stream]
    do {
      streams = try await database.read { db in try StreamOperations.activeStreams(in: db) }
    } catch is CancellationError {
      return
    } catch {
      errorMessage = error.localizedDescription
      return
    }
    for stream in streams {
      do {
        _ = try await FeedIngestor(client: feedClient).ingest(stream: stream, into: database)
      } catch is CancellationError {
        return
      } catch {
        // The Stream row records the exact failure and exposes it in Following. One bad feed
        // must not stop acquisition from the remaining active Streams.
      }
    }
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

  private func insertSeedsIfNeeded() async {
    do {
      try await database.write { db in try StreamOperations.insertSeedsIfMissing(in: db) }
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
