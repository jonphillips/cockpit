import CockpitCore
import SwiftUI

extension View {
  @ViewBuilder
  func readerEmailColumn(width: CGFloat?) -> some View {
    if let width {
      frame(maxWidth: width, alignment: .leading)
        .frame(maxWidth: .infinity)
    } else {
      self
    }
  }
}

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
  let emailKind: EmailPresentation.Kind?
  let emailZoom: Double
  let zoomAdjustmentStep: Int
  let isZoomPreferenceLoaded: Bool
  let magnify: (CGFloat) -> Void
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    switch presentation {
    case let .html(rawHTML):
      TodayOriginalWebView(webView: originalWebViewStore.webView)
        .frame(maxWidth: .infinity)
        .frame(height: originalWebViewStore.contentHeight)
        .frame(maxWidth: emailKind.map { kind in
          if case .letter = kind { return Theme.readingMeasure * CGFloat(emailZoom) }
          return .infinity
        } ?? .infinity)
        .padding(.horizontal, emailKind.map { if case .designed = $0 { return 12 }; return 0 } ?? 0)
        .background(emailBackground)
        .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.width } action: {
          originalWebViewStore.reportViewportWidth($0)
        }
        .simultaneousGesture(
          MagnifyGesture().onEnded { value in magnify(value.magnification) }
        )
        .onAppear { loadHTMLIfReady(rawHTML, step: zoomAdjustmentStep) }
        .onAppear { configureEmailAppearance() }
        .onChange(of: colorScheme) { _, _ in configureEmailAppearance() }
        .onChange(of: originalWebViewStore.supportsDarkAppearance) { _, _ in configureEmailAppearance() }
        .onChange(of: originalWebViewStore.letterSetsOwnColors) { _, _ in configureEmailAppearance() }
        .onChange(of: rawHTML) { _, newValue in
          loadHTMLIfReady(newValue, step: zoomAdjustmentStep)
        }
        .onChange(of: zoomAdjustmentStep) { _, newValue in
          loadHTMLIfReady(rawHTML, step: newValue)
        }
        .onChange(of: isZoomPreferenceLoaded) { _, isLoaded in
          if isLoaded { originalWebViewStore.load(rawHTML: rawHTML, adjustmentStep: zoomAdjustmentStep) }
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

  private var emailBackground: Color {
    guard let emailKind else { return .clear }
    if case .designed = emailKind { return Theme.ground }
    return originalWebViewStore.letterSetsOwnColors ? .white : .clear
  }

  private func configureEmailAppearance() {
    guard case .html = presentation else { return }
    let designed = emailKind.map { if case .designed = $0 { return true }; return false } ?? false
    let mustRenderLight = (designed && !originalWebViewStore.supportsDarkAppearance)
      || (!designed && originalWebViewStore.letterSetsOwnColors)
    originalWebViewStore.webView.overrideUserInterfaceStyle = mustRenderLight ? .light : .unspecified
    originalWebViewStore.webView.isOpaque = mustRenderLight
    originalWebViewStore.webView.backgroundColor = mustRenderLight ? .white : .clear
    originalWebViewStore.webView.scrollView.backgroundColor = mustRenderLight ? .white : .clear
  }

  private func loadHTMLIfReady(_ html: String, step: Int) {
    guard isZoomPreferenceLoaded else { return }
    originalWebViewStore.load(rawHTML: html, adjustmentStep: step)
  }

  @ViewBuilder
  private var openOriginalButton: some View {
    if let canonicalURL, let url = URL(string: canonicalURL) {
      Button("Open Original", systemImage: "arrow.up.right.square") { openURL(url) }
    }
  }
}
