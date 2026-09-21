import Foundation
import SQLiteData

/// The normalized locator for a Gmail newsletter series. List-ID is preferred so two publications
/// from one sender remain distinct; the sender mailbox is only the fallback when List-ID is absent.
public enum GmailSeriesKey {
  /// Returns nil for non-Gmail, non-newsletter, malformed-provenance, or headerless pieces.
  public static func seriesKey(
    forContentPieceID id: ContentPiece.ID, in db: Database
  ) throws -> String? {
    let artifact = try Artifact.where {
      $0.contentPieceID.eq(id) && $0.transport.eq(StreamTransport.gmail)
    }.fetchAll(db).max { $0.acquiredAt < $1.acquiredAt }
    guard try ContentPiece.find(id).fetchOne(db)?.emailTreatment == .newsletter,
      let artifact,
      let provenanceText = artifact.providerProvenance,
      let provenance = try? JSONDecoder().decode(
        GmailArtifactProvenance.self, from: Data(provenanceText.utf8))
    else { return nil }

    return normalizedListID(provenance.listID)
      ?? GmailHeaderParser.senderKey(from: provenance.senderAddress)
  }

  /// The locator set shared by Gmail Stream resolution and series identity. A List-ID such as
  /// `Letters <letters.example.com>` matches both its full display form and the bracketed locator.
  static func locatorKeys(_ locator: String?) -> Set<String> {
    guard let locator = locator?.lowercased().trimmedNonEmpty else { return [] }
    var keys = Set([locator])
    if let email = GmailHeaderParser.senderKey(from: locator) { keys.insert(email) }
    if let open = locator.lastIndex(of: "<"), let close = locator[open...].firstIndex(of: ">") {
      let inner = String(locator[locator.index(after: open)..<close])
        .trimmingCharacters(in: .whitespaces)
      if let inner = inner.trimmedNonEmpty { keys.insert(inner) }
    }
    return keys
  }

  /// The canonical List-ID value is the bracketed locator when present, otherwise the trimmed
  /// lowercased header. This is deterministic and keeps the sender fallback separate.
  static func normalizedListID(_ value: String?) -> String? {
    guard let value = value?.lowercased().trimmedNonEmpty else { return nil }
    if let open = value.lastIndex(of: "<"), let close = value[open...].firstIndex(of: ">") {
      return String(value[value.index(after: open)..<close]).trimmedNonEmpty
    }
    return value
  }
}
