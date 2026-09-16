import Foundation
import SQLiteData

/// The latest materialised Edition and its entries, read entirely from stored state — no judgment
/// re-run, no re-derivation (ADR-0001 D5; done-criterion 4). A closed Edition renders from exactly
/// these rows.
public struct CurrentEditionRequest: FetchKeyRequest {
  @Selection
  public struct Row: Equatable, Identifiable, Sendable {
    public let id: EditionEntry.ID
    public let contentPieceID: ContentPiece.ID
    public let title: String
    public let publisher: String
    public let summary: String?
    public let canonicalURL: String?
    public let isSubstantivePrimary: Bool?
    public let bodyCompleteness: BodyCompleteness?
    public let section: JudgmentSection
    public let rank: Int
    public let rationale: String?
    public let matchedPersonalKnowledgeClaimID: PersonalKnowledgeClaim.ID?
    public let entryState: EditionEntryState
    public let timesCarried: Int
    public let firstAdmittedEditionID: Edition.ID
  }

  public struct Value: Equatable, Sendable {
    public var edition: Edition?
    public var entries: [Row] = []
    public init() {}
  }

  public init() {}

  public func fetch(_ db: Database) throws -> Value {
    var value = Value()
    guard let edition = try Edition.order { $0.date.desc() }.fetchOne(db) else { return value }
    value.edition = edition
    value.entries = try EditionEntry
      .where { $0.editionID.eq(edition.id) }
      .order { ($0.rank, $0.id) }
      .join(ContentPiece.all) { $0.contentPieceID.eq($1.id) }
      .select {
        Row.Columns(
          id: $0.id, contentPieceID: $0.contentPieceID, title: $1.title, publisher: $1.publisher,
          summary: $1.summary, canonicalURL: $1.canonicalURL, isSubstantivePrimary: $1.isSubstantivePrimary,
          bodyCompleteness: $1.bodyCompleteness,
          section: $0.section, rank: $0.rank, rationale: $0.rationale,
          matchedPersonalKnowledgeClaimID: $0.matchedPersonalKnowledgeClaimID,
          entryState: $0.entryState, timesCarried: $0.timesCarried,
          firstAdmittedEditionID: $0.firstAdmittedEditionID)
      }
      .fetchAll(db)
    return value
  }
}
