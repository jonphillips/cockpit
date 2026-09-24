import Foundation
import SQLiteData

extension ContentPieceReaderModel {
  /// Loads the device-local size preference for this newsletter's List-ID-first series.
  public func loadEmailZoomPreference() async {
    do {
      let key = try await database.read { db in
        try GmailSeriesKey.seriesKey(forContentPieceID: contentPieceID, in: db)
      }
      emailSeriesKey = key
      emailZoomAdjustmentStep = key.flatMap(emailZoomPreferenceStore.adjustmentStep(for:)) ?? 0
      isEmailZoomPreferenceLoaded = true
    } catch is CancellationError {
      isEmailZoomPreferenceLoaded = true
    } catch {
      emailSeriesKey = nil
      emailZoomAdjustmentStep = 0
      isEmailZoomPreferenceLoaded = true
    }
  }

  public func largerEmailText(designWidth: Double?, viewportWidth: Double) {
    guard EmailFitZoom.canIncrease(
      designWidth: designWidth, viewportWidth: viewportWidth, adjustmentStep: emailZoomAdjustmentStep
    ) else { return }
    setEmailZoomAdjustmentStep(emailZoomAdjustmentStep + 1)
  }

  public func smallerEmailText(designWidth: Double?, viewportWidth: Double) {
    guard EmailFitZoom.canDecrease(
      designWidth: designWidth, viewportWidth: viewportWidth, adjustmentStep: emailZoomAdjustmentStep
    ) else { return }
    setEmailZoomAdjustmentStep(emailZoomAdjustmentStep - 1)
  }

  /// Applies a multi-step gesture through the same per-step viewport checks as the buttons.
  public func adjustEmailZoom(by requestedSteps: Int, designWidth: Double?, viewportWidth: Double) {
    let steps = min(8, max(-8, requestedSteps))
    guard steps != 0 else { return }
    for _ in 0..<abs(steps) {
      let previousStep = emailZoomAdjustmentStep
      if steps > 0 {
        largerEmailText(designWidth: designWidth, viewportWidth: viewportWidth)
      } else {
        smallerEmailText(designWidth: designWidth, viewportWidth: viewportWidth)
      }
      guard emailZoomAdjustmentStep != previousStep else { break }
    }
  }

  public func resetEmailTextSize() {
    setEmailZoomAdjustmentStep(0)
  }

  /// Pinch gestures may move several steps; clamp to the same explicit range as keyboard/menu input.
  public func setEmailZoomAdjustmentStep(_ step: Int) {
    let bounded = min(EmailFitZoom.adjustmentRange.upperBound, max(EmailFitZoom.adjustmentRange.lowerBound, step))
    emailZoomAdjustmentStep = bounded
    if let emailSeriesKey { emailZoomPreferenceStore.setAdjustmentStep(bounded, for: emailSeriesKey) }
  }
}
