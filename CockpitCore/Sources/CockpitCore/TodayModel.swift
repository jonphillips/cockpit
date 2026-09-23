import Dependencies
import Foundation
import LLMClientKit
import Observation
import SQLiteData

/// Owns the role-oriented orientation projection and Cockpit-only resolution for the Today destination.
/// It has no Gmail provider dependency: `Clear` deliberately cannot perform a provider write.
@MainActor
@Observable
public final class TodayModel {
  public struct RoleSection: Equatable, Identifiable, Sendable {
    public let role: ContentRole
    public let rows: [TodayRequest.Row]

    public var id: ContentRole { role }
    public var title: String { role.displayName }

    public init(role: ContentRole, rows: [TodayRequest.Row]) {
      self.role = role
      self.rows = rows
    }
  }

  public struct PublisherRollup: Equatable, Identifiable, Sendable {
    public let id: String
    public let label: String
    public let rows: [TodayRequest.Row]

    public var count: Int { rows.count }
    public var representative: TodayRequest.Row { rows[0] }

    public init(id: String, label: String, rows: [TodayRequest.Row]) {
      self.id = id
      self.label = label
      self.rows = rows
    }
  }

  @ObservationIgnored @Dependency(\.defaultDatabase) var database
  @ObservationIgnored @Dependency(\.date.now) var now
  @ObservationIgnored @Dependency(\.gmailDispositionClient) var dispositionClient
  @ObservationIgnored @Dependency(\.modelClient) private var modelClient
  @ObservationIgnored @Fetch(TodayRequest()) public var content = .init()
  public var recentTrashes = RecentTrashRequest.Value()
  public var selectedContentPieceID: ContentPiece.ID?
  public var errorMessage: String?

  public init() {}

  public var totalCount: Int { content.rows.count }

  /// The orientation sections are content roles, in the same order used by the future reading
  /// queue. Rows stay in the projection's arrival order within a role.
  public var sections: [RoleSection] {
    ContentRole.allCases.sorted { $0.sortOrder < $1.sortOrder }.compactMap { role in
      let rows = content.rows.filter { $0.role == role }
      return rows.isEmpty ? nil : RoleSection(role: role, rows: rows)
    }
  }

  public func rows(for role: ContentRole) -> [TodayRequest.Row] {
    content.rows.filter { $0.role == role }
  }

  /// Highlights are a navigational sampler only. Every row is selected from an existing section;
  /// this property never creates a second promoted collection or admits anything into Today.
  public var highlightRows: [TodayRequest.Row] {
    sections.compactMap(\.rows.first)
  }

  /// Offers are compacted by publisher for orientation. The rows remain intact behind each group;
  /// this is presentational grouping, not a new Find or entity.
  public var offerGroups: [PublisherRollup] {
    publisherRollups(for: .offers)
  }

  public var roleCounts: [ContentRole: Int] {
    Dictionary(grouping: content.rows, by: \.role).mapValues(\.count)
  }

  public var orientationSummary: String {
    let summaries = ContentRole.allCases.sorted { $0.sortOrder < $1.sortOrder }.compactMap { role -> String? in
      guard let count = roleCounts[role], count > 0 else { return nil }
      return "\(count) \(role.displayName.lowercased())"
    }
    return summaries.isEmpty ? "Nothing curated yet." : summaries.joined(separator: " · ")
  }

