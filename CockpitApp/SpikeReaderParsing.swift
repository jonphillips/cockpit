import Foundation
import SwiftSoup

struct SpikeInlineRun: Equatable {
  let text: String
  let isBold: Bool
  let isItalic: Bool
  let href: String?
}

enum SpikeReaderBlock: Identifiable {
  case heading(id: Int, level: Int, text: String)
  case paragraph(id: Int, runs: [SpikeInlineRun])
  case listItem(id: Int, text: String)
  case image(id: Int, source: String, alt: String)
  case blockquote(id: Int, text: String)
  case divider(id: Int)

  var id: Int {
    switch self {
    case let .heading(id, _, _), let .paragraph(id, _), let .listItem(id, _),
      let .image(id, _, _), let .blockquote(id, _), let .divider(id):
      id
    }
  }
}

enum SpikeReaderParser {
  static func parse(_ rawHTML: String) -> [SpikeReaderBlock] {
    guard let document = try? SwiftSoup.parse(rawHTML), let body = document.body() else { return [] }
    _ = try? document.select("script, style, head").remove()
    removeComments(from: body)
    removeTrackingPixels(from: body)

    var parser = SpikeBlockParser()
    parser.walk(body)
    return parser.blocks
  }

  private static func removeComments(from node: Node) {
    for child in node.getChildNodes() {
      if child is Comment {
        try? child.remove()
      } else {
        removeComments(from: child)
      }
    }
  }

  private static func removeTrackingPixels(from root: Element) {
    for image in (try? root.select("img").array()) ?? [] {
      let width = dimension(try? image.attr("width"))
      let height = dimension(try? image.attr("height"))
      let style = (try? image.attr("style"))?.lowercased() ?? ""
      let source = ((try? image.attr("src")) ?? "").lowercased()
      let looksLikeSpacer = source.contains("1x1") || source.contains("spacer")
        || source.contains("tracking") || source.contains("pixel")
        || style.contains("width:1px") || style.contains("height:1px")
      if width == 1 || height == 1 || looksLikeSpacer {
        try? image.remove()
      }
    }
  }

  private static func dimension(_ value: String?) -> Int? {
    guard let value else { return nil }
    return Int(value.trimmingCharacters(in: .whitespacesAndNewlines).trimSuffix("px"))
  }
}

private struct SpikeBlockParser {
  var blocks: [SpikeReaderBlock] = []
  private var nextID = 0

  mutating func walk(_ element: Element) {
    for child in element.getChildNodes() {
      guard let childElement = child as? Element else { continue }
      append(element: childElement)
    }
  }

  private mutating func append(element: Element) {
    let tag = element.tagName().lowercased()
    switch tag {
    case "h1", "h2", "h3", "h4", "h5", "h6":
      appendHeading(element, level: Int(String(tag.last!)) ?? 2)
    case "p":
      appendParagraph(element)
    case "li":
      appendListItem(element)
    case "blockquote":
      appendBlockquote(element)
    case "hr":
      appendDivider()
    case "img":
      appendImage(element)
    case "br":
      break
    default:
      walkContainer(element)
    }
  }

  private mutating func walkContainer(_ element: Element) {
    let hasBlockDescendant: Bool
    if let isEmpty = try? element.select("h1, h2, h3, h4, h5, h6, p, li, blockquote, hr, img").isEmpty() {
      hasBlockDescendant = !isEmpty
    } else {
      hasBlockDescendant = false
    }
    if !hasBlockDescendant, let text = normalized(try? element.text()) {
      appendParagraph(runs: [SpikeInlineRun(text: text, isBold: false, isItalic: false, href: nil)])
      return
    }
    walk(element)
  }

  private mutating func appendHeading(_ element: Element, level: Int) {
    guard let text = normalized(try? element.text()) else { return }
    blocks.append(.heading(id: takeID(), level: level, text: text))
  }

  private mutating func appendParagraph(_ element: Element) {
    let runs = SpikeInlineParser.runs(in: element)
    guard !runs.isEmpty else { return }
    appendParagraph(runs: runs)
  }

