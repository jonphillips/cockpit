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
