import SQLiteData

extension CockpitMigrations {
  static func registerGmailDispositionPolicies(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("M5 S8 Gmail explicit disposition policies") { db in
      // The smallest table the demonstrated cases justify (DECISIONS §7): one row per established
      // policy kind, never a generic condition/action engine. `enabled` lets a policy be turned off
      // without erasing that it was established, and without un-disposing what it already did.
      try #sql(
        """
        CREATE TABLE "gmailDispositionPolicies" (
          "kind" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE,
          "establishedAt" TEXT NOT NULL,
          "enabled" INTEGER NOT NULL DEFAULT 1
        ) STRICT
        """
      ).execute(db)
    }
  }
}
