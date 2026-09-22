import SQLiteData

extension CockpitMigrations {
  static func registerCurationRouting(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("M6 S-d0d editable sub-feed routing") { db in
      // This table records explicit locator-routing edits only. Seeded defaults remain in code so
      // the initial routing table is deterministic and future seeds can arrive without a data
      // migration. The locator is the same normalized List-ID/sender identity used by Gmail.
      try #sql(
        """
        CREATE TABLE "contentRoleRoutingRules" (
          "locator" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE,
          "role" TEXT NOT NULL,
          "isFollowed" INTEGER NOT NULL DEFAULT 1,
          "isMuted" INTEGER NOT NULL DEFAULT 0
        ) STRICT
        """
      ).execute(db)
    }
  }
}
