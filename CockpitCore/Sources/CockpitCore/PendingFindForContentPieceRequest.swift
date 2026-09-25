import Foundation
import SQLiteData

/// The unresolved Find proposal attached to one Reader ContentPiece.
public struct PendingFindForContentPieceRequest: FetchKeyRequest {
  public struct Value: Equatable, Sendable {
    public var find: PendingFind?
    public var recipeFind: PendingFind?
    public init(find: PendingFind? = nil, recipeFind: PendingFind? = nil) {
      self.find = find
      self.recipeFind = recipeFind
    }
  }

  public let contentPieceID: ContentPiece.ID

  public init(contentPieceID: ContentPiece.ID) {
    self.contentPieceID = contentPieceID
  }

  public func fetch(_ db: Database) throws -> Value {
    let finds = try PendingFind
      .where { $0.contentPieceID.eq(contentPieceID) }
      .order { $0.id }
      .fetchAll(db)
    let recipeFinds = finds.filter {
      RecipeCandidateKind.matches($0.kind) && $0.state != .dismissed
    }
    let recipeFind = recipeFinds.first { $0.state == .referred }
      ?? recipeFinds.first { $0.state == .handedOff }
      ?? recipeFinds.first { $0.state == .declined }
      ?? recipeFinds.first { $0.state == .pending }
      ?? recipeFinds.first { $0.state == .confirmed }
    return Value(
      find: finds.first { $0.state == .pending },
      recipeFind: recipeFind
    )
  }
}
