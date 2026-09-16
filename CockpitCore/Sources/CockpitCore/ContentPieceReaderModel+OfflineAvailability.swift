import Foundation

extension ContentPieceReaderModel {
  public var offlinePresentation: OfflineAvailabilityPresentation {
    offlineAvailabilityPresentation(for: row, at: now)
  }

  public func keepOffline(until date: Date) async {
    guard let id = row?.id else { return }
    let verificationDate = now
    await run {
      try LocalAvailabilityOperations.keepOffline(id, until: date, verifiedAt: verificationDate, in: $0)
    }
  }

  public func keepOffline() async {
    guard let id = row?.id else { return }
    let verificationDate = now
    await run { try LocalAvailabilityOperations.keepOffline(id, verifiedAt: verificationDate, in: $0) }
  }

  public func releaseOffline() async {
    guard let id = row?.id else { return }
    await run { try LocalAvailabilityOperations.releaseOffline(id, in: $0) }
  }
}
