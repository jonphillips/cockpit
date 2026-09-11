import CockpitCore
import Foundation
import JudgmentFixtureSupport

@main
struct JudgmentFixtureHarvest {
  static func main() async {
    do {
      let command = try Command(arguments: Array(CommandLine.arguments.dropFirst()))
      try await command.run()
    } catch {
      fputs("error: \(error.localizedDescription)\n", stderr)
      exit(1)
    }
  }
}

private struct Command {
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
    try JSONEncoder.fixture.encode(JudgmentFixtureExport(fixtures: harvested.fixtures)).write(to: fixturesURL)
    try JSONEncoder.fixture.encode(JudgmentLabelExport(labels: labels)).write(to: labelsURL)
    print("Exported \(harvested.fixtures.count) judgment fixtures and preserved \(labels.count) labels.")
  }
}

private struct ArgumentValues {
  let values: [String: String]

  init(arguments: [String]) throws {
    guard arguments.count.isMultiple(of: 2) else { throw HarvestError.usage }
    var values: [String: String] = [:]
    for index in stride(from: 0, to: arguments.count, by: 2) {
      let key = arguments[index]
      guard key.hasPrefix("--"), values[key] == nil else { throw HarvestError.usage }
      values[key] = arguments[index + 1]
    }
    self.values = values
  }

  func value(named name: String) throws -> String {
    guard let value = values[name], !value.isEmpty else { throw HarvestError.usage }
    return value
  }

  func fileURL(named name: String) throws -> URL {
    URL(fileURLWithPath: try value(named: name))
  }
}

enum HarvestError: LocalizedError {
  case usage
  case missingAccessToken
  case httpStatus(Int, String)
  case invalidMessage

  var errorDescription: String? {
    switch self {
    case .usage:
      return "usage: swift run JudgmentFixtureHarvest --config path --fixtures path --labels path --after YYYY-MM-DD --before YYYY-MM-DD"
    case .missingAccessToken:
      return "GMAIL_ACCESS_TOKEN is required when the configuration includes Gmail sources."
    case let .httpStatus(status, body):
      return "Gmail request failed (HTTP \(status)): \(body)"
    case .invalidMessage:
      return "Gmail returned a message without editorial text or a stable RFC 822 Message-ID."
    }
  }
}

private struct HarvestConfiguration: Decodable {
  let rssSources: [RSSSource]
  let gmailSources: [GmailSource]

  enum CodingKeys: String, CodingKey {
    case rssSources
    case gmailSources
  }
}

private struct RSSSource: Decodable {
  let fixture: String
  let stream: SourceStreamContext
}

private struct GmailSource: Decodable {
  let fromContains: String
  let stream: SourceStreamContext
}

private struct SourceStreamContext: Decodable {
  let name: String
  let handling: String
  let handlingGuidance: String
  let isEssential: Bool
  let interestAreaName: String
  let interestAreaGuidance: String

  var streamContext: StreamContext {
    StreamContext(
      name: name,
      handling: handling,
      handlingGuidance: handlingGuidance,
      isEssential: isEssential
    )
  }

  var interestAreaContext: InterestAreaContext {
    InterestAreaContext(name: interestAreaName, guidance: interestAreaGuidance)
  }
}

private struct FixtureExporter {
  let configuration: HarvestConfiguration

  func export(after: String, before: String) async throws -> HarvestedFixtures {
    var rows = try configuration.rssSources.flatMap(exportRSS)
    if !configuration.gmailSources.isEmpty {
      let token = ProcessInfo.processInfo.environment["GMAIL_ACCESS_TOKEN"]
      guard let token, !token.isEmpty else { throw HarvestError.missingAccessToken }
      let client = GmailReadOnlyClient(accessToken: token)
      let messages = try await client.messages(
        after: after,
        before: before,
        fromContains: configuration.gmailSources.map(\.fromContains)
      )
      rows += try messages.compactMap { message in
        guard let source = matchingGmailSource(for: message) else { return nil }
        guard let fixture = try fixture(from: message, source: source) else { return nil }
        return HarvestedFixture(
          fixture: fixture,
          prior: message.dispositionPrior,
          gmailDisposition: message.disposition,
          gmailReadState: message.readState
        )
      }
    }
    let unique = Dictionary(rows.map { ($0.fixture.id, $0) }, uniquingKeysWith: first).values
      .sorted { $0.fixture.id.uuidString < $1.fixture.id.uuidString }
    return HarvestedFixtures(rows: unique)
  }

  private func exportRSS(_ source: RSSSource) throws -> [HarvestedFixture] {
    let feed = try FeedParser.parse(Data(contentsOf: URL(fileURLWithPath: source.fixture)))
    return feed.entries.compactMap { entry in
      guard let normalizedText = entry.normalizedText else { return nil }
      let identity = ContentIdentity.derive(for: ContentIdentityInput(
        canonicalURL: entry.canonicalURL,
        providerStableID: entry.providerID,
        feedGUID: entry.guid,
        feedGUIDIsPermanent: entry.guidIsPermanent,
        title: entry.title,
        publisher: source.stream.name,
        publishedAt: entry.publishedAt
      ))
      return HarvestedFixture(fixture: JudgmentFixture(
        id: identity,
        kind: contentKind(for: entry.canonicalURL),
        title: entry.title,
        creator: entry.creator,
        publisher: source.stream.name,
        publishedAt: entry.publishedAt,
        normalizedText: String(normalizedText.prefix(1_500)),
        stream: source.stream.streamContext,
        interestArea: source.stream.interestAreaContext
      ), prior: .uncertain)
    }
  }

  private func matchingGmailSource(for message: GmailMessage) -> GmailSource? {
    let from = message.header(named: "From")?.lowercased() ?? ""
    return configuration.gmailSources.first { from.contains($0.fromContains.lowercased()) }
  }

  private func fixture(from message: GmailMessage, source: GmailSource) throws -> JudgmentFixture? {
    guard let messageID = message.header(named: "Message-ID"),
      let title = message.header(named: "Subject")?.trimmingCharacters(in: .whitespacesAndNewlines),
      !title.isEmpty,
      let text = message.normalizedText
    else { return nil }
    let identity = ContentIdentity.derive(for: ContentIdentityInput(
      providerStableID: "gmail:\(messageID)", title: title, publisher: source.stream.name,
      publishedAt: message.date
    ))
    return JudgmentFixture(
      id: identity,
      kind: "newsletter",
      title: title,
      creator: message.header(named: "From"),
      publisher: source.stream.name,
      publishedAt: message.date,
      normalizedText: String(text.prefix(1_500)),
      stream: source.stream.streamContext,
      interestArea: source.stream.interestAreaContext
    )
  }
}

private func first<T>(_ first: T, _: T) -> T { first }

private func contentKind(for url: URL?) -> String {
  let host = url?.host?.lowercased() ?? ""
  return host.contains("youtube.com") || host == "youtu.be" ? "video" : "article"
}

struct HarvestedFixture {
  let fixture: JudgmentFixture
  let prior: DispositionPrior
  let gmailDisposition: GmailDisposition?
  let gmailReadState: GmailReadState?

  init(
    fixture: JudgmentFixture,
    prior: DispositionPrior,
    gmailDisposition: GmailDisposition? = nil,
    gmailReadState: GmailReadState? = nil
  ) {
    self.fixture = fixture
    self.prior = prior
    self.gmailDisposition = gmailDisposition
    self.gmailReadState = gmailReadState
  }
}

struct HarvestedFixtures {
  let rows: [HarvestedFixture]

  var fixtures: [JudgmentFixture] { rows.map(\.fixture) }
}
