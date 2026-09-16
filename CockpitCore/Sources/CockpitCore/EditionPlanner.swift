import Foundation
import SQLiteData

/// Everything the judgment pass and the entry writer need, gathered inside the composer's opening
/// transaction so the model call and the final write both work from one consistent snapshot.
struct EditionPlan: Sendable {
  var candidates: [JudgmentCandidate]
  var personalKnowledge: PersonalKnowledgeProjection
  /// Per-candidate facts judgment does not carry: whether an Essential Stream protects the piece,
  /// and (for carryovers) the predecessor entry to inherit from.
  var contexts: [ContentPiece.ID: EditionCandidateContext]
}

struct EditionCandidateContext: Sendable {
  /// Whether any Essential Stream carries this piece — a stream-level fact known before the piece
  /// is classified. Combined with substantive-primary at write time, it triggers the Essential
  /// guarantee (IMPLEMENTATION-CONTRACT §3).
  var isFromEssentialStream: Bool
  var carried: EditionCarriedPredecessor?
}

/// The prior-Edition entry a carried piece inherits from, so its successor preserves origin and
/// presentation when a re-judgment does not (IMPLEMENTATION-CONTRACT §3).
struct EditionCarriedPredecessor: Sendable {
  var firstAdmittedEditionID: Edition.ID
  var timesCarried: Int
  var section: JudgmentSection
  var rank: Int
  var rationale: String?
  var matchedPersonalKnowledgeClaimID: PersonalKnowledgeClaim.ID?
}

/// Gathers the day's candidates — new arrivals plus carryovers — and the context each needs. Pure
/// reads; it never writes. The composer runs it inside its Phase-1 transaction.
struct EditionPlanner: Sendable {
  func buildPlan(
    previousEditionID: Edition.ID?, since: Date?, in db: Database
  ) throws -> EditionPlan {
    let essentialStreamPieceIDs = try EditionOperations.essentialStreamPieceIDs(in: db)
    let carriedByPiece = try carryovers(previousEditionID: previousEditionID, in: db)
    let newPieceIDs = try newPieceIDs(since: since, in: db)

    let candidatePieceIDs = Array(carriedByPiece.keys) + newPieceIDs
    let builds = try candidateBuilds(for: candidatePieceIDs, carriedByPiece: carriedByPiece, in: db)

    var candidates: [JudgmentCandidate] = []
    var contexts: [ContentPiece.ID: EditionCandidateContext] = [:]
    for candidate in builds {
      candidates.append(candidate)
      contexts[candidate.id] = EditionCandidateContext(
        isFromEssentialStream: essentialStreamPieceIDs.contains(candidate.id),
        carried: carriedByPiece[candidate.id])
    }

    let claims = try PersonalKnowledgeClaim.all.fetchAll(db)
    return EditionPlan(
      candidates: candidates,
      personalKnowledge: PersonalKnowledgeProjector.project(claims),
      contexts: contexts)
  }

  /// Entries the day-boundary finaliser just marked `carried` on the prior Edition.
  private func carryovers(
    previousEditionID: Edition.ID?, in db: Database
  ) throws -> [ContentPiece.ID: EditionCarriedPredecessor] {
    guard let previousEditionID else { return [:] }
    let carriedEntries = try EditionEntry
      .where { $0.editionID.eq(previousEditionID) && $0.entryState.eq(EditionEntryState.carried) }
      .fetchAll(db)
    var result: [ContentPiece.ID: EditionCarriedPredecessor] = [:]
    for entry in carriedEntries {
      result[entry.contentPieceID] = EditionCarriedPredecessor(
        firstAdmittedEditionID: entry.firstAdmittedEditionID, timesCarried: entry.timesCarried,
        section: entry.section, rank: entry.rank, rationale: entry.rationale,
        matchedPersonalKnowledgeClaimID: entry.matchedPersonalKnowledgeClaimID)
    }
    return result
  }

  /// Pieces ingested since the previous Edition and never yet surfaced. A piece with any existing
  /// entry (carried, or terminal) is excluded — carryovers arrive via `carryovers`, and a
  /// resolved/dismissed/aged piece is not reconsidered without an explicit request.
  private func newPieceIDs(since: Date?, in db: Database) throws -> [ContentPiece.ID] {
    let existingEntryPieceIDs = Set(try EditionEntry.select(\.contentPieceID).fetchAll(db))
    let candidatePieces: [ContentPiece.ID]
    if let since {
      candidatePieces = try ContentPiece.where { $0.createdAt > since }.select(\.id).fetchAll(db)
    } else {
      candidatePieces = try ContentPiece.select(\.id).fetchAll(db)
    }
    return candidatePieces.filter { !existingEntryPieceIDs.contains($0) }
  }

