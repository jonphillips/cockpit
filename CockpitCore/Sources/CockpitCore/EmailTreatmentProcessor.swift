import Foundation
import LLMClientKit
import SQLiteData

/// Summarizes an offer and proposes one Find from its own body. Grab-bag issues remain whole and
/// readable without model processing.
public struct EmailTreatmentProcessor: Sendable {
  private let modelClient: any ModelClient

  public init(modelClient: any ModelClient = JudgmentModel.makeClient()) {
    self.modelClient = modelClient
  }

  /// Model failures leave the message visible with S7's plain treatment row. A treatment may add
  /// detail, never decide whether a curated item appears.
  @discardableResult
  public func process(
    emailContentPieceIDs: some Sequence<ContentPiece.ID>, in database: any DatabaseWriter
  ) async throws -> [EmailTreatmentDetails] {
    let ids = Array(Set(emailContentPieceIDs)).sorted { $0.uuidString < $1.uuidString }
    let candidates = try await database.read { db in
      try ids.compactMap { id in try candidate(for: id, in: db) }
    }
    var outputs: [EmailTreatmentOutput] = []
    for candidate in candidates {
      try Task.checkCancellation()
      if let output = try? await extract(candidate) {
        outputs.append(output)
      }
    }
    guard !outputs.isEmpty else { return [] }
    let persistedOutputs = outputs
    return try await database.write { db in
      try persistedOutputs.map { output in
        let details = try persist(output, in: db)
        if let find = output.find {
          try PendingFindOperations.persist([find], for: output.contentPieceID, in: db)
        }
        return details
      }
    }
  }

  private func candidate(for id: ContentPiece.ID, in db: Database) throws -> EmailTreatmentCandidate? {
    guard let piece = try ContentPiece.find(id).fetchOne(db),
      piece.kind == .email,
      let treatment = extractionTreatment(
        role: try CurationRouting.resolution(for: id, in: db).role,
        treatment: piece.emailTreatment),
      try EmailTreatmentDetails.find(id).fetchOne(db)?.offerSummary == nil,
      let artifact = try (Artifact
        .where { $0.contentPieceID.eq(id) && $0.transport.eq(StreamTransport.gmail) }
        .order { $0.acquiredAt.desc() }
        .fetchOne(db))
    else { return nil }

    let text = try NormalizedTextOperations.text(for: id, in: db)
      ?? artifact.rawSourceText
      ?? piece.summary
    guard let text = text?.trimmedNonEmpty else { return nil }
    return EmailTreatmentCandidate(
      id: piece.id, treatment: treatment, title: piece.title, publisher: piece.publisher,
      text: String(text.prefix(12_000)))
  }

  private func extractionTreatment(
    role: ContentRole?, treatment: EmailTreatment?
  ) -> EmailTreatment? {
    switch role {
    case .grabBag: nil
    case .offers: .offer
    default: treatment == .offer ? .offer : nil
    }
  }

  private func extract(_ candidate: EmailTreatmentCandidate) async throws -> EmailTreatmentOutput {
    let response = try await modelClient.completeStreaming(
      ModelRequest(
        tier: .onDevice, system: EmailTreatmentPrompt.system,
        prompt: try EmailTreatmentPrompt.make(candidate: candidate), maxTokens: 500,
        responseFormat: .jsonSchema(
          name: "cockpit_email_treatment", schema: EmailTreatmentPrompt.schema(for: candidate.treatment))))
    return try EmailTreatmentResponseDecoder.decode(
      response.text, candidate: candidate)
  }

  private func persist(_ output: EmailTreatmentOutput, in db: Database) throws -> EmailTreatmentDetails {
    let details = EmailTreatmentDetails(
      contentPieceID: output.contentPieceID, offerSummary: output.summary)
    try EmailTreatmentDetails.upsert { EmailTreatmentDetails.Draft(details) }.execute(db)
    return details
  }
}

private struct EmailTreatmentCandidate: Codable, Sendable {
  let id: ContentPiece.ID
  let treatment: EmailTreatment
  let title: String
  let publisher: String
  let text: String
}

private enum EmailTreatmentOutput: Sendable {
  case offer(contentPieceID: ContentPiece.ID, summary: String, find: JudgmentFind)

