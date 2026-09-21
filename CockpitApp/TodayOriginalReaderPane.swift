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

struct TodayOriginalReaderPane: View {
  let model: TodayOriginalReaderModel
  let presentation: TodayOriginalReaderPresentation
  let todayModel: TodayModel
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
      // One decision while reading: Archive. Trash and the sender/treatment tools live under the
      // menu so the common gesture is a single tap. Both dispositions advance to the next piece in
      // the same category and close the reader once the category is cleared.
      ToolbarItem(placement: .primaryAction) {
        Button("Archive", systemImage: "archivebox") {
          Task { await disposeAndAdvance { await todayModel.archive($0) } }
        }
        .disabled(currentRow == nil)
      }
      ToolbarItem(placement: .primaryAction) { readerMenu }
      ToolbarItem(placement: .cancellationAction) {
        // Environment dismiss drives the sheet away; the framework nils the binding and the
        // sheet's onDismiss (presentationDismissed) does the load teardown. Don't also write
        // `presentation` here — that reintroduces the clobber race.
        Button("Done", systemImage: "xmark") { dismiss() }
      }
    }
  }

  private var currentRow: TodayRequest.Row? {
    todayModel.content.rows.first { $0.id == presentation.id }
  }

  /// Applies a disposition to the piece on screen, then advances to the next piece in the same
  /// treatment. When that treatment is exhausted the reader closes — "close out when done with the
  /// category". The category is captured before the write because the write reloads the projection.
  private func disposeAndAdvance(_ dispose: (TodayRequest.Row) async -> Void) async {
    let currentID = presentation.id
    let treatment = model.treatment
    guard let row = currentRow else { dismiss(); return }
    await dispose(row)
    guard let treatment,
      let next = todayModel.content.rows.first(where: { $0.treatment == treatment && $0.id != currentID })
    else {
      dismiss()
      return
    }
    // Reassigning the presentation identity re-presents the sheet on the next piece; the guarded
    // onDismiss teardown treats this as the "quick swap" case and leaves the incoming load alone.
    model.begin(contentPieceID: next.id)
  }

  private var readerMenu: some View {
    Menu {
      SenderTreatmentSubmenu(currentTreatment: model.treatment) { treatment in
        Task {
          let reclassified = await todayModel.setSenderOverride(treatment, for: model.sender)
          if let piece = reclassified.first(where: { $0.id == presentation.id }) {
            model.treatment = piece.emailTreatment
          }
        }
      }
      if let row = currentRow {
        Divider()
        Button("Trash", systemImage: "trash", role: .destructive) {
          Task { await disposeAndAdvance { await todayModel.trash($0) } }
        }
        Button("Undo disposition", systemImage: "arrow.uturn.backward") {
          Task { await todayModel.undoDisposition(row) }
        }
      }
    } label: {
      Image(systemName: "ellipsis.circle")
    }
    .disabled(model.sender.isEmpty && currentRow == nil)
    .accessibilityLabel("More reader tools")
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
