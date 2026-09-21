import CockpitCore
import Dependencies
import Foundation
import Observation
import SQLiteData
import SwiftUI
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
  var sender = ""
  var treatment: EmailTreatment?
  var isLoading = false
  var hasBody = false
  private(set) var lastPresentedContentPieceID: ContentPiece.ID?

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
    sender = ""
    treatment = nil
    hasBody = false
    isLoading = true
    lastPresentedContentPieceID = contentPieceID
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
  func presentationDismissed() -> ContentPiece.ID? {
    guard presentation == nil else { return nil }
    let dismissedID = lastPresentedContentPieceID
    lastPresentedContentPieceID = nil
    loadTask?.cancel()
    loadTask = nil
    webView.stopLoading()
    isLoading = false
    return dismissedID
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
          sender: contentPiece?.creator ?? contentPiece?.publisher ?? "",
          treatment: contentPiece?.emailTreatment,
          rawSourceText: rawSourceText)
      }

      guard !Task.isCancelled, presentation?.id == contentPieceID else { return }
      title = value.title
      publisher = value.publisher
      sender = value.sender
      treatment = value.treatment
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
  let sender: String
  let treatment: EmailTreatment?
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
