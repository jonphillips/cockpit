import SQLiteData

extension CockpitMigrations {
  static func registerGmailSyncState(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("M5 S6 Gmail delta-sync cursor") { db in
      // `historyId` is a device-local observation cursor. It is intentionally the only new
      // persistence required for partial reads: failed messages re-enter because the cursor is
      // not advanced until every message in the history range is durably recorded.
      try #sql(
        """
        CREATE TABLE "gmailSyncStates" (
          "accountID" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE,
          "historyID" TEXT NOT NULL,
          "updatedAt" TEXT NOT NULL
        ) STRICT
        """
      ).execute(db)
    }
  }
}
