import SwiftSoup
import SwiftUI
import WebKit

enum TodayOriginalReaderConfiguration {
  /// Jon accepts remote images/fonts for the full-fidelity original by default. This is the one
  /// switch to flip when an explicit in-app "load remote content" control exists.
  static let loadRemoteContent = true
  // TODO: replace this gate with a user-visible "Load remote content" refinement.
}

enum TodayOriginalHTML {
  static func sanitizedForWebView(_ rawHTML: String) -> String {
    guard let document = try? SwiftSoup.parse(rawHTML) else { return rawHTML }
    _ = try? document.select("script").remove()

    for image in (try? document.select("img").array()) ?? [] {
      if isTrackingPixel(image) { try? image.remove() }
    }

    if !TodayOriginalReaderConfiguration.loadRemoteContent {
      removeRemoteContent(from: document)
    }
    return (try? document.html()) ?? rawHTML
  }

  private static func isTrackingPixel(_ image: Element) -> Bool {
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

  private static func dimension(_ value: String?) -> Int? {
    guard let value else { return nil }
    let number = value.trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased().replacingOccurrences(of: "px", with: "")
    return Int(number)
  }

  private static func removeRemoteContent(from document: SwiftSoup.Document) {
    for image in (try? document.select("img").array()) ?? [] {
      _ = try? image.removeAttr("src")
      _ = try? image.removeAttr("srcset")
    }
    for link in (try? document.select("link[href]").array()) ?? [] {
      _ = try? link.removeAttr("href")
    }
    for style in (try? document.select("style").array()) ?? [] {
      guard let css = try? style.html(),
        let regex = try? NSRegularExpression(
          pattern: #"(?i)url\(\s*(['\"]?)(?:https?:)?//[^)]*\)"#)
      else { continue }
      let range = NSRange(css.startIndex..<css.endIndex, in: css)
      let localCSS = regex.stringByReplacingMatches(
        in: css, options: [], range: range, withTemplate: "none")
      _ = try? style.html(localCSS)
    }
  }
}

struct TodayOriginalWebView: UIViewRepresentable {
  let webView: WKWebView

  func makeUIView(context: Context) -> WKWebView { webView }

  func updateUIView(_ webView: WKWebView, context: Context) {}
}
