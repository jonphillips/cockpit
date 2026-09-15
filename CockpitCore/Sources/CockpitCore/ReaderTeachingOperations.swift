import Foundation
import SQLiteData

extension PersonalKnowledgeOperations {
  /// Commits the explicit Reader teaching and its accepted proposal atomically. The model may
  /// suggest wording, but nothing durable exists until this deterministic, human-authorized write.
  public static func applyReaderTeaching(
    _ proposal: PersonalKnowledgeProposal,
    reason: String,
    contentPieceID: ContentPiece.ID,
    teachingID: PersonalKnowledgeTeaching.ID,
    claimID: PersonalKnowledgeClaim.ID,
    at date: Date,
    in db: Database
  ) throws {
    guard case .newClaim = proposal.action else { throw Failure.invalidReaderTeachingProposal }
    let reason = try nonEmpty(reason)
    let claim = try nonEmpty(proposal.claim)
    try PersonalKnowledgeTeaching.insert {
      PersonalKnowledgeTeaching.Draft(
        PersonalKnowledgeTeaching(
          id: teachingID, contentPieceID: contentPieceID, reason: reason, createdAt: date
        )
      )
    }.execute(db)
    try PersonalKnowledgeClaim.insert {
      PersonalKnowledgeClaim.Draft(
        PersonalKnowledgeClaim(
          id: claimID, kind: proposal.kind, claim: claim, scope: normalized(proposal.scope),
          provenance: .readerTeaching, teachingID: teachingID, createdAt: date
        )
      )
    }.execute(db)
  }
}
