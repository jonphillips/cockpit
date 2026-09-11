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
  static func supplyLibraryTextIfMissing(for id: ContentPiece.ID, in db: Database) throws {
    guard try LibraryMembership.find(id).fetchOne(db) != nil,
      try LibraryNormalizedText.find(id).fetchOne(db)?.utf8 == nil,
      let text = try text(for: id, in: db)
    else { return }
    try store(text, for: id, in: db)
  }
}
