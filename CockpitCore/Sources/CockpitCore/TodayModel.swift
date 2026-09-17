import Dependencies
import Foundation
import Observation
import SQLiteData

/// Owns the stable treatment hierarchy and Cockpit-only resolution for the Today destination.
/// It has no Gmail provider dependency: `Clear` deliberately cannot perform a provider write.
@MainActor
@Observable
public final class TodayModel {
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
      }
    }
  }

  @ObservationIgnored @Dependency(\.defaultDatabase) private var database
  @ObservationIgnored @Dependency(\.date.now) private var now
  @ObservationIgnored @Fetch(TodayRequest()) public var content = .init()
  public var selectedContentPieceID: ContentPiece.ID?
  public var errorMessage: String?

  public init() {}

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
}

public extension EmailTreatment {
  /// The Today hierarchy is deterministic across types. It is intentionally not importance order.
  static let todayHierarchy: [Self] = [.personal, .newsletter, .offer, .grabBag]
}
