import SQLiteData

extension CockpitMigrations {
  static func registerPersonalKnowledge(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("Personal Knowledge claims") { db in
      // This deliberately has no self-referential foreign key. CloudSyncKit rejects cyclic
      // schemas, while deterministic operations validate the current claim before recording
      // its supersession link.
      try #sql(
        """
        CREATE TABLE "personalKnowledgeClaims" (
          "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE,
          "kind" TEXT NOT NULL,
          "claim" TEXT NOT NULL,
          "scope" TEXT,
          "provenance" TEXT NOT NULL,
          "status" TEXT NOT NULL DEFAULT 'current',
          "supersededByID" TEXT,
          "createdAt" TEXT NOT NULL
        ) STRICT
        """
      ).execute(db)
      try #sql(
        """
        CREATE INDEX "index_personalKnowledgeClaims_on_current_kind"
        ON "personalKnowledgeClaims" ("status", "kind", "createdAt")
        """
      ).execute(db)
    }
  }
}
