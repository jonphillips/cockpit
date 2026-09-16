import Foundation
import LLMClientKit

/// Strict, per-piece decoding shared by both judgment passes. A malformed, missing, duplicated,
/// or extra object fails only its candidate closed. A truncated envelope — the model reaching its
/// output cap mid-array — is salvaged for its complete leading objects so it degrades to a per-piece
/// partial omission (which the engine re-requests) instead of failing every piece; only a response
/// with nothing recoverable fails the whole pass.
enum JudgmentResponseDecoder {
  static func decodeSinglePassControl(
    _ text: String,
    expectedCandidateIDs: [UUID],
    allowedPersonalKnowledgeClaimIDs: Set<PersonalKnowledgeClaim.ID>
  ) throws -> [JudgmentOutcome] {
    let elements = try JudgmentEnvelope.elements(
      text, strict: { try JSONDecoder().decode(RawEditorialEnvelope.self, from: Data(text.utf8)).judgments },
      salvageKeys: ["judgments"])
    return decode(
      elements, expectedCandidateIDs: expectedCandidateIDs,
      decode: { element in
        let decoded = try JSONDecoder().decode(
          DecodedSinglePassControlJudgment.self, from: JSONEncoder().encode(element))
        guard decoded.matchedPersonalKnowledgeClaimID == nil
          || allowedPersonalKnowledgeClaimIDs.contains(decoded.matchedPersonalKnowledgeClaimID!)
        else { throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unprojected claim")) }
        return JudgmentOutcome(decoded)
      },
      id: { $0.contentPieceID },
      failed: { .failed(contentPieceID: $0, error: $1) })
  }

  static func decodeEditorial(
    _ text: String,
    expectedCandidateIDs: [UUID],
    allowedPersonalKnowledgeClaimIDs: Set<PersonalKnowledgeClaim.ID>
  ) throws -> [EditorialJudgment] {
    let elements = try JudgmentEnvelope.elements(
      text, strict: { try JSONDecoder().decode(RawEditorialEnvelope.self, from: Data(text.utf8)).judgments },
      salvageKeys: ["judgments"])
    return decode(
      elements, expectedCandidateIDs: expectedCandidateIDs,
      decode: { element in
        let decoded = try JSONDecoder().decode(
          DecodedEditorialJudgment.self, from: JSONEncoder().encode(element))
        guard decoded.matchedPersonalKnowledgeClaimID == nil
          || allowedPersonalKnowledgeClaimIDs.contains(decoded.matchedPersonalKnowledgeClaimID!)
        else { throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unprojected claim")) }
        return EditorialJudgment(decoded)
      },
      id: { $0.contentPieceID },
      failed: { .failed(contentPieceID: $0, error: $1) })
  }

  static func decodeClassification(
    _ text: String, expectedCandidateIDs: [UUID]
  ) throws -> [JudgmentClassification] {
    let elements = try JudgmentEnvelope.elements(
      text, strict: { try JSONDecoder().decode(RawClassificationEnvelope.self, from: Data(text.utf8)).classifications },
      salvageKeys: ["classifications", "judgments"])
    return decode(
      elements, expectedCandidateIDs: expectedCandidateIDs,
      decode: { element in
        JudgmentClassification(try JSONDecoder().decode(
          DecodedClassification.self, from: JSONEncoder().encode(element)))
      },
      id: { $0.contentPieceID },
      failed: { .failed(contentPieceID: $0, error: $1) })
  }

  static func errorMessage(for error: Error) -> String {
    if let error = error as? LocalizedError, let description = error.errorDescription {
      return description
    }
    return "Judgment response could not be decoded: \(error.localizedDescription)"
  }

  private static func decode<Output>(
    _ elements: [JSONValue], expectedCandidateIDs: [UUID],
    decode decodeElement: (JSONValue) throws -> Output,
    id: (Output) -> UUID,
    failed: (UUID, String) -> Output
  ) -> [Output] {
    var decodedByID: [UUID: Output] = [:]
    var duplicated: Set<UUID> = []
    var shapeFailedIDs: Set<UUID> = []

    for element in elements {
      do {
        let decoded = try decodeElement(element)
        let candidateID = id(decoded)
        if decodedByID.updateValue(decoded, forKey: candidateID) != nil {
          duplicated.insert(candidateID)
        }
      } catch {
        if let candidateID = element.string("contentPieceID").flatMap(UUID.init(uuidString:)) {
          shapeFailedIDs.insert(candidateID)
        }
      }
    }

    return expectedCandidateIDs.map { candidateID in
      if duplicated.contains(candidateID) {
        return failed(candidateID, "The model returned more than one judgment for this candidate.")
      }
      if let decoded = decodedByID[candidateID] { return decoded }
      if shapeFailedIDs.contains(candidateID) {
        return failed(candidateID, "The model's judgment for this candidate did not match the required shape.")
      }
      return failed(candidateID, "The model returned no judgment for this candidate.")
    }
  }
}

struct EditorialJudgment: Equatable, Sendable, Identifiable {
  let contentPieceID: UUID
  let admit: Bool
  let section: JudgmentSection?
  let rank: Int?
  let rationale: String?
  let matchedPersonalKnowledgeClaimID: PersonalKnowledgeClaim.ID?
  let finds: [JudgmentFind]?
  let errorDescription: String?

  var id: UUID { contentPieceID }

  static func failed(contentPieceID: UUID, error: String) -> Self {
    .init(
      contentPieceID: contentPieceID, admit: false, section: nil, rank: nil, rationale: nil,
      matchedPersonalKnowledgeClaimID: nil, finds: nil, errorDescription: error)
  }
}

private struct RawEditorialEnvelope: Decodable {
  let judgments: [JSONValue]
}

private struct RawClassificationEnvelope: Decodable {
  let classifications: [JSONValue]

  private enum CodingKeys: String, CodingKey { case classifications, judgments }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // Historic deterministic fixtures emitted the former one-pass envelope. Accept it here so
    // their tests continue to exercise the same strict per-piece behavior; live requests use the
    // `classifications` schema exclusively.
    classifications = try container.decodeIfPresent([JSONValue].self, forKey: .classifications)
      ?? container.decode([JSONValue].self, forKey: .judgments)
  }
}

private struct DecodedEditorialJudgment: Decodable {
  let contentPieceID: UUID
  let admit: Bool
  let section: JudgmentSection
  let rank: Int
  let rationale: String
  let matchedPersonalKnowledgeClaimID: PersonalKnowledgeClaim.ID?
  let finds: [JudgmentFind]
}

private struct DecodedSinglePassControlJudgment: Decodable {
  let contentPieceID: UUID
  let admit: Bool
  let isSubstantivePrimary: Bool
  let section: JudgmentSection
  let rank: Int
  let rationale: String
  let matchedPersonalKnowledgeClaimID: PersonalKnowledgeClaim.ID?
  let subjects: [String]
  let summary: String
  let bodyCompleteness: BodyCompleteness?
  let finds: [JudgmentFind]
}

private extension JudgmentOutcome {
  init(_ decoded: DecodedSinglePassControlJudgment) {
    self.init(
      contentPieceID: decoded.contentPieceID, admit: decoded.admit,
      isSubstantivePrimary: decoded.isSubstantivePrimary, section: decoded.section,
      rank: decoded.rank, rationale: decoded.rationale,
      matchedPersonalKnowledgeClaimID: decoded.matchedPersonalKnowledgeClaimID,
      subjects: decoded.subjects, summary: decoded.summary,
      bodyCompleteness: decoded.bodyCompleteness, finds: decoded.finds)
  }
}

private extension EditorialJudgment {
  init(_ decoded: DecodedEditorialJudgment) {
    self.init(
      contentPieceID: decoded.contentPieceID, admit: decoded.admit, section: decoded.section,
      rank: decoded.rank, rationale: decoded.rationale,
      matchedPersonalKnowledgeClaimID: decoded.matchedPersonalKnowledgeClaimID,
      finds: decoded.finds, errorDescription: nil)
  }
}

private struct DecodedClassification: Decodable {
  let contentPieceID: UUID
  let isSubstantivePrimary: Bool
  let subjects: [String]
  let summary: String
  let bodyCompleteness: BodyCompleteness?
}

private extension JudgmentClassification {
  init(_ decoded: DecodedClassification) {
    self.init(
      contentPieceID: decoded.contentPieceID,
      isSubstantivePrimary: decoded.isSubstantivePrimary,
      subjects: decoded.subjects,
      summary: decoded.summary,
      bodyCompleteness: decoded.bodyCompleteness)
  }
}
