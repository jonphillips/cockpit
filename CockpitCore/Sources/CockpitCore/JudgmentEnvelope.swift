import Foundation
import LLMClientKit

/// Extracts the array of judgment objects from a model response envelope, tolerating truncation.
/// A composition batches every candidate into one structured response, so a response that reaches
/// the model's output cap is cut off mid-array. Rather than fail every piece on the unparseable
/// whole, this recovers the complete leading objects and lets the missing tail fall through to the
/// decoder's per-piece "no judgment" path — which the engine re-requests (JUDGMENT-CONTRACT §3).
enum JudgmentEnvelope {
  /// Returns the envelope's array of judgment objects. The strict decode is tried first; if it fails
  /// because the response is truncated or otherwise malformed, the complete leading objects are
  /// salvaged instead. Only a response with nothing recoverable rethrows the original error, which
  /// the engine turns into a whole-pass fail-closed run.
  static func elements(
    _ text: String, strict: () throws -> [JSONValue], salvageKeys: [String]
  ) throws -> [JSONValue] {
    do {
      return try strict()
    } catch {
      for key in salvageKeys {
        let salvaged = salvaged(text, key: key)
        if !salvaged.isEmpty { return salvaged }
      }
      throw error
    }
  }

  /// Recovers the complete objects of the top-level `"key": [ … ]` array from a response cut off
  /// mid-array. Every element that closes cleanly is returned; a partial trailing object is dropped,
  /// so its candidate falls through to the per-piece "no judgment" path and is re-requested. Byte
  /// scanning is safe here: JSON's structural characters are all ASCII, and UTF-8 continuation bytes
  /// never collide with them.
  static func salvaged(_ text: String, key: String) -> [JSONValue] {
    let bytes = Array(text.utf8)
    let quote = UInt8(ascii: "\""), backslash = UInt8(ascii: "\\")
    let openBrace = UInt8(ascii: "{"), closeBrace = UInt8(ascii: "}")
    let openBracket = UInt8(ascii: "["), closeBracket = UInt8(ascii: "]")

    let needle = Array("\"\(key)\"".utf8)
    guard var i = subsequenceIndex(of: needle, in: bytes) else { return [] }
    i += needle.count
    while i < bytes.count, bytes[i] != openBracket { i += 1 }
    guard i < bytes.count else { return [] }
    i += 1  // past the array's opening bracket

    var elements: [JSONValue] = []
    var depth = 0
    var elementStart: Int?
    var inString = false
    var escaped = false

    while i < bytes.count {
      let byte = bytes[i]
      if inString {
        if escaped { escaped = false } else if byte == backslash { escaped = true }
        else if byte == quote { inString = false }
      } else if byte == quote {
        inString = true
      } else if byte == openBrace || byte == openBracket {
        if depth == 0 { elementStart = i }
        depth += 1
      } else if byte == closeBrace || byte == closeBracket {
        if depth == 0 { break }  // the array's own closing bracket; no complete element follows
        depth -= 1
        if depth == 0, let start = elementStart {
          if let value = try? JSONDecoder().decode(JSONValue.self, from: Data(bytes[start...i])) {
            elements.append(value)
          }
          elementStart = nil
        }
      }
      i += 1
    }
    return elements
  }

  private static func subsequenceIndex(of needle: [UInt8], in haystack: [UInt8]) -> Int? {
    guard !needle.isEmpty, haystack.count >= needle.count else { return nil }
    for start in 0...(haystack.count - needle.count)
    where !zip(needle, haystack[start...]).contains(where: { $0 != $1 }) {
      return start
    }
    return nil
  }
}
