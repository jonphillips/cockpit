import Foundation
import LLMClientKit

/// The mechanical, PK-free half of judgment. Its API intentionally has no Personal Knowledge or
/// Current Context argument, making it impossible for an editorial preference to leak into the
/// primary-vs-accessory type decision.
enum JudgmentClassificationPrompt {
  static let system = """
  You are Cockpit's content classification pass. Produce only the structured response requested.
  Classify the material itself; do not make editorial relevance, ranking, or retention decisions.
  """

  static func make(candidates: [JudgmentCandidate]) throws -> String {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    let candidateJSON = String(decoding: try encoder.encode(candidates), as: UTF8.self)
    return """
    Prompt version: \(JudgmentEngine.typePromptVersion)

    For every candidate, classify whether it is substantive primary material: the Stream's own
    primary authored work (an original article, issue, episode, or report), rather than an
    accessory such as a roundup, housekeeping notice, promotion, or body-less teaser. This is a
    structural type property, not a measure of value, reader interest, or durable-worth.

    Also extract a concise factual summary and three to eight short lowercase subjects. Do not
    choose what the reader should see, rank candidates, or rely on any information beyond each
    candidate and its Stream context.

    Candidates:
    \(candidateJSON)

    Return exactly one classification object for every candidate ID. Preserve a supplied
    bodyCompleteness value. When it was unresolved, return full, truncated, or teaser as a fallback
    based only on the held text.
    """
  }

