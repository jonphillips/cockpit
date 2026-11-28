@testable import CockpitCore
import Foundation
import Testing

struct GmailAutoSyncPolicyTests {
  @Test
  func foregroundThrottle() {
    let now = Date(timeIntervalSince1970: 100_000)
    let recent = now.addingTimeInterval(-4 * 60)
    let stale = now.addingTimeInterval(-6 * 60)

    #expect(GmailAutoSyncPolicy.shouldSync(
      lastSyncedAt: nil, now: now, isSyncing: false))
    #expect(!GmailAutoSyncPolicy.shouldSync(
      lastSyncedAt: recent, now: now, isSyncing: false))
    #expect(GmailAutoSyncPolicy.shouldSync(
      lastSyncedAt: stale, now: now, isSyncing: false))
    #expect(!GmailAutoSyncPolicy.shouldSync(
      lastSyncedAt: stale, now: now, isSyncing: true))
  }
}
