import SQLiteData

extension CockpitMigrations {
  static func registerRelevanceChange(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("Judgment-matched Personal Knowledge rationale") { db in
      // This is presentation provenance for a materialised Edition, not a foreign key. A claim
      // may later be superseded, while the historical Edition must retain the explanation it had.
      try #sql(
        """
        ALTER TABLE "editionEntries"
        ADD COLUMN "matchedPersonalKnowledgeClaimID" TEXT
        """
      ).execute(db)
    }
  }
}
