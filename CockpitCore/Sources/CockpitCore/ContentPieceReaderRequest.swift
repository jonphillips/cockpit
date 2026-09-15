import Foundation
import SQLiteData

/// The ContentPiece-shaped projection used by the single Reader outside an Edition. Edition adds
/// rationale and resolution state as an optional context layer; the substance lives here.
public struct ContentPieceReaderRequest: FetchKeyRequest {
  @Selection
  public struct Row: Equatable, Identifiable, Sendable {
    public let id: ContentPiece.ID
    public let title: String
    public let publisher: String
    public let summary: String?
    public let canonicalURL: String?
    public let isSubstantivePrimary: Bool?
    public let bodyCompleteness: BodyCompleteness?
    public let laterAddedAt: Date?
    public let libraryAddedAt: Date?
  }

  public struct Value: Equatable, Sendable {
    public var row: Row?
    public init() {}
  }

  public let contentPieceID: ContentPiece.ID

  public init(contentPieceID: ContentPiece.ID) {
    self.contentPieceID = contentPieceID
  }

  public func fetch(_ db: Database) throws -> Value {
    var value = Value()
    value.row = try ContentPiece
      .where { $0.id.eq(contentPieceID) }
      .leftJoin(LaterMembership.all) { $0.id.eq($1.contentPieceID) }
      .leftJoin(LibraryMembership.all) { $0.id.eq($2.contentPieceID) }
      .select {
        Row.Columns(
          id: $0.id, title: $0.title, publisher: $0.publisher, summary: $0.summary,
          canonicalURL: $0.canonicalURL, isSubstantivePrimary: $0.isSubstantivePrimary,
          bodyCompleteness: $0.bodyCompleteness, laterAddedAt: $1.addedAt,
          libraryAddedAt: $2.addedAt)
      }
      .fetchOne(db)
    return value
  }
}
