import Foundation
import SQLiteData

public enum DestinationOperations {
  public enum Failure: Error {
    case missingContentPiece
  }

  public static func saveForLater(_ id: ContentPiece.ID, at date: Date, in db: Database) throws {
    try requireContentPiece(id, in: db)
    try LaterMembership.insert {
      LaterMembership.Draft(contentPieceID: id, addedAt: date)
    } onConflictDoUpdate: { _ in
    }.execute(db)
  }

  public static func addToLibrary(_ id: ContentPiece.ID, at date: Date, in db: Database) throws {
    try requireContentPiece(id, in: db)
    try LibraryMembership.insert {
      LibraryMembership.Draft(contentPieceID: id, addedAt: date, admittedBy: "explicit")
    } onConflictDoUpdate: { _ in
    }.execute(db)
  }

  public static func removeFromLater(_ id: ContentPiece.ID, in db: Database) throws {
    try LaterMembership.find(id).delete().execute(db)
  }

  public static func removeFromLibrary(_ id: ContentPiece.ID, in db: Database) throws {
    try LibraryMembership.find(id).delete().execute(db)
  }

  private static func requireContentPiece(_ id: ContentPiece.ID, in db: Database) throws {
    guard try ContentPiece.find(id).fetchOne(db) != nil else { throw Failure.missingContentPiece }
  }
}
