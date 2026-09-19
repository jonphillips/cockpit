import SQLiteData

extension CockpitMigrations {
  static func registerGmailDispositionLog(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("M5 S7 Gmail disposition Undo log") { db in
      // The bounded, inspectable Undo log (ADR-0002 D6). It records only what an applied disposition
      // did and whether it has been reversed; the inverse operation is derived from `operation`, so
      // there is no redundant column. `reversedAt` NULL means the disposition is still in effect.
      try #sql(
        """
        CREATE TABLE "gmailDispositionLogEntries" (
          "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE,
          "providerID" TEXT NOT NULL,
          "operation" TEXT NOT NULL,
          "appliedAt" TEXT NOT NULL,
          "reversedAt" TEXT
        ) STRICT
        """
      ).execute(db)
    }
  }
}
