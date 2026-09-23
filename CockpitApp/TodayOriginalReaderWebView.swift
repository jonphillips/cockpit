import CockpitCore
import Observation
import SwiftSoup
import SwiftUI
import UIKit
import WebKit

enum TodayOriginalReaderConfiguration {
  /// The original email design may load remote images and fonts for fidelity. JavaScript,
  /// navigation, cookies, and persistent web data remain disabled below.
  static let loadRemoteContent = true
}

enum TodayOriginalHTML {
  static func sanitizedForWebView(_ rawHTML: String) -> String {
    guard let document = try? SwiftSoup.parse(rawHTML) else { return rawHTML }
    _ = try? document.select("script").remove()
    normalizeViewport(in: document)
    appendFitZoom(to: document)

    for image in (try? document.select("img").array()) ?? [] {
      if isTrackingPixel(image) { try? image.remove() }
    }

    if !TodayOriginalReaderConfiguration.loadRemoteContent {
      removeRemoteContent(from: document)
    }
    return (try? document.html()) ?? rawHTML
  }

  private static func normalizeViewport(in document: SwiftSoup.Document) {
    let viewportTags = (try? document.select("meta[name]").array()) ?? []
    for meta in viewportTags where ((try? meta.attr("name")) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      .caseInsensitiveCompare("viewport") == .orderedSame {
      _ = try? meta.remove()
    }

    guard let viewport = try? document.createElement("meta") else { return }
    _ = try? viewport.attr("name", "viewport")
    _ = try? viewport.attr("content", "width=device-width, initial-scale=1")
    if let head = document.head() {
      _ = try? head.appendChild(viewport)
    } else {
      _ = try? document.prependChild(viewport)
    }
  }

  /// Appended last in `<head>` so it follows the email's own head styles.
  private static func appendFitZoom(to document: SwiftSoup.Document) {
    guard let css = EmailFitZoom.stylesheet(designWidth: EmailDesignWidth.detect(in: document)),
      let head = document.head(),
      let style = try? document.createElement("style")
    else { return }
    _ = try? style.attr("id", fitZoomStyleID)
    _ = try? style.html(css)
    _ = try? head.appendChild(style)
  }

  static let fitZoomStyleID = "cockpit-email-fit"

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

@Observable
@MainActor
final class TodayOriginalWebViewStore {
  private static let processPool = WKProcessPool()
  @ObservationIgnored private var contentSizeObservation: NSKeyValueObservation?
  @ObservationIgnored private var loadedHTML: String?
  @ObservationIgnored private let navigationCoordinator: TodayOriginalWebViewCoordinator
  @ObservationIgnored let webView: WKWebView

  private(set) var contentHeight: CGFloat = 44

  init() {
    let configuration = WKWebViewConfiguration()
    configuration.processPool = Self.processPool
    configuration.websiteDataStore = .nonPersistent()
    configuration.defaultWebpagePreferences.allowsContentJavaScript = false
    configuration.defaultWebpagePreferences.preferredContentMode = .mobile

    let webView = WKWebView(frame: .zero, configuration: configuration)
    let navigationCoordinator = TodayOriginalWebViewCoordinator()
    webView.navigationDelegate = navigationCoordinator
    webView.uiDelegate = navigationCoordinator
    webView.allowsBackForwardNavigationGestures = false
    webView.scrollView.isScrollEnabled = false
    webView.scrollView.bounces = false

    self.webView = webView
    self.navigationCoordinator = navigationCoordinator
    contentSizeObservation = webView.scrollView.observe(\.contentSize, options: [.initial, .new]) {
      [weak self] _, _ in
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.contentHeight = max(44, self.webView.scrollView.contentSize.height)
      }
    }
  }

  func load(rawHTML: String) {
    let sanitizedHTML = TodayOriginalHTML.sanitizedForWebView(rawHTML)
    guard loadedHTML != sanitizedHTML else { return }
    webView.stopLoading()
    webView.scrollView.setContentOffset(.zero, animated: false)
    contentHeight = 44
    navigationCoordinator.allowNextInitialLoad = true
    loadedHTML = sanitizedHTML
    webView.loadHTMLString(sanitizedHTML, baseURL: nil)
  }
}

@MainActor
private final class TodayOriginalWebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
  var allowNextInitialLoad = false

  func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
  ) {
    // loadHTMLString uses .other. Once it is admitted, only a user tap on an approved external
    // scheme may leave the app; the web view itself never follows links.
    let isInitialLoad = allowNextInitialLoad && navigationAction.navigationType == .other
    allowNextInitialLoad = false
    if isInitialLoad {
      decisionHandler(.allow)
    } else {
      openExternally(navigationAction.request.url, isUserActivated: navigationAction.navigationType == .linkActivated)
      decisionHandler(.cancel)
    }
  }

  func webView(
    _ webView: WKWebView,
    createWebViewWith configuration: WKWebViewConfiguration,
    for navigationAction: WKNavigationAction,
    windowFeatures: WKWindowFeatures
  ) -> WKWebView? {
    openExternally(navigationAction.request.url, isUserActivated: navigationAction.navigationType == .linkActivated)
    return nil
  }

  private func openExternally(_ url: URL?, isUserActivated: Bool) {
    guard let url = EmailLinkPolicy.externalURL(for: url, isUserActivated: isUserActivated) else { return }
    UIApplication.shared.open(url)
  }
}

struct TodayOriginalWebView: UIViewRepresentable {
  let webView: WKWebView

  func makeUIView(context: Context) -> WKWebView { webView }

  func updateUIView(_ webView: WKWebView, context: Context) {}
}
