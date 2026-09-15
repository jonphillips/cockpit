import SQLiteData

extension CockpitMigrations {
  static func registerS5(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("M2 S5 completeness and Pending Finds") { db in
      // ContentPiece already existed before S5; this is a real additive schema migration
      // (ADR-0001). Existing rows remain unresolved until their next ingest or judgment fallback.
      try #sql("ALTER TABLE \"contentPieces\" ADD COLUMN \"bodyCompleteness\" TEXT").execute(db)
      try #sql(
        """
        CREATE TABLE "pendingFinds" (
          "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE,
          "contentPieceID" TEXT NOT NULL,
          "kind" TEXT NOT NULL,
          "name" TEXT NOT NULL,
          "descriptor" TEXT NOT NULL,
          "rationale" TEXT NOT NULL,
          "sourceURL" TEXT,
          "hints" TEXT,
          "state" TEXT NOT NULL DEFAULT 'pending'
        ) STRICT
        """
      ).execute(db)
      try #sql(
        "CREATE INDEX \"index_pendingFinds_on_contentPieceID\" ON \"pendingFinds\" (\"contentPieceID\")"
      ).execute(db)
    }
  }
}
