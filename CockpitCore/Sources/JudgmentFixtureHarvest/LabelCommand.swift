import Foundation
import JudgmentFixtureSupport

/// `label` — generates a local HTML labeling page that joins the frozen fixtures with the label file
/// so Jon can set surface/quiet/never + isSubstantivePrimary by clicking or keyboard, then save
/// labels.json back. The page embeds real mail text; it is written locally and is never published.
struct LabelCommand {
  let fixturesURL: URL
  let labelsURL: URL
  let outURL: URL

  init(arguments: [String]) throws {
    let values = try ArgumentValues(arguments: arguments)
    fixturesURL = try values.fileURL(named: "--fixtures")
    labelsURL = try values.fileURL(named: "--labels")
    outURL = try values.fileURL(named: "--out")
  }

  func run() throws {
    let fixtures = try JSONDecoder.fixture
      .decode(JudgmentFixtureExport.self, from: Data(contentsOf: fixturesURL)).fixtures
    let labels = try LabelStore.load(from: labelsURL)
    let payload = LabelerPayload(
      labels: labels,
      fixtures: Dictionary(fixtures.map { ($0.id.uuidString, FixtureDisplay(fixture: $0)) },
        uniquingKeysWith: { first, _ in first }))
    // Escape `</` so the embedded JSON cannot close the <script> block early.
    let json = String(decoding: try JSONEncoder.fixture.encode(payload), as: UTF8.self)
      .replacingOccurrences(of: "</", with: "<\\/")
    let html = try Self.template().replacingOccurrences(of: "__LABELER_DATA__", with: json)
    try OutputFile.write(Data(html.utf8), to: outURL)
    print("""
      Wrote \(outURL.path) — \(labels.count) fixtures.
      Open it in a browser, label each (S / Q / N + "substantive primary"), then Save labels.json
      over \(labelsURL.path). Progress autosaves in the browser. The page holds your mail — keep it local.
      """)
  }

  private static func template() throws -> String {
    guard let url = Bundle.module.url(forResource: "Labeler", withExtension: "html") else {
      throw HarvestError.resourceMissing("Labeler.html")
    }
    return try String(contentsOf: url, encoding: .utf8)
  }
}

private struct LabelerPayload: Encodable {
  let labels: [JudgmentFixtureLabel]
  let fixtures: [String: FixtureDisplay]
}

private struct FixtureDisplay: Encodable {
  let title: String
  let publisher: String
  let kind: String
  let publishedAt: Date?
  let text: String

  init(fixture: JudgmentFixture) {
    title = fixture.title
    publisher = fixture.publisher
    kind = fixture.kind
    publishedAt = fixture.publishedAt
    text = fixture.normalizedText
  }
}
