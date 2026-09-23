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
      guard property == "width" || property == "max-width",
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

  public static func zoom(designWidth: Double?, availableWidth: Double) -> Double {
    guard let designWidth, designWidth > 0, availableWidth > 0 else { return 1.0 }
    return min(maximumZoom, max(minimumZoom, availableWidth / designWidth))
  }
}
