import Foundation

public struct FeedEntry: Equatable, Sendable {
  public var title: String
  public var canonicalURL: URL?
  public var providerID: String?
  public var guid: String?
  public var guidIsPermanent: Bool
  public var creator: String?
  public var publishedAt: Date?
  public var bodyHTML: String?
  public var descriptionHTML: String?

  public init(
    title: String,
    canonicalURL: URL? = nil,
    providerID: String? = nil,
    guid: String? = nil,
    guidIsPermanent: Bool = false,
    creator: String? = nil,
    publishedAt: Date? = nil,
    bodyHTML: String? = nil,
    descriptionHTML: String? = nil
  ) {
    self.title = title
    self.canonicalURL = canonicalURL
    self.providerID = providerID
    self.guid = guid
    self.guidIsPermanent = guidIsPermanent
    self.creator = creator
    self.publishedAt = publishedAt
    self.bodyHTML = bodyHTML
    self.descriptionHTML = descriptionHTML
  }

  public var normalizedText: String? {
    HTMLText.normalizedText(from: bodyHTML ?? descriptionHTML)
  }
}

public struct ParsedFeed: Equatable, Sendable {
  public var transport: StreamTransport
  public var title: String
  public var publisher: String
  public var entries: [FeedEntry]

  public init(transport: StreamTransport, title: String, publisher: String, entries: [FeedEntry]) {
    self.transport = transport
    self.title = title
    self.publisher = publisher
    self.entries = entries
  }
}

public enum FeedParsingError: Error, Equatable, Sendable {
  case unsupportedDocument
  case malformedDocument
  case noEntries
}

public enum FeedParser {
  public static func parse(_ data: Data) throws -> ParsedFeed {
    let collector = FeedXMLCollector()
    let parser = XMLParser(data: data)
    parser.delegate = collector
    guard parser.parse() else { throw FeedParsingError.malformedDocument }
    guard let feed = collector.feed else { throw FeedParsingError.unsupportedDocument }
    guard !feed.entries.isEmpty else { throw FeedParsingError.noEntries }
    return feed
  }
}

private final class FeedXMLCollector: NSObject, XMLParserDelegate {
  private enum Context {
    case none
    case rssItem
    case atomEntry
  }

  private var rootName: String?
  private var context: Context = .none
  private var feedTitle = ""
  private var entries: [FeedEntry] = []
  private var entry = FeedEntry(title: "")
  private var elementName = ""
  private var elementText = ""
  private var currentGUIDIsPermanent = false
  private var isInsideAtomAuthor = false

  var feed: ParsedFeed? {
    guard let rootName else { return nil }
    let transport: StreamTransport
    switch rootName {
    case "rss", "rdf", "rdf:rdf": transport = .rss
    case "feed": transport = .atom
    default: return nil
    }
    return ParsedFeed(
      transport: transport,
      title: feedTitle,
      publisher: feedTitle,
      entries: entries
    )
  }

  func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?,
    attributes attributeDict: [String: String] = [:]
  ) {
    let name = (qName ?? elementName).lowercased()
    if rootName == nil { rootName = name }
    switch name {
    case "item":
      context = .rssItem
      entry = FeedEntry(title: "")
    case "entry":
      context = .atomEntry
      entry = FeedEntry(title: "")
    case "author" where context == .atomEntry:
      isInsideAtomAuthor = true
    case "link" where context == .atomEntry:
      let relationship = attributeDict["rel"]?.lowercased()
      if relationship == nil || relationship == "alternate", let href = attributeDict["href"] {
        entry.canonicalURL = URL(string: href)
      }
    case "guid" where context == .rssItem:
      currentGUIDIsPermanent = attributeDict["isPermaLink"]?.lowercased() != "false"
    default:
      break
    }
    self.elementName = name
    elementText = ""
  }

  func parser(_ parser: XMLParser, foundCharacters string: String) {
    elementText += string
  }

  func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    let name = (qName ?? elementName).lowercased()
    let value = elementText.trimmingCharacters(in: .whitespacesAndNewlines)
    defer {
      self.elementName = ""
      elementText = ""
    }
    switch context {
    case .none:
      if name == "title", !value.isEmpty { feedTitle = value }
    case .rssItem:
      switch name {
      case "title": entry.title = value
      case "link": entry.canonicalURL = URL(string: value)
      case "guid":
        entry.guid = value
        entry.guidIsPermanent = currentGUIDIsPermanent
      case "creator", "dc:creator", "author": entry.creator = value.nilIfEmpty
      case "pubdate", "date": entry.publishedAt = FeedDateParser.date(from: value)
      case "description": entry.descriptionHTML = value.nilIfEmpty
      case "content:encoded", "encoded": entry.bodyHTML = value.nilIfEmpty
      case "item":
        entries.append(entry)
        context = .none
      default: break
      }
    case .atomEntry:
      switch name {
      case "title": entry.title = value
      case "id": entry.providerID = value.nilIfEmpty
      case "name" where isInsideAtomAuthor: entry.creator = value.nilIfEmpty
      case "published", "updated": entry.publishedAt = FeedDateParser.date(from: value)
      case "summary": entry.descriptionHTML = value.nilIfEmpty
      case "content": entry.bodyHTML = value.nilIfEmpty
      case "entry":
        entries.append(entry)
        context = .none
      default: break
      }
    }
    if name == "author", context == .atomEntry {
      isInsideAtomAuthor = false
    }
  }
}

enum FeedDateParser {
  static func date(from value: String) -> Date? {
    if let date = try? Date(value, strategy: .iso8601) {
      return date
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
    if let date = formatter.date(from: value) {
      return date
    }
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
    return formatter.date(from: value)
  }
}

public enum HTMLText {
  public static func normalizedText(from html: String?) -> String? {
    guard let html, !html.isEmpty else { return nil }
    let lineBreaks = html.replacingOccurrences(
      of: "(?i)<(?:br|/p|/div|/li|/h[1-6])\\b[^>]*>",
      with: "\n",
      options: .regularExpression
    )
    let withoutTags = lineBreaks.replacingOccurrences(
      of: "<[^>]+>", with: " ", options: .regularExpression
    )
    let decoded = withoutTags
      .replacingOccurrences(of: "&nbsp;", with: " ")
      .replacingOccurrences(of: "&amp;", with: "&")
      .replacingOccurrences(of: "&lt;", with: "<")
      .replacingOccurrences(of: "&gt;", with: ">")
      .replacingOccurrences(of: "&quot;", with: "\"")
    let compactedPunctuation = decoded.replacingOccurrences(
      of: "\\s+([.,;:!?])", with: "$1", options: .regularExpression
    )
    let normalized = compactedPunctuation
      .split(whereSeparator: { $0.isWhitespace })
      .joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return normalized.nilIfEmpty
  }
}

private extension String {
  var nilIfEmpty: Self? { isEmpty ? nil : self }
}
