import Foundation
import SQLiteData

/// The unresolved Find proposal attached to one Reader ContentPiece.
public struct PendingFindForContentPieceRequest: FetchKeyRequest {
  public struct Value: Equatable, Sendable {
    public var find: PendingFind?
    public init(find: PendingFind? = nil) { self.find = find }
  }

  public let contentPieceID: ContentPiece.ID

  public init(contentPieceID: ContentPiece.ID) {
    self.contentPieceID = contentPieceID
  }

  public func fetch(_ db: Database) throws -> Value {
    Value(find: try PendingFind
      .where { $0.contentPieceID.eq(contentPieceID) && $0.state.eq(PendingFindState.pending) }
      .order { $0.id }
      .fetchOne(db))
  }
}
