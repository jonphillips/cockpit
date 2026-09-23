@testable import Cockpit
import SwiftSoup
import Testing

struct TodayOriginalReaderTests {
  @Test("Original HTML sanitization removes an obvious tracking pixel and scripts")
  func sanitizesTrackingPixel() {
    let rawHTML = """
      <html><body>
        <img width="1" height="1" src="https://tracker.example/1x1.gif">
        <img width="600" height="200" src="https://cdn.example/hero.jpg">
        <script>window.location = 'https://untrusted.example';</script>
        <p>Newsletter body</p>
      </body></html>
      """

    let sanitized = TodayOriginalHTML.sanitizedForWebView(rawHTML).html

    #expect(sanitized.contains("hero.jpg"))
    #expect(sanitized.contains("Newsletter body"))
    #expect(!sanitized.contains("1x1.gif"))
    #expect(!sanitized.contains("tracker.example"))
    #expect(!sanitized.contains("window.location"))
  }

  @Test("Viewport sanitization replaces existing tags with one device-width tag")
  func replacesViewport() {
    let sanitized = TodayOriginalHTML.sanitizedForWebView("""
      <html><head><meta name="viewport" content="width=980"><meta name="viewport" content="initial-scale=2"></head>
      <body><p>Newsletter body</p></body></html>
      """).html

    #expect(sanitized.lowercased().components(separatedBy: "name=\"viewport\"").count - 1 == 1)
    #expect(sanitized.contains("width=device-width, initial-scale=1"))
    #expect(!sanitized.contains("width=980"))
    #expect(!sanitized.contains("initial-scale=2"))
  }

  @Test("Viewport sanitization adds a tag when the document has none")
  func addsViewport() {
    let sanitized = TodayOriginalHTML.sanitizedForWebView("<html><body><p>Newsletter body</p></body></html>").html

    #expect(sanitized.lowercased().components(separatedBy: "name=\"viewport\"").count - 1 == 1)
    #expect(sanitized.contains("width=device-width, initial-scale=1"))
  }

  @Test("A fixed-width email gets the fit-zoom stylesheet last in the head")
  func appendsFitZoomForFixedWidth() throws {
    let result = TodayOriginalHTML.sanitizedForWebView("""
      <html><head><style>p { color: black; }</style></head>
      <body><table width="600"><tr><td><p>Newsletter body</p></td></tr></table></body></html>
      """)
    let document = try SwiftSoup.parse(result.html)
    let lastInHead = try #require(document.head()?.children().last())

    #expect(result.designWidth == 600)
    #expect(lastInHead.id() == TodayOriginalHTML.fitZoomStyleID)
    #expect(try lastInHead.html().contains("html { zoom: 0.50; }"))
  }

  @Test("A fluid email gets no fit-zoom stylesheet")
  func skipsFitZoomForFluidEmail() {
    let result = TodayOriginalHTML.sanitizedForWebView(
      "<html><body><table width='100%'><tr><td><p>Newsletter body</p></td></tr></table></body></html>")

    #expect(result.designWidth == nil)
    #expect(!result.html.contains(TodayOriginalHTML.fitZoomStyleID))
  }
}
