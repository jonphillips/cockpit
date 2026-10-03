import SQLiteData

extension CockpitMigrations {
  static func registerListedFeeds(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("M6 S-l1 listed piece states") { db in
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
