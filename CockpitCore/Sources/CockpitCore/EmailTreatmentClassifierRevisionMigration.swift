import SQLiteData

extension CockpitMigrations {
  static func registerEmailTreatmentClassifierRevision(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("M6 S-t8 email treatment classifier revision") { db in
      try #sql(
        """
        CREATE TABLE "emailTreatmentClassifierState" (
          "singletonID" INTEGER PRIMARY KEY NOT NULL CHECK ("singletonID" = 1),
          "revision" INTEGER NOT NULL
        ) STRICT
        """
      ).execute(db)
    }
  }
}
