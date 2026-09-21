import Foundation
import SQLiteData

/// The deliberately small, consultable trace for Gmail Trash operations. It is a projection of the
/// existing disposition log, not a second history table.
public struct RecentTrashRequest: FetchKeyRequest {
  /// The trace is a recent-glance, not the whole history — bound it so the query and the list stay
  /// small as the disposition log grows. Undo of anything older still works from its own row.
  static let limit = 100

  @Selection
  public struct Row: Equatable, Identifiable, Sendable {
    public let id: GmailDispositionLogEntry.ID
    public let contentPieceID: ContentPiece.ID
    public let sender: String?
    public let publisher: String
    public let subject: String
    public let appliedAt: Date
    public let reversedAt: Date?

    public var senderLabel: String { sender ?? publisher }
    public var isUndoable: Bool { reversedAt == nil }
  }

  public struct Value: Equatable, Sendable {
    public var rows: [Row] = []
    public init() {}
  }

  public init() {}

  public func fetch(_ db: Database) throws -> Value {
    var value = Value()
    value.rows = try GmailDispositionLogEntry
      .where { $0.operation.eq(GmailDispositionOperation.trash) }
      .order { $0.appliedAt.desc() }
      .join(Artifact.all) { $1.providerID.eq($0.providerID) }
      .join(ContentPiece.all) { $1.contentPieceID.eq($2.id) }
      .select {
        Row.Columns(
          id: $0.id, contentPieceID: $2.id, sender: $2.creator,
          publisher: $2.publisher, subject: $2.title, appliedAt: $0.appliedAt,
          reversedAt: $0.reversedAt
        )
      }
      .limit(Self.limit)
      .fetchAll(db)
    return value
  }
}
