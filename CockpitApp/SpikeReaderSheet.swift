import CockpitCore
import Dependencies
import LazyState
import SQLiteData
import SwiftUI
import WebKit

/// Throwaway feel-finding harness for comparing an email's original HTML with a structured
/// SwiftUI rendering. Keep this file isolated: it is intentionally not production Reader code.
enum SpikeConfig {
  /// TODO: production should default this off and expose an explicit "Load Remote Content" action
  /// because images/fonts can include tracking pixels and read-receipt signals.
  static let loadRemoteContent = true
}

struct SpikeReaderSheet: View {
  let contentPieceID: ContentPiece.ID
  @LazyState private var readerModel: ContentPieceReaderModel
  @Dependency(\.defaultDatabase) private var database
  @State private var mode: SpikeReaderMode = .original
  @State private var rawSourceText: String?
  @State private var readerBlocks: [SpikeReaderBlock] = []
  @State private var isLoading = true

  init(contentPieceID: ContentPiece.ID) {
    self.contentPieceID = contentPieceID
    _readerModel = LazyState { ContentPieceReaderModel(contentPieceID: contentPieceID) }
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      Picker("Rendering", selection: $mode) {
        ForEach(SpikeReaderMode.allCases) { mode in
          Text(mode.rawValue).tag(mode)
        }
      }
      .pickerStyle(.segmented).padding(.horizontal).padding(.bottom, 10)

      Divider()

      Group {
        if isLoading {
          ProgressView("Loading email")
        } else if let rawSourceText {
          switch mode {
          case .original:
            SpikeOriginalWebView(rawSourceText: rawSourceText)
          case .reader:
            SpikeReaderModeView(blocks: readerBlocks)
          }
        } else {
          ContentUnavailableView(
            "Original body unavailable",
            systemImage: "envelope.badge.xmark",
            description: Text("This email has no retained raw HTML on this device.")
          )
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .background(Color(uiColor: .systemBackground))
    .navigationTitle("Reader")
    .navigationBarTitleDisplayMode(.inline)
    .task { await load() }
  }

  @ViewBuilder
  private var header: some View {
    if let row = readerModel.row {
      VStack(alignment: .leading, spacing: 3) {
        Text(row.title).font(.headline).lineLimit(2)
        Text(row.publisher).font(.subheadline).foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
      .padding(.top, 12).padding(.bottom, 10)
    } else {
      ProgressView().frame(maxWidth: .infinity, alignment: .leading).padding()
    }
  }

  private func load() async {
    try? await readerModel.$content.load()
    do {
      rawSourceText = try await database.read { db in
        try Artifact
          .where { $0.contentPieceID.eq(contentPieceID) }
          .order { $0.acquiredAt.desc() }
          .fetchAll(db)
          .compactMap(\.rawSourceText)
          .first
      }
      if let rawSourceText {
        readerBlocks = SpikeReaderParser.parse(rawSourceText)
      }
    } catch {
      rawSourceText = nil
    }
    isLoading = false
  }
}

private enum SpikeReaderMode: String, CaseIterable, Identifiable {
  case original = "Original"
  case reader = "Reader"

  var id: Self { self }
}

private struct SpikeOriginalWebView: UIViewRepresentable {
  let rawSourceText: String

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.defaultWebpagePreferences.allowsContentJavaScript = false
    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = context.coordinator
    webView.uiDelegate = context.coordinator
    webView.allowsBackForwardNavigationGestures = false
    load(in: webView)
    context.coordinator.loadedHTML = rawSourceText
    return webView
  }

  func updateUIView(_ webView: WKWebView, context: Context) {
    guard context.coordinator.loadedHTML != rawSourceText else { return }
    load(in: webView)
    context.coordinator.loadedHTML = rawSourceText
  }

  private func load(in webView: WKWebView) {
    let html = SpikeConfig.loadRemoteContent ? rawSourceText : SpikeHTML.withRemoteContentRemoved(rawSourceText)
    webView.loadHTMLString(html, baseURL: nil)
  }

  @MainActor final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    var loadedHTML: String?

    func webView(
      _ webView: WKWebView,
      decidePolicyFor navigationAction: WKNavigationAction,
      decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
      // loadHTMLString arrives as .other. Every user-initiated link tap is canceled.
      decisionHandler(navigationAction.navigationType == .other ? .allow : .cancel)
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
}

private struct SpikeReaderModeView: View {
  let blocks: [SpikeReaderBlock]

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 18) {
        ForEach(blocks) { block in
          blockView(block)
        }
      }
      .frame(maxWidth: 640, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .center)
      .padding(.horizontal, 24)
      .padding(.vertical, 24)
    }
    .scrollIndicators(.hidden)
  }

  @ViewBuilder
  private func blockView(_ block: SpikeReaderBlock) -> some View {
    switch block {
    case let .heading(_, level, text):
      Text(text)
        .font(level == 1 ? .title2.weight(.semibold) : .title3.weight(.semibold))
        .lineSpacing(3)
    case let .paragraph(_, runs):
      SpikeInlineText(runs: runs)
    case let .listItem(_, text):
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Text("•").foregroundStyle(.secondary)
        Text(text)
      }
      .font(.body.monospacedDigit())
      .lineSpacing(5)
    case let .image(_, source, alt):
      SpikeImageView(source: source, alt: alt)
    case let .blockquote(_, text):
      HStack(alignment: .top, spacing: 12) {
        Rectangle().fill(.tint).frame(width: 3)
        Text(text).italic()
      }
      .font(.body.monospacedDigit())
      .foregroundStyle(.secondary)
      .lineSpacing(5)
    case .divider:
      Divider().padding(.vertical, 3)
    }
  }
}

private struct SpikeInlineText: View {
  let runs: [SpikeInlineRun]

  var body: some View {
    runs.reduce(Text("")) { partial, run in
      var text = Text(run.text)
      if run.isBold { text = text.bold() }
      if run.isItalic { text = text.italic() }
      if run.href != nil { text = text.foregroundStyle(.tint) }
      return Text("\(partial)\(text)")
    }
    .font(.body.monospacedDigit())
    .lineSpacing(5)
    .foregroundStyle(.primary)
  }
}

private struct SpikeImageView: View {
  let source: String
  let alt: String

  var body: some View {
    if SpikeConfig.loadRemoteContent, let url = URL(string: source) {
      AsyncImage(url: url) { phase in
        switch phase {
        case let .success(image):
          image.resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 10))
        case .failure:
          placeholder
        case .empty:
          ProgressView().frame(maxWidth: .infinity).frame(height: 90)
        @unknown default:
          placeholder
        }
      }
      .accessibilityLabel(alt)
    } else {
      placeholder
    }
  }

  private var placeholder: some View {
    Label(alt.isEmpty ? "Image" : alt, systemImage: "photo")
      .font(.caption)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity)
      .frame(height: 72)
      .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
  }
}

private enum SpikeHTML {
  static func withRemoteContentRemoved(_ html: String) -> String {
    html.replacingOccurrences(
      of: #"(?is)\s(?:src|srcset|href)\s*=\s*([\"'])https?://.*?\1"#,
      with: "", options: .regularExpression
    )
  }
}
