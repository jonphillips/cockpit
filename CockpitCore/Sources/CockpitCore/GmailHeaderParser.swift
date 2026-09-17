import Foundation

/// Small deterministic parsing helpers for the raw headers retained on a Gmail Artifact.
enum GmailHeaderParser {
  static func sendingDomain(from header: String?) -> String? {
    let address = emailAddress(in: header)
    guard let at = address?.lastIndex(of: "@") else { return nil }
    return String(address![address!.index(after: at)...]).lowercased().trimmedNonEmpty
  }

  static func dkimDomain(from header: String?) -> String? {
    guard let header,
      let match = try? NSRegularExpression(pattern: "(?i)(?:^|;)\\s*d=([^;\\s]+)")
        .firstMatch(in: header, range: NSRange(header.startIndex..., in: header)),
      let range = Range(match.range(at: 1), in: header)
    else { return nil }
    return String(header[range]).lowercased().trimmedNonEmpty
  }

  static func recipientCount(in header: String?) -> Int {
    guard let header = header?.trimmedNonEmpty else { return 0 }
    return header.split(separator: ",").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
  }

  private static func emailAddress(in header: String?) -> String? {
    guard let header else { return nil }
    if let open = header.lastIndex(of: "<"), let close = header[open...].firstIndex(of: ">") {
      return String(header[header.index(after: open)..<close])
    }
    return header.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

extension String {
  var trimmedNonEmpty: String? {
    let value = trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
  }
}
