import SQLiteData

extension CockpitMigrations {
  static func registerGmailIngest(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("M4 S4 Gmail provider provenance") { db in
      // Artifacts are device-local evidence. This JSON field retains only the raw headers and
      // provider identity S5 needs; ContentPiece remains the shared, provider-neutral result.
      try #sql("ALTER TABLE \"artifacts\" ADD COLUMN \"providerProvenance\" TEXT").execute(db)
    }
  }
}
