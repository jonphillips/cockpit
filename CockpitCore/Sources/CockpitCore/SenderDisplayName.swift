import Foundation

/// Produces a readable display name from a Gmail-style sender header without changing stored data.
public enum SenderDisplayName {
  public static func make(from rawValue: String?) -> String {
    guard let rawValue else { return "" }
    let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return "" }

    guard let open = value.lastIndex(of: "<"), let close = value[open...].firstIndex(of: ">") else {
      return value
    }

    let name = String(value[..<open]).trimmingCharacters(in: .whitespacesAndNewlines)
    if name.isEmpty {
      return String(value[value.index(after: open)..<close]).trimmedNonEmpty ?? value
    }

    var displayName = name
    if displayName.first == "\"", displayName.last == "\"", displayName.count >= 2 {
      displayName.removeFirst()
      displayName.removeLast()
      displayName = displayName
        .replacingOccurrences(of: "\\\"", with: "\"")
        .replacingOccurrences(of: "\\\\", with: "\\")
    }
    return displayName.trimmedNonEmpty ?? String(value[value.index(after: open)..<close])
  }
}
