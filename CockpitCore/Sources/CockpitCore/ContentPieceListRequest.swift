import Foundation
import SQLiteData

public struct ContentPieceListRequest: FetchKeyRequest {
  @Selection
  public struct Row: Equatable, Identifiable, Sendable {
    public let id: ContentPiece.ID
    public let title: String
    public let publisher: String
    public let publishedAt: Date?
    public let streamName: String?
    public let laterAddedAt: Date?
    public let libraryAddedAt: Date?
  }

  public struct Value: Equatable, Sendable {
    public var rows: [Row] = []
    public init() {}
  }

  public init() {}

  public func fetch(_ db: Database) throws -> Value {
    var value = Value()
    value.rows = try ContentPiece
      .order { ($0.publishedAt.desc(), $0.id) }
      .group(by: \.id)
      .leftJoin(Artifact.all) { $1.contentPieceID.eq($0.id) }
      .leftJoin(Stream.all) { $1.streamID.eq($2.id) }
      .leftJoin(LaterMembership.all) { $0.id.eq($3.contentPieceID) }
      .leftJoin(LibraryMembership.all) { $0.id.eq($4.contentPieceID) }
      .select {
        Row.Columns(
          id: $0.id, title: $0.title, publisher: $0.publisher, publishedAt: $0.publishedAt,
          streamName: $2.name.min(), laterAddedAt: $3.addedAt, libraryAddedAt: $4.addedAt
        )
      }.fetchAll(db)
    return value
  }
}
