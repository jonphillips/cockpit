import Foundation

struct GmailProfile: Decodable {
  let emailAddress: String
  let historyID: String?
  enum CodingKeys: String, CodingKey { case emailAddress; case historyID = "historyId" }
}

struct GmailMessageList: Decodable {
  let messages: [GmailMessageReference]?
  let nextPageToken: String?
}

struct GmailMessageReference: Decodable { let id: String }

struct GmailMessageResponse: Decodable {
  let id: String
  let threadID: String
  let labelIDs: [String]
  let payload: GmailPayload
  enum CodingKeys: String, CodingKey {
    case id
    case threadID = "threadId"
    case labelIDs = "labelIds"
    case payload
  }
}

struct GmailPayload: Decodable {
  let mimeType: String?
  let headers: [GmailInboxHeader]
  let body: GmailBody?
  let parts: [GmailPayload]?

  func text(matching expectedMIMEType: String) -> String? {
    if mimeType?.caseInsensitiveCompare(expectedMIMEType) == .orderedSame,
      let encoded = body?.data, let data = Data(base64URLEncoded: encoded),
      let text = String(data: data, encoding: .utf8), !text.isEmpty { return text }
    return parts?.lazy.compactMap { $0.text(matching: expectedMIMEType) }.first
  }
}

struct GmailBody: Decodable { let data: String? }

/// Preserves Gmail's error body so throttling can be distinguished from a scope failure.
struct GmailInboxError: LocalizedError {
  let status: Int
  let reason: String?
  let message: String?

  init(status: Int, reason: String?, message: String?) {
    self.status = status
    self.reason = reason
    self.message = message
  }

  init(status: Int, body: Data) {
    let decoded = try? JSONDecoder().decode(GmailAPIErrorEnvelope.self, from: body)
    self.init(status: status, reason: decoded?.error.errors?.first?.reason, message: decoded?.error.message)
  }

  static let noResponse = GmailInboxError(status: -1, reason: nil, message: "Gmail returned no HTTP response.")
  static let accountChanged = GmailInboxError(
    status: -2, reason: nil,
    message: "The authorized Gmail account does not match this device's saved sync cursor."
  )

  var isRetryable: Bool {
    switch status {
    case 429, 503: return true
    case 403: return reason == "rateLimitExceeded" || reason == "userRateLimitExceeded"
    default: return false
    }
  }

  var errorDescription: String? {
    let detail = [reason, message].compactMap { $0?.trimmedNonEmpty }.joined(separator: " — ")
    return detail.isEmpty ? "Gmail returned HTTP \(status)." : "Gmail returned HTTP \(status): \(detail)"
  }
}

struct GmailMessageReads: Sendable {
  var messages: [GmailInboxMessage] = []
  var failures: [GmailInboxMessageFailure] = []
}

enum GmailMessageReadResult: Sendable {
  case success(GmailInboxMessage)
  case failure(GmailInboxMessageFailure)
}

struct GmailAPIErrorEnvelope: Decodable {
  struct APIError: Decodable {
    struct Item: Decodable { let reason: String? }
    let message: String?
    let errors: [Item]?
  }
  let error: APIError
}

extension Data {
  init?(base64URLEncoded value: String) {
    let padding = String(repeating: "=", count: (4 - value.count % 4) % 4)
    self.init(base64Encoded: value.replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/") + padding)
  }
}
