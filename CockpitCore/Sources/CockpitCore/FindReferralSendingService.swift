import Dependencies
import Foundation
import SQLiteData

public struct FindReferralSendingResult: Equatable, Sendable {
  public let contentPieceID: ContentPiece.ID
  public let opened: Bool
  public let dispositionPolicyMatches: Bool

  public init(
    contentPieceID: ContentPiece.ID, opened: Bool, dispositionPolicyMatches: Bool = false
  ) {
    self.contentPieceID = contentPieceID
    self.opened = opened
    self.dispositionPolicyMatches = dispositionPolicyMatches
  }
}

/// The one referral path used by the Finds list and the Reader. It owns mailbox delivery and the
/// device-local referral log; the caller owns any resulting Gmail disposition.
public struct FindReferralSendingService: Sendable {
  private let database: any DatabaseWriter
  private let handoffClient: FindReferralHandoffClient
  private let now: @Sendable () -> Date
  private let uuid: @Sendable () -> UUID

  public init(
    database: any DatabaseWriter,
    handoffClient: FindReferralHandoffClient,
    now: @escaping @Sendable () -> Date = Date.init,
    uuid: @escaping @Sendable () -> UUID = UUID.init
  ) {
    self.database = database
    self.handoffClient = handoffClient
    self.now = now
    self.uuid = uuid
  }

  /// Reports whether Yes Chef opened and whether a disposition policy now matches the piece.
  /// A failed open is recorded and the Find is restored to confirmed first.
  @discardableResult
  public func send(findID: PendingFind.ID) async throws -> FindReferralSendingResult {
    let referralID = uuid()
    let snapshot = try await database.read { db -> Snapshot in
      guard let find = try PendingFind.find(findID).fetchOne(db),
        RecipeCandidateKind.matches(find.kind)
      else { throw FindReferralHandoffError.readableBodyUnavailable }
      guard find.state == .pending || find.state == .confirmed else {
        throw PendingFindOperations.Failure.cannotRefer
      }
      guard let row = try ContentPieceReaderRequest(contentPieceID: find.contentPieceID).fetch(db).row
      else { throw FindReferralHandoffError.readableBodyUnavailable }
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
  public func sendFromReader(contentPieceID: ContentPiece.ID) async throws -> FindReferralSendingResult {
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

  private func send(
    _ snapshot: Snapshot, referralID: UUID
  ) async throws -> FindReferralSendingResult {
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
      return FindReferralSendingResult(contentPieceID: snapshot.contentPieceID, opened: false)
    }

    let policyMatches = (try? await database.read { db in
      try GmailDispositionPolicyOperations.matchingPieceIDs(in: db)
        .contains(snapshot.contentPieceID)
    }) ?? false
    return FindReferralSendingResult(
      contentPieceID: snapshot.contentPieceID, opened: true,
      dispositionPolicyMatches: policyMatches
    )
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