  private mutating func appendParagraph(runs: [SpikeInlineRun]) {
    let cleaned = SpikeInlineParser.cleaned(runs)
    guard !cleaned.isEmpty else { return }
    blocks.append(.paragraph(id: takeID(), runs: cleaned))
  }

  private mutating func appendListItem(_ element: Element) {
    guard element.parent()?.tagName().lowercased() != "li",
      let text = normalized(try? element.text())
    else { return }
    blocks.append(.listItem(id: takeID(), text: text))
  }

  private mutating func appendBlockquote(_ element: Element) {
    guard let text = normalized(try? element.text()) else { return }
    blocks.append(.blockquote(id: takeID(), text: text))
  }

  private mutating func appendImage(_ element: Element) {
    guard let source = ((try? element.attr("src")) ?? "").trimmedNonEmpty else { return }
    let alt = (try? element.attr("alt")) ?? ""
    blocks.append(.image(id: takeID(), source: source, alt: alt))
  }

  private mutating func appendDivider() {
    guard case .divider = blocks.last else {
      blocks.append(.divider(id: takeID()))
      return
    }
  }

  private mutating func takeID() -> Int {
    defer { nextID += 1 }
    return nextID
  }

  private func normalized(_ value: String?) -> String? {
    guard let value else { return nil }
    let result = value.components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
    return result.isEmpty ? nil : result
  }
}

private enum SpikeInlineParser {
  static func runs(in element: Element) -> [SpikeInlineRun] {
    element.getChildNodes().flatMap {
      runs(from: $0, isBold: false, isItalic: false, href: nil)
    }
  }

  static func cleaned(_ runs: [SpikeInlineRun]) -> [SpikeInlineRun] {
    var result: [SpikeInlineRun] = []
    for run in runs {
      let text = run.text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      guard !text.isEmpty else { continue }
      if let index = result.indices.last,
        result[index].isBold == run.isBold,
        result[index].isItalic == run.isItalic,
        result[index].href == run.href
      {
        result[index] = SpikeInlineRun(
          text: result[index].text + text, isBold: run.isBold, isItalic: run.isItalic, href: run.href)
      } else {
        result.append(SpikeInlineRun(text: text, isBold: run.isBold, isItalic: run.isItalic, href: run.href))
      }
    }
    guard let first = result.first, let last = result.last else { return [] }
    var trimmed = result
    trimmed[trimmed.startIndex] = SpikeInlineRun(
      text: first.text.trimmingCharacters(in: .whitespaces), isBold: first.isBold,
      isItalic: first.isItalic, href: first.href)
    trimmed[trimmed.index(before: trimmed.endIndex)] = SpikeInlineRun(
      text: last.text.trimmingCharacters(in: .whitespaces), isBold: last.isBold,
      isItalic: last.isItalic, href: last.href)
    return trimmed.filter { !$0.text.isEmpty }
  }

  private static func runs(
    from node: Node, isBold: Bool, isItalic: Bool, href: String?
  ) -> [SpikeInlineRun] {
    if let textNode = node as? TextNode {
      return [SpikeInlineRun(text: textNode.text(), isBold: isBold, isItalic: isItalic, href: href)]
    }
    guard let element = node as? Element else { return [] }
    let tag = element.tagName().lowercased()
    let childBold = isBold || tag == "b" || tag == "strong"
    let childItalic = isItalic || tag == "i" || tag == "em"
    let childHref = tag == "a" ? (try? element.attr("href")).flatMap { $0.isEmpty ? nil : $0 } : href
    return element.getChildNodes().flatMap {
      runs(from: $0, isBold: childBold, isItalic: childItalic, href: childHref)
    }
  }
}

private extension String {
  func trimSuffix(_ suffix: String) -> String {
    hasSuffix(suffix) ? String(dropLast(suffix.count)) : self
  }

  var trimmedNonEmpty: String? {
    let value = trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
  }
}
