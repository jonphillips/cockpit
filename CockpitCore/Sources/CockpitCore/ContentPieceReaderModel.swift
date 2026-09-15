import Dependencies
import Foundation
import Observation
import SQLiteData

/// Owns the Reader's ContentPiece-intrinsic state and idempotent membership writes. Edition-only
/// state remains in `EditionModel` so a Library/Later read can never manufacture an Edition action.
@MainActor
@Observable
public final class ContentPieceReaderModel {
  @ObservationIgnored @Dependency(\.defaultDatabase) private var database
  @ObservationIgnored @Dependency(\.date.now) private var now
  @ObservationIgnored @Fetch public var content = ContentPieceReaderRequest.Value()
  public var errorMessage: String?

  public init(contentPieceID: ContentPiece.ID) {
    _content = Fetch(wrappedValue: .init(), ContentPieceReaderRequest(contentPieceID: contentPieceID))
  }

  public var row: ContentPieceReaderRequest.Row? { content.row }

  public func saveForLater() async {
    guard let id = row?.id else { return }
    let date = now
    await run { try DestinationOperations.saveForLater(id, at: date, in: $0) }
  }

  public func addToLibrary() async {
    guard let id = row?.id else { return }
    let date = now
    await run { try DestinationOperations.addToLibrary(id, at: date, in: $0) }
  }

  public func correctIsSubstantivePrimary(to value: Bool) async {
    guard let id = row?.id else { return }
    await run {
      try ContentPiece.find(id).update { $0.isSubstantivePrimary = #bind(value) }.execute($0)
    }
  }

  private func run(_ operation: @escaping @Sendable (Database) throws -> Void) async {
    do {
      try await database.write { db in try operation(db) }
      try await $content.load()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
