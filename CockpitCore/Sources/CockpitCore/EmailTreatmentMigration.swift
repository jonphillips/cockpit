import SQLiteData

extension CockpitMigrations {
  static func registerEmailTreatment(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("M4 S5 Gmail treatment classification") { db in
      // Treatment is the smallest durable projection that lets Today organize every email without
      // making it a new entity or treating an AI result as a disposition command.
      try #sql("ALTER TABLE \"contentPieces\" ADD COLUMN \"emailTreatment\" TEXT").execute(db)
      // Grab-bag is an explicit per-Stream setting, not a detector or a reputation system.
      try #sql(
        "ALTER TABLE \"streams\" ADD COLUMN \"isGrabBag\" INTEGER NOT NULL DEFAULT 0"
      ).execute(db)
      // This table contains only corrections Jon explicitly makes. It starts empty; deterministic
      // classification never adds rows and no default sender list is seeded.
      try #sql(
        """
        CREATE TABLE "emailSenderTreatmentOverrides" (
          "senderKey" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE,
          "treatment" TEXT NOT NULL
        ) STRICT
        """
      ).execute(db)
    }
  }
}

extension CockpitMigrations {
  static func registerTransactionalTreatment(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("M5 S3 transactional Gmail treatment") { db in
      // The treatment stays a placement tag on the existing ContentPiece. The nullable sub-kind is
      // the minimum durable fact a later explicit OTP policy needs; it does not create a policy,
      // sender reputation, or provider-write authority.
      try #sql(
        "ALTER TABLE \"contentPieces\" ADD COLUMN \"emailTransactionalKind\" TEXT"
      ).execute(db)
    }
  }
}
