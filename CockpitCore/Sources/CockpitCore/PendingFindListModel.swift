import Observation
import Dependencies
import Foundation
import SQLiteData

@MainActor
@Observable
public final class PendingFindListModel {
  @ObservationIgnored @Dependency(\.defaultDatabase) private var database
  @ObservationIgnored @Dependency(\.gmailDispositionClient) private var dispositionClient
  @ObservationIgnored @Dependency(\.findReferralHandoffClient) private var findReferralClient
  @ObservationIgnored @Dependency(\.date.now) private var now
  @ObservationIgnored @Dependency(\.uuid) private var uuid
  @ObservationIgnored @Fetch(PendingFindListRequest()) public var content = .init()
  public var errorMessage: String?
  public var errorTitle = "Couldn't Send Find"
  public private(set) var strandedReferrals: [PendingFind.ID: FindReferralStrand] = [:]
  private var isRefreshingHandoff = false

  public init() {}

  public var rows: [PendingFindListRequest.Row] { content.rows }

  public func confirm(_ id: PendingFind.ID) async {
    do {
      guard let pieceID = try await database.read({ db in
        try PendingFind.find(id).fetchOne(db)?.contentPieceID
      }) else { return }
      let dispositionDate = now
      try await database.write { db in try PendingFindOperations.confirm(id, in: db) }
      try await $content.load()
      _ = try await GmailDispositionPolicyService(client: dispositionClient, now: { dispositionDate })
        .applyEnabledPolicies(forContentPieceID: pieceID, in: database)
    } catch is CancellationError {
    } catch {
      // The list has no separate error surface; the persisted row remains available for retry.
    }
  }

  public func dismiss(_ id: PendingFind.ID) async { await update(id, state: .dismissed) }

  public func sendToYesChef(_ id: PendingFind.ID) async {
    errorTitle = "Couldn't Send Find"
    do {
      let referralID = uuid()
      let (contentPieceID, message) = try await database.read { db -> (ContentPiece.ID, FindReferralMessage) in
        guard let find = try PendingFind.find(id).fetchOne(db), RecipeCandidateKind.matches(find.kind)
        else { throw FindReferralHandoffError.readableBodyUnavailable }
        guard find.state == .pending || find.state == .confirmed else {
          throw PendingFindOperations.Failure.cannotRefer
        }
        guard let row = try ContentPieceReaderRequest(contentPieceID: find.contentPieceID).fetch(db).row
        else { throw FindReferralHandoffError.readableBodyUnavailable }
        let gmailProvenance = try GmailArtifactProvenance.latest(forContentPiece: row.id, in: db)
        return (row.id, try FindReferralMessage.make(
          referralID: referralID, find: find, readerRow: row, gmailProvenance: gmailProvenance
        ))
      }

      let sentAt = now
      try await findReferralClient.writeReferral(message)
      do {
        try await database.write { db in
          try PendingFindOperations.startReferral(
            referralID: message.referralID, for: id, at: sentAt, in: db
          )
        }
      } catch {
        _ = try? await findReferralClient.deleteReferral(message.referralID)
        throw error
      }

      guard await findReferralClient.openReferral(message.referralID) else {
        let failedAt = now
        try await database.write { db in
          try PendingFindOperations.recordReferralOpenFailure(
            referralID: message.referralID, for: id, at: failedAt, in: db
          )
        }
        _ = try? await findReferralClient.deleteReferral(message.referralID)
        try await $content.load()
        errorMessage = FindReferralHandoffError.yesChefUnavailable.localizedDescription
        return
      }

      try await $content.load()
      errorMessage = nil
      _ = try? await GmailDispositionPolicyService(client: dispositionClient, now: { sentAt })
        .applyEnabledPolicies(forContentPieceID: contentPieceID, in: database)
    } catch is CancellationError {
    } catch {
      errorTitle = "Couldn't Send Find"
      errorMessage = error.localizedDescription
    }
  }

