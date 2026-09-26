import Foundation
import SQLiteData

public struct PendingFindListRequest: FetchKeyRequest {
  @Selection
  public struct Row: Equatable, Identifiable, Sendable {
    public let id: PendingFind.ID
    public let contentPieceID: ContentPiece.ID
    public let kind: String
    public let name: String
    public let descriptor: String
    public let rationale: String
    public let state: PendingFindState
    public let sourceURL: String?
    public let publishedAt: Date?
    public let createdAt: Date

    public var sortDate: Date { publishedAt ?? createdAt }

    public var section: Section {
      switch state {
      case .pending: .needsDecision
      case .confirmed, .referred: .saved
      case .handedOff, .declined: .resolved
      case .dismissed: .dismissed
      }
    }
  }

  public enum Section: Int, Equatable, Sendable {
    case needsDecision
    case saved
    case resolved
    case dismissed
  }

  public struct Value: Equatable, Sendable {
    public var rows: [Row] = []
    public init() {}
  }

  public var showDismissed: Bool

  public init(showDismissed: Bool = false) {
    self.showDismissed = showDismissed
  }

  public func fetch(_ db: Database) throws -> Value {
    var value = Value()
    value.rows = try PendingFind
      .join(ContentPiece.all) { $0.contentPieceID.eq($1.id) }
      .select {
        Row.Columns(
          id: $0.id, contentPieceID: $0.contentPieceID, kind: $0.kind, name: $0.name,
          descriptor: $0.descriptor, rationale: $0.rationale, state: $0.state, sourceURL: $0.sourceURL,
          publishedAt: $1.publishedAt, createdAt: $1.createdAt)
      }
      .fetchAll(db)
      .filter { showDismissed || $0.section != .dismissed }
      .sorted {
        if $0.sortDate != $1.sortDate { return $0.sortDate > $1.sortDate }
        let nameOrder = $0.name.localizedCaseInsensitiveCompare($1.name)
        if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
        return $0.id.uuidString < $1.id.uuidString
      }
    return value
  }
}
