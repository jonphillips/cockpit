import CloudKit
import CloudSyncKit
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
    try SyncEngine(
      for: database,
      tables: InterestArea.self, Stream.self, ContentPiece.self,
        LaterMembership.self, LibraryMembership.self, LibraryNormalizedText.self,
      containerIdentifier: configuration.containerIdentifier,
      startImmediately: startImmediately
    )
  }
}
