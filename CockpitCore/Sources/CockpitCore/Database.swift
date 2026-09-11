import CloudKit
import CloudSyncKit
import Dependencies
import Foundation
import SQLiteData

public enum CockpitCloudSync {
  public static let configuration = CloudSyncConfiguration(
    containerIdentifier: "iCloud.com.jonphillips.cockpit",
    enabledDefaultsKey: "CockpitCloudKitSyncEnabled",
    enabledEnvironmentKey: "COCKPIT_CLOUDKIT_SYNC_ENABLED",
    enabledLaunchArgument: "-CockpitCloudKitSyncEnabled"
  )

  public static func makeSyncEngine(
    for database: any DatabaseWriter,
    startImmediately: Bool
  ) throws -> SyncEngine {
    throw CockpitCloudSyncError.normalizedTextRequiresLibraryChildRecord
  }
}

public enum CockpitCloudSyncError: Error, Equatable, Sendable {
  case normalizedTextRequiresLibraryChildRecord
}

public enum CockpitStorage {
  public static func liveDatabasePath() -> String {
    let directory = URL.applicationSupportDirectory.appending(
      path: "Cockpit", directoryHint: .isDirectory
    )
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appending(path: "cockpit.sqlite").path(percentEncoded: false)
  }
}

extension DependencyValues {
  public mutating func bootstrapDatabase() throws {
    @Dependency(\.context) var context
    var configuration = Configuration()
    configuration.prepareDatabase { db in
      guard context == .live else { return }
      try? db.attachMetadatabase(containerIdentifier: CockpitCloudSync.configuration.containerIdentifier)
    }
    let database: any DatabaseWriter = if context == .live {
      try SQLiteData.defaultDatabase(
        path: CockpitStorage.liveDatabasePath(), configuration: configuration
      )
    } else {
      try SQLiteData.defaultDatabase(configuration: configuration)
    }
    var migrator = DatabaseMigrator()
    migrator.registerMigration("Create persistence spine tables") { db in
      try #sql(
        """
        CREATE TABLE "interestAreas" (
          "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE,
          "name" TEXT NOT NULL,
          "guidance" TEXT NOT NULL DEFAULT '',
          "sortOrder" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0
        ) STRICT
        """
      ).execute(db)
      try #sql(
        """
        CREATE TABLE "streams" (
          "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE,
          "name" TEXT NOT NULL,
          "publisher" TEXT NOT NULL,
          "interestAreaID" TEXT REFERENCES "interestAreas"("id") ON DELETE SET NULL,
          "transport" TEXT NOT NULL,
          "locator" TEXT NOT NULL,
          "handling" TEXT NOT NULL DEFAULT 'following',
          "isEssential" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,
          "followState" TEXT NOT NULL DEFAULT 'active',
          "health" TEXT NOT NULL DEFAULT 'unknown',
          "lastReceivedAt" TEXT,
          "autoLibrary" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0
        ) STRICT
        """
      ).execute(db)
      try #sql(
        """
        CREATE TABLE "contentPieces" (
          "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE,
          "kind" TEXT NOT NULL,
          "title" TEXT NOT NULL,
          "creator" TEXT,
          "publisher" TEXT NOT NULL,
          "publishedAt" TEXT,
          "canonicalURL" TEXT,
          "summary" TEXT,
          "normalizedText" TEXT,
          "subjects" TEXT,
          "isSubstantivePrimary" INTEGER,
          "createdAt" TEXT NOT NULL
        ) STRICT
        """
      ).execute(db)
      try #sql(
        """
        CREATE TABLE "artifacts" (
          "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE,
          "streamID" TEXT REFERENCES "streams"("id") ON DELETE SET NULL,
          "transport" TEXT NOT NULL,
          "providerID" TEXT,
          "canonicalURL" TEXT,
          "acquiredAt" TEXT NOT NULL,
          "payloadRef" TEXT,
          "rawSourceText" TEXT,
          "contentPieceID" TEXT REFERENCES "contentPieces"("id") ON DELETE SET NULL
        ) STRICT
        """
      ).execute(db)
      try #sql("CREATE INDEX \"index_artifacts_on_contentPieceID\" ON \"artifacts\" (\"contentPieceID\")").execute(db)
      try #sql("CREATE INDEX \"index_artifacts_on_streamID\" ON \"artifacts\" (\"streamID\")").execute(db)
    }
    migrator.registerMigration("Deduplicate feed artifacts") { db in
      try #sql(
        """
        DELETE FROM "artifacts"
        WHERE "streamID" IS NOT NULL
          AND "providerID" IS NOT NULL
          AND "id" NOT IN (
            SELECT MIN("id")
            FROM "artifacts"
            WHERE "streamID" IS NOT NULL AND "providerID" IS NOT NULL
            GROUP BY "streamID", "providerID"
          )
        """
      ).execute(db)
      try #sql(
        """
        CREATE UNIQUE INDEX "index_artifacts_on_streamID_providerID"
        ON "artifacts" ("streamID", "providerID")
        WHERE "streamID" IS NOT NULL AND "providerID" IS NOT NULL
        """
      ).execute(db)
      try #sql(
        """
        DELETE FROM "artifacts"
        WHERE "streamID" IS NOT NULL
          AND "providerID" IS NULL
          AND "canonicalURL" IS NOT NULL
          AND "id" NOT IN (
            SELECT MIN("id")
            FROM "artifacts"
            WHERE "streamID" IS NOT NULL
              AND "providerID" IS NULL
              AND "canonicalURL" IS NOT NULL
            GROUP BY "streamID", "canonicalURL"
          )
        """
      ).execute(db)
      try #sql(
        """
        CREATE UNIQUE INDEX "index_artifacts_on_streamID_canonicalURL_without_providerID"
        ON "artifacts" ("streamID", "canonicalURL")
        WHERE "streamID" IS NOT NULL
          AND "providerID" IS NULL
          AND "canonicalURL" IS NOT NULL
        """
      ).execute(db)
    }
    try migrator.migrate(database)
    defaultDatabase = database
  }
}
