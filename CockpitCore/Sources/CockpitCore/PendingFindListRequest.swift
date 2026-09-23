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
  }

  public struct Value: Equatable, Sendable {
    public var rows: [Row] = []
    public init() {}
  }

  public init() {}

  public func fetch(_ db: Database) throws -> Value {
    var value = Value()
    value.rows = try PendingFind
      .order { ($0.id) }
      .join(ContentPiece.all) { $0.contentPieceID.eq($1.id) }
      .select {
        Row.Columns(
          id: $0.id, contentPieceID: $0.contentPieceID, kind: $0.kind, name: $0.name,
          descriptor: $0.descriptor, rationale: $0.rationale, state: $0.state, sourceURL: $0.sourceURL,
          publishedAt: $1.publishedAt)
      }
      .fetchAll(db)
    return value
  }
}
