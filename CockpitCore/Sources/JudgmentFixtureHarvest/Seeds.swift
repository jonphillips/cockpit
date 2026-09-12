import Foundation

/// A machine-readable projection of `docs/stream-handling-seeds.md` — the editorial sources Jon
/// already identified from his real corpus, with their handling intent. `discover` reads these so
/// the harvest is configured from existing seed context rather than reconstructed by hand.
///
/// A seed with `rssFixture` is feed-backed and taken from the recorded fixture; a seed with
/// `gmailQuery` (defaulting to `name`) is discovered from Gmail. A Substack that arrives by both is
/// deliberately marked feed-backed only, so the same post is not harvested twice under two ids.
struct StreamSeed: Decodable {
  let name: String
  let handling: String
  let handlingGuidance: String
  let isEssential: Bool
  let interestAreaName: String
  let interestAreaGuidance: String
  let rssFixture: String?
  let gmailQuery: String?

  enum CodingKeys: String, CodingKey {
    case name, handling, handlingGuidance, isEssential
    case interestAreaName, interestAreaGuidance, rssFixture, gmailQuery
  }

  // Synthesized `Decodable` ignores default values, so decode optionals explicitly: only `name`
  // and `handlingGuidance` are required in the seeds file; everything else has a sensible default.
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decode(String.self, forKey: .name)
    handlingGuidance = try container.decode(String.self, forKey: .handlingGuidance)
    handling = try container.decodeIfPresent(String.self, forKey: .handling) ?? "following"
    isEssential = try container.decodeIfPresent(Bool.self, forKey: .isEssential) ?? false
    interestAreaName = try container.decodeIfPresent(String.self, forKey: .interestAreaName) ?? ""
    interestAreaGuidance = try container.decodeIfPresent(String.self, forKey: .interestAreaGuidance) ?? ""
    rssFixture = try container.decodeIfPresent(String.self, forKey: .rssFixture)
    gmailQuery = try container.decodeIfPresent(String.self, forKey: .gmailQuery)
  }

  var searchQuery: String { gmailQuery ?? "\"\(name)\"" }

  var sourceContext: SourceStreamContext {
    SourceStreamContext(
      name: name,
      handling: handling,
      handlingGuidance: handlingGuidance,
      isEssential: isEssential,
      interestAreaName: interestAreaName,
      interestAreaGuidance: interestAreaGuidance
    )
  }
}

struct SeedFile: Decodable {
  let seeds: [StreamSeed]

  static func load(from url: URL) throws -> SeedFile {
    try JSONDecoder.fixture.decode(SeedFile.self, from: Data(contentsOf: url))
  }

  var rssSeeds: [StreamSeed] { seeds.filter { $0.rssFixture != nil } }
  var gmailSeeds: [StreamSeed] { seeds.filter { $0.rssFixture == nil } }
}
