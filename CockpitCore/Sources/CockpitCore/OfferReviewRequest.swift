import Foundation
import SQLiteData

/// Today-membership projection for offer review. Provider mutations and Cockpit attention remain
/// separate: the request reuses Today's projection, then enriches those rows for the review cards.
public struct OfferReviewRequest: FetchKeyRequest {
  @Selection
  public struct Row: Equatable, Identifiable, Sendable {
    public let id: ContentPiece.ID
    public let role: ContentRole
    public let subject: String
    public let sender: String
    public let arrivedAt: Date
    public let summary: String?
    public let pendingFind: PendingFind?
    public let isUnread: Bool
    public let heroURL: URL?
  }

  public struct Value: Equatable, Sendable {
    public var rows: [Row] = []

    public init(rows: [Row] = []) { self.rows = rows }
  }

  public let role: ContentRole?

  public init(role: ContentRole? = nil) {
    self.role = role
  }

  public func fetch(_ db: Database) throws -> Value {
    let todayRows = try TodayRequest().fetch(db).rows
    let pendingFinds = try PendingFind.all.fetchAll(db)
    let findsByPiece = Dictionary(grouping: pendingFinds, by: \.contentPieceID)
    let rows = try todayRows.compactMap { row -> Row? in
      guard OfferPieces.isOffer(role: row.role, treatment: row.treatment),
        role == nil || role == row.role
      else { return nil }
      return Row(
        id: row.id,
        role: row.role,
        subject: row.title,
        sender: row.sender,
        arrivedAt: row.arrivedAt,
        summary: row.treatmentSummary,
        pendingFind: findsByPiece[row.id]?.sorted { $0.id.uuidString < $1.id.uuidString }.first,
        isUnread: row.isUnread,
        heroURL: try OfferHeroImageOperations.url(for: row.id, in: db)
      )
    }
    return Value(rows: rows)
  }
}
