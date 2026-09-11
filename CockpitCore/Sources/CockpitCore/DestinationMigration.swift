import SQLiteData

extension CockpitMigrations {
  static func registerDestinations(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("Destinations and normalized text custody") { db in
      try createMemberships(in: db)
      try createTextTables(in: db)
      try #sql("""
        INSERT INTO "localNormalizedTexts" ("contentPieceID", "normalizedText")
        SELECT "id", "normalizedText" FROM "contentPieces" WHERE "normalizedText" IS NOT NULL
        """).execute(db)
      // S1 never registered this column with CloudKit; this is the pre-sync migration.
      try #sql("ALTER TABLE \"contentPieces\" DROP COLUMN \"normalizedText\"").execute(db)
      try NormalizedTextTriggers.install(in: db)
    }
  }

  private static func createMemberships(in db: Database) throws {
    // Membership identity is the ContentPiece UUID. Admission checks the relationship in
    // deterministic code; root records can arrive in either order during CloudKit sync.
    // No cascading parent deletion or nullable membership identity is introduced.
    try #sql("""
      CREATE TABLE "laterMemberships" (
        "contentPieceID" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE,
        "addedAt" TEXT NOT NULL
      ) STRICT
      """).execute(db)
    try #sql("""
      CREATE TABLE "libraryMemberships" (
        "contentPieceID" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE,
        "addedAt" TEXT NOT NULL,
        "admittedBy" TEXT NOT NULL
      ) STRICT
      """).execute(db)
  }

  private static func createTextTables(in db: Database) throws {
    try #sql("""
      CREATE TABLE "localNormalizedTexts" (
        "contentPieceID" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE,
        "normalizedText" TEXT NOT NULL
      ) STRICT
      """).execute(db)
    try #sql("""
      CREATE TABLE "libraryNormalizedTexts" (
        "contentPieceID" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE,
        "libraryMembershipID" TEXT REFERENCES "libraryMemberships"("contentPieceID") ON DELETE SET NULL,
        "utf8" BLOB,
        CHECK ("libraryMembershipID" IS NULL OR "libraryMembershipID" = "contentPieceID")
      ) STRICT
      """).execute(db)
    try #sql("""
      CREATE INDEX "index_libraryNormalizedTexts_on_membership"
      ON "libraryNormalizedTexts" ("libraryMembershipID")
      """).execute(db)
  }
}
