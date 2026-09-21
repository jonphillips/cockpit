import SQLiteData

extension CockpitMigrations {
  static func registerGmailSeriesDispositions(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("M6 S1 Gmail series dispositions") { db in
      // Presence is the explicit declaration. Deleting the row undeclares the series; no enabled
      // flag or generic action column is permitted by the slice contract.
      try #sql(
        """
        CREATE TABLE "gmailSeriesDispositions" (
          "seriesKey" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE,
          "establishedAt" TEXT NOT NULL
        ) STRICT
        """
      ).execute(db)
    }
  }
}
