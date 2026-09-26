import Dependencies
import Foundation
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
  /// A square JPEG from `DailyLinkThumbnail.make`. When present it stands in for `symbolName`.
  public var thumbnail: Data?

  public init(
    id: UUID, title: String, url: String, symbolName: String = "link", sortOrder: Int,
    lastVisitedAt: Date? = nil, createdAt: Date, thumbnail: Data? = nil
  ) {
    self.id = id
    self.title = title
    self.url = url
    self.symbolName = symbolName
    self.sortOrder = sortOrder
    self.lastVisitedAt = lastVisitedAt
    self.createdAt = createdAt
    self.thumbnail = thumbnail
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
  public var thumbnail: Data?

  public init(
    id: UUID? = nil, title: String = "", url: String = "", symbolName: String = "link",
    thumbnail: Data? = nil
  ) {
    self.id = id
    self.title = title
    self.url = url
    self.symbolName = symbolName
    self.thumbnail = thumbnail
  }

  public init(editing link: DailyLink) {
    self.init(
      id: link.id, title: link.title, url: link.url, symbolName: link.symbolName,
      thumbnail: link.thumbnail)
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
    case thumbnailTooLarge

    public var errorDescription: String? {
      switch self {
      case .invalidURL: "Enter a valid http or https link with a host."
      case .emptyTitle: "Enter a title for this link."
      case .missingLink: "This daily link no longer exists."
      case .thumbnailTooLarge: "That thumbnail is too large. Choose the photo again."
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
    let thumbnail = try validatedThumbnail(draft.thumbnail)
    let existing = try orderedLinks(in: db)
    try DailyLink.insert {
      DailyLink.Draft(
        id: id,
        title: title,
        url: url,
        symbolName: validSymbol(draft.symbolName),
        sortOrder: existing.count,
        lastVisitedAt: nil,
        createdAt: date,
        thumbnail: thumbnail
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
    let thumbnail = try validatedThumbnail(draft.thumbnail)
    try DailyLink.find(id).update {
      $0.title = #bind(title)
      $0.url = #bind(url)
      $0.symbolName = #bind(validSymbol(draft.symbolName))
      $0.thumbnail = #bind(thumbnail)
    }.execute(db)
  }

  public static func delete(_ id: UUID, in db: Database) throws {
    try DailyLink.find(id).delete().execute(db)
    try rewriteOrder(orderedLinks(in: db).filter { $0.id != id }, in: db)
  }

  /// Moves `ids` (in their current relative order) to sit before `anchor`, or at the end when
  /// `anchor` is nil or is itself being moved. Unknown ids are ignored.
  public static func reorder(moving ids: [UUID], before anchor: UUID?, in db: Database) throws {
    let links = try orderedLinks(in: db)
    try rewriteOrder(reordered(links, moving: ids, before: anchor), in: db)
  }

  public static func reordered(
    _ links: [DailyLink], moving ids: [UUID], before anchor: UUID?
  ) -> [DailyLink] {
    let moving = Set(ids)
    var remaining = links.filter { !moving.contains($0.id) }
    let moved = links.filter { moving.contains($0.id) }
    let index = anchor.flatMap { id in remaining.firstIndex { $0.id == id } } ?? remaining.endIndex
    remaining.insert(contentsOf: moved, at: index)
    return remaining
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

  private static func validatedThumbnail(_ data: Data?) throws -> Data? {
    guard let data, !data.isEmpty else { return nil }
    guard data.count <= DailyLinkThumbnail.maximumBytes else { throw Failure.thumbnailTooLarge }
    return data
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
