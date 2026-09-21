import Foundation
import SQLiteData

/// Resolves Gmail mail to an explicitly configured Gmail Stream. Matching is exact over a Stream
/// locator and retained sender/List-ID evidence; it is not a sender-reputation heuristic or an
/// email-delivered-Stream detector. Ambiguous evidence deliberately leaves an Artifact unlinked.
enum GmailStreamResolver {
  static func streamID(
    for provenance: GmailArtifactProvenance, sender: String?, in db: Database
  ) throws -> Stream.ID? {
    let streams = try Stream.where { $0.transport.eq(StreamTransport.gmail) }.fetchAll(db)
    let senderKey = GmailHeaderParser.senderKey(from: sender)
    let listIDKeys = GmailSeriesKey.locatorKeys(provenance.listID)
    let senderMatches = streams.filter { stream in
      guard let senderKey else { return false }
      return GmailSeriesKey.locatorKeys(stream.locator).contains(senderKey)
    }
    if senderMatches.count == 1 { return senderMatches[0].id }
    if senderMatches.count > 1 { return nil }

    let listMatches = streams.filter { stream in
      !listIDKeys.isEmpty && !GmailSeriesKey.locatorKeys(stream.locator).isDisjoint(with: listIDKeys)
    }
    return listMatches.count == 1 ? listMatches[0].id : nil
  }

  /// Reconciliation makes the relationship work for mail ingested before its manually configured
  /// Stream existed. It only attaches unlinked Gmail Artifacts and returns affected ContentPieces
  /// so their deterministic S5 treatment can be recomputed by the caller.
  static func linkUnresolvedArtifacts(in db: Database) throws -> [ContentPiece.ID] {
    let artifacts = try Artifact.where {
      $0.transport.eq(StreamTransport.gmail) && $0.streamID.is(nil)
    }.fetchAll(db)
    var linked: [ContentPiece.ID] = []
    for artifact in artifacts {
      guard let provenance = decode(artifact.providerProvenance),
        let streamID = try streamID(for: provenance, sender: provenance.senderAddress, in: db)
      else { continue }
      try Artifact.find(artifact.id).update { $0.streamID = #bind(streamID) }.execute(db)
      if let contentPieceID = artifact.contentPieceID { linked.append(contentPieceID) }
    }
    return linked
  }

  private static func decode(_ value: String?) -> GmailArtifactProvenance? {
    guard let value else { return nil }
    return try? JSONDecoder().decode(GmailArtifactProvenance.self, from: Data(value.utf8))
  }

}
