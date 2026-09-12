import Dependencies
import LLMClientKit
import Observation

/// Owns the one piece of AI configuration a person controls in Cockpit: the frontier
/// API key per provider. The key is the only credential that is *not* shared through
/// the synced database — it lives in the Keychain (`APIKeyStore`, iCloud-Keychain
/// synced across the user's own devices), so this model reads and writes it through
/// that injectable store rather than any SQLiteData/CloudKit table.
///
/// Cockpit's model access degrades to on-device when no key is present; a configured
/// frontier key is what lets `.frontierPreferred` work — notably the Jon Brain import
/// reconciliation, an infrequent, correctness-critical pass that wants the strong model.
@MainActor
@Observable
public final class AISettingsModel {
  @ObservationIgnored @Dependency(\.apiKeyStore) private var keyStore
  @ObservationIgnored @Dependency(\.frontierPreferenceStore) private var preferenceStore

  /// The provider being configured, which is also the one Cockpit uses when a frontier
  /// model is called. Persisted via `persistPreferredProvider()` when the user changes it.
  public var provider: FrontierProvider
  public var draftKey = ""
  /// Masked previews of the stored keys, refreshed from the Keychain after every
  /// mutation so the view reflects reality without reading the secret itself.
  public private(set) var maskedKeys: [FrontierProvider: String] = [:]
  public var statusMessage: String?

  public init(provider: FrontierProvider = .anthropic) {
    self.provider = provider
  }

  public var providers: [FrontierProvider] { FrontierProvider.allCases }

  public var maskedKeyForSelected: String? { maskedKeys[provider] }

  public func refresh() {
    if let stored = preferenceStore.preferred() { provider = stored }
    var result: [FrontierProvider: String] = [:]
    for candidate in FrontierProvider.allCases {
      if let masked = keyStore.maskedKey(candidate) { result[candidate] = masked }
    }
    maskedKeys = result
  }

  /// Persist the current provider selection as the preferred one. Called when the user
  /// changes the picker, so the choice survives relaunch and drives the import path.
  public func persistPreferredProvider() {
    preferenceStore.setPreferred(provider)
  }

  public func saveButtonTapped() {
    let trimmed = draftKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      statusMessage = nil
      return
    }
    keyStore.setKey(trimmed, for: provider)
    draftKey = ""
    refresh()
    statusMessage = "Saved \(provider.displayName) key."
  }

  public func clearButtonTapped(_ provider: FrontierProvider) {
    keyStore.setKey(nil, for: provider)
    if self.provider == provider { draftKey = "" }
    refresh()
    statusMessage = "Removed \(provider.displayName) key."
  }
}
