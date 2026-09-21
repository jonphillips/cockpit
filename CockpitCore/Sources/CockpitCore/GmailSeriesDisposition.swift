import Foundation
import SQLiteData

/// One explicit, user-established newsletter series whose Gmail source is Trashed after Jon reads
/// it. Presence is the declaration; removing the row stops the behavior. There is deliberately no
/// enabled flag or action column because M6 S1 has exactly one action and one unit of control.
@Table("gmailSeriesDispositions")
public struct GmailSeriesDisposition: Codable, Equatable, Identifiable, Sendable {
  @Column(primaryKey: true) public let seriesKey: String
  public let establishedAt: Date

  public var id: String { seriesKey }

  public init(seriesKey: String, establishedAt: Date) {
    self.seriesKey = seriesKey
    self.establishedAt = establishedAt
  }
}

/// Database-only operations for the explicit series declaration. Provider mutation belongs to
/// `GmailDispositionService`; these operations only establish or remove authority.
public enum GmailSeriesDispositionOperations {
  public static func declare(seriesKey: String, at date: Date, in db: Database) throws {
    try GmailSeriesDisposition
      .upsert { GmailSeriesDisposition.Draft(GmailSeriesDisposition(seriesKey: seriesKey, establishedAt: date)) }
      .execute(db)
  }

  public static func undeclare(seriesKey: String, in db: Database) throws {
    try GmailSeriesDisposition.find(seriesKey).delete().execute(db)
  }

  public static func isDeclared(seriesKey: String, in db: Database) throws -> Bool {
    try GmailSeriesDisposition.find(seriesKey).fetchOne(db) != nil
  }

  public static func declaredKeys(in db: Database) throws -> [String] {
    try GmailSeriesDisposition.order { $0.seriesKey }.fetchAll(db).map(\.seriesKey)
  }
}
