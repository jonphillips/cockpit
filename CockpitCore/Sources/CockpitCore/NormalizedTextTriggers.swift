import SQLiteData

enum NormalizedTextTriggers {
  static func install(in db: Database) throws {
    db.add(function: SyncEngine.$isSynchronizing)
    try promoteOnAdmission(in: db)
    try projectLocalText(in: db)
    try receiveLibraryText(in: db)
  }

  private static func promoteOnAdmission(in db: Database) throws {
    try #sql("""
      CREATE TRIGGER "library_text_admission" AFTER INSERT ON "libraryMemberships"
      WHEN NOT \(SyncEngine.$isSynchronizing)
      BEGIN
        INSERT INTO "libraryNormalizedTexts" ("contentPieceID", "libraryMembershipID", "utf8")
        SELECT "contentPieceID", "contentPieceID", CAST("normalizedText" AS BLOB)
        FROM "localNormalizedTexts" WHERE "contentPieceID" = new."contentPieceID"
        ON CONFLICT ("contentPieceID") DO UPDATE
        SET "libraryMembershipID" = excluded."libraryMembershipID", "utf8" = excluded."utf8"
        WHERE "libraryNormalizedTexts"."libraryMembershipID" IS NOT excluded."libraryMembershipID"
          OR "libraryNormalizedTexts"."utf8" IS NOT excluded."utf8";
      END
      """).execute(db)
  }

  private static func projectLocalText(in db: Database) throws {
    for event in ["INSERT", "UPDATE OF normalizedText"] {
      try #sql("""
        CREATE TRIGGER \(quote: "library_text_local_\(event)", delimiter: .identifier)
        AFTER \(raw: event) ON "localNormalizedTexts"
        WHEN NOT \(SyncEngine.$isSynchronizing)
        BEGIN
          INSERT INTO "libraryNormalizedTexts" ("contentPieceID", "libraryMembershipID", "utf8")
          SELECT new."contentPieceID", new."contentPieceID", CAST(new."normalizedText" AS BLOB)
          WHERE EXISTS (SELECT 1 FROM "libraryMemberships" WHERE "contentPieceID" = new."contentPieceID")
          ON CONFLICT ("contentPieceID") DO UPDATE
          SET "libraryMembershipID" = excluded."libraryMembershipID", "utf8" = excluded."utf8"
          WHERE "libraryNormalizedTexts"."libraryMembershipID" IS NOT excluded."libraryMembershipID"
            OR "libraryNormalizedTexts"."utf8" IS NOT excluded."utf8";
        END
        """).execute(db)
    }
  }

  private static func receiveLibraryText(in db: Database) throws {
    for event in ["INSERT", "UPDATE"] {
      try #sql("""
        CREATE TRIGGER \(quote: "library_text_receive_\(event)", delimiter: .identifier)
        AFTER \(raw: event) ON "libraryNormalizedTexts"
        BEGIN
          INSERT INTO "localNormalizedTexts" ("contentPieceID", "normalizedText")
          SELECT new."contentPieceID", CAST(new."utf8" AS TEXT)
          WHERE new."utf8" IS NOT NULL AND new."libraryMembershipID" IS NOT NULL
          ON CONFLICT ("contentPieceID") DO UPDATE SET "normalizedText" = excluded."normalizedText"
          WHERE "localNormalizedTexts"."normalizedText" IS NOT excluded."normalizedText";
          UPDATE "libraryNormalizedTexts" SET "utf8" = NULL
          WHERE "contentPieceID" = new."contentPieceID" AND "libraryMembershipID" IS NULL
            AND "utf8" IS NOT NULL;
        END
        """).execute(db)
    }
  }
}
