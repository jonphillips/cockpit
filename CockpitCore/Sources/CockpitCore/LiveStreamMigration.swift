import SQLiteData

extension CockpitMigrations {
  static func registerLiveStreams(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("Live Stream handling and health") { db in
      // These are additive fields on the CloudKit-synced `streams` table. Existing data retains
      // its active follow state and gains quiet, healthy defaults until the first live poll.
      try #sql("ALTER TABLE \"streams\" ADD COLUMN \"handlingGuidance\" TEXT NOT NULL DEFAULT ''").execute(db)
      try #sql("ALTER TABLE \"streams\" ADD COLUMN \"consecutiveFailureCount\" INTEGER NOT NULL DEFAULT 0").execute(db)
      try #sql("ALTER TABLE \"streams\" ADD COLUMN \"lastFailureDescription\" TEXT").execute(db)
    }
  }
}
