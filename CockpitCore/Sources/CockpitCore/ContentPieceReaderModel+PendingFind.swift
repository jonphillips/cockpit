import Foundation
import SQLiteData

public enum ReaderFindHandoffStatus: Equatable, Sendable {
  case send
  case sending
  case sent
  case added
  case declined
  case unavailable

  public var title: String? {
    switch self {
    case .send: "Send to Yes Chef"
    case .sending: "Sending to Yes Chef…"
    case .sent: "Sent to Yes Chef"
    case .added: "Added to Yes Chef"
    case .declined: "Declined by Yes Chef"
    case .unavailable: nil
    }
  }
}

extension ContentPieceReaderModel {
  public var pendingFind: PendingFind? {
    row?.emailTreatment == .offer ? pendingFindContent.find : nil
  }

  public var recipeFind: PendingFind? { pendingFindContent.recipeFind }

  public var yesChefReaderActionStatus: ReaderFindHandoffStatus {
    if isSendingToYesChef { return .sending }
    guard let row, row.bodyCompleteness != .teaser,
      let text = row.localNormalizedText,
      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { return .unavailable }
    return switch recipeFind?.state {
    case .some(.referred): .sent
    case .some(.handedOff): .added
    case .some(.declined): .declined
    default: .send
    }
  }

  public var yesChefReaderActionTitle: String? { yesChefReaderActionStatus.title }

  public var canSendToYesChefFromReader: Bool {
    yesChefReaderActionStatus == .send
  }

  /// Jon's Reader action declares the recipe hint without a model call. The shared sender creates
  /// or reuses the Find and completes the same mailbox, referral-log, and policy path as Settings.
  public func sendToYesChefFromReader() async -> Bool {
    guard canSendToYesChefFromReader else { return false }
    setSendingToYesChef(true)
    defer { setSendingToYesChef(false) }
    do {
      let sentAt = now
      let makeUUID = uuid
      let result = try await FindReferralSendingService(
        database: database, handoffClient: findReferralClient,
        now: { sentAt }, uuid: { makeUUID() }
      ).sendFromReader(contentPieceID: contentPieceID)
      try await $pendingFindContent.load()
      errorMessage = result.opened ? nil : FindReferralHandoffError.yesChefUnavailable.localizedDescription
      return result.opened && result.dispositionPolicyMatches
    } catch is CancellationError {
      return false
    } catch {
      errorMessage = error.localizedDescription
      return false
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
