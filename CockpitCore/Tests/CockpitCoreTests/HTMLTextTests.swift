@testable import CockpitCore
import CustomDump
import Testing

struct HTMLTextTests {
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
