import SQLiteData

extension CockpitMigrations {
  static func registerTodayAttention(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("M4 S7 local Today attention") { db in
      // Gmail Artifacts and Inbox observations are device-local. Clear is therefore a local
      // Cockpit resolution marker, not a synchronized provider-disposition command.
      try #sql("""
        CREATE TABLE "todayAttentions" (
          "contentPieceID" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE,
          "clearedAt" TEXT NOT NULL
        ) STRICT
        """).execute(db)
    }
  }
}
