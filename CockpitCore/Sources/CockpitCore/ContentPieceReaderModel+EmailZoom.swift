import Foundation
import SQLiteData

extension ContentPieceReaderModel {
  public func saveForLater() async {
    guard let id = row?.id else { return }
    let date = now
    await run { try DestinationOperations.saveForLater(id, at: date, in: $0) }
  }

  public func addToLibrary() async {
    guard let id = row?.id else { return }
    let date = now
    await run { try DestinationOperations.addToLibrary(id, at: date, in: $0) }
  }

  public func correctIsSubstantivePrimary(to value: Bool) async {
    guard let id = row?.id else { return }
    await run {
      try ContentPiece.find(id).update { $0.isSubstantivePrimary = #bind(value) }.execute($0)
    }
  }

  /// Loads the device-local size preference for this newsletter's List-ID-first series.
  public func loadEmailZoomPreference() async {
    guard let id = row?.id else { return }
    do {
      let key = try await database.read { db in try GmailSeriesKey.seriesKey(forContentPieceID: id, in: db) }
      emailSeriesKey = key
      emailZoomAdjustmentStep = key.flatMap(emailZoomPreferenceStore.adjustmentStep(for:)) ?? 0
    } catch is CancellationError {
    } catch {
      emailSeriesKey = nil
      emailZoomAdjustmentStep = 0
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
