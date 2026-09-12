import CockpitCore
import Foundation
import JudgmentFixtureSupport

/// `export` — the body-bearing harvest. Reads a confirmed config, pulls the allowlisted messages
/// plus the recorded RSS backfill, and freezes fixtures + labels. Preserves existing labels by id.
struct ExportCommand {
  let configURL: URL
  let fixturesURL: URL
  let labelsURL: URL
  let after: String
  let before: String

  init(arguments: [String]) throws {
    let values = try ArgumentValues(arguments: arguments)
    configURL = try values.fileURL(named: "--config")
    fixturesURL = try values.fileURL(named: "--fixtures")
    labelsURL = try values.fileURL(named: "--labels")
    after = try values.value(named: "--after")
    before = try values.value(named: "--before")
  }

  func run() async throws {
    let data = try Data(contentsOf: configURL)
    let configuration = try JSONDecoder.fixture.decode(HarvestConfiguration.self, from: data)
    let exporter = FixtureExporter(configuration: configuration)
    let harvested = try await exporter.export(after: after, before: before)
    let oldLabels = try LabelStore.load(from: labelsURL)
    let labels = LabelStore.merging(oldLabels, with: harvested)
    try OutputFile.write(JSONEncoder.fixture.encode(JudgmentFixtureExport(fixtures: harvested.fixtures)), to: fixturesURL)
    try OutputFile.write(JSONEncoder.fixture.encode(JudgmentLabelExport(labels: labels)), to: labelsURL)
    print("Exported \(harvested.fixtures.count) judgment fixtures and preserved \(labels.count) labels.")
  }
}

struct FixtureExporter {
  let configuration: HarvestConfiguration

  func export(after: String, before: String) async throws -> HarvestedFixtures {
    var rows = try configuration.rssSources.flatMap(exportRSS)
    if !configuration.gmailSources.isEmpty {
      rows += try await exportGmail(after: after, before: before)
    }
    let unique = Dictionary(rows.map { ($0.fixture.id, $0) }, uniquingKeysWith: { first, _ in first })
      .values
      .sorted { $0.fixture.id.uuidString < $1.fixture.id.uuidString }
    return HarvestedFixtures(rows: unique)
  }

  private func exportGmail(after: String, before: String) async throws -> [HarvestedFixture] {
    let client = GmailReadOnlyClient(accessToken: try requireAccessToken())
    let messages = try await client.messages(
      after: after, before: before, fromContains: configuration.gmailSources.map(\.fromContains))
    return messages.compactMap { message in
      guard let source = matchingGmailSource(for: message),
        let fixture = fixture(from: message, source: source)
      else { return nil }
      return HarvestedFixture(
        fixture: fixture, prior: message.dispositionPrior,
        gmailDisposition: message.disposition, gmailReadState: message.readState)
    }
  }

  private func exportRSS(_ source: RSSSource) throws -> [HarvestedFixture] {
    let feed = try FeedParser.parse(Data(contentsOf: URL(fileURLWithPath: source.fixture)))
    return feed.entries.compactMap { entry in
      guard let normalizedText = entry.normalizedText else { return nil }
      let identity = ContentIdentity.derive(for: ContentIdentityInput(
        canonicalURL: entry.canonicalURL, providerStableID: entry.providerID,
        feedGUID: entry.guid, feedGUIDIsPermanent: entry.guidIsPermanent,
        title: entry.title, publisher: source.stream.name, publishedAt: entry.publishedAt))
      return HarvestedFixture(fixture: JudgmentFixture(
        id: identity, kind: contentKind(for: entry.canonicalURL), title: entry.title,
        creator: entry.creator, publisher: source.stream.name, publishedAt: entry.publishedAt,
        normalizedText: String(normalizedText.prefix(1_500)),
        stream: source.stream.streamContext, interestArea: source.stream.interestAreaContext),
        prior: .uncertain)
    }
  }

  private func matchingGmailSource(for message: GmailMessage) -> GmailSource? {
    let from = message.header(named: "From")?.lowercased() ?? ""
    return configuration.gmailSources.first { from.contains($0.fromContains.lowercased()) }
  }

  private func fixture(from message: GmailMessage, source: GmailSource) -> JudgmentFixture? {
    guard let messageID = message.header(named: "Message-ID"),
      let title = message.header(named: "Subject")?.trimmingCharacters(in: .whitespacesAndNewlines),
      !title.isEmpty, let text = message.normalizedText
    else { return nil }
    let identity = ContentIdentity.derive(for: ContentIdentityInput(
      providerStableID: "gmail:\(messageID)", title: title, publisher: source.stream.name,
      publishedAt: message.date))
    return JudgmentFixture(
      id: identity, kind: "newsletter", title: title, creator: message.header(named: "From"),
      publisher: source.stream.name, publishedAt: message.date,
      normalizedText: String(text.prefix(1_500)),
      stream: source.stream.streamContext, interestArea: source.stream.interestAreaContext)
  }
}

private func contentKind(for url: URL?) -> String {
  let host = url?.host?.lowercased() ?? ""
  return host.contains("youtube.com") || host == "youtu.be" ? "video" : "article"
}

struct HarvestedFixture {
  let fixture: JudgmentFixture
  let prior: DispositionPrior
  var gmailDisposition: GmailDisposition? = nil
  var gmailReadState: GmailReadState? = nil
}

struct HarvestedFixtures {
  let rows: [HarvestedFixture]
  var fixtures: [JudgmentFixture] { rows.map(\.fixture) }
}