  public func clear(_ row: TodayRequest.Row) async {
    let date = now
    do {
      try await database.write { db in
        try TodayAttentionOperations.clear(row.id, at: date, in: db)
      }
      if selectedContentPieceID == row.id { selectedContentPieceID = nil }
      try await $content.load()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// Routes the piece's canonical locator, reloads Today immediately, then schedules any missing
  /// offer extraction independently so model failures cannot block the move.
  public func moveToSection(_ contentPieceID: ContentPiece.ID, to role: ContentRole) async {
    guard role != .transactional else { return }
    do {
      let locator = try await database.write { db -> String? in
        let resolution = try CurationRouting.resolution(for: contentPieceID, in: db)
        guard resolution.role != .transactional else { return nil }
        guard let locator = resolution.locator else { return nil }
        try StreamOperations.saveRoutingRule(
          ContentRoleRoutingRule(locator: locator, role: role, isFollowed: true, isMuted: false),
          in: db)
        return locator
      }
      guard let locator else {
        errorMessage = "This message has no routable locator."
        return
      }
      try await $content.load()
      errorMessage = nil
      guard role == .offers else { return }
      let processor = EmailTreatmentProcessor(modelClient: modelClient)
      let database = database
      Task { [weak self] in
        _ = try? await Task.detached(priority: .utility) {
          try await processor.processUnextractedPieces(for: locator, in: database)
        }.value
        try? await self?.$content.load()
      }
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

}

private extension TodayModel {
  func publisherRollups(for role: ContentRole) -> [PublisherRollup] {
    var groups: [String: [TodayRequest.Row]] = [:]
    var order: [String] = []
    for row in rows(for: role) {
      let key = offerGroupKey(for: row.publisher)
      if groups[key] == nil { order.append(key) }
      groups[key, default: []].append(row)
    }
    return order.compactMap { key in
      guard let rows = groups[key] else { return nil }
      return PublisherRollup(id: key, label: offerGroupLabel(for: rows[0].publisher), rows: rows)
    }
  }

  func offerGroupKey(for publisher: String) -> String {
    publisher
      .split(separator: "<", maxSplits: 1, omittingEmptySubsequences: true)[0]
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
  }

  func offerGroupLabel(for publisher: String) -> String {
    let label = SenderDisplayName.make(from: publisher)
    return label.isEmpty ? "Offers" : label
  }
}

extension TodayModel {
  /// Archives the Gmail source behind the disposition barrier. Independent of `clear`: archiving the
  /// provider message does not resolve Today attention, and clearing does not mutate Gmail (§7).
  public func archive(_ row: TodayRequest.Row) async {
    await applyDisposition(.archive, to: row.id)
  }

  /// Trashes the Gmail source behind the disposition barrier; reversible via `undoDisposition`.
  public func trash(_ row: TodayRequest.Row) async {
    await applyDisposition(.trash, to: row.id)
  }

  /// Archives every message in a landing group (an offer publisher's rows) in one gesture, reloading
  /// the projection once. Each disposition still rides its own barrier. If one row fails the barrier
  /// the batch stops there and surfaces the error; rows disposed before the failure keep their
  /// disposition and leave Today (the reload runs on both paths).
  public func archiveAll(_ rows: [TodayRequest.Row]) async {
    await applyDisposition(.archive, to: rows.map(\.id))
  }

  /// Trashes every message in a landing group in one gesture. Reversible per row via `undoDisposition`.
  public func trashAll(_ rows: [TodayRequest.Row]) async {
    await applyDisposition(.trash, to: rows.map(\.id))
  }

  /// Reverses the message's current disposition, if any, by issuing the inverse label operation.
  public func undoDisposition(_ row: TodayRequest.Row) async {
    await undoDisposition(forContentPieceID: row.id)
  }

  private func applyDisposition(_ disposition: GmailSourceDisposition, to id: ContentPiece.ID) async {
    await applyDisposition(disposition, to: [id])
  }

  private func applyDisposition(_ disposition: GmailSourceDisposition, to ids: [ContentPiece.ID]) async {
    do {
      let service = dispositionService
      for id in ids {
        _ = try await service.apply(disposition, toContentPieceID: id, in: database)
      }
      // The disposition log now hides these rows (`TodayRequest`); reload so Today reflects it now.
      try await $content.load()
      await loadRecentTrashes()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      // A failed barrier aborts the batch, but any rows disposed before it are already durable and
      // hidden by `TodayRequest`; reload so they leave Today instead of lingering until the next load.
      try? await $content.load()
      await loadRecentTrashes()
      errorMessage = error.localizedDescription
    }
  }

  var dispositionService: GmailDispositionService {
    let date = now
    return GmailDispositionService(client: dispositionClient, now: { date })
  }
}

public extension EmailTreatment {
  /// The Today hierarchy is deterministic across types. It is intentionally not importance order.
  static let todayHierarchy: [Self] = [.personal, .newsletter, .offer, .grabBag, .transactional]
}
