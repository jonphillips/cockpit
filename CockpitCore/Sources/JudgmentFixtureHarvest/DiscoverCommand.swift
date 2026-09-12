import Foundation

/// `discover` — the harvest preflight. From the editorial seeds, it discovers which Gmail `From`
/// addresses correspond to each publication using metadata only (no body is fetched or written),
/// prints the candidate mappings and counts for Jon to confirm, and writes a candidate harvest
/// config carrying each seed's Stream/Interest context. `export` then runs against the confirmed
/// config. Nothing here writes a message body, so the allowlist is confirmed before any body lands.
struct DiscoverCommand {
  let seedsURL: URL
  let outURL: URL
  let after: String
  let before: String
  let cap: Int

  init(arguments: [String]) throws {
    let values = try ArgumentValues(arguments: arguments)
    seedsURL = try values.fileURL(named: "--seeds")
    outURL = try values.fileURL(named: "--out")
    after = try values.value(named: "--after")
    before = try values.value(named: "--before")
    cap = Int(values.value(named: "--cap", default: "200")) ?? 200
  }

  func run() async throws {
    let seeds = try SeedFile.load(from: seedsURL)
    let client = GmailReadOnlyClient(accessToken: try requireAccessToken())
    var gmailSources: [GmailSource] = []
    print("Sender discovery (metadata only — no message bodies fetched):\n")
    for seed in seeds.gmailSeeds {
      let candidates = try await client.senderCandidates(
        matching: seed.searchQuery, after: after, before: before, cap: cap)
      report(seed: seed, candidates: candidates)
      if let top = candidates.first {
        gmailSources.append(GmailSource(fromContains: top.email, stream: seed.sourceContext))
      }
    }
    let config = HarvestConfiguration(
      rssSources: seeds.rssSeeds.map { RSSSource(fixture: $0.rssFixture!, stream: $0.sourceContext) },
      gmailSources: gmailSources)
    try OutputFile.write(JSONEncoder.fixture.encode(config), to: outURL)
    printSummary(config: config)
  }

  private func report(seed: StreamSeed, candidates: [SenderCandidate]) {
    print("▸ \(seed.name)")
    guard !candidates.isEmpty else {
      print("    (no messages matched in window — refine this seed's gmailQuery)\n")
      return
    }
    for candidate in candidates {
      print("    \(String(candidate.count).leftPadded(4))  \(candidate.email)   e.g. \(candidate.sampleFrom)")
    }
    print("")
  }

  private func printSummary(config: HarvestConfiguration) {
    print("""
      Wrote candidate config to \(outURL.path)
        \(config.rssSources.count) RSS source(s) from recorded fixtures
        \(config.gmailSources.count) Gmail source(s) — the highest-count sender per seed

      Confirm the allowlist before harvesting: add any additional senders shown above, remove any
      that are not editorial, then run `export` with the confirmed config. No body was fetched.
      """)
  }
}

private extension String {
  func leftPadded(_ width: Int) -> String {
    count >= width ? self : String(repeating: " ", count: width - count) + self
  }
}
