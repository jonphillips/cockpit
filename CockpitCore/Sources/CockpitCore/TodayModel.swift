import Dependencies
import Foundation
import Observation
import SQLiteData

/// Owns the stable treatment hierarchy and Cockpit-only resolution for the Today destination.
/// It has no Gmail provider dependency: `Clear` deliberately cannot perform a provider write.
@MainActor
@Observable
public final class TodayModel {
  public struct OfferGroup: Equatable, Identifiable, Sendable {
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

  public struct Tier: Equatable, Identifiable, Sendable {
    public let treatment: EmailTreatment
    public let rows: [TodayRequest.Row]

    public var id: EmailTreatment { treatment }

    public var title: String {
      switch treatment {
      case .personal: "Personal"
      case .newsletter: "Newsletters"
      case .offer: "Offers"
      case .grabBag: "Grab-bags"
      case .transactional: "Transactional"
      }
    }
  }

  @ObservationIgnored @Dependency(\.defaultDatabase) var database
  @ObservationIgnored @Dependency(\.date.now) var now
  @ObservationIgnored @Dependency(\.gmailDispositionClient) var dispositionClient
  @ObservationIgnored @Fetch(TodayRequest()) public var content = .init()
  public var recentTrashes = RecentTrashRequest.Value()
  public var selectedContentPieceID: ContentPiece.ID?
  public var errorMessage: String?

  public init() {}

  /// The live number of visible messages in each treatment. Counts are orientation, not a
  /// completion badge: Clear remains an explicit attention action on an individual message.
  public var tierCounts: [EmailTreatment: Int] {
    Dictionary(grouping: content.rows, by: \.treatment).mapValues(\.count)
  }

  public var totalCount: Int { content.rows.count }

  /// One representative fresh arrival per enticing treatment. The treatment order is fixed and
  /// the row order within a treatment remains the projection's arrival order; this is not ranking.
  /// Personal mail has its own highlight and transactional mail is deliberately not promoted.
  public var promotedRows: [TodayRequest.Row] {
    let cutoff = now.addingTimeInterval(-24 * 60 * 60)
    return [EmailTreatment.newsletter, .offer, .grabBag].compactMap { treatment in
      content.rows.first {
        $0.treatment == treatment && $0.arrivedAt <= now && $0.arrivedAt >= cutoff
      }
    }
  }

  /// Personal mail is highlighted by relationship, not by an importance score. The newest row is
  /// the representative because the projection already preserves arrival order.
  public var personalHighlight: TodayRequest.Row? {
    content.rows.first { $0.treatment == .personal }
  }

  /// Offers are compacted by their retained publisher/domain for the landing surface. The rows
  /// remain intact behind each group; this is presentational grouping, not a new Find or entity.
  public var offerGroups: [OfferGroup] {
    var groups: [String: [TodayRequest.Row]] = [:]
    var order: [String] = []
    for row in content.rows where row.treatment == .offer {
      let key = offerGroupKey(for: row.publisher)
      if groups[key] == nil { order.append(key) }
      groups[key, default: []].append(row)
    }
    return order.compactMap { key in
      guard let rows = groups[key] else { return nil }
      return OfferGroup(id: key, label: offerGroupLabel(for: rows[0].publisher), rows: rows)
    }
  }

  public func count(for treatment: EmailTreatment) -> Int {
    tierCounts[treatment, default: 0]
  }

  /// Cross-type rank is fixed by treatment. Within each tier the projection's arrival order is
  /// preserved exactly; Cockpit does not rank peers by relevance.
  public var tiers: [Tier] {
    EmailTreatment.todayHierarchy.compactMap { treatment in
      let rows = content.rows.filter { $0.treatment == treatment }
      return rows.isEmpty ? nil : Tier(treatment: treatment, rows: rows)
    }
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

  /// Applies the one sanctioned correction for a visible treatment misplacement. The database
  /// writer performs the operation off the main actor; reloading the projection makes the row
  /// move tiers and updates the landing counts immediately.
  @discardableResult
  public func setSenderOverride(_ treatment: EmailTreatment, for sender: String) async -> [ContentPiece] {
    do {
      let reclassified = try await database.write { db in
        try EmailTreatmentOperations.setSenderOverride(treatment, for: sender, in: db)
      }
      try await $content.load()
      errorMessage = nil
      return reclassified
    } catch is CancellationError {
      return []
    } catch EmailTreatmentOperations.Failure.emptySender {
      errorMessage = "This message has no sender address to correct."
      return []
    } catch {
      errorMessage = error.localizedDescription
      return []
    }
  }

  public func setSenderOverride(_ treatment: EmailTreatment, for row: TodayRequest.Row) async {
    await setSenderOverride(treatment, for: row.sender)
  }

  private func offerGroupKey(for publisher: String) -> String {
    publisher
      .split(separator: "<", maxSplits: 1, omittingEmptySubsequences: true)[0]
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
  }

  private func offerGroupLabel(for publisher: String) -> String {
    let label = publisher
      .split(separator: "<", maxSplits: 1, omittingEmptySubsequences: true)[0]
      .trimmingCharacters(in: .whitespacesAndNewlines)
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
