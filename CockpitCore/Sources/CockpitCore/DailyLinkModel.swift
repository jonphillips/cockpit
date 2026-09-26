import Dependencies
import Foundation
import Observation
import SQLiteData

@MainActor
@Observable
public final class DailyLinkModel {
  @ObservationIgnored @Dependency(\.defaultDatabase) private var database
  @ObservationIgnored @Dependency(\.uuid) private var uuid
  @ObservationIgnored @Dependency(\.date.now) private var now
  @ObservationIgnored @Fetch(DailyLinkRequest()) public var content = DailyLinkRequest.Value()
  public var errorMessage: String?

  public init() {}

  /// The order a drag just produced, shown until the write lands so the row doesn't snap back.
  private var pendingOrder: [UUID]?

  public var links: [DailyLink] {
    guard let pendingOrder else { return content.links }
    let position = Dictionary(uniqueKeysWithValues: pendingOrder.enumerated().map { ($1, $0) })
    return content.links.sorted { (position[$0.id] ?? .max) < (position[$1.id] ?? .max) }
  }

  public func save(_ draft: DailyLinkDraft) async -> Bool {
    do {
      let id = draft.id == nil ? uuid() : nil
      let date = now
      try await database.write { db in
        if let id {
          try DailyLinkOperations.add(draft, id: id, at: date, in: db)
        } else {
          try DailyLinkOperations.update(draft, in: db)
        }
      }
      try await $content.load()
      errorMessage = nil
      return true
    } catch is CancellationError {
      return false
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }

  public func delete(_ id: UUID) async {
    do {
      try await database.write { db in try DailyLinkOperations.delete(id, in: db) }
      try await $content.load()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func reorder(moving ids: [UUID], before anchor: UUID?) async {
    pendingOrder = DailyLinkOperations.reordered(links, moving: ids, before: anchor).map(\.id)
    defer { pendingOrder = nil }
    do {
      try await database.write { db in
        try DailyLinkOperations.reorder(moving: ids, before: anchor, in: db)
      }
      try await $content.load()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func recordVisit(_ id: UUID) async {
    do {
      let date = now
      try await database.write { db in try DailyLinkOperations.recordVisit(id, at: date, in: db) }
      try await $content.load()
      errorMessage = nil
    } catch is CancellationError {
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