  /// Assemble a `JudgmentCandidate` per piece. One piece can have several (Artifact, Stream) rows;
  /// the representative Stream is an Essential one if any, so its posture is what judgment sees.
  /// Carryovers carry their `carriedEntry` context so the judge re-judges them sighted — it can tell
  /// a carryover from a fresh arrival and see how often it has already been shown (S2 CarriedEntryContext).
  private func candidateBuilds(
    for pieceIDs: [ContentPiece.ID],
    carriedByPiece: [ContentPiece.ID: EditionCarriedPredecessor],
    in db: Database
  ) throws -> [JudgmentCandidate] {
    guard !pieceIDs.isEmpty else { return [] }
    let rows = try ContentPiece
      .where { $0.id.in(pieceIDs) }
      .leftJoin(Artifact.all) { $1.contentPieceID.eq($0.id) }
      .leftJoin(Stream.all) { $1.streamID.eq($2.id) }
      .leftJoin(InterestArea.all) { $2.interestAreaID.eq($3.id) }
      .leftJoin(LocalNormalizedText.all) { $0.id.eq($4.contentPieceID) }
      .select {
        CandidateBuildRow.Columns(
          pieceID: $0.id, kind: $0.kind, title: $0.title, creator: $0.creator,
          publisher: $0.publisher, publishedAt: $0.publishedAt, canonicalURL: $0.canonicalURL,
          bodyCompleteness: $0.bodyCompleteness,
          normalizedText: $4.normalizedText, streamName: $2.name, handling: $2.handling,
          handlingGuidance: $2.handlingGuidance, streamIsEssential: $2.isEssential,
          interestAreaName: $3.name, interestAreaGuidance: $3.guidance)
      }
      .fetchAll(db)

    var rowsByPiece: [ContentPiece.ID: [CandidateBuildRow]] = [:]
    for row in rows { rowsByPiece[row.pieceID, default: []].append(row) }

    return pieceIDs.compactMap { pieceID in
      guard let pieceRows = rowsByPiece[pieceID], let first = pieceRows.first else { return nil }
      let representative = pieceRows.first(where: { $0.streamIsEssential == true }) ?? first
      let carriedEntry = carriedByPiece[pieceID].map {
        // `timesCarried` is the count this candidate will carry if re-admitted (predecessor + this
        // boundary) — the fatigue signal the judge should weigh. Its prior entry is `carried` by
        // definition; the pre-carry seen/admitted state is not preserved through the boundary.
        CarriedEntryContext(
          timesCarried: $0.timesCarried + 1, entryState: EditionEntryState.carried.rawValue)
      }
      return JudgmentCandidate(
        id: pieceID, kind: first.kind.rawValue, title: first.title, creator: first.creator,
        publisher: first.publisher, publishedAt: first.publishedAt, canonicalURL: first.canonicalURL,
        normalizedText: first.normalizedText ?? "", bodyCompleteness: first.bodyCompleteness,
        stream: StreamContext(
          name: representative.streamName ?? first.publisher,
          handling: representative.handling?.rawValue ?? StreamHandling.following.rawValue,
          handlingGuidance: representative.handlingGuidance ?? "",
          isEssential: representative.streamIsEssential ?? false),
        interestArea: InterestAreaContext(
          name: representative.interestAreaName ?? "General",
          guidance: representative.interestAreaGuidance ?? ""),
        carriedEntry: carriedEntry)
    }
  }
}

/// One (ContentPiece, Stream) row used to assemble a `JudgmentCandidate`. A piece with several
/// Artifacts yields several rows, grouped and reduced to one representative Stream in the planner.
@Selection
struct CandidateBuildRow: Sendable {
  let pieceID: ContentPiece.ID
  let kind: ContentKind
  let title: String
  let creator: String?
  let publisher: String
  let publishedAt: Date?
  let canonicalURL: String?
  let bodyCompleteness: BodyCompleteness?
  let normalizedText: String?
  let streamName: String?
  let handling: StreamHandling?
  let handlingGuidance: String?
  let streamIsEssential: Bool?
  let interestAreaName: String?
  let interestAreaGuidance: String?
}
