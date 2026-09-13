import Foundation
import SQLiteData

public enum PersonalKnowledgeOperations {
  public enum Failure: Error, Equatable {
    case emptyClaim
    case missingCurrentClaim(PersonalKnowledgeClaim.ID)
  }

  public static func teach(
    id: PersonalKnowledgeClaim.ID,
    kind: PersonalKnowledgeKind,
    claim: String,
    scope: String?,
    at date: Date,
    in db: Database
  ) throws {
    let claim = try nonEmpty(claim)
    try PersonalKnowledgeClaim.insert {
      PersonalKnowledgeClaim.Draft(
        PersonalKnowledgeClaim(
          id: id, kind: kind, claim: claim, scope: normalized(scope),
          provenance: .directTeaching, createdAt: date
        )
      )
    }.execute(db)
  }

  public static func apply(
    _ proposals: [PersonalKnowledgeProposal],
    at date: Date,
    ids: [PersonalKnowledgeClaim.ID],
    in db: Database
  ) throws {
    precondition(proposals.count == ids.count)
    for (proposal, newID) in zip(proposals, ids) {
      let claim = try nonEmpty(proposal.claim)
      switch proposal.action {
      case .newClaim:
        try PersonalKnowledgeClaim.insert {
          PersonalKnowledgeClaim.Draft(
            PersonalKnowledgeClaim(
              id: newID, kind: proposal.kind, claim: claim, scope: normalized(proposal.scope),
              provenance: .jonBrainImport, createdAt: date
            )
          )
        }.execute(db)
      case let .consolidate(replacing: ids):
        for id in ids {
          guard let existing = try PersonalKnowledgeClaim.find(id).fetchOne(db), existing.status == .current
          else { throw Failure.missingCurrentClaim(id) }
        }
        try PersonalKnowledgeClaim.insert {
          PersonalKnowledgeClaim.Draft(
            PersonalKnowledgeClaim(
              id: newID, kind: proposal.kind, claim: claim, scope: normalized(proposal.scope),
              provenance: .semanticConsolidation, createdAt: date
            )
          )
        }.execute(db)
        for id in ids {
          try PersonalKnowledgeClaim.find(id)
            .update {
              $0.status = #bind(PersonalKnowledgeClaimStatus.superseded)
              $0.supersededByID = #bind(newID)
            }
            .execute(db)
        }
      }
    }
  }

  private static func nonEmpty(_ text: String) throws -> String {
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { throw Failure.emptyClaim }
    return value
  }

  private static func normalized(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
      return nil
    }
    return value
  }
}
