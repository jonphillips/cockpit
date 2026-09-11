import CockpitCore
import Foundation
import JudgmentFixtureSupport

struct GmailReadOnlyClient {
  let accessToken: String

  func messages(after: String, before: String, fromContains: [String]) async throws -> [GmailMessage] {
    let senderTerms = fromContains.map { "from:\($0)" }.joined(separator: " ")
    let query = "after:\(after) before:\(before) {\(senderTerms)}"
    var ids: [String] = []
    var pageToken: String?
    repeat {
      var components = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages")!
      components.queryItems = [
        URLQueryItem(name: "q", value: query),
        URLQueryItem(name: "maxResults", value: "500"),
        pageToken.map { URLQueryItem(name: "pageToken", value: $0) },
      ].compactMap { $0 }
      let page: GmailMessageList = try await get(components.url!)
      ids += page.messages?.map(\.id) ?? []
      pageToken = page.nextPageToken
    } while pageToken != nil

    var fetched: [GmailMessage] = []
    for id in ids {
      fetched.append(try await message(id: id))
    }
    return fetched
  }

  private func message(id: String) async throws -> GmailMessage {
    let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)?format=full")!
    return try await get(url)
  }

  private func get<Response: Decodable>(_ url: URL) async throws -> Response {
    var request = URLRequest(url: url)
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
      let status = (response as? HTTPURLResponse)?.statusCode ?? -1
      throw HarvestError.httpStatus(status, String(decoding: data, as: UTF8.self))
    }
    return try JSONDecoder.gmail.decode(Response.self, from: data)
  }
}

struct GmailMessageList: Decodable {
  let messages: [GmailMessageReference]?
  let nextPageToken: String?
}

struct GmailMessageReference: Decodable {
  let id: String
}

struct GmailMessage: Decodable {
  let id: String
  let labelIds: [String]
  let payload: GmailPart

  func header(named name: String) -> String? {
    payload.headers.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
  }

  var normalizedText: String? {
    let plain = payload.text(matching: "text/plain")
    let html = payload.text(matching: "text/html")
    return HTMLText.normalizedText(from: plain ?? html)
  }

  var date: Date? {
    guard let value = header(named: "Date") else { return nil }
    return GmailDateParser.date(from: value)
  }

  var dispositionPrior: DispositionPrior {
    if disposition == .trashed { return .never }
    if disposition == .archived { return readState == .unread ? .quiet : .surface }
    return .uncertain
  }

  var disposition: GmailDisposition {
    if labelIds.contains("TRASH") { return .trashed }
    return labelIds.contains("INBOX") ? .inbox : .archived
  }

  var readState: GmailReadState {
    labelIds.contains("UNREAD") ? .unread : .read
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

enum GmailDateParser {
  static func date(from value: String) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "EEE, d MMM yyyy HH:mm:ss Z"
    return formatter.date(from: value)
  }
}

private extension Data {
  init?(base64URLEncoded value: String) {
    let padding = String(repeating: "=", count: (4 - value.count % 4) % 4)
    self.init(base64Encoded: value.replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/") + padding)
  }
}

private extension JSONDecoder {
  static let gmail = JSONDecoder()
}
