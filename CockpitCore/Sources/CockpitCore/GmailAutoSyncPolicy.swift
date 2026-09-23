import Foundation
import SQLiteData

/// Foreground polling is a cheap delta sync, but repeated activations should not repeat a failed
/// attempt or race an in-flight request.
public enum GmailAutoSyncPolicy {
  public static let minimumInterval: TimeInterval = 5 * 60

  public static func lastSyncedAt(in database: any DatabaseReader) async throws -> Date? {
    try await database.read { db in
      try GmailSyncState.all.fetchAll(db).first?.updatedAt
    }
  }

  public static func shouldSync(
    lastSyncedAt: Date?, lastAttemptAt: Date?, now: Date, isSyncing: Bool
  ) -> Bool {
    guard !isSyncing else { return false }
    guard let latest = [lastSyncedAt, lastAttemptAt].compactMap({ $0 }).max() else { return true }
    return now.timeIntervalSince(latest) >= minimumInterval
  }
}
