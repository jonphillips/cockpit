import SQLiteData

extension CockpitMigrations {
  static func registerSenderTreatmentRoutingMigration(in migrator: inout DatabaseMigrator) {
    migrator.registerMigration("M6 migrate sender treatment corrections to content roles") { db in
      let existingLocators = Set(try ContentRoleRoutingRule.all.fetchAll(db).map {
        CurationRouting.canonicalLocator($0.locator)
      })
      for override in try EmailSenderTreatmentOverride.all.fetchAll(db) {
        let role: ContentRole
        switch override.treatment {
        case .grabBag: role = .grabBag
        case .offer: role = .offers
        case .personal, .newsletter, .transactional: continue
        }
        let locator = CurationRouting.canonicalLocator(override.senderKey)
        guard !existingLocators.contains(locator) else { continue }
        try ContentRoleRoutingRule.insert {
          ContentRoleRoutingRule.Draft(
            ContentRoleRoutingRule(locator: locator, role: role, isFollowed: true, isMuted: false))
        }.execute(db)
      }
    }
  }
}
