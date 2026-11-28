import Foundation
import SQLiteData

/// Foreground polling is a cheap delta sync: repeated activations within the interval of a
/// successful sync skip it, and none races an in-flight request. A failed attempt is not a sync,
/// so the next activation retries it (MorningPrep's Ready rule must not see a failure as fresh).
public enum GmailAutoSyncPolicy {
  public static let minimumInterval: TimeInterval = 5 * 60

  public static func lastSyncedAt(in database: any DatabaseReader) async throws -> Date? {
    try await database.read { db in
      try GmailSyncState.all.fetchAll(db).first?.updatedAt
    }
  }

  public static func shouldSync(
    lastSyncedAt: Date?, now: Date, isSyncing: Bool
  ) -> Bool {
    guard !isSyncing else { return false }
    guard let lastSyncedAt else { return true }
    return now.timeIntervalSince(lastSyncedAt) >= minimumInterval
  }
}
