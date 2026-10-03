import SQLiteData

extension CockpitMigrations {
  static func registerListedFeeds(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("Listed feeds posture and state") { db in
      try #sql("""
        CREATE TABLE "listedPieceStates" (
          "contentPieceID" TEXT PRIMARY KEY NOT NULL,
          "openedAt" TEXT,
          "dismissedAt" TEXT
        ) STRICT
        """).execute(db)
    }
  }
}
