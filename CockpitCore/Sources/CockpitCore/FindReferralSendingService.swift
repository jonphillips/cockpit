import Dependencies
import Foundation
import SQLiteData

/// The one referral path used by the Finds list and the Reader. It owns mailbox delivery, the
/// device-local referral log, failed-open recovery, and the post-confirmation disposition pass.
public struct FindReferralSendingService: Sendable {
  private let database: any DatabaseWriter
  private let handoffClient: FindReferralHandoffClient
  private let dispositionClient: GmailDispositionClient
  private let now: @Sendable () -> Date
  private let uuid: @Sendable () -> UUID

  public init(
    database: any DatabaseWriter,
    handoffClient: FindReferralHandoffClient,
    dispositionClient: GmailDispositionClient,
    now: @escaping @Sendable () -> Date = Date.init,
    uuid: @escaping @Sendable () -> UUID = UUID.init
  ) {
    self.database = database
    self.handoffClient = handoffClient
    self.dispositionClient = dispositionClient
    self.now = now
    self.uuid = uuid
  }

  /// Returns `false` when Yes Chef could not be opened. The Find is restored to confirmed first.
  @discardableResult
  public func send(findID: PendingFind.ID) async throws -> Bool {
    let referralID = uuid()
    let snapshot = try await database.read { db -> Snapshot in
      guard let find = try PendingFind.find(findID).fetchOne(db),
        find.state == .pending || find.state == .confirmed,
        RecipeCandidateKind.matches(find.kind),
        let row = try ContentPieceReaderRequest(contentPieceID: find.contentPieceID).fetch(db).row
      else { throw PendingFindOperations.Failure.cannotRefer }
      let provenance = try GmailArtifactProvenance.latest(forContentPiece: row.id, in: db)
      return Snapshot(
        contentPieceID: row.id, findID: find.id, find: find, row: row,
        gmailProvenance: provenance, hintSource: .extracted
      )
    }
    return try await send(snapshot, referralID: referralID)
  }

  /// Sends a Reader-declared recipe Find, reusing an extracted pending/confirmed Find when present.
  /// A new Find and its referral log row are committed together after the message is built.
  @discardableResult
  public func sendFromReader(contentPieceID: ContentPiece.ID) async throws -> Bool {
    let referralID = uuid()
    let snapshot = try await database.read { db -> Snapshot in
      guard let row = try ContentPieceReaderRequest(contentPieceID: contentPieceID).fetch(db).row
      else { throw FindReferralHandoffError.readableBodyUnavailable }
      let finds = try PendingFind.where { $0.contentPieceID.eq(contentPieceID) }
        .order { $0.id }.fetchAll(db)
      if finds.contains(where: {
        RecipeCandidateKind.matches($0.kind)
          && ($0.state == .referred || $0.state == .handedOff || $0.state == .declined)
      }) {
        throw PendingFindOperations.Failure.cannotRefer
      }
      let extractedFind = finds.first {
        RecipeCandidateKind.matches($0.kind) && ($0.state == .pending || $0.state == .confirmed)
      }
      let find = extractedFind ?? ReaderDeclaredRecipeFind.make(for: row)
      let provenance = try GmailArtifactProvenance.latest(forContentPiece: row.id, in: db)
      return Snapshot(
        contentPieceID: row.id, findID: find.id, find: find, row: row,
        gmailProvenance: provenance, hintSource: extractedFind == nil ? .jonDeclared : .extracted,
        shouldInsertFind: extractedFind == nil
      )
    }
    return try await send(snapshot, referralID: referralID)
  }

  private func send(_ snapshot: Snapshot, referralID: UUID) async throws -> Bool {
    let message = try FindReferralMessage.make(
      referralID: referralID, find: snapshot.find, readerRow: snapshot.row,
      gmailProvenance: snapshot.gmailProvenance
    )
    try await handoffClient.writeReferral(message)
    let sentAt = now()
    do {
      try await database.write { db in
        if snapshot.shouldInsertFind {
          if let existing = try PendingFind.find(snapshot.findID).fetchOne(db) {
            guard existing.state == .dismissed else {
              throw PendingFindOperations.Failure.cannotRefer
            }
            try PendingFind.find(existing.id).update {
              $0.state = #bind(PendingFindState.confirmed)
              $0.rationale = #bind(snapshot.find.rationale)
            }.execute(db)
          } else {
            try PendingFind.insert { PendingFind.Draft(snapshot.find) }.execute(db)
          }
        }
        try PendingFindOperations.startReferral(
          referralID: referralID, for: snapshot.findID, at: sentAt,
          hintSource: snapshot.hintSource, in: db
        )
      }
    } catch {
      _ = try? await handoffClient.deleteReferral(referralID)
      throw error
    }

    guard await handoffClient.openReferral(referralID) else {
      try await database.write { db in
        try PendingFindOperations.recordReferralOpenFailure(
          referralID: referralID, for: snapshot.findID, at: now(), in: db
        )
      }
      _ = try? await handoffClient.deleteReferral(referralID)
      return false
    }

    _ = try? await GmailDispositionPolicyService(client: dispositionClient, now: { sentAt })
      .applyEnabledPolicies(forContentPieceID: snapshot.contentPieceID, in: database)
    return true
  }

}

private struct Snapshot: Sendable {
  let contentPieceID: ContentPiece.ID
  let findID: PendingFind.ID
  let find: PendingFind
  let row: ContentPieceReaderRequest.Row
  let gmailProvenance: GmailArtifactProvenance?
  let hintSource: FindHintSource
  var shouldInsertFind = false
}

private enum ReaderDeclaredRecipeFind {
  static func make(for row: ContentPieceReaderRequest.Row) -> PendingFind {
    let name = row.title
    let sourceURL = row.canonicalURL
    return PendingFind(
      id: PendingFindOperations.id(kind: "recipe", name: name, sourceURL: sourceURL, for: row.id),
      contentPieceID: row.id, kind: "recipe", name: name, descriptor: "",
      rationale: "Jon sent this from the Reader.", sourceURL: sourceURL, state: .confirmed
    )
  }
}