  var contentPieceID: ContentPiece.ID {
    switch self {
    case let .offer(contentPieceID, _, _): contentPieceID
    }
  }

  var summary: String {
    switch self {
    case let .offer(_, summary, _): summary
    }
  }

  var find: JudgmentFind? {
    guard case let .offer(_, _, find) = self else { return nil }
    return find
  }
}

private enum EmailTreatmentPrompt {
  static let system = """
  You organize one curated Gmail message at a time. Produce only the requested structured result.
  Do not rank it against any other message, decide whether it belongs in Today, infer personal
  knowledge, change provider state, or create a receiver-owned record.
  """

  static func make(candidate: EmailTreatmentCandidate) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let json = String(decoding: try encoder.encode(candidate), as: UTF8.self)
    switch candidate.treatment {
    case .offer:
      return """
      Summarize this domain offer in one factual sentence, then extract exactly one useful Pending
      Find candidate. The Find is descriptive/provenance context for a future specialist app, not
      a purchase recommendation or canonical product record. Use only evidence in this message.
      Use the short singular noun `recipe` as kind for recipe candidates. This is only a routing hint;
      do not parse, validate, split, or structure a recipe.
      Return a JSON object with summary and find. Find has kind, name, descriptor, rationale, and
      optional sourceURL. Omit sourceURL when the message does not contain the exact URL.

      Message:
      \(json)
      """
    case .personal, .newsletter, .grabBag, .transactional:
      preconditionFailure("Only offers have model prompts.")
    }
  }

  static func schema(for treatment: EmailTreatment) -> JSONValue {
    let json: String
    switch treatment {
    case .offer:
      json = #"""
      {"type":"object","additionalProperties":false,"properties":{"summary":{"type":"string"},"find":{"type":"object","additionalProperties":false,"properties":{"kind":{"type":"string"},"name":{"type":"string"},"descriptor":{"type":"string"},"rationale":{"type":"string"},"sourceURL":{"type":"string"}},"required":["kind","name","descriptor","rationale"]}},"required":["summary","find"]}
      """#
    case .personal, .newsletter, .grabBag, .transactional:
      preconditionFailure("Only offers have schemas.")
    }
    return try! JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
  }
}

private enum EmailTreatmentResponseDecoder {
  private struct OfferResponse: Decodable {
    let summary: String
    let find: OfferFind
  }

  private struct OfferFind: Decodable {
    let kind: String
    let name: String
    let descriptor: String
    let rationale: String
    let sourceURL: String?
  }

  static func decode(
    _ text: String, candidate: EmailTreatmentCandidate
  ) throws -> EmailTreatmentOutput {
    let data = Data(text.utf8)
    switch candidate.treatment {
    case .offer:
      let response = try JSONDecoder().decode(OfferResponse.self, from: data)
      guard let summary = oneLine(response.summary), valid(response.find) else {
        throw EmailTreatmentDecodingError.invalidOffer
      }
      let sourceURL = response.find.sourceURL?.trimmedNonEmpty.flatMap { url in
        candidate.text.contains(url) ? url : nil
      }
      let find = JudgmentFind(
        kind: response.find.kind, name: response.find.name,
        descriptor: response.find.descriptor, rationale: response.find.rationale,
        sourceURL: sourceURL, hints: [:])
      return .offer(contentPieceID: candidate.id, summary: summary, find: find)
    case .personal, .newsletter, .grabBag, .transactional:
      throw EmailTreatmentDecodingError.unsupportedTreatment
    }
  }

  private static func oneLine(_ value: String) -> String? {
    let normalized = value
      .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
      .joined(separator: " ")
      .trimmedNonEmpty
    guard let normalized, normalized.count <= 280 else { return nil }
    return normalized
  }

  private static func valid(_ find: OfferFind) -> Bool {
    find.kind.trimmedNonEmpty != nil
      && find.name.trimmedNonEmpty != nil
      && find.descriptor.trimmedNonEmpty != nil
      && find.rationale.trimmedNonEmpty != nil
  }
}

private enum EmailTreatmentDecodingError: Error {
  case invalidOffer
  case unsupportedTreatment
}
