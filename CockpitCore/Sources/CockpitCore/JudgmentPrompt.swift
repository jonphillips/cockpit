import Foundation
import LLMClientKit

enum JudgmentPrompt {
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
    Prompt version: \(JudgmentEngine.promptVersion)

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
      Personal Knowledge that matched, never hidden model scoring.
      Return exactly one judgment object for every candidate ID, including non-admitted pieces.
      Every judgment must include isSubstantivePrimary, subjects, and summary even when admit is false.
      Subjects are three to eight short lowercase topical strings. Keep summaries under 70 words,
      rationales under 40 words, and finds empty when no concrete useful thing is present.
    """
  }

  static let schema: JSONValue = {
    let json = #"""
    {"type":"object","additionalProperties":false,"properties":{"judgments":{"type":"array","items":{"type":"object","additionalProperties":false,"properties":{"contentPieceID":{"type":"string"},"admit":{"type":"boolean"},"isSubstantivePrimary":{"type":"boolean"},"section":{"type":"string","enum":["essentials","forYou","interestArea","essentialBacklog"]},"rank":{"type":"integer"},"rationale":{"type":"string"},"subjects":{"type":"array","items":{"type":"string"}},"summary":{"type":"string"},"finds":{"type":"array","items":{"type":"object","additionalProperties":false,"properties":{"kind":{"type":"string"},"name":{"type":"string"},"descriptor":{"type":"string"},"rationale":{"type":"string"},"sourceURL":{"type":["string","null"]},"hints":{"type":"object"}},"required":["kind","name","descriptor","rationale","sourceURL","hints"]}}},"required":["contentPieceID","admit","isSubstantivePrimary","section","rank","rationale","subjects","summary","finds"]}}},"required":["judgments"]}
    """#
    return try! JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
  }()
}
