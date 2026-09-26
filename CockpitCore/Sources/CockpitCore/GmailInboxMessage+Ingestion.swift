import Foundation

extension GmailInboxMessage {
  var subject: String { header(named: "Subject")?.trimmedNonEmpty ?? "(No subject)" }
  var sender: String { header(named: "From")?.trimmedNonEmpty ?? "Unknown sender" }
  var date: Date? { header(named: "Date").flatMap(GmailIngestDateParser.date(from:)) }
}

enum GmailIngestDateParser {
  static func date(from value: String) -> Date? {
    let withoutComment = String(value.prefix { $0 != "(" }).trimmingCharacters(in: .whitespaces)
    for format in ["EEE, d MMM yyyy HH:mm:ss Z", "d MMM yyyy HH:mm:ss Z"] {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.dateFormat = format
      if let date = formatter.date(from: withoutComment) { return date }
    }
    return nil
  }
}
