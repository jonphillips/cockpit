@testable import CockpitCore
import CustomDump
import Foundation
import Testing

struct HTMLTextTests {
  @Test("Normalizer removes MJML and Outlook boilerplate from the MyUNCChart estimate")
  func removesEmailBoilerplate() throws {
    let fixtureURL = try #require(
      Bundle.module.url(forResource: "myuncchart-new-estimate", withExtension: "html", subdirectory: "Fixtures/email"))
    let html = try String(contentsOf: fixtureURL, encoding: .utf8)

    let normalized = try #require(HTMLText.normalizedText(from: html))
    #expect(normalized.hasPrefix("You have a new estimate for your visit"))
    #expect(!normalized.contains("{"))
    #expect(!normalized.contains("}"))
    #expect(!normalized.contains("@media"))
    #expect(!normalized.contains("mso-"))
    #expect(!normalized.contains("tracking-pixel"))
  }

  @Test("Normalizer decodes numeric and common named HTML entities")
  func decodesNumericAndNamedEntities() {
    expectNoDifference(
      HTMLText.normalizedText(
        from: "&#8217; &#x2019; &mdash; &ndash; &rsquo; &lsquo; &rdquo; &ldquo; &hellip; &#39;"
      ),
      "’ ’ — – ’ ‘ ” “ … '"
    )
  }

  @Test("Normalizer preserves HTML block boundaries while collapsing intra-line whitespace")
  func preservesBlockBoundaries() {
    let html = """
      <h2> A   heading </h2>
      <p> First    paragraph with <strong>emphasis</strong>. </p>


      <p> Second paragraph. </p>
      <ul><li> First   item </li><li>Second item</li></ul>
      """

    expectNoDifference(
      HTMLText.normalizedText(from: html),
      "A heading\nFirst paragraph with emphasis.\nSecond paragraph.\nFirst item\nSecond item"
    )
  }

  @Test("Normalizer squeezes a run of blank lines to one separator")
  func squeezesBlankLineRuns() {
    expectNoDifference(
      HTMLText.normalizedText(from: "One\n\n\n\t\nTwo"),
      "One\nTwo"
    )
  }

  @Test("RSS entries retain the shared normalizer's block boundaries")
  func feedEntryUsesSharedNormalizer() {
    let entry = FeedEntry(title: "Fixture", bodyHTML: "<p>First paragraph.</p><p>Second paragraph.</p>")

    expectNoDifference(entry.normalizedText, "First paragraph.\nSecond paragraph.")
  }
}