  private func update(_ id: PendingFind.ID, state: PendingFindState) async {
    do {
      try await database.write { db in
        switch state {
        case .confirmed: try PendingFindOperations.confirm(id, in: db)
        case .dismissed: try PendingFindOperations.dismiss(id, in: db)
        case .pending, .referred, .handedOff, .declined: break
        }
      }
      try await $content.load()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      // The list has no separate error surface; the persisted row remains available for retry.
    }
  }
}

extension PendingFindListModel {
  public func refreshHandoffState() async {
    guard !isRefreshingHandoff else { return }
    isRefreshingHandoff = true
    defer { isRefreshingHandoff = false }
    do {
      let scan = try await findReferralClient.listVerdicts()
      for verdict in scan.verdicts {
        let resolvedAt = now
        let resolution = try await database.write { db in
          try FindReferralOperations.resolve(verdict, at: resolvedAt, in: db)
        }
        switch resolution {
        case .missingLog:
          FindHandoffLog.record("Discarding a verdict with no local referral log: \(verdict.referralID)")
        case .missingFind:
          FindHandoffLog.record("Resolved a verdict whose Find no longer exists: \(verdict.referralID)")
        case .alreadyResolved:
          if verdict.outcomes.contains(where: { if case .admitted = $0 { true } else { false } }) {
            FindHandoffLog.record("Ignored a duplicate admitted verdict for referral: \(verdict.referralID)")
          }
        case .applied:
          break
        }
        _ = try await findReferralClient.deleteVerdict(verdict.referralID)
      }

      let mailboxReferralIDs = try await findReferralClient.unconsumedReferralIDs()
      let unresolved = try await database.read { db in
        try FindReferralOperations.unresolved(in: db)
      }
      strandedReferrals = Dictionary(
        unresolved.compactMap { referral in
          if scan.unreadableReferralIDs.contains(referral.id) {
            return (referral.pendingFindID, FindReferralStrand.unreadableReply(referral.id))
          }
          return mailboxReferralIDs.contains(referral.id)
            ? (referral.pendingFindID, FindReferralStrand.unconsumed(referral.id)) : nil
        }, uniquingKeysWith: { _, latest in latest })
      try await $content.load()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorTitle = "Couldn't Check Find Replies"
      errorMessage = error.localizedDescription
    }
  }

  public func retryStrandedReferral(for findID: PendingFind.ID) async {
    guard case let .unconsumed(referralID)? = strandedReferrals[findID] else { return }
    guard await findReferralClient.openReferral(referralID) else {
      errorTitle = "Couldn't Send Find"
      errorMessage = FindReferralHandoffError.yesChefUnavailable.localizedDescription
      return
    }
    strandedReferrals[findID] = nil
  }

  public func returnStrandedReferralToConfirmed(for findID: PendingFind.ID) async {
    guard let strand = strandedReferrals[findID] else { return }
    do {
      let referralID: UUID
      let removed: Bool
      switch strand {
      case let .unconsumed(id):
        referralID = id
        removed = try await findReferralClient.deleteReferral(id)
      case let .unreadableReply(id):
        referralID = id
        removed = try await findReferralClient.deleteVerdict(id)
      }
      guard removed else {
        errorTitle = "Waiting for Yes Chef"
        errorMessage = "Yes Chef has this referral. Cockpit will keep waiting for its reply."
        return
      }
      let returnedAt = now
      _ = try await database.write { db in
        try FindReferralOperations.returnToConfirmed(
          referralID: referralID, at: returnedAt, in: db
        )
      }
      strandedReferrals[findID] = nil
      try await $content.load()
    } catch is CancellationError {
    } catch {
      errorTitle = "Couldn't Return Find to Confirmed"
      errorMessage = error.localizedDescription
    }
  }
}

public enum FindReferralStrand: Equatable, Sendable {
  case unconsumed(UUID)
  case unreadableReply(UUID)

  public var referralID: UUID {
    switch self {
    case let .unconsumed(id), let .unreadableReply(id): id
    }
  }
}
