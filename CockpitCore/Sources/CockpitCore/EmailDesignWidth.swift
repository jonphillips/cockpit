import Foundation
import SwiftSoup

/// Static clues for the fixed-width layout used by many HTML email templates.
public enum EmailDesignWidth {
  private static let minimumPlausibleWidth = 320.0
  private static let maximumPlausibleWidth = 1_200.0
  private static let maximumContainerDepth = 4
  private static let layoutTags: Set<String> = ["table", "td", "div", "center"]

  /// Returns the widest plausible width on a top-level email layout container.
  /// Stylesheets are intentionally ignored; inline declarations and width attributes are enough
  /// for common fixed-column email templates without evaluating page CSS.
  public static func detect(html: String) -> Double? {
    guard let document = try? SwiftSoup.parse(html) else { return nil }
    guard let body = document.body() else { return nil }
    var widths: [Double] = []

    func visit(_ element: Element, containerDepth: Int) {
      guard containerDepth < maximumContainerDepth else { return }
      let children = element.children()

      for child in children {
        let tag = child.tagName().lowercased()
        let isLayoutContainer = layoutTags.contains(tag)
        let depth = containerDepth + (isLayoutContainer ? 1 : 0)
        guard depth <= maximumContainerDepth else { continue }
        if isLayoutContainer {
          widths.append(contentsOf: widthsDeclared(on: child).filter(isPlausible))
        }
        visit(child, containerDepth: depth)
      }
    }

    visit(body, containerDepth: 0)
    return widths.max()
  }

  private static func widthsDeclared(on element: Element) -> [Double] {
    var widths: [Double] = []
    if let attribute = try? element.attr("width"), let width = parseHTMLWidth(attribute) {
      widths.append(width)
    }

    guard let style = try? element.attr("style") else { return widths }
    for declaration in style.split(separator: ";") {
      let parts = declaration.split(separator: ":", maxSplits: 1)
      guard parts.count == 2 else { continue }
      let property = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      guard property == "width" || property == "max-width" || property == "min-width",
        let width = parseCSSPixelWidth(String(parts[1]))
      else { continue }
      widths.append(width)
    }
    return widths
  }

  private static func parseHTMLWidth(_ value: String) -> Double? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let numeric = trimmed.hasSuffix("px") ? String(trimmed.dropLast(2)) : trimmed
    return Double(numeric)
  }

  private static func parseCSSPixelWidth(_ value: String) -> Double? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      .replacingOccurrences(of: #"\s*!important\s*$"#, with: "", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasSuffix("px") else { return nil }
    return Double(trimmed.dropLast(2).trimmingCharacters(in: .whitespacesAndNewlines))
  }

  private static func isPlausible(_ width: Double) -> Bool {
    width.isFinite && (minimumPlausibleWidth...maximumPlausibleWidth).contains(width)
  }
}

/// A bounded fit for fixed-width email; fluid layouts retain their native scale.
public enum EmailFitZoom {
  // 1.3 keeps body copy around 20pt; filling a landscape iPad pane would reach ~1.6× / 26pt.
  public static let maximumZoom = 1.3
  public static let minimumZoom = 0.5
  public static let horizontalGutter = 16.0

  public static func zoom(designWidth: Double?, availableWidth: Double) -> Double {
    guard let designWidth, designWidth > 0, availableWidth > 0 else { return 1.0 }
    let fittedWidth = designWidth + 2 * horizontalGutter
    return min(maximumZoom, max(minimumZoom, availableWidth / fittedWidth))
  }
}

/// The width an email is fitted to: the statically detected column, widened by any overflow the
/// rendered page reveals. Stylesheet rules, deep nesting, or fixed images can make the page wider
/// than the detected column; the web view does not scroll, so that overflow would be unreachable.
public struct EmailFitWidth: Equatable, Sendable {
  /// Sub-point differences are layout rounding, not overflow.
  public static let overflowTolerance = 1.0

  public let detected: Double?
  public private(set) var measured: Double?
  private var staleContentWidth: Double?

  public init(detected: Double?) {
    self.detected = detected
  }

  public var designWidth: Double? {
    [detected, measured].compactMap(\.self).max()
  }

  /// Call before a zoom or view-width change. Until the page lays out again, the rendered width
  /// still reflects the old layout, and reading it against the new zoom or a narrower view would
  /// look like overflow. Because the fit width only widens, that misreading would stick.
  public mutating func expectRelayout(fromContentWidth contentWidth: Double) {
    staleContentWidth = contentWidth
  }

  /// Records a rendered page, in points at `zoom`. Returns true when the fit width grew. The width
  /// only widens within one email, so a correction cannot oscillate: at the 0.5 floor a still-wide
  /// page measures the same and stops.
  public mutating func recordRendered(contentWidth: Double, viewWidth: Double, zoom: Double) -> Bool {
    if let staleContentWidth {
      guard abs(contentWidth - staleContentWidth) > Self.overflowTolerance else { return false }
      self.staleContentWidth = nil
    }
    guard contentWidth.isFinite, viewWidth > 0, zoom > 0,
      contentWidth > viewWidth + Self.overflowTolerance
    else { return false }
    let pageWidth = contentWidth / zoom
    guard pageWidth > (measured ?? 0) else { return false }
    measured = pageWidth
    return true
  }
}
