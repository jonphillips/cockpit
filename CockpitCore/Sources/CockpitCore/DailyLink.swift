import Dependencies
import Foundation
import Observation
import SQLiteData

/// A user-authored shortcut on Today. Visits are a one-day checklist signal only.
@Table("dailyLinks")
public struct DailyLink: Codable, Equatable, Identifiable, Sendable {
  @Column(primaryKey: true) public let id: UUID
  public var title: String
  public var url: String
  public var symbolName: String
  public var sortOrder: Int
  public var lastVisitedAt: Date?
  public var createdAt: Date

  public init(
    id: UUID, title: String, url: String, symbolName: String = "link", sortOrder: Int,
    lastVisitedAt: Date? = nil, createdAt: Date
  ) {
    self.id = id
    self.title = title
    self.url = url
    self.symbolName = symbolName
    self.sortOrder = sortOrder
    self.lastVisitedAt = lastVisitedAt
    self.createdAt = createdAt
  }

  public func isVisited(on date: Date, calendar: Calendar = .current) -> Bool {
    guard let lastVisitedAt else { return false }
    return calendar.isDate(lastVisitedAt, inSameDayAs: date)
  }
}

public struct DailyLinkDraft: Equatable, Sendable {
  public var id: UUID?
  public var title: String
  public var url: String
  public var symbolName: String

  public init(id: UUID? = nil, title: String = "", url: String = "", symbolName: String = "link") {
    self.id = id
    self.title = title
    self.url = url
    self.symbolName = symbolName
  }
}

public enum DailyLinkIcon {
  public static let defaultSymbol = "link"
  public static let symbols = [
    "newspaper", "globe", "link", "book", "chart.line.uptrend.xyaxis", "cloud.sun",
    "sportscourt", "film", "music.note", "cart", "fork.knife", "wineglass", "cpu",
    "quote.bubble", "building.columns", "star",
  ]
}

public enum DailyLinkOperations {
  public enum Failure: Error, Equatable, LocalizedError, Sendable {
    case invalidURL
    case emptyTitle
    case missingLink

    public var errorDescription: String? {
      switch self {
      case .invalidURL: "Enter a valid http or https link with a host."
      case .emptyTitle: "Enter a title for this link."
      case .missingLink: "This daily link no longer exists."
      }
    }
  }

  public static func validatedURL(_ rawValue: String) throws -> String {
    let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let components = URLComponents(string: value),
      let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
      let host = components.host, !host.isEmpty, URL(string: value) != nil
    else { throw Failure.invalidURL }
    return value
  }

  public static func add(_ draft: DailyLinkDraft, id: UUID, at date: Date, in db: Database) throws {
    let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { throw Failure.emptyTitle }
    let url = try validatedURL(draft.url)
    let existing = try orderedLinks(in: db)
    try DailyLink.insert {
      DailyLink.Draft(
        id: id,
        title: title,
        url: url,
        symbolName: validSymbol(draft.symbolName),
        sortOrder: existing.count,
        lastVisitedAt: nil,
        createdAt: date
      )
    }.execute(db)
  }

  public static func update(_ draft: DailyLinkDraft, in db: Database) throws {
    guard let id = draft.id, try DailyLink.find(id).fetchOne(db) != nil else {
      throw Failure.missingLink
    }
    let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { throw Failure.emptyTitle }
    let url = try validatedURL(draft.url)
    try DailyLink.find(id).update {
      $0.title = #bind(title)
      $0.url = #bind(url)
      $0.symbolName = #bind(validSymbol(draft.symbolName))
    }.execute(db)
  }

  public static func delete(_ id: UUID, in db: Database) throws {
    try DailyLink.find(id).delete().execute(db)
    try rewriteOrder(orderedLinks(in: db).filter { $0.id != id }, in: db)
  }

  public static func move(from source: Int, to destination: Int, in db: Database) throws {
    var links = try orderedLinks(in: db)
    guard links.indices.contains(source), destination >= 0, destination <= links.count else { return }
    let link = links.remove(at: source)
    links.insert(link, at: min(destination, links.count))
    try rewriteOrder(links, in: db)
  }

  public static func recordVisit(_ id: UUID, at date: Date, in db: Database) throws {
    guard try DailyLink.find(id).fetchOne(db) != nil else { throw Failure.missingLink }
    try DailyLink.find(id)
      .update { $0.lastVisitedAt = #bind(date) }
      .execute(db)
  }

  public static func orderedLinks(in db: Database) throws -> [DailyLink] {
    try DailyLink.order { ($0.sortOrder, $0.createdAt, $0.id) }
      .fetchAll(db)
  }

  private static func rewriteOrder(_ links: [DailyLink], in db: Database) throws {
    for (order, link) in links.enumerated() where link.sortOrder != order {
      try DailyLink.find(link.id).update { $0.sortOrder = #bind(order) }.execute(db)
    }
  }

  private static func validSymbol(_ value: String) -> String {
    DailyLinkIcon.symbols.contains(value) ? value : DailyLinkIcon.defaultSymbol
  }
}

public struct DailyLinkRequest: FetchKeyRequest {
  public struct Value: Equatable, Sendable {
    public var links: [DailyLink] = []
    public init() {}
  }

  public init() {}

  public func fetch(_ db: Database) throws -> Value {
    var value = Value()
    value.links = try DailyLink.order { ($0.sortOrder, $0.createdAt, $0.id) }.fetchAll(db)
    return value
  }
}

@MainActor
@Observable
public final class DailyLinkModel {
  @ObservationIgnored @Dependency(\.defaultDatabase) private var database
  @ObservationIgnored @Dependency(\.uuid) private var uuid
  @ObservationIgnored @Dependency(\.date.now) private var now
  @ObservationIgnored @Fetch(DailyLinkRequest()) public var content = DailyLinkRequest.Value()
  public var errorMessage: String?

  public init() {}

  public var links: [DailyLink] { content.links }

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

  public func move(from source: Int, to destination: Int) async {
    do {
      try await database.write { db in
        try DailyLinkOperations.move(from: source, to: destination, in: db)
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
