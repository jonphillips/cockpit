import Foundation
import SQLiteData

/// The device-local cursor for one Gmail account's category-scoped delta sync. It is intentionally
/// separate from Artifact provenance: this is an observation of one device's read progress, not
/// shared Cockpit content or a cross-device source-of-truth.
@Table("gmailSyncStates")
public struct GmailSyncState: Equatable, Identifiable, Sendable {
  @Column(primaryKey: true) public let accountID: String
  public let historyID: String
  public let updatedAt: Date
  public let readStateRefreshCompletedAt: Date?

  public var id: String { accountID }

  public init(
    accountID: String, historyID: String, updatedAt: Date,
    readStateRefreshCompletedAt: Date? = nil
  ) {
    self.accountID = accountID
    self.historyID = historyID
    self.updatedAt = updatedAt
    self.readStateRefreshCompletedAt = readStateRefreshCompletedAt
  }
}
