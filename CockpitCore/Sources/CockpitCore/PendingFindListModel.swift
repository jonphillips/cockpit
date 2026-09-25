import Observation
import Dependencies
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
    do {
      let referralID = uuid()
      let (contentPieceID, message) = try await database.read { db -> (ContentPiece.ID, FindReferralMessage) in
        guard let find = try PendingFind.find(id).fetchOne(db),
          RecipeCandidateKind.matches(find.kind),
          find.state == .pending || find.state == .confirmed
        else { throw FindReferralHandoffError.readableBodyUnavailable }
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
        try? await findReferralClient.deleteReferral(message.referralID)
        throw error
      }

      guard await findReferralClient.openReferral(message.referralID) else {
        try? await findReferralClient.deleteReferral(message.referralID)
        let failedAt = now
        try await database.write { db in
          try PendingFindOperations.recordReferralOpenFailure(
            referralID: message.referralID, for: id, at: failedAt, in: db
          )
        }
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
    } catch is CancellationError {
    } catch {
      // The list has no separate error surface; the persisted row remains available for retry.
    }
  }
}
