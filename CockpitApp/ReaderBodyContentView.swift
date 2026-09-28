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

  @ViewBuilder
  func readerEmailColumn(width: CGFloat?, kind: EmailPresentation.Kind?) -> some View {
    if case .designed? = kind {
      self
    } else {
      readerEmailColumn(width: width)
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
        .clipShape(.rect(cornerRadius: emailKind.map {
          if case .designed = $0 { return 0 }
          return 12
        } ?? 12))
        .frame(maxWidth: emailKind.map { kind in
          if case .letter = kind { return Theme.readingMeasure * CGFloat(emailZoom) }
          return .infinity
        } ?? .infinity)
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
    return .white
  }

  private func configureEmailAppearance() {
    guard case .html = presentation, let emailKind else {
      originalWebViewStore.webView.overrideUserInterfaceStyle = .unspecified
      originalWebViewStore.webView.isOpaque = true
      originalWebViewStore.webView.backgroundColor = .white
      originalWebViewStore.webView.scrollView.backgroundColor = .white
      return
    }
    let shouldFollowSystem = if case .designed = emailKind {
      originalWebViewStore.supportsDarkAppearance
    } else {
      false
    }
    let usesDocumentColors = if case .designed = emailKind {
      true
    } else {
      originalWebViewStore.letterSetsOwnColors
    }
    originalWebViewStore.webView.overrideUserInterfaceStyle = shouldFollowSystem ? .unspecified : .light
    originalWebViewStore.webView.isOpaque = !usesDocumentColors
    originalWebViewStore.webView.backgroundColor = usesDocumentColors ? .clear : .white
    originalWebViewStore.webView.scrollView.backgroundColor = usesDocumentColors ? .clear : .white
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
