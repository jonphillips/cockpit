import SQLiteData

extension CockpitMigrations {
  static func registerLiveStreams(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("Live Stream handling and poll state") { db in
      // Handling is synced editorial intent. Poll state is per-device acquisition observation.
      try #sql("ALTER TABLE \"streams\" ADD COLUMN \"handlingGuidance\" TEXT NOT NULL DEFAULT ''").execute(db)
      try #sql(
        """
        CREATE TABLE "streamPollStates" (
          "streamID" TEXT PRIMARY KEY NOT NULL REFERENCES "streams"("id"),
          "health" TEXT NOT NULL DEFAULT 'unknown',
          "lastReceivedAt" TEXT,
          "consecutiveFailureCount" INTEGER NOT NULL DEFAULT 0,
          "lastFailureDescription" TEXT
        ) STRICT
        """
      ).execute(db)
    }
  }
}
