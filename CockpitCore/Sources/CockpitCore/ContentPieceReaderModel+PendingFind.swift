import Foundation
import SQLiteData

extension ContentPieceReaderModel {
  public var pendingFind: PendingFind? {
    row?.emailTreatment == .offer ? pendingFindContent.find : nil
  }

  public var bodyPresentation: ReaderBodyPresentation { readerBodyPresentation(for: row) }

  /// In V1 an email ContentPiece is a Gmail message, so the Reader offers a source disposition only
  /// for these. Other transports have no provider disposition yet.
  public var isGmailSource: Bool { row?.kind == .email }

  /// Explicitly confirms the Reader's proposal. If the established offer policy is enabled, it is
  /// immediately re-evaluated for this piece through the shared disposition/Undo path.
  public func confirmPendingFind() async {
    guard let find = pendingFind else { return }
    let dispositionDate = now
    do {
      try await database.write { db in try PendingFindOperations.confirm(find.id, in: db) }
      try await $pendingFindContent.load()
      _ = try await GmailDispositionPolicyService(client: dispositionClient, now: { dispositionDate })
        .applyEnabledPolicies(forContentPieceID: find.contentPieceID, in: database)
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
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
