import SwiftSoup

/// Deterministic signals shared by the original email reader and email image selection.
public enum EmailImageSignals {
  /// Matches the Reader's existing tracking-pixel predicate.
  public static func isTrackingPixel(_ image: Element) -> Bool {
    let width = dimension(try? image.attr("width"))
    let height = dimension(try? image.attr("height"))
    let style = (try? image.attr("style"))?.lowercased() ?? ""
    let source = ((try? image.attr("src")) ?? "").lowercased()
    let compactStyle = style.replacingOccurrences(of: " ", with: "")
    let hiddenOrZeroArea = image.hasAttr("hidden") || [
      "display:none", "visibility:hidden", "opacity:0", "width:0", "height:0",
    ].contains { compactStyle.contains($0) }
    let obviousBeaconName = ["1x1", "spacer", "tracking", "pixel", "beacon"].contains {
      source.contains($0)
    }
    return width.map { $0 <= 1 } ?? false
      || height.map { $0 <= 1 } ?? false
      || hiddenOrZeroArea
      || obviousBeaconName
  }

  static func dimension(_ value: String?) -> Int? {
    guard let value else { return nil }
    let number = value.trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased().replacingOccurrences(of: "px", with: "")
    return Int(number)
  }
}
