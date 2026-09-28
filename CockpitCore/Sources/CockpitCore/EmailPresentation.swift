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
}

// MARK: - Page background

extension EmailPresentation {
  /// A page background only: `html`, `body`, or the wrapper chain below `body`. A background on a
  /// button or callout cell doesn't count, because body text can sit outside it. A miss costs only the
  /// paper-on-Ground look; a false positive would put black text on dark Ground.
  public static func paintsOwnBackground(in document: Document) -> Bool {
    var candidates: [Element] = []
    if let root = document.children().first() { candidates.append(root) }
    candidates.append(contentsOf: wrapperChain(in: document))
    if candidates.contains(where: paintsBackground) { return true }

    let styles: [Element] = (try? document.select("style").array()) ?? []
    return styles.contains { style in
      guard let css = try? style.html() else { return false }
      return stylesheetPaintsPageBackground(css)
    }
  }

  /// `body`, then each only rendered child, ending at the first element that branches.
  private static func wrapperChain(in document: Document) -> [Element] {
    guard var element = document.body() else { return [] }
    var chain = [element]
    while true {
      let children = element.children().array().filter { !nonRenderingTags.contains($0.tagName().lowercased()) }
      guard children.count == 1, let only = children.first else { return chain }
      element = only
      chain.append(element)
    }
  }

  private static let nonRenderingTags: Set<String> = ["style", "script", "meta", "link", "title"]

  private static func paintsBackground(_ element: Element) -> Bool {
    if let color = try? element.attr("bgcolor"), paintsColor(color) { return true }
    let style = (try? element.attr("style")) ?? ""
    return style.split(separator: ";").contains { declaration in
      let parts = declaration.split(separator: ":", maxSplits: 1)
      guard parts.count == 2 else { return false }
      let property = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      guard property == "background" || property == "background-color" else { return false }
      return paintsColor(String(parts[1]))
    }
  }

  private static func paintsColor(_ value: String) -> Bool {
    let value = value.lowercased()
      .replacingOccurrences(of: "!important", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    // A bare image may not load (remote content is off by default), so it doesn't count.
    guard !value.isEmpty, !value.hasPrefix("url(") else { return false }
    return !["none", "transparent", "inherit", "initial", "unset"].contains(value)
  }

  /// Innermost `selector { declarations }` blocks whose subject is `html` or `body`.
  private static func stylesheetPaintsPageBackground(_ css: String) -> Bool {
    guard let rule = try? NSRegularExpression(pattern: #"([^{}]+)\{([^{}]*)\}"#) else { return false }
    let range = NSRange(css.startIndex..., in: css)
    return rule.matches(in: css, range: range).contains { match in
      guard let selectors = Range(match.range(at: 1), in: css),
        let declarations = Range(match.range(at: 2), in: css)
      else { return false }
      let targetsPage = css[selectors].split(separator: ",").contains { selector in
        let subject = selector.split(whereSeparator: { " >+~\n\t".contains($0) }).last ?? ""
        let tag = subject.prefix { $0.isLetter }.lowercased()
        return tag == "html" || tag == "body"
      }
      guard targetsPage else { return false }
      return css[declarations].split(separator: ";").contains { declaration in
        let parts = declaration.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return false }
        let property = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return (property == "background" || property == "background-color") && paintsColor(String(parts[1]))
      }
    }
  }
}
