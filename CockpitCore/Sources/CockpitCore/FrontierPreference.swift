import Dependencies
import Foundation
import LLMClientKit
import Synchronization

/// The one AI *preference* Cockpit persists: which frontier provider to use when a
/// frontier model is called and more than one is configured. Keys live in the Keychain
/// (`APIKeyStore`); this is an ordinary device-local preference, so it lives in
/// `UserDefaults`. Injectable so the settings model and the import path are testable
/// without touching real defaults.
///
/// This does not decide *whether* a frontier model is used — that is still "a key exists,
/// else degrade to on-device." It only breaks the tie between configured providers, which
/// `FrontierResolver`'s fixed Anthropic-first order cannot express.
public struct FrontierPreferenceStore: Sendable {
  var read: @Sendable () -> FrontierProvider?
  var write: @Sendable (FrontierProvider?) -> Void

  public init(
    read: @escaping @Sendable () -> FrontierProvider?,
    write: @escaping @Sendable (FrontierProvider?) -> Void
  ) {
    self.read = read
    self.write = write
  }

  /// The provider the user prefers, or nil when they have never chosen one.
  public func preferred() -> FrontierProvider? { read() }

  /// Store a preference, or clear it by passing nil.
  public func setPreferred(_ provider: FrontierProvider?) { write(provider) }
}

extension FrontierPreferenceStore: DependencyKey {
  public static let liveValue = FrontierPreferenceStore.live()

  static let defaultsKey = "cockpit.preferredFrontierProvider"

  public static func live() -> FrontierPreferenceStore {
    // `UserDefaults.standard` is read inside each closure rather than captured, since
    // `UserDefaults` is not `Sendable`. Its accessors are themselves thread-safe.
    FrontierPreferenceStore(
      read: {
        UserDefaults.standard.string(forKey: defaultsKey).flatMap(FrontierProvider.init(rawValue:))
      },
      write: { provider in
        if let provider {
          UserDefaults.standard.set(provider.rawValue, forKey: defaultsKey)
        } else {
          UserDefaults.standard.removeObject(forKey: defaultsKey)
        }
      }
    )
  }

  public static var testValue: FrontierPreferenceStore { inMemory() }
  public static var previewValue: FrontierPreferenceStore { inMemory() }

  static func inMemory() -> FrontierPreferenceStore {
    let storage = Mutex<FrontierProvider?>(nil)
    return FrontierPreferenceStore(
      read: { storage.withLock { $0 } },
      write: { provider in storage.withLock { $0 = provider } }
    )
  }
}

extension DependencyValues {
  public var frontierPreferenceStore: FrontierPreferenceStore {
    get { self[FrontierPreferenceStore.self] }
    set { self[FrontierPreferenceStore.self] = newValue }
  }
}
