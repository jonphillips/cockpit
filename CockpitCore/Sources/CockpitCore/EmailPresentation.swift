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
    guard let width = EmailDesignWidth.detect(html: html) else { return .letter }
    return .designed(width: width)
  }

  public static func supportsDarkAppearance(html: String) -> Bool {
    guard let document = try? SwiftSoup.parse(html) else { return false }
    let metas = (try? document.select("meta[name=color-scheme], meta[content][name=color-scheme]").array()) ?? []
    if metas.contains(where: { meta in
      let name = ((try? meta.attr("name")) ?? "").lowercased()
      let content = ((try? meta.attr("content")) ?? "").lowercased()
      return name == "color-scheme" && content.contains("dark")
    }) { return true }

    let styles = (try? document.select("style").array()) ?? []
    return styles.contains { style in
      guard let css = try? style.html() else { return false }
      return css.range(of: #"@media\s*\([^)]*prefers-color-scheme\s*:\s*dark[^)]*\)"#,
                       options: [.regularExpression, .caseInsensitive]) != nil
    }
  }

  public static func letterSetsOwnColors(html: String) -> Bool {
    guard let document = try? SwiftSoup.parse(html) else { return false }
    let elements = (try? document.select("body, p" ).array()) ?? []
    return elements.contains { element in
      let style = ((try? element.attr("style")) ?? "").lowercased()
      return style.split(separator: ";").contains { declaration in
        let property = declaration.split(separator: ":", maxSplits: 1).first?
          .trimmingCharacters(in: .whitespacesAndNewlines)
        return property == "color" || property == "background" || property == "background-color"
      }
    }
  }
}

/// The next item shown in Process' reader footer. Position is local to that item's role section.
public struct ProcessNextCard: Equatable, Sendable {
  public let row: TodayReadingQueueRequest.Row
  public let roleIndex: Int
  public let roleCount: Int

  public static func after(
    _ contentPieceID: ContentPiece.ID,
    in rows: [TodayReadingQueueRequest.Row]
  ) -> ProcessNextCard? {
    guard let index = rows.firstIndex(where: { $0.id == contentPieceID }), rows.indices.contains(index + 1) else {
      return nil
    }
    let next = rows[index + 1]
    let sectionRows = rows.filter { $0.role == next.role }
    guard let roleIndex = sectionRows.firstIndex(where: { $0.id == next.id }) else { return nil }
    return ProcessNextCard(row: next, roleIndex: roleIndex + 1, roleCount: sectionRows.count)
  }

  public init(row: TodayReadingQueueRequest.Row, roleIndex: Int, roleCount: Int) {
    self.row = row
    self.roleIndex = roleIndex
    self.roleCount = roleCount
  }
}
