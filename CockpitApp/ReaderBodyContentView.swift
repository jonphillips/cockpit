import CockpitCore
import SwiftUI

struct ReaderSummaryView: View {
  let summary: String?
  let isCompactPreview: Bool

  var body: some View {
    if let summary, !summary.isEmpty {
      if isCompactPreview {
        VStack(alignment: .leading, spacing: 6) {
          Text("Contents preview")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(summary)
        }
        .padding()
        .background(.thinMaterial, in: .rect(cornerRadius: 12))
      } else {
        Text(summary)
      }
    }
  }
}

struct ReaderBodyView: View {
  let presentation: ReaderBodyPresentation
  let canonicalURL: String?
  let openURL: OpenURLAction
  let originalWebViewStore: TodayOriginalWebViewStore

  var body: some View {
    switch presentation {
    case let .html(rawHTML):
      TodayOriginalWebView(webView: originalWebViewStore.webView)
        .frame(height: originalWebViewStore.contentHeight)
        .clipShape(.rect(cornerRadius: 12))
        .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.width } action: { width in
          originalWebViewStore.setAvailableWidth(width)
        }
        .onAppear { originalWebViewStore.load(rawHTML: rawHTML) }
        .onChange(of: rawHTML) { _, newValue in
          originalWebViewStore.load(rawHTML: newValue)
        }

    case let .inline(text, isTruncated):
      Text(text)
        .font(.body)
        .textSelection(.enabled)

      if isTruncated {
        Text("Cockpit holds the opening; the rest is at the source.")
          .font(.callout)
          .foregroundStyle(.secondary)
        openOriginalButton
      } else {
        openOriginalButton
          .font(.caption)
          .foregroundStyle(.secondary)
      }

    case .unavailable:
      Text("Cockpit does not hold this body on this device.")
        .font(.callout)
        .foregroundStyle(.secondary)
      openOriginalButton

    case .preview, .compactPreview:
      openOriginalButton
    }
  }

  @ViewBuilder
  private var openOriginalButton: some View {
    if let canonicalURL, let url = URL(string: canonicalURL) {
      Button("Open Original", systemImage: "arrow.up.right.square") { openURL(url) }
    }
  }
}
