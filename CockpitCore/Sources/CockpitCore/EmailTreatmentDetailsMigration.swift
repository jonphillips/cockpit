import SQLiteData

extension CockpitMigrations {
  static func registerEmailTreatmentDetails(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("M4 S8 Gmail treatment details") { db in
      // These are device-local, regenerable interpretations of Gmail source text. They belong to
      // one email ContentPiece and deliberately do not introduce a child domain model: grab-bag
      // items have no lifecycle outside their issue, while offer Finds keep using PendingFind.
      try #sql(
        """
        CREATE TABLE "emailTreatmentDetails" (
          "contentPieceID" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE,
          "offerSummary" TEXT,
          "grabBagItems" TEXT
        ) STRICT
        """
      ).execute(db)
    }
  }
}
