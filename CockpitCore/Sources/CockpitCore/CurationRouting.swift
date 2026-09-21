import SQLiteData

/// The current surface role of Gmail-backed ContentPieces. This is deliberately derived from
/// Stream membership and follow state rather than from Gmail transport alone: the same provider
/// can deliver either a followed Stream issue or loose Primary mail.
struct CurationRoutingSnapshot: Sendable {
  let followedGmailStreamContentPieceIDs: Set<ContentPiece.ID>
  let primaryGmailContentPieceIDs: Set<ContentPiece.ID>

  /// Both Gmail roles are curated input under §24 and stay outside the uncurated Edition tail.
  /// S-b supplies the Stream Handling surface for the first role; Today already owns the second.
  var editionExcludedContentPieceIDs: Set<ContentPiece.ID> {
    followedGmailStreamContentPieceIDs.union(primaryGmailContentPieceIDs)
  }
}

enum CurationRouting {
  static func snapshot(in db: Database) throws -> CurationRoutingSnapshot {
    let gmailArtifacts = try Artifact
      .where { $0.transport.eq(StreamTransport.gmail) }
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
      primaryGmailContentPieceIDs: gmailContentPieceIDs.subtracting(followedGmailStreamContentPieceIDs)
    )
  }
}
