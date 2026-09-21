import SQLiteData

@Selection
private struct GmailArtifactRoutingRow: Sendable {
  let streamID: Stream.ID?
  let contentPieceID: ContentPiece.ID?
}

/// The current surface role of Gmail-backed ContentPieces. This is deliberately derived from
/// Stream membership and follow state rather than from Gmail transport alone: the same provider
/// can deliver either a followed Stream issue or loose Primary mail.
struct CurationRoutingSnapshot: Sendable {
  let followedGmailStreamContentPieceIDs: Set<ContentPiece.ID>
  /// Gmail ContentPieces that remain in Today's loose Primary triage. This includes artifacts
  /// with no Stream and artifacts linked to a paused or stopped Stream: only an active Stream is
  /// currently a followed Stream for routing purposes. Keep that state decision explicit here so
  /// a future paused-Stream policy is not hidden by the old `primary` name.
  let todayTriageGmailContentPieceIDs: Set<ContentPiece.ID>

  /// Both Gmail roles stay outside the uncurated Edition tail. S-b supplies the Stream Handling
  /// surface for the first role; Today owns the second.
  var editionExcludedContentPieceIDs: Set<ContentPiece.ID> {
    followedGmailStreamContentPieceIDs.union(todayTriageGmailContentPieceIDs)
  }
}

enum CurationRouting {
  static func snapshot(in db: Database) throws -> CurationRoutingSnapshot {
    let gmailArtifacts = try Artifact
      .where { $0.transport.eq(StreamTransport.gmail) }
      .select {
        GmailArtifactRoutingRow.Columns(
          streamID: $0.streamID,
          contentPieceID: $0.contentPieceID
        )
      }
      .fetchAll(db)
    let gmailContentPieceIDs = Set(gmailArtifacts.compactMap { $0.contentPieceID })

    let activeGmailStreamIDs = try Stream
      .where {
        $0.transport.eq(StreamTransport.gmail)
          && $0.followState.eq(StreamFollowState.active)
      }
      .select(\.id)
      .fetchAll(db)
    let activeGmailStreamIDSet = Set(activeGmailStreamIDs)
    var followedGmailStreamContentPieceIDs = Set<ContentPiece.ID>()
    for artifact in gmailArtifacts {
      guard let streamID = artifact.streamID,
        activeGmailStreamIDSet.contains(streamID),
        let contentPieceID = artifact.contentPieceID
      else { continue }
      followedGmailStreamContentPieceIDs.insert(contentPieceID)
    }

    return CurationRoutingSnapshot(
      followedGmailStreamContentPieceIDs: followedGmailStreamContentPieceIDs,
      todayTriageGmailContentPieceIDs: gmailContentPieceIDs.subtracting(followedGmailStreamContentPieceIDs)
    )
  }
}
