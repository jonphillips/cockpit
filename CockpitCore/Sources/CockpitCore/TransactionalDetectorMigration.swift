import SQLiteData

extension CockpitMigrations {
  static func registerTransactionalDetector(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("M6 S-t8 reclassify transactional detector") { db in
      // Deterministic treatment is a local projection of retained Gmail evidence. Re-run the
      // classifier once so older messages receive the expanded detector without provider writes.
      try EmailTreatmentOperations.reclassifyAll(in: db)
    }
  }
}
