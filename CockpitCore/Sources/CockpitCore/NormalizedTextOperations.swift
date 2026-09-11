import Foundation
import SQLiteData

public enum NormalizedTextOperations {
  public static func store(_ text: String, for id: ContentPiece.ID, in db: Database) throws {
    try LocalNormalizedText.upsert {
      LocalNormalizedText.Draft(contentPieceID: id, normalizedText: text)
    }.execute(db)
  }

  public static func text(for id: ContentPiece.ID, in db: Database) throws -> String? {
    try LocalNormalizedText.find(id).select(\.normalizedText).fetchOne(db)
  }

  /// A membership received from another device may need this device's local substance.
  /// Fill only an absent projection on the ingest path, never overwrite received text.
  ///
  /// The projection is written by the `library_text_local_*` triggers, not here: rewriting
  /// the local row is what fires them. That indirection is deliberate — one code path owns
  /// the projection — but it means an upsert that skipped a no-op write would silently turn
  /// this into nothing. `ingestSuppliesMissingBody` is the test that would catch it.
  static func supplyLibraryTextIfMissing(for id: ContentPiece.ID, in db: Database) throws {
    guard try LibraryMembership.find(id).fetchOne(db) != nil,
      try LibraryNormalizedText.find(id).fetchOne(db)?.utf8 == nil,
      let text = try text(for: id, in: db)
    else { return }
    try store(text, for: id, in: db)
  }
}
