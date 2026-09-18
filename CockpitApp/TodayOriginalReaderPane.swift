import CockpitCore
import Dependencies
import Foundation
import Observation
import SQLiteData
import SwiftUI
import SwiftSoup
import WebKit

/// The reader intentionally keeps one warm web view above the sheet. The shared process pool
/// makes opening consecutive messages cheap while the non-persistent store keeps email state
/// isolated from the rest of the app and from the next message.
@MainActor
@Observable
final class TodayOriginalReaderModel {
  @ObservationIgnored @Dependency(\.defaultDatabase) private var database
  @ObservationIgnored private let processPool = WKProcessPool()
  @ObservationIgnored private let navigationCoordinator: TodayOriginalWebViewCoordinator
  @ObservationIgnored let webView: WKWebView
  @ObservationIgnored private var loadTask: Task<Void, Never>?

  var presentation: TodayOriginalReaderPresentation?
  var title = ""
  var publisher = ""
  var isLoading = false
  var hasBody = false

  init() {
    let configuration = WKWebViewConfiguration()
    configuration.processPool = processPool
    configuration.websiteDataStore = .nonPersistent()
    configuration.defaultWebpagePreferences.allowsContentJavaScript = false

    let webView = WKWebView(frame: .zero, configuration: configuration)
    let navigationCoordinator = TodayOriginalWebViewCoordinator()
    webView.navigationDelegate = navigationCoordinator
    webView.uiDelegate = navigationCoordinator
    webView.allowsBackForwardNavigationGestures = false

    self.webView = webView
    self.navigationCoordinator = navigationCoordinator
  }

  func begin(contentPieceID: ContentPiece.ID) {
    loadTask?.cancel()
    webView.stopLoading()
    title = ""
    publisher = ""
    hasBody = false
    isLoading = true
    presentation = TodayOriginalReaderPresentation(id: contentPieceID)

    // Starting the fetch before the sheet exists lets the web view render under the zoom.
    loadTask = Task { [weak self] in
      await self?.load(contentPieceID: contentPieceID)
    }
  }

  /// Teardown after the sheet has actually dismissed. The framework already nils the
  /// `presentation` binding on dismiss; this only tears down the load. The guard is the fix
  /// for the "quick close, tap again" race: tapping a new item in the outgoing sheet's dimmed
  /// margin both dismisses the old sheet AND begins the new piece, so by the time this dismiss
  /// handler runs `presentation` is already the NEW piece — tearing down here would cancel its
  /// load and dismiss it a frame after it opened. Only clean up when nothing is re-presented.
  func presentationDismissed() {
    guard presentation == nil else { return }
    loadTask?.cancel()
    loadTask = nil
    webView.stopLoading()
    isLoading = false
  }

  private func load(contentPieceID: ContentPiece.ID) async {
    do {
      let value = try await database.read { db in
        let contentPiece = try ContentPiece.find(contentPieceID).fetchOne(db)
        let rawSourceText = try Artifact
          .where { $0.contentPieceID.eq(contentPieceID) }
          .order { $0.acquiredAt.desc() }
          .fetchAll(db)
          .compactMap(\.rawSourceText)
          .first
        return TodayOriginalReaderLoadData(
          title: contentPiece?.title ?? "",
          publisher: contentPiece?.publisher ?? "",
          rawSourceText: rawSourceText)
      }

      guard !Task.isCancelled, presentation?.id == contentPieceID else { return }
      title = value.title
      publisher = value.publisher
      guard let rawSourceText = value.rawSourceText else {
        isLoading = false
        return
      }

      navigationCoordinator.allowNextInitialLoad = true
      hasBody = true
      // This is deliberately the first presentation-side write after the artifact read. The
      // sheet is already presenting, but the web view starts loading before its animation ends.
      webView.loadHTMLString(
        TodayOriginalHTML.sanitizedForWebView(rawSourceText), baseURL: nil)
      isLoading = false
    } catch is CancellationError {
    } catch {
      guard presentation?.id == contentPieceID else { return }
      isLoading = false
    }
  }
}

private struct TodayOriginalReaderLoadData {
  let title: String
  let publisher: String
  let rawSourceText: String?
}

struct TodayOriginalReaderPresentation: Identifiable, Equatable {
  let id: ContentPiece.ID
}

@MainActor
private final class TodayOriginalWebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
  var allowNextInitialLoad = false

  func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
  ) {
    // loadHTMLString uses .other. Once that one navigation is admitted, every link tap is
    // canceled; email HTML is untrusted content and must not navigate the app or browser.
    let isInitialLoad = allowNextInitialLoad && navigationAction.navigationType == .other
    allowNextInitialLoad = false
    decisionHandler(isInitialLoad ? .allow : .cancel)
  }

  func webView(
    _ webView: WKWebView,
    createWebViewWith configuration: WKWebViewConfiguration,
    for navigationAction: WKNavigationAction,
    windowFeatures: WKWindowFeatures
  ) -> WKWebView? {
    nil
  }
}

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

struct TodayOriginalReaderPane: View {
  let model: TodayOriginalReaderModel
  let presentation: TodayOriginalReaderPresentation
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      ZStack {
        if model.hasBody {
          TodayOriginalWebView(webView: model.webView)
        } else if model.isLoading {
          ProgressView("Loading email")
        } else {
          ContentUnavailableView(
            "Original body unavailable",
            systemImage: "envelope.badge.xmark",
            description: Text("This email has no retained raw HTML on this device."))
        }

        if model.isLoading && model.hasBody {
          ProgressView().padding(12).background(.regularMaterial, in: Capsule())
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .background(Color(uiColor: .systemBackground))
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        // Environment dismiss drives the sheet away; the framework nils the binding and the
        // sheet's onDismiss (presentationDismissed) does the load teardown. Don't also write
        // `presentation` here — that reintroduces the clobber race.
        Button("Done", systemImage: "xmark") { dismiss() }
      }
    }
  }

  @ViewBuilder
  private var header: some View {
    if model.title.isEmpty && model.isLoading {
      ProgressView().frame(maxWidth: .infinity, alignment: .leading).padding()
    } else {
      VStack(alignment: .leading, spacing: 3) {
        Text(model.title.isEmpty ? "Email" : model.title)
          .font(.headline).lineLimit(2)
        if !model.publisher.isEmpty {
          Text(model.publisher).font(.subheadline).foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal).padding(.vertical, 10)
    }
  }
}

private struct TodayOriginalWebView: UIViewRepresentable {
  let webView: WKWebView

  func makeUIView(context: Context) -> WKWebView { webView }

  func updateUIView(_ webView: WKWebView, context: Context) {}
}
