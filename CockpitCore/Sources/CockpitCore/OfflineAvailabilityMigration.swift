import SQLiteData

extension CockpitMigrations {
  static func registerOfflineAvailability(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("M4 S3 local offline availability") { db in
      // Per-device by definition, so this table is intentionally not registered with CloudKit.
      try #sql("""
        CREATE TABLE "localAvailabilities" (
          "contentPieceID" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE,
          "mode" TEXT NOT NULL,
          "expiresAt" TEXT,
          "verifiedAt" TEXT NOT NULL,
          "payloadRef" TEXT
        ) STRICT
        """).execute(db)
    }
  }
}
