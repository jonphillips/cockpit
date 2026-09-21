import Foundation
import SQLiteData

/// The reachable-first projection for one Stream. It follows Stream membership through Artifacts,
/// regardless of transport or current Gmail source disposition. A Stream is the durable route back
/// to its ContentPieces; it is not a second Edition or Today attention state.
public struct StreamHandlingRequest: FetchKeyRequest {
  @Selection
  public struct Row: Equatable, Identifiable, Sendable {
    public let id: ContentPiece.ID
    public let kind: ContentKind
    public let title: String
    public let publisher: String
    public let summary: String?
    public let canonicalURL: String?
    public let publishedAt: Date?
    public let isSubstantivePrimary: Bool?
    public let bodyCompleteness: BodyCompleteness?
  }

  public struct Value: Equatable, Sendable {
    public var stream: Stream?
    public var rows: [Row] = []

    public init() {}
  }

  private let streamID: Stream.ID

  public init(streamID: Stream.ID) {
    self.streamID = streamID
  }

  public func fetch(_ db: Database) throws -> Value {
    var value = Value()
    value.stream = try Stream.find(streamID).fetchOne(db)
    value.rows = try ContentPiece
      .order { ($0.publishedAt.desc(), $0.id) }
      .group(by: \.id)
      .join(Artifact.all) { $1.contentPieceID.eq($0.id) }
      .where { $1.streamID.eq(streamID) }
      .select { piece, _ in
        Row.Columns(
          id: piece.id,
          kind: piece.kind,
          title: piece.title,
          publisher: piece.publisher,
          summary: piece.summary,
          canonicalURL: piece.canonicalURL,
          publishedAt: piece.publishedAt,
          isSubstantivePrimary: piece.isSubstantivePrimary,
          bodyCompleteness: piece.bodyCompleteness
        )
      }
      .fetchAll(db)
    return value
  }
}
