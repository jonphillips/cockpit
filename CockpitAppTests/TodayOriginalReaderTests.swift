@testable import Cockpit
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

    let sanitized = TodayOriginalHTML.sanitizedForWebView(rawHTML)

    #expect(sanitized.contains("hero.jpg"))
    #expect(sanitized.contains("Newsletter body"))
    #expect(!sanitized.contains("1x1.gif"))
    #expect(!sanitized.contains("tracker.example"))
    #expect(!sanitized.contains("window.location"))
  }
}
