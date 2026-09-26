import Foundation
import SQLiteData

/// Today-membership projection for offer review. Provider mutations and Cockpit attention remain
/// separate: the request reuses Today's projection, then enriches those rows for the review cards.
public struct OfferReviewRequest: FetchKeyRequest {
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
  /// Bounds hero extraction on Today while preserving every offer row and count. `nil` loads a
  /// hero for every row, which is used when one role's review grid is open.
  public let heroLimit: Int?

  public init(role: ContentRole? = nil, heroLimit: Int? = nil) {
    self.role = role
    self.heroLimit = heroLimit
  }

  public func fetch(_ db: Database) throws -> Value {
    let todayRows = try TodayRequest().fetch(db).rows.filter {
      OfferPieces.isOffer(role: $0.role, treatment: $0.treatment)
        && (role == nil || role == $0.role)
    }
    let pieceIDs = todayRows.map(\.id)
    let pendingFinds = try pieceIDs.isEmpty
      ? []
      : PendingFind.where { $0.contentPieceID.in(pieceIDs) }.fetchAll(db)
    let findsByPiece = Dictionary(grouping: pendingFinds, by: \.contentPieceID)
    var heroCounts: [ContentRole: Int] = [:]
    let rows = try todayRows.map { row -> Row in
      let selectedFind = findsByPiece[row.id]?.filter { $0.state != .dismissed }
        .sorted(by: Self.findPriority).first
      let heroURL: URL?
      if heroLimit.map({ (heroCounts[row.role] ?? 0) >= $0 }) == true {
        heroURL = nil
      } else {
        heroURL = try OfferHeroImageOperations.url(for: row.id, in: db)
        if heroURL != nil { heroCounts[row.role, default: 0] += 1 }
      }
      return Row(
        id: row.id,
        role: row.role,
        subject: row.title,
        sender: row.sender,
        arrivedAt: row.arrivedAt,
        summary: row.treatmentSummary,
        pendingFind: selectedFind,
        isUnread: row.isUnread,
        heroURL: heroURL
      )
    }
    return Value(rows: rows)
  }

  private static func findPriority(_ lhs: PendingFind, _ rhs: PendingFind) -> Bool {
    func priority(_ state: PendingFindState) -> Int {
      switch state {
      case .confirmed: 0
      case .pending: 1
      default: 2
      }
    }
    let leftPriority = priority(lhs.state)
    let rightPriority = priority(rhs.state)
    return leftPriority == rightPriority
      ? lhs.id.uuidString < rhs.id.uuidString
      : leftPriority < rightPriority
  }
}
