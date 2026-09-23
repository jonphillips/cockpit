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

struct EmailFitBandTests {
  @Test("Fluid email gets no bands and keeps its native scale")
  func fluidEmail() {
    #expect(EmailFitZoom.stylesheet(designWidth: nil) == nil)
    #expect(EmailFitZoom.bandedZoom(designWidth: nil, viewportWidth: 952) == 1.0)
  }

  @Test("A 550px newsletter in a landscape iPad pane reaches the 1.3 cap")
  func substackOnIPad() throws {
    #expect(EmailFitZoom.bandedZoom(designWidth: 550, viewportWidth: 952) == 1.3)
    let css = try #require(EmailFitZoom.stylesheet(designWidth: 550))
    // 1.3 × (550 + 32) = 756.6, so the cap starts at 757px.
    #expect(css.contains("@media (min-width: 757px) { html { zoom: 1.30; } }"))
  }

  @Test("A 600px email on iPhone shrinks to fit")
  func tableOnIPhone() {
    // The exact fit is 390 / 632 ≈ 0.617; the band below it applies.
    #expect(EmailFitZoom.bandedZoom(designWidth: 600, viewportWidth: 390) == 0.6)
  }

  @Test("The floor band has no media query and the rest ascend")
  func bandOrder() throws {
    let bands = try #require(EmailFitZoom.bands(designWidth: 600))
    #expect(bands.first == EmailFitZoom.Band(minimumViewportWidth: 0, zoom: 0.5))
    #expect(bands.last?.zoom == EmailFitZoom.maximumZoom)
    #expect(zip(bands, bands.dropFirst()).allSatisfy {
      $0.minimumViewportWidth < $1.minimumViewportWidth && $0.zoom < $1.zoom
    })
    let css = try #require(EmailFitZoom.stylesheet(designWidth: 600))
    #expect(css.hasPrefix("html { zoom: 0.50; }"))
  }

  @Test("At every width a band never overflows and trails the exact fit by under one step")
  func bandsTrackExactFit() {
    let step = 1 / Double(EmailFitZoom.bandsPerUnitZoom)
    for designWidth in [320.0, 550, 600, 700, 1_000] {
      let fittedWidth = designWidth + 2 * EmailFitZoom.horizontalGutter
      for viewportWidth in stride(from: 300.0, through: 1_600, by: 7) {
        let zoom = EmailFitZoom.bandedZoom(designWidth: designWidth, viewportWidth: viewportWidth)
        let exact = EmailFitZoom.zoom(designWidth: designWidth, availableWidth: viewportWidth)
        #expect(zoom <= exact + 1e-9)
        #expect(exact - zoom < step + 1e-9)
        if viewportWidth >= fittedWidth * EmailFitZoom.minimumZoom {
          #expect(fittedWidth * zoom <= viewportWidth + 1e-9)
        }
      }
    }
  }
}

struct EmailColumnTests {
  @Test("Fixed email column follows the zoom band and never exceeds its viewport")
  func fixedEmailColumn() {
    #expect(EmailColumn.width(designWidth: 550, viewportWidth: 952) == 715)
    #expect(EmailColumn.width(designWidth: 600, viewportWidth: 390) == 360)
    #expect(EmailColumn.width(designWidth: 600, viewportWidth: 632) == 600)
  }

  @Test("Email column changes at the same viewport thresholds as the stylesheet")
  func columnTracksZoomBands() throws {
    let designWidth = 550.0
    let bands = try #require(EmailFitZoom.bands(designWidth: designWidth))
    for (previousBand, band) in zip(bands, bands.dropFirst()) {
      let before = Double(band.minimumViewportWidth - 1)
      let at = Double(band.minimumViewportWidth)
      #expect(EmailColumn.width(designWidth: designWidth, viewportWidth: before)
        == min(before, designWidth * previousBand.zoom))
      #expect(EmailColumn.width(designWidth: designWidth, viewportWidth: at)
        == min(at, designWidth * band.zoom))
    }
  }

  @Test("Fluid email uses the viewport width")
  func fluidEmailColumn() {
    #expect(EmailColumn.width(designWidth: nil, viewportWidth: 390) == 390)
    #expect(EmailColumn.width(designWidth: nil, viewportWidth: 0) == 0)
  }
}
