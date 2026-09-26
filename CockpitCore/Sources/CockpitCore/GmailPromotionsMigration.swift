import SQLiteData

extension CockpitMigrations {
  static func registerGmailPromotions(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("M6 S-t3 Gmail Promotions epoch") { db in
      try #sql("ALTER TABLE \"gmailSyncStates\" ADD COLUMN \"promotionsSince\" TEXT")
        .execute(db)
    }
  }
}
