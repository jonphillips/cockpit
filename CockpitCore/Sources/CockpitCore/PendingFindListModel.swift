import Observation
import Dependencies
import SQLiteData

@MainActor
@Observable
public final class PendingFindListModel {
  @ObservationIgnored @Dependency(\.defaultDatabase) private var database
  @ObservationIgnored @Dependency(\.gmailDispositionClient) private var dispositionClient
  @ObservationIgnored @Dependency(\.date.now) private var now
  @ObservationIgnored @Fetch(PendingFindListRequest()) public var content = .init()

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

  private func update(_ id: PendingFind.ID, state: PendingFindState) async {
    do {
      try await database.write { db in
        switch state {
        case .confirmed: try PendingFindOperations.confirm(id, in: db)
        case .dismissed: try PendingFindOperations.dismiss(id, in: db)
        case .pending, .handedOff: break
        }
      }
      try await $content.load()
    } catch is CancellationError {
    } catch {
      // The list has no separate error surface; the persisted row remains available for retry.
    }
  }
}
