import Foundation
import SQLiteData

/// A transient question derived solely from recurring deliberate actions. It has no table and no
/// synced state: dismissing it leaves no durable trace, while confirmation is the only operation
/// that can write Personal Knowledge.
public struct PersonalKnowledgeHypothesisRequest: FetchKeyRequest {
  public struct Candidate: Equatable, Identifiable, Sendable {
    public let subject: String
    /// The number of *distinct content pieces* on this subject that received an explicit action.
    /// A single piece counts once however many actions it drew (saved *and* added, or taught more
    /// than once), so recurrence means acting on the subject across more than one piece — not one
    /// piece treated two ways.
    public let explicitActionCount: Int

    public var id: String { subject }

    public init(subject: String, explicitActionCount: Int) {
      self.subject = subject
      self.explicitActionCount = explicitActionCount
    }
  }

  public struct Value: Equatable, Sendable {
    public var candidates: [Candidate] = []
    public init() {}
  }

  @Selection
  struct ContentPieceActionRow: Equatable, Sendable {
    let contentPieceID: ContentPiece.ID
    let subjects: String?
    let laterAddedAt: Date?
    let libraryAddedAt: Date?
    let teachingID: PersonalKnowledgeTeaching.ID?
  }

  public init() {}

  public func fetch(_ db: Database) throws -> Value {
    let actionRows = try ContentPiece
      .leftJoin(LaterMembership.all) { $0.id.eq($1.contentPieceID) }
      .leftJoin(LibraryMembership.all) { $0.id.eq($2.contentPieceID) }
      .leftJoin(PersonalKnowledgeTeaching.all) { $0.id.eq($3.contentPieceID) }
      .select {
        ContentPieceActionRow.Columns(
          contentPieceID: $0.id,
          subjects: $0.subjects,
          laterAddedAt: $1.addedAt,
          libraryAddedAt: $2.addedAt,
          teachingID: $3.id
        )
      }
      .fetchAll(db)

    let confirmedSubjects = Set(
      try PersonalKnowledgeClaim
        .where {
          $0.kind.eq(PersonalKnowledgeKind.interest)
            && $0.provenance.eq(PersonalKnowledgeProvenance.confirmedHypothesis)
            && $0.status.eq(PersonalKnowledgeClaimStatus.current)
        }
        .select(\.scope)
        .fetchAll(db)
        .compactMap { $0 }
        .compactMap(Self.normalizedSubject)
    )

    // Recurrence is measured across distinct content pieces, so a single piece that was both
    // saved and added to Library (or taught more than once) counts exactly once toward the subject.
    var piecesBySubject: [String: Set<ContentPiece.ID>] = [:]
    for row in actionRows {
      let hasExplicitAction =
        row.laterAddedAt != nil || row.libraryAddedAt != nil || row.teachingID != nil
      guard hasExplicitAction, let subjects = Self.decodedSubjects(row.subjects) else { continue }
      for subject in subjects {
        piecesBySubject[subject, default: []].insert(row.contentPieceID)
      }
    }

    var value = Value()
    value.candidates = piecesBySubject.compactMap { subject, pieceIDs in
      guard pieceIDs.count >= 2, !confirmedSubjects.contains(subject) else { return nil }
      return Candidate(subject: subject, explicitActionCount: pieceIDs.count)
    }
    .sorted { lhs, rhs in
      if lhs.explicitActionCount != rhs.explicitActionCount {
        return lhs.explicitActionCount > rhs.explicitActionCount
      }
      return lhs.subject < rhs.subject
    }
    return value
  }

  private static func decodedSubjects(_ encoded: String?) -> [String]? {
    guard let encoded, let data = encoded.data(using: .utf8),
      let rawSubjects = try? JSONDecoder().decode([String].self, from: data)
    else { return nil }
    let subjects = Set(rawSubjects.compactMap(normalizedSubject))
    return subjects.isEmpty ? nil : subjects.sorted()
  }

  private static func normalizedSubject(_ subject: String) -> String? {
    let normalized = subject
      .split(whereSeparator: { $0.isWhitespace })
      .joined(separator: " ")
      .lowercased()
    return normalized.isEmpty ? nil : normalized
  }
}
