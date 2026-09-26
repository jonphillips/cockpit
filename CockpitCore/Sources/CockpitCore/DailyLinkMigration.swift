import SQLiteData

extension CockpitMigrations {
  static func registerDailyLinks(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("M6 S-t4 daily links") { db in
      try #sql("""
        CREATE TABLE "dailyLinks" (
          "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE,
          "title" TEXT NOT NULL,
          "url" TEXT NOT NULL,
          "symbolName" TEXT NOT NULL DEFAULT 'link',
          "sortOrder" INTEGER NOT NULL,
          "lastVisitedAt" TEXT,
          "createdAt" TEXT NOT NULL
        ) STRICT
        """).execute(db)
    }
  }
}
