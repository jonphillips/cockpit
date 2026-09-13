import Foundation
import LLMClientKit

/// Decodes the model's batch response into one outcome per expected candidate,
/// **per piece** (JUDGMENT-CONTRACT §3): a single malformed, missing, duplicated,
/// or extra judgment fails only *that* candidate to `admit: false` with a recorded
/// error — it never drops a piece silently and never nulls the rest of the batch.
///
/// Only a total top-level parse failure (e.g. a response truncated mid-JSON, or not
/// JSON at all) is unrecoverable and throws; the engine turns that into a whole-batch
/// fail-closed run. Composition-sized batching (see `JudgmentEval`) keeps responses
/// within the output budget so that whole-batch case stays rare.
enum JudgmentResponseDecoder {
  static func decode(_ text: String, expectedCandidateIDs: [UUID]) throws -> [JudgmentOutcome] {
    // Parse the envelope leniently: each element stays a JSONValue so one bad object
    // cannot fail the array. A missing/!object `judgments` is a total failure and throws.
    let envelope = try JSONDecoder().decode(RawEnvelope.self, from: Data(text.utf8))

    var decodedByID: [UUID: DecodedJudgment] = [:]
    var duplicated: Set<UUID> = []
    var shapeFailedIDs: Set<UUID> = []
    for element in envelope.judgments {
      let fullyDecoded = (try? JSONEncoder().encode(element))
        .flatMap { try? JSONDecoder().decode(DecodedJudgment.self, from: $0) }
      if let fullyDecoded {
        if decodedByID.updateValue(fullyDecoded, forKey: fullyDecoded.contentPieceID) != nil {
          duplicated.insert(fullyDecoded.contentPieceID)
        }
      } else if let id = element.string("contentPieceID").flatMap(UUID.init(uuidString:)) {
        // The object carried a usable id but did not match the required shape.
        shapeFailedIDs.insert(id)
      }
      // An element with neither a usable id nor a full decode is unattributable to any
      // candidate; it is ignored here and surfaces below as a "no judgment" for whichever
      // expected candidate it was meant to be.
    }

    return expectedCandidateIDs.map { id in
      if duplicated.contains(id) {
        return .failed(
          contentPieceID: id,
          error: "The model returned more than one judgment for this candidate.")
      }
      if let decoded = decodedByID[id] {
        return JudgmentOutcome(decoded)
      }
      if shapeFailedIDs.contains(id) {
        return .failed(
          contentPieceID: id,
          error: "The model's judgment for this candidate did not match the required shape.")
      }
      return .failed(
        contentPieceID: id, error: "The model returned no judgment for this candidate.")
    }
  }

  static func errorMessage(for error: Error) -> String {
    if let error = error as? LocalizedError, let description = error.errorDescription {
      return description
    }
    return "Judgment response could not be decoded: \(error.localizedDescription)"
  }
}

private struct RawEnvelope: Decodable {
  let judgments: [JSONValue]
}

private struct DecodedJudgment: Decodable {
  let contentPieceID: UUID
  let admit: Bool
  let isSubstantivePrimary: Bool
  let section: JudgmentSection
  let rank: Int
  let rationale: String
  let subjects: [String]
  let summary: String
  let finds: [JudgmentFind]
}

private extension JudgmentOutcome {
  init(_ decoded: DecodedJudgment) {
    self.init(
      contentPieceID: decoded.contentPieceID, admit: decoded.admit,
      isSubstantivePrimary: decoded.isSubstantivePrimary, section: decoded.section,
      rank: decoded.rank, rationale: decoded.rationale, subjects: decoded.subjects,
      summary: decoded.summary, finds: decoded.finds
    )
  }
}
