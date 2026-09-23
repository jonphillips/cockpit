@testable import CockpitCore
import Testing

struct EmailFitTests {
  @Test("Detects a Substack style max width wrapper")
  func detectsMaxWidthWrapper() {
    #expect(EmailDesignWidth.detect(html: "<body><div style='max-width: 550px; margin:auto'>x</div></body>") == 550)
    #expect(EmailDesignWidth.detect(html: "<body><div style='max-width: 600px !important'>x</div></body>") == 600)
    #expect(EmailDesignWidth.detect(html: "<body><table style='min-width: 600px'></table></body>") == 600)
  }

  @Test("Chooses the widest fixed width among shallow layout containers")
  func choosesWidestContainer() {
    #expect(EmailDesignWidth.detect(html: "<body><table width='600'><tr><td><table width='500'></table></td></tr></table></body>") == 600)
  }

  @Test("Finds a fixed inner container inside a fluid outer container")
  func findsFixedInnerContainer() {
    #expect(EmailDesignWidth.detect(html: "<body><table width='100%'><tr><td><div style='width: 600px'></div></td></tr></table></body>") == 600)
  }

  @Test("Ignores fluid, spacer, and implausibly wide dimensions")
  func ignoresFluidAndImplausibleDimensions() {
    #expect(EmailDesignWidth.detect(html: "<body><div style='width: 100%; max-width: 100%'><table width='1'></table></div></body>") == nil)
    #expect(EmailDesignWidth.detect(html: "<body><table width='2000'></table></body>") == nil)
  }

  @Test("Accepts pixel suffix in HTML width attributes")
  func acceptsPixelAttribute() {
    #expect(EmailDesignWidth.detect(html: "<body><table width='600px'></table></body>") == 600)
  }

  @Test("Fits at a comfortable cap and shrinks wide email to the pane")
  func zoomBounds() {
    #expect(EmailFitZoom.zoom(designWidth: 550, availableWidth: 950) == 1.3)
    #expect(abs(EmailFitZoom.zoom(designWidth: 700, availableWidth: 800) - 1.09) < 0.01)
    let narrowPaneZoom = EmailFitZoom.zoom(designWidth: 600, availableWidth: 390)
    #expect(abs(narrowPaneZoom - 0.617) < 0.001)
    #expect((600 + 2 * EmailFitZoom.horizontalGutter) * narrowPaneZoom <= 390)
    #expect(EmailFitZoom.zoom(designWidth: 800, availableWidth: 390) == 0.5)
    #expect(EmailFitZoom.zoom(designWidth: nil, availableWidth: 950) == 1.0)
  }
}

struct EmailFitWidthTests {
  /// `#expect` cannot wrap a mutating call, so each recording goes through here.
  private func record(
    _ width: inout EmailFitWidth, contentWidth: Double, viewWidth: Double, zoom: Double
  ) -> Bool {
    width.recordRendered(contentWidth: contentWidth, viewWidth: viewWidth, zoom: zoom)
  }

  @Test("A page that fits the view leaves the detected width alone")
  func fittingPageIsNotMeasured() {
    var width = EmailFitWidth(detected: 600)
    #expect(record(&width, contentWidth: 952.5, viewWidth: 952, zoom: 1.3) == false)
    #expect(width.designWidth == 600)
  }

  @Test("Overflow wider than the detected column refits the whole page into the pane")
  func overflowRefitsPage() throws {
    // NYT Travel Dispatch on iPad: a 600px column detected, but the page lays out about 940px wide.
    var width = EmailFitWidth(detected: 600)
    #expect(record(&width, contentWidth: 1_222, viewWidth: 952, zoom: 1.3) == true)
    let designWidth = try #require(width.designWidth)
    #expect(abs(designWidth - 940) < 0.01)

    let zoom = EmailFitZoom.zoom(designWidth: designWidth, availableWidth: 952)
    #expect((designWidth + 2 * EmailFitZoom.horizontalGutter) * zoom <= 952)
  }

  @Test("A fluid email that overflows gets a fit width")
  func fluidOverflow() {
    var width = EmailFitWidth(detected: nil)
    #expect(record(&width, contentWidth: 500, viewWidth: 390, zoom: 1.0) == true)
    #expect(width.designWidth == 500)
  }

  @Test("The fit width only widens within one email")
  func onlyWidens() {
    var width = EmailFitWidth(detected: 600)
    #expect(record(&width, contentWidth: 1_222, viewWidth: 952, zoom: 1.3) == true)
    #expect(record(&width, contentWidth: 960, viewWidth: 952, zoom: 1.1) == false)
    #expect(abs((width.designWidth ?? 0) - 940) < 0.01)
  }

  @Test("At the zoom floor, the same overflow measures the same and stops")
  func floorConverges() {
    var width = EmailFitWidth(detected: nil)
    #expect(record(&width, contentWidth: 1_600, viewWidth: 390, zoom: 1.0) == true)
    let zoom = EmailFitZoom.zoom(designWidth: width.designWidth, availableWidth: 390)
    #expect(zoom == EmailFitZoom.minimumZoom)
    #expect(record(&width, contentWidth: 1_600 * zoom, viewWidth: 390, zoom: zoom) == false)
  }

  @Test("A detected width wider than the measured page still wins")
  func detectedWins() {
    var width = EmailFitWidth(detected: 900)
    #expect(record(&width, contentWidth: 800, viewWidth: 700, zoom: 1.0) == true)
    #expect(width.designWidth == 900)
  }

  @Test("After a zoom change, the old layout is not read against the new zoom")
  func staleLayoutAfterZoomIsIgnored() {
    var width = EmailFitWidth(detected: 600)
    #expect(record(&width, contentWidth: 1_222, viewWidth: 952, zoom: 1.3) == true)
    width.expectRelayout(fromContentWidth: 1_222)
    // Still the 1.3 layout; read at the new zoom it would claim a page about 1250px wide.
    #expect(record(&width, contentWidth: 1_222, viewWidth: 952, zoom: 0.979) == false)
    #expect(abs((width.designWidth ?? 0) - 940) < 0.01)
    // The fresh layout fits, so nothing more is recorded.
    #expect(record(&width, contentWidth: 952, viewWidth: 952, zoom: 0.979) == false)
  }

  @Test("After the pane narrows, the old layout is not taken for overflow")
  func staleLayoutAfterNarrowingIsIgnored() {
    var width = EmailFitWidth(detected: 600)
    width.expectRelayout(fromContentWidth: 952)
    #expect(record(&width, contentWidth: 952, viewWidth: 800, zoom: 1.3) == false)
    #expect(width.designWidth == 600)
    // Once the page lays out again, real overflow is still caught.
    #expect(record(&width, contentWidth: 1_000, viewWidth: 800, zoom: 1.2) == true)
    #expect(abs((width.designWidth ?? 0) - 833.33) < 0.01)
  }

  @Test("Degenerate measurements are ignored")
  func degenerateInputs() {
    var width = EmailFitWidth(detected: 600)
    #expect(record(&width, contentWidth: .infinity, viewWidth: 952, zoom: 1.3) == false)
    #expect(record(&width, contentWidth: 1_222, viewWidth: 0, zoom: 1.3) == false)
    #expect(record(&width, contentWidth: 1_222, viewWidth: 952, zoom: 0) == false)
  }
}
