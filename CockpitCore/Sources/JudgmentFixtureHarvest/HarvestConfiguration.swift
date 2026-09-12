import Foundation
import JudgmentFixtureSupport

/// The confirmed harvest configuration `export` consumes. `discover` generates a candidate of
/// this exact shape from the seeds, so a confirmed allowlist never has to be hand-authored.
struct HarvestConfiguration: Codable {
  var rssSources: [RSSSource]
  var gmailSources: [GmailSource]
}

struct RSSSource: Codable {
  let fixture: String
  let stream: SourceStreamContext
}

struct GmailSource: Codable {
  let fromContains: String
  let stream: SourceStreamContext
}

/// The Stream/Interest context §2 names as judgment inputs, flattened for hand-editing. Carried
/// verbatim from a seed into the generated config so Jon confirms rather than retypes it.
struct SourceStreamContext: Codable {
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
