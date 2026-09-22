import Foundation
import SQLiteData

extension TodayModel {
  /// Whether the visible row is a newsletter in a declared series. The key resolution is the same
  /// one used by application, so a missing List-ID/sender or non-newsletter row returns false.
  public func seriesTrashState(for row: TodayRequest.Row) async -> Bool {
    (try? await database.read { db in
      guard let seriesKey = try GmailSeriesKey.seriesKey(forContentPieceID: row.id, in: db) else {
        return false
      }
      return try GmailSeriesDispositionOperations.isDeclared(seriesKey: seriesKey, in: db)
    }) ?? false
  }

  /// Establishes the one supported series action from a visible newsletter row. No series key can
  /// be declared from a non-newsletter row because the model repeats the guard before writing.
  public func declareSeriesTrash(for row: TodayRequest.Row) async {
    do {
      guard let seriesKey = try await database.read({ db in
        try GmailSeriesKey.seriesKey(forContentPieceID: row.id, in: db)
      }) else { return }
      let date = now
      try await database.write { db in
        try GmailSeriesDispositionOperations.declare(seriesKey: seriesKey, at: date, in: db)
      }
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func undeclareSeriesTrash(for row: TodayRequest.Row) async {
    do {
      guard let seriesKey = try await database.read({ db in
        try GmailSeriesKey.seriesKey(forContentPieceID: row.id, in: db)
      }) else { return }
      try await database.write { db in
        try GmailSeriesDispositionOperations.undeclare(seriesKey: seriesKey, in: db)
      }
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func loadRecentTrashes() async {
    do {
      recentTrashes = try await database.read { db in
        try RecentTrashRequest().fetch(db)
      }
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// Reverses a recent Trash entry even though its row is no longer in the Today projection.
  public func undoDisposition(forContentPieceID id: ContentPiece.ID) async {
    do {
      guard let entry = try await database.read({ db in
        try GmailDispositionOperations.activeDisposition(forContentPieceID: id, in: db)
      }) else { return }
      try await dispositionService.undo(entry, in: database)
      try await $content.load()
      await loadRecentTrashes()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
