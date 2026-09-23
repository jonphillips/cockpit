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
    return detect(in: document)
  }

  /// Detects from an already-parsed document, so the Reader's sanitizer parses each email once.
  public static func detect(in document: Document) -> Double? {
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
///
/// The Reader applies it as a root CSS `zoom`, not `WKWebView.pageZoom`. On iOS, `pageZoom` scales
/// the laid-out page without re-laying it out, so any zoom above 1 pushes the right side past the
/// view's edge. CSS `zoom` scales fixed pixel sizes inside a page that stays the view's width, so
/// the column grows and stays centered.
public enum EmailFitZoom {
  // 1.3 keeps body copy around 20pt; filling a landscape iPad pane would reach ~1.6× / 26pt.
  public static let maximumZoom = 1.3
  public static let minimumZoom = 0.5
  public static let horizontalGutter = 16.0
  /// Bands step the zoom by 5%, so a band undershoots the exact fit by less than one step.
  public static let bandsPerUnitZoom = 20

  public struct Band: Equatable, Sendable {
    /// The narrowest viewport, in CSS px, where this zoom fits. Zero for the floor band.
    public let minimumViewportWidth: Int
    public let zoom: Double
  }

  /// The exact fit for a viewport width.
  public static func zoom(designWidth: Double?, availableWidth: Double) -> Double {
    guard let designWidth, designWidth > 0, availableWidth > 0 else { return 1.0 }
    let fittedWidth = designWidth + 2 * horizontalGutter
    return min(maximumZoom, max(minimumZoom, availableWidth / fittedWidth))
  }

  /// The zoom bands for a fixed design width, narrowest first; nil for fluid email. Each band
  /// starts at the width where its zoom exactly fits, so a band never overflows the view.
  public static func bands(designWidth: Double?) -> [Band]? {
    guard let designWidth, designWidth > 0 else { return nil }
    let fittedWidth = designWidth + 2 * horizontalGutter
    let perUnit = Double(bandsPerUnitZoom)
    let lowest = Int((minimumZoom * perUnit).rounded())
    let highest = Int((maximumZoom * perUnit).rounded())
    return (lowest...highest).map { step in
      let zoom = Double(step) / perUnit
      let minimumWidth = step == lowest ? 0 : Int((zoom * fittedWidth).rounded(.up))
      return Band(minimumViewportWidth: minimumWidth, zoom: zoom)
    }
  }

  /// The zoom the bands apply at a viewport width.
  public static func bandedZoom(designWidth: Double?, viewportWidth: Double) -> Double {
    guard let bands = bands(designWidth: designWidth) else { return 1.0 }
    return bands.last { Double($0.minimumViewportWidth) <= viewportWidth }?.zoom ?? minimumZoom
  }

  /// The bands as a stylesheet of root `zoom` rules. Media queries re-pick the band when the pane
  /// resizes, with no reload or script.
  public static func stylesheet(designWidth: Double?) -> String? {
    guard let bands = bands(designWidth: designWidth) else { return nil }
    return bands.map { band in
      let rule = "html { zoom: \(String(format: "%.2f", band.zoom)); }"
      guard band.minimumViewportWidth > 0 else { return rule }
      return "@media (min-width: \(band.minimumViewportWidth)px) { \(rule) }"
    }.joined(separator: "\n")
  }
}

/// The visual width of the fixed email column after its root CSS zoom is applied.
public enum EmailColumn {
  /// Uses the same zoom band as the injected stylesheet, so surrounding Reader content follows
  /// the email's actual width at each viewport size. Fluid email occupies the whole viewport.
  public static func width(designWidth: Double?, viewportWidth: Double) -> Double {
    let viewportWidth = max(0, viewportWidth)
    guard let designWidth, designWidth > 0 else { return viewportWidth }
    return min(viewportWidth, designWidth * EmailFitZoom.bandedZoom(
      designWidth: designWidth,
      viewportWidth: viewportWidth
    ))
  }
}
