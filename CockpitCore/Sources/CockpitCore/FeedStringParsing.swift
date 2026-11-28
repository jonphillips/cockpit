import Foundation

extension String {
  func matches(for pattern: String) -> [String] {
    guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(startIndex..., in: self)
    return expression.matches(in: self, range: range).compactMap { match in
      Range(match.range, in: self).map { String(self[$0]) }
    }
  }

  var attributePairs: [(String, String)] {
    let pattern = "(?i)([a-z][a-z0-9:_-]*)\\s*=\\s*([\\\"'])(.*?)\\2"
    guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(startIndex..., in: self)
    return expression.matches(in: self, range: range).compactMap { match in
      guard let keyRange = Range(match.range(at: 1), in: self),
        let valueRange = Range(match.range(at: 3), in: self)
      else { return nil }
      return (String(self[keyRange]).lowercased(), String(self[valueRange]))
    }
  }

  var feedNilIfEmpty: Self? { isEmpty ? nil : self }
}