  static let schema: JSONValue = {
    let json = #"""
    {"type":"object","additionalProperties":false,"properties":{"classifications":{"type":"array","items":{"type":"object","additionalProperties":false,"properties":{"contentPieceID":{"type":"string"},"isSubstantivePrimary":{"type":"boolean"},"subjects":{"type":"array","items":{"type":"string"}},"summary":{"type":"string"},"bodyCompleteness":{"type":"string","enum":["full","truncated","teaser"]}},"required":["contentPieceID","isSubstantivePrimary","subjects","summary"]}}},"required":["classifications"]}
    """#
    return try! JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
  }()
}

/// The finite-package decision. It receives PK and the already-produced type metadata, but it
/// cannot revise primary-ness, subjects, or summary.
enum JudgmentEditorialPrompt {
  static let system = """
  You are Cockpit's editorial judgment pass. Produce only the structured response requested.
  Judgment proposes relevance, selection, ranking, rationale, and finds. It never writes Personal Knowledge,
  changes provider state, admits to Library, or hands off a Find.
  """

  static func make(
    candidates: [EditorialJudgmentCandidate], personalKnowledge: PersonalKnowledgeProjection,
    currentContext: String, targetSize: Int
  ) throws -> String {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    let candidateJSON = String(decoding: try encoder.encode(candidates), as: UTF8.self)
    return """
    Prompt version: \(JudgmentEngine.editorialPromptVersion)

    You are composing today's edition of a personal newspaper for one reader.

    Editorial posture:
      finite over comprehensive; the reader should finish it
      explicit stated intent constrains inferred relevance
      target approximately \(targetSize) admitted pieces

    What you know about the reader (explicitly taught, never inferred):
    \(personalKnowledge.text.isEmpty ? "(none)" : personalKnowledge.text)

    Current situation:
    \(currentContext.isEmpty ? "(none)" : currentContext)

    Streams, candidates, and their already-classified type metadata:
    \(candidateJSON)

    Rules:
      Essential Streams: admit all candidates already classified as substantive primary material,
      regardless of target size.
      Do not alter the supplied substantive-primary classification, subjects, summary, or body
      completeness. They are facts about the material, not editorial outputs.
      Stream handling overrides generic interest matching.
      Prefer omitting a weak piece to padding toward the target.
      Rationale is addressed to the reader: cite Stream posture, Interest Area, or explicit
      Personal Knowledge that matched, never hidden model scoring. When explicit Personal Knowledge
      drove admission or rank, choose exactly one Claim ID from the projection and return it as
      matchedPersonalKnowledgeClaimID. The rationale must name that claim in the reader's terms;
      otherwise return null for matchedPersonalKnowledgeClaimID.
      Return exactly one editorial judgment object for every candidate ID, including non-admitted
      pieces. Keep rationales under 40 words and finds empty when no concrete useful thing is present.
    """
  }

  static let schema: JSONValue = {
    let json = #"""
    {"type":"object","additionalProperties":false,"properties":{"judgments":{"type":"array","items":{"type":"object","additionalProperties":false,"properties":{"contentPieceID":{"type":"string"},"admit":{"type":"boolean"},"section":{"type":"string","enum":["essentials","forYou","interestArea","essentialBacklog"]},"rank":{"type":"integer"},"rationale":{"type":"string"},"matchedPersonalKnowledgeClaimID":{"type":["string","null"]},"finds":{"type":"array","items":{"type":"object","additionalProperties":false,"properties":{"kind":{"type":"string"},"name":{"type":"string"},"descriptor":{"type":"string"},"rationale":{"type":"string"},"sourceURL":{"type":["string","null"]},"hints":{"type":"object"}},"required":["kind","name","descriptor","rationale","sourceURL","hints"]}}},"required":["contentPieceID","admit","section","rank","rationale","matchedPersonalKnowledgeClaimID","finds"]}}},"required":["judgments"]}
    """#
    return try! JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
  }()
}

struct EditorialJudgmentCandidate: Codable, Sendable {
  let candidate: JudgmentCandidate
  let classification: EditorialClassification
}

struct EditorialClassification: Codable, Sendable {
  let isSubstantivePrimary: Bool
  let subjects: [String]
  let summary: String
  let bodyCompleteness: BodyCompleteness?
}

/// The frozen M3 prompt exists only for the paired M4 evaluation control. Production composition
/// never calls it; retaining the exact old shape lets JudgmentEval measure the split against the
/// same-session single-pass baseline rather than against a noisy historical number.
enum JudgmentSinglePassControlPrompt {
  static let system = """
  You are Cockpit's editorial judgment pass. Produce only the structured response requested.
  Judgment proposes relevance, summaries, subjects, substantive-primary classification, and finds.
  It never writes Personal Knowledge, changes provider state, admits to Library, or hands off a Find.
  """

  static func make(
    candidates: [JudgmentCandidate], personalKnowledge: PersonalKnowledgeProjection,
    currentContext: String, targetSize: Int
  ) throws -> String {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    let candidateJSON = String(decoding: try encoder.encode(candidates), as: UTF8.self)
    return """
    Prompt version: \(JudgmentEngine.singlePassControlPromptVersion)

    You are composing today's edition of a personal newspaper for one reader.

    Editorial posture:
      finite over comprehensive; the reader should finish it
      explicit stated intent constrains inferred relevance
      target approximately \(targetSize) admitted pieces

    What you know about the reader (explicitly taught, never inferred):
    \(personalKnowledge.text.isEmpty ? "(none)" : personalKnowledge.text)

    Current situation:
    \(currentContext.isEmpty ? "(none)" : currentContext)

    Streams and why he follows them, plus candidates:
    \(candidateJSON)

    Rules:
      Essential Streams: admit all substantive primary material regardless of target size.
      Judge substantive primary versus accessory honestly.
      Stream handling overrides generic interest matching.
      Prefer omitting a weak piece to padding toward the target.
      Rationale is addressed to the reader: cite Stream posture, Interest Area, or explicit
      Personal Knowledge that matched, never hidden model scoring. When explicit Personal Knowledge
      drove admission or rank, choose exactly one Claim ID from the projection and return it as
      matchedPersonalKnowledgeClaimID. The rationale must name that claim in the reader's terms;
      otherwise return null for matchedPersonalKnowledgeClaimID.
      Return exactly one judgment object for every candidate ID, including non-admitted pieces.
      Every judgment must include isSubstantivePrimary, subjects, and summary even when admit is false.
      bodyCompleteness is supplied when deterministic ingest evidence was unavailable; otherwise
      preserve the supplied value. Use truncated for a real body cut off by a paywall and teaser
      when only an introduction or no body is held.
      Subjects are three to eight short lowercase topical strings. Keep summaries under 70 words,
      rationales under 40 words, and finds empty when no concrete useful thing is present.
    """
  }

  static let schema: JSONValue = {
    let json = #"""
    {"type":"object","additionalProperties":false,"properties":{"judgments":{"type":"array","items":{"type":"object","additionalProperties":false,"properties":{"contentPieceID":{"type":"string"},"admit":{"type":"boolean"},"isSubstantivePrimary":{"type":"boolean"},"section":{"type":"string","enum":["essentials","forYou","interestArea","essentialBacklog"]},"rank":{"type":"integer"},"rationale":{"type":"string"},"matchedPersonalKnowledgeClaimID":{"type":["string","null"]},"subjects":{"type":"array","items":{"type":"string"}},"summary":{"type":"string"},"bodyCompleteness":{"type":"string","enum":["full","truncated","teaser"]},"finds":{"type":"array","items":{"type":"object","additionalProperties":false,"properties":{"kind":{"type":"string"},"name":{"type":"string"},"descriptor":{"type":"string"},"rationale":{"type":"string"},"sourceURL":{"type":["string","null"]},"hints":{"type":"object"}},"required":["kind","name","descriptor","rationale","sourceURL","hints"]}}},"required":["contentPieceID","admit","isSubstantivePrimary","section","rank","rationale","matchedPersonalKnowledgeClaimID","subjects","summary","finds"]}}},"required":["judgments"]}
    """#
    return try! JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
  }()
}
