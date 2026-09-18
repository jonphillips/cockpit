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

  @ObservationIgnored @Dependency(\.defaultDatabase) private var database
  @ObservationIgnored @Dependency(\.date.now) private var now
  @ObservationIgnored @Fetch(TodayRequest()) public var content = .init()
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
  public func setSenderOverride(_ treatment: EmailTreatment, for sender: String) async {
    do {
      try await database.write { db in
        _ = try EmailTreatmentOperations.setSenderOverride(treatment, for: sender, in: db)
      }
      try await $content.load()
      errorMessage = nil
    } catch is CancellationError {
    } catch EmailTreatmentOperations.Failure.emptySender {
      errorMessage = "This message has no sender address to correct."
    } catch {
      errorMessage = error.localizedDescription
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

public extension EmailTreatment {
  /// The Today hierarchy is deterministic across types. It is intentionally not importance order.
  static let todayHierarchy: [Self] = [.personal, .newsletter, .offer, .grabBag, .transactional]
}
