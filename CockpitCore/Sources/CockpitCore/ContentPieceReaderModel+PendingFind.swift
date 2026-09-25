import Foundation
import SQLiteData

extension ContentPieceReaderModel {
  public var pendingFind: PendingFind? {
    row?.emailTreatment == .offer ? pendingFindContent.find : nil
  }

  public var recipeFind: PendingFind? { pendingFindContent.recipeFind }

  public var yesChefReaderActionTitle: String? {
    guard let row, row.bodyCompleteness != .teaser,
      let text = row.localNormalizedText,
      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { return nil }
    return switch recipeFind?.state {
    case .some(.referred): "Sent to Yes Chef"
    case .some(.handedOff): "Added to Yes Chef"
    case .some(.declined): "Declined by Yes Chef"
    default: "Send to Yes Chef"
    }
  }

  public var canSendToYesChefFromReader: Bool {
    guard let title = yesChefReaderActionTitle else { return false }
    return title == "Send to Yes Chef"
  }

  /// Jon's Reader action declares the recipe hint without a model call. The shared sender creates
  /// or reuses the Find and completes the same mailbox, referral-log, and policy path as Settings.
  public func sendToYesChefFromReader() async {
    do {
      let sentAt = now
      let makeUUID = uuid
      let opened = try await FindReferralSendingService(
        database: database, handoffClient: findReferralClient,
        dispositionClient: dispositionClient, now: { sentAt }, uuid: { makeUUID() }
      ).sendFromReader(contentPieceID: contentPieceID)
      try await $pendingFindContent.load()
      errorMessage = opened ? nil : FindReferralHandoffError.yesChefUnavailable.localizedDescription
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// Explicitly confirms the Reader's proposal. If the established offer policy is enabled, it is
  /// now eligible, leaving the surface to perform the appropriate disposition action.
  public func confirmPendingFind() async -> Bool {
    guard let find = pendingFind else { return false }
    do {
      try await database.write { db in try PendingFindOperations.confirm(find.id, in: db) }
      try await $pendingFindContent.load()
      let matches = try await database.read { db in
        try GmailDispositionPolicyOperations.matchingPieceIDs(in: db).contains(find.contentPieceID)
      }
      errorMessage = nil
      return matches
    } catch is CancellationError {
      return false
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }

  public func dismissPendingFind() async {
    guard let find = pendingFind else { return }
    do {
      try await database.write { db in try PendingFindOperations.dismiss(find.id, in: db) }
      try await $pendingFindContent.load()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
