import SQLiteData

extension CockpitMigrations {
  static func registerGmailReadState(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("M6 S-t2 Gmail read-state mirror") { db in
      try #sql("ALTER TABLE \"artifacts\" ADD COLUMN \"providerIsUnread\" INTEGER").execute(db)
      try #sql(
        "ALTER TABLE \"gmailSyncStates\" ADD COLUMN \"readStateRefreshCompletedAt\" TEXT"
      ).execute(db)
    }
  }
}
