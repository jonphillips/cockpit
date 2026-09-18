import Foundation

public enum HTMLText {
  public static func normalizedText(from html: String?) -> String? {
    guard let html, !html.isEmpty else { return nil }
    let withoutNonContent = html
      .replacingOccurrences(
        of: "(?is)<(?:style|script|head)\\b[^>]*>.*?</(?:style|script|head)\\s*>",
        with: " ", options: .regularExpression
      )
      .replacingOccurrences(of: "(?s)<!--.*?-->", with: " ", options: .regularExpression)
    let lineBreaks = withoutNonContent.replacingOccurrences(
      of: "(?i)<(?:br\\s*/?|/(?:p|div|li|h[1-6]))\\b[^>]*>",
      with: "\n", options: .regularExpression
    )
    let withoutTags = lineBreaks.replacingOccurrences(
      of: "<[^>]+>", with: " ", options: .regularExpression
    )
    let decoded = decodeHTMLEntities(in: withoutTags)
    let compactedPunctuation = decoded.replacingOccurrences(
      of: "\\s+([.,;:!?])", with: "$1", options: .regularExpression
    )
    let normalized = compactedPunctuation
      .components(separatedBy: .newlines)
      .map {
        $0
          .replacingOccurrences(of: "[\\t\\p{Zs}]+", with: " ", options: .regularExpression)
          .trimmingCharacters(in: .whitespaces)
      }
      // Block tags above deliberately create newlines. Preserve those boundaries while collapsing
      // whitespace inside each line and squeezing blank-line runs to one separator.
      .filter { !$0.isEmpty }
      .joined(separator: "\n")
    return normalized.nilIfEmpty
  }

  private static func decodeHTMLEntities(in text: String) -> String {
    var decoded = ""
    var index = text.startIndex
    while index < text.endIndex {
      guard text[index] == "&",
        let semicolon = text[index...].firstIndex(of: ";"),
        text.distance(from: index, to: semicolon) <= 16
      else {
        decoded.append(text[index])
        index = text.index(after: index)
        continue
      }
      let body = String(text[text.index(after: index)..<semicolon])
      if let replacement = decodeHTMLEntity(body) {
        decoded.append(contentsOf: replacement)
        index = text.index(after: semicolon)
      } else {
        decoded.append(text[index])
        index = text.index(after: index)
      }
    }
    return decoded
  }

  private static func decodeHTMLEntity(_ body: String) -> String? {
    let value: UInt32?
    if body.hasPrefix("#x") || body.hasPrefix("#X") {
      value = UInt32(body.dropFirst(2), radix: 16)
    } else if body.hasPrefix("#") {
      value = UInt32(body.dropFirst(), radix: 10)
    } else {
      return namedEntities[body]
    }
    guard let value, let scalar = UnicodeScalar(value) else { return nil }
    return String(scalar)
  }

  private static let namedEntities: [String: String] = [
    "nbsp": " ", "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
    "mdash": "—", "ndash": "–", "rsquo": "’", "lsquo": "‘", "rdquo": "”", "ldquo": "“",
    "hellip": "…", "bull": "•", "middot": "·", "laquo": "«", "raquo": "»", "copy": "©",
    "reg": "®", "trade": "™",
  ]
}

private extension String {
  var nilIfEmpty: Self? { isEmpty ? nil : self }
}
