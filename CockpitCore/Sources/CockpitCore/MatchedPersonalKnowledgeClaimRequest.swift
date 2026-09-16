import Foundation
import SQLiteData

/// The current claim judgment named for this materialised Edition entry. A superseded or retired
/// claim deliberately stops offering correction: the Reader still preserves its historical
/// rationale, while correction belongs to the current understanding that replaced it.
public struct MatchedPersonalKnowledgeClaimRequest: FetchKeyRequest {
  public struct Value: Equatable, Sendable {
    public var claim: PersonalKnowledgeRequest.Row?
    public init() {}
  }

  public let claimID: PersonalKnowledgeClaim.ID?

  public init(claimID: PersonalKnowledgeClaim.ID?) {
    self.claimID = claimID
  }

  public func fetch(_ db: Database) throws -> Value {
    guard let claimID else { return .init() }
    var value = Value()
    value.claim = try PersonalKnowledgeClaim
      .where { $0.id.eq(claimID) && $0.status.eq(PersonalKnowledgeClaimStatus.current) }
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
