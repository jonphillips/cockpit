import Foundation
import SwiftSoup

/// Static presentation facts derived from the email HTML. These facts choose the surrounding
/// Cockpit treatment; they never rewrite the message.
public enum EmailPresentation {
  public enum Kind: Equatable, Sendable {
    case designed(width: Double)
    case letter
  }

  public static func kind(html: String) -> Kind {
    guard let document = try? SwiftSoup.parse(html) else { return .letter }
    return kind(in: document)
  }

  public static func kind(in document: Document) -> Kind {
    guard let width = EmailDesignWidth.detect(in: document) else { return .letter }
    return .designed(width: width)
  }

  public static func supportsDarkAppearance(html: String) -> Bool {
    guard let document = try? SwiftSoup.parse(html) else { return false }
    return supportsDarkAppearance(in: document)
  }

  public static func supportsDarkAppearance(in document: Document) -> Bool {
    let metas: [Element] = (try? document.select("meta[name]").array()) ?? []
    for meta in metas {
      let name = ((try? meta.attr("name")) ?? "").lowercased()
      guard name == "color-scheme" || name == "supported-color-schemes" else { continue }
      let content = ((try? meta.attr("content")) ?? "").lowercased()
      let normalizedContent = content.replacingOccurrences(of: ",", with: " ")
      let schemes = normalizedContent.split(whereSeparator: { character in character.isWhitespace })
      if schemes.contains(where: { scheme in scheme == "dark" }) { return true }
    }

    let cssTexts = cssTexts(in: document)
    for css in cssTexts {
      if containsDarkAppearanceCSS(css) { return true }
    }
    return false
  }

  public static func paintsOwnBackground(html: String) -> Bool {
    guard let document = try? SwiftSoup.parse(html) else { return false }
    return paintsOwnBackground(in: document)
  }

  public static func paintsOwnBackground(in document: Document) -> Bool {
    let elements: [Element] = (try? document.select("*").array()) ?? []
    for element in elements {
      if hasNonemptyAttribute("bgcolor", on: element) { return true }
    }
    for css in cssTexts(in: document) {
      if hasBackgroundDeclaration(in: css) { return true }
    }
    return false
  }

  private static func cssTexts(in document: Document) -> [String] {
    var result: [String] = []
    let styles: [Element] = (try? document.select("style").array()) ?? []
    for style in styles {
      if let css = try? style.html() { result.append(css) }
    }
    let inlineStyles: [Element] = (try? document.select("[style]").array()) ?? []
    for element in inlineStyles {
      if let css = try? element.attr("style") { result.append(css) }
    }
    return result
  }

  private static func containsDarkAppearanceCSS(_ css: String) -> Bool {
    let mediaRange = css.range(
      of: #"@media\b[^{}]*\([^)]*prefers-color-scheme\s*:\s*dark[^)]*\)"#,
      options: [.regularExpression, .caseInsensitive]
    )
    if mediaRange != nil { return true }
    let schemeRange = css.range(
      of: #"(?:^|[;{\s])color-scheme\s*:[^;}]*\bdark\b"#,
      options: [.regularExpression, .caseInsensitive]
    )
    return schemeRange != nil
  }

  private static func hasNonemptyAttribute(_ name: String, on element: Element) -> Bool {
    guard let value = try? element.attr(name) else { return false }
    return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private static func hasBackgroundDeclaration(in css: String) -> Bool {
    css.range(
      of: #"(?:^|[;{\s])background(?:-color)?\s*:\s*[^;}]+"#,
      options: [.regularExpression, .caseInsensitive]
    ) != nil
  }
}
