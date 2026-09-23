import Dependencies
import Foundation
import Synchronization

/// Device-local display preferences for newsletter series. These are intentionally separate from
/// synced Cockpit state and are keyed by Gmail's List-ID-first series identity.
public struct EmailZoomPreferenceStore: Sendable {
  var read: @Sendable (String) -> Int?
  var write: @Sendable (Int?, String) -> Void

  public init(
    read: @escaping @Sendable (String) -> Int?,
    write: @escaping @Sendable (Int?, String) -> Void
  ) {
    self.read = read
    self.write = write
  }

  public func adjustmentStep(for seriesKey: String) -> Int? {
    read(seriesKey).map { min(EmailFitZoom.adjustmentRange.upperBound, max(EmailFitZoom.adjustmentRange.lowerBound, $0)) }
  }

  /// Step zero removes the override so the series follows automatic fitting again.
  public func setAdjustmentStep(_ step: Int, for seriesKey: String) {
    let bounded = min(EmailFitZoom.adjustmentRange.upperBound, max(EmailFitZoom.adjustmentRange.lowerBound, step))
    write(bounded == 0 ? nil : bounded, seriesKey)
  }
}

extension EmailZoomPreferenceStore: DependencyKey {
  public static let liveValue = EmailZoomPreferenceStore.live()

  static let defaultsPrefix = "cockpit.emailZoom.series."

  public static func live() -> EmailZoomPreferenceStore {
    EmailZoomPreferenceStore(
      read: { key in UserDefaults.standard.object(forKey: defaultsPrefix + key) as? Int },
      write: { step, key in
        let defaultsKey = defaultsPrefix + key
        if let step { UserDefaults.standard.set(step, forKey: defaultsKey) }
        else { UserDefaults.standard.removeObject(forKey: defaultsKey) }
      }
    )
  }

  public static var testValue: EmailZoomPreferenceStore { inMemory() }
  public static var previewValue: EmailZoomPreferenceStore { inMemory() }

  static func inMemory() -> EmailZoomPreferenceStore {
    let storage = Mutex<[String: Int]>([:])
    return EmailZoomPreferenceStore(
      read: { key in storage.withLock { $0[key] } },
      write: { step, key in
        storage.withLock { values in
          if let step { values[key] = step } else { values.removeValue(forKey: key) }
        }
      }
    )
  }
}

extension DependencyValues {
  public var emailZoomPreferenceStore: EmailZoomPreferenceStore {
    get { self[EmailZoomPreferenceStore.self] }
    set { self[EmailZoomPreferenceStore.self] = newValue }
  }
}
