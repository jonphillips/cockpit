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
    let listIDKeys = locatorKeys(provenance.listID)
    let senderMatches = streams.filter { stream in
      guard let senderKey else { return false }
      return locatorKeys(stream.locator).contains(senderKey)
    }
    if senderMatches.count == 1 { return senderMatches[0].id }
    if senderMatches.count > 1 { return nil }

    let listMatches = streams.filter { stream in
      !listIDKeys.isEmpty && !locatorKeys(stream.locator).isDisjoint(with: listIDKeys)
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

  /// A Gmail Stream locator may be an exact sender mailbox or an exact List-ID value. Angle-bracket
  /// List-ID syntax is normalized so `Feed Me <digest.example.com>` and `digest.example.com` refer
  /// to the same explicit source without introducing fuzzy domain matching.
  private static func locatorKeys(_ locator: String?) -> Set<String> {
    guard let locator = locator?.lowercased().trimmedNonEmpty else { return [] }
    var keys = Set([locator])
    if let email = GmailHeaderParser.senderKey(from: locator) { keys.insert(email) }
    if let open = locator.lastIndex(of: "<"), let close = locator[open...].firstIndex(of: ">") {
      let inner = String(locator[locator.index(after: open)..<close]).trimmingCharacters(in: .whitespaces)
      if let inner = inner.trimmedNonEmpty { keys.insert(inner) }
    }
    return keys
  }
}
