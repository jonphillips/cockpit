import Dependencies
import Foundation
import Observation
import SQLiteData

@MainActor
@Observable
public final class ContentPieceListModel {
  public enum Destination: String, CaseIterable, Sendable {
    case all = "All"
    case later = "Later"
    case library = "Library"
  }

  @ObservationIgnored @Dependency(\.defaultDatabase) private var database
  @ObservationIgnored @Dependency(\.date.now) private var now
  @ObservationIgnored @Fetch(ContentPieceListRequest()) public var content = .init()
  public var destination = Destination.all
  public var errorMessage: String?

  public init() {}

  public var rows: [ContentPieceListRequest.Row] {
    content.rows.filter {
      switch destination {
      case .all: true
      case .later: $0.laterAddedAt != nil
      case .library: $0.libraryAddedAt != nil
      }
    }
  }

  public func laterButtonTapped(_ row: ContentPieceListRequest.Row) async {
    let date = now
    do {
      try await database.write { db in
        if row.laterAddedAt == nil {
          try DestinationOperations.saveForLater(row.id, at: date, in: db)
        } else {
          try DestinationOperations.removeFromLater(row.id, in: db)
        }
      }
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func libraryButtonTapped(_ row: ContentPieceListRequest.Row) async {
    let date = now
    do {
      try await database.write { db in
        if row.libraryAddedAt == nil {
          try DestinationOperations.addToLibrary(row.id, at: date, in: db)
        } else {
          try DestinationOperations.removeFromLibrary(row.id, in: db)
        }
      }
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
