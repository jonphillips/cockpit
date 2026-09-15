import Foundation
import SQLiteData

/// The current understanding explicitly taught from the ContentPiece in the Reader. This is a
/// narrow contextual route into S2 correction, not a general Personal Knowledge browse surface.
public struct ReaderTeachingClaimRequest: FetchKeyRequest {
  public struct Value: Equatable, Sendable {
    public var claim: PersonalKnowledgeRequest.Row?
    public init() {}
  }

  public let contentPieceID: ContentPiece.ID

  public init(contentPieceID: ContentPiece.ID) {
    self.contentPieceID = contentPieceID
  }

  public func fetch(_ db: Database) throws -> Value {
    var value = Value()
    guard let teaching = try (PersonalKnowledgeTeaching
      .where { $0.contentPieceID.eq(contentPieceID) }
      .order { $0.createdAt.desc() }
      .fetchOne(db))
    else {
      return value
    }

    value.claim = try PersonalKnowledgeClaim
      .where { $0.teachingID.eq(#bind(teaching.id)) }
      .where { $0.status.eq(PersonalKnowledgeClaimStatus.current) }
      .select {
        PersonalKnowledgeRequest.Row.Columns(
          id: $0.id, kind: $0.kind, claim: $0.claim, scope: $0.scope,
          provenance: $0.provenance, status: $0.status,
          supersededByID: $0.supersededByID, createdAt: $0.createdAt
        )
      }
      .fetchOne(db)
    return value
  }
}
