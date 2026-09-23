import Foundation
import SQLiteData

extension ContentPieceReaderModel {
  public var pendingFind: PendingFind? {
    row?.emailTreatment == .offer ? pendingFindContent.find : nil
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
