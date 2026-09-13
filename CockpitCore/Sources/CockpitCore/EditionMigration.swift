import SQLiteData

extension CockpitMigrations {
  static func registerEdition(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("Edition and EditionEntry") { db in
      try #sql(
        """
        CREATE TABLE "editions" (
          "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE,
          "date" TEXT NOT NULL,
          "composedAt" TEXT,
          "state" TEXT NOT NULL DEFAULT 'composing',
          "targetSize" INTEGER NOT NULL DEFAULT 20,
          "estimatedCostUSD" REAL,
          "promptVersion" TEXT,
          "modelName" TEXT
        ) STRICT
        """
      ).execute(db)
      // One Edition per day is enforced in code: `id` is derived from the day (`EditionDay`) and
      // composition is a no-op when today's row already exists. The index is not unique because
      // SQLiteData's SyncEngine rejects uniqueness constraints on synchronized tables (Edition
      // syncs, ADR-0001 D6); it exists only to order by day.
      try #sql(
        """
        CREATE INDEX "index_editions_on_date" ON "editions" ("date")
        """
      ).execute(db)
      // No foreign keys: `editionID`/`contentPieceID`/`firstAdmittedEditionID` are non-null
      // single-parent references, which SQLiteData cannot express (see `DestinationMigration`
      // for the same constraint on memberships). The relationships are enforced in
      // `EditionOperations` / `EditionComposer` instead.
      try #sql(
        """
        CREATE TABLE "editionEntries" (
          "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE,
          "editionID" TEXT NOT NULL,
          "contentPieceID" TEXT NOT NULL,
          "section" TEXT NOT NULL,
          "rank" INTEGER NOT NULL,
          "rationale" TEXT,
          "entryState" TEXT NOT NULL DEFAULT 'admitted',
          "firstAdmittedEditionID" TEXT NOT NULL,
          "timesCarried" INTEGER NOT NULL DEFAULT 0
        ) STRICT
        """
      ).execute(db)
      try #sql(
        """
        CREATE INDEX "index_editionEntries_on_editionID" ON "editionEntries" ("editionID")
        """
      ).execute(db)
      try #sql(
        """
        CREATE INDEX "index_editionEntries_on_contentPieceID" ON "editionEntries" ("contentPieceID")
        """
      ).execute(db)
    }
  }
}
