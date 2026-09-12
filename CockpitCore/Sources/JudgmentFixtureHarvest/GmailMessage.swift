import CockpitCore
import Foundation
import JudgmentFixtureSupport

struct GmailMessageList: Decodable {
  let messages: [GmailMessageReference]?
  let nextPageToken: String?
}

struct GmailMessageReference: Decodable {
  let id: String
}

struct GmailMessage: Decodable {
  let id: String
  let labelIds: [String]?
  let payload: GmailPart

  func header(named name: String) -> String? {
    payload.headers.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
  }

  /// nil under `format: metadata` — the body is never fetched during discovery.
  var normalizedText: String? {
    let plain = payload.text(matching: "text/plain")
    let html = payload.text(matching: "text/html")
    return HTMLText.normalizedText(from: plain ?? html)
  }

  var date: Date? {
    header(named: "Date").flatMap(GmailDateParser.date(from:))
  }

  private var labels: [String] { labelIds ?? [] }

  var dispositionPrior: DispositionPrior {
    if disposition == .trashed { return .never }
    if disposition == .archived { return readState == .unread ? .quiet : .surface }
    return .uncertain
  }

  var disposition: GmailDisposition {
    if labels.contains("TRASH") { return .trashed }
    return labels.contains("INBOX") ? .inbox : .archived
  }

  var readState: GmailReadState {
    labels.contains("UNREAD") ? .unread : .read
  }
}

struct GmailPart: Decodable {
  let mimeType: String?
  let headers: [GmailHeader]
  let body: GmailBody?
  let parts: [GmailPart]?

  func text(matching expectedMIMEType: String) -> String? {
    if mimeType?.caseInsensitiveCompare(expectedMIMEType) == .orderedSame,
      let encoded = body?.data,
      let data = Data(base64URLEncoded: encoded),
      let text = String(data: data, encoding: .utf8),
      !text.isEmpty
    {
      return text
    }
    return parts?.lazy.compactMap { $0.text(matching: expectedMIMEType) }.first
  }
}

struct GmailHeader: Decodable {
  let name: String
  let value: String
}

struct GmailBody: Decodable {
  let data: String?
}

/// RFC 5322 `Date:` headers vary: the leading weekday is optional and many carry a trailing zone
/// comment like `-0700 (PDT)`. A single rigid format nulls `publishedAt` — a §2 input — on those,
/// so strip the comment and try both shapes.
enum GmailDateParser {
  static func date(from value: String) -> Date? {
    let trimmed = stripTrailingComment(value).trimmingCharacters(in: .whitespaces)
    for format in ["EEE, d MMM yyyy HH:mm:ss Z", "d MMM yyyy HH:mm:ss Z"] {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.dateFormat = format
      if let date = formatter.date(from: trimmed) { return date }
    }
    return nil
  }

  private static func stripTrailingComment(_ value: String) -> String {
    guard let paren = value.firstIndex(of: "(") else { return value }
    return String(value[..<paren])
  }
}

extension Data {
  init?(base64URLEncoded value: String) {
    let padding = String(repeating: "=", count: (4 - value.count % 4) % 4)
    self.init(base64Encoded: value.replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/") + padding)
  }
}

extension JSONDecoder {
  static let gmail = JSONDecoder()
}
