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

  /// Constructed **stopped**, per CloudSyncKit: "the app constructs the engine stopped at
  /// bootstrap, then calls `startIfManuallyEnabled` from `init()`." Starting here would push
  /// records to the container on first launch without the gate ever being consulted, and the
  /// CloudKit schema hardens the moment records exist.
  public static func makeSyncEngine(for database: any DatabaseWriter) throws -> SyncEngine {
    try SyncEngine(
      for: database,
      tables: InterestArea.self, Stream.self, ContentPiece.self,
        LaterMembership.self, LibraryMembership.self, LibraryNormalizedText.self,
        PersonalKnowledgeClaim.self,
      containerIdentifier: configuration.containerIdentifier,
      startImmediately: false
    )
  }

  /// Call from app `init()`. Starts the engine only when the enablement gate is on and an
  /// iCloud account is available. The gate is off until `-CockpitCloudKitSyncEnabled` is
  /// passed once, which is then persisted so later launches from the Home Screen still sync.
  /// The result is returned rather than discarded so a sync-health row can surface it later.
  @discardableResult
  public static func startIfEnabled() async -> CloudSync.StartResult {
    CloudSync.persistManualEnablementFromLaunchEnvironment(configuration: configuration)
    return await CloudSync.startIfManuallyEnabled(configuration: configuration)
  }
}
