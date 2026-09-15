import Foundation

/// Deterministic, source-content-only completeness detection. A nil result means that the source
/// did not contain enough evidence for a deterministic classification and leaves the judgment pass
/// as the fallback classifier.
public enum BodyCompletenessDetector {
  private static let substantiveWordMinimum = 40
  private static let cutoffTailWordMaximum = 80

  public static func detect(entry: FeedEntry) -> BodyCompleteness? {
    detect(bodyHTML: entry.bodyHTML, descriptionHTML: entry.descriptionHTML)
  }

  public static func detect(bodyHTML: String?, descriptionHTML: String?) -> BodyCompleteness? {
    guard let bodyHTML, let bodyText = HTMLText.normalizedText(from: bodyHTML) else {
      // RSS/Atom descriptions without a body are the source's teaser, even when the description
      // itself is non-empty. A missing description is likewise an empty teaser.
      return .teaser
    }

    if let cutoff = cutoff(in: bodyText) {
      let wordsBeforeCutoff = wordCount(in: String(bodyText[..<cutoff]))
      return wordsBeforeCutoff >= substantiveWordMinimum ? .truncated : .teaser
    }

    return .full
  }

  /// This overload is used by harvested email fixtures, whose HTML envelope is not retained in
  /// the fixture export. It intentionally applies the same cutoff rules to normalized source text.
  public static func detect(normalizedText: String?) -> BodyCompleteness? {
    guard let normalizedText, !normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { return .teaser }
    guard let cutoff = cutoff(in: normalizedText) else { return .full }
    let wordsBeforeCutoff = wordCount(in: String(normalizedText[..<cutoff]))
    return wordsBeforeCutoff >= substantiveWordMinimum ? .truncated : .teaser
  }

  private static func cutoff(in text: String) -> String.Index? {
    let patterns = [
      #"(?i)\bthis\s+post\s+is\s+(?:only\s+)?for\s+paid\s+subscribers\b"#,
      #"(?i)\bpaid\s+subscribers\s+only\b"#,
      #"(?i)\bsubscribe\s+to\s+read\b"#,
      #"(?i)\bto\s+continue\s+reading\b"#,
      #"(?i)\b(?:continue|read)\s+reading\b"#,
      #"(?i)\bread\s+the\s+full\s+(?:post|story|article)\b"#,
      #"(?i)\bbecome\s+a\s+(?:paid\s+)?subscriber\b"#
    ]
    let candidates: [Range<String.Index>] = patterns.flatMap { pattern in
      guard let expression = try? NSRegularExpression(pattern: pattern) else {
        return [Range<String.Index>]()
      }
      let range = NSRange(text.startIndex..., in: text)
      return expression.matches(in: text, range: range).compactMap { match in
        Range(match.range, in: text)
      }
    }
    guard let match = candidates.sorted(by: { $0.lowerBound < $1.lowerBound }).first else {
      return nil
    }

    // A subscription mention in the middle of a real post is not a cutoff. The marker must be
    // near the end, with only footer/CTA text remaining. This keeps full paid posts that advertise
    // a subscription before continuing with their article body classified as full.
    let tail = String(text[match.upperBound...])
    return wordCount(in: tail) <= cutoffTailWordMaximum ? match.lowerBound : nil
  }

  private static func wordCount(in text: String) -> Int {
    text.split(whereSeparator: { $0.isWhitespace }).count
  }
}
