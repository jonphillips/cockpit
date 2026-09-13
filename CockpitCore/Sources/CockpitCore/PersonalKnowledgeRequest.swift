import Foundation
import SQLiteData

public struct PersonalKnowledgeRequest: FetchKeyRequest {
  @Selection
  public struct Row: Equatable, Identifiable, Sendable {
    public let id: PersonalKnowledgeClaim.ID
    public let kind: PersonalKnowledgeKind
    public let claim: String
    public let scope: String?
    public let provenance: PersonalKnowledgeProvenance
    public let status: PersonalKnowledgeClaimStatus
    public let supersededByID: PersonalKnowledgeClaim.ID?
    public let createdAt: Date

    public var asClaim: PersonalKnowledgeClaim {
      PersonalKnowledgeClaim(
        id: id, kind: kind, claim: claim, scope: scope, provenance: provenance,
        status: status, supersededByID: supersededByID, createdAt: createdAt
      )
    }
  }

  public struct Value: Equatable, Sendable {
    public var rows: [Row] = []
    public init() {}
  }

  public init() {}

  public func fetch(_ db: Database) throws -> Value {
    var value = Value()
    value.rows = try PersonalKnowledgeClaim
      .order { ($0.status, $0.kind, $0.createdAt, $0.id) }
      .select {
        Row.Columns(
          id: $0.id, kind: $0.kind, claim: $0.claim, scope: $0.scope,
          provenance: $0.provenance, status: $0.status,
          supersededByID: $0.supersededByID, createdAt: $0.createdAt
        )
      }
      .fetchAll(db)
    return value
  }
}
