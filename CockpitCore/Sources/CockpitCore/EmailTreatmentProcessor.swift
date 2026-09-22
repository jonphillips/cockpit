import Foundation
import LLMClientKit
import SQLiteData

/// Runs the two content treatments that operate on a curated message's own body. Each request is
/// intentionally one email wide: it may summarize or sift that issue, but cannot rank one Gmail
/// message against another or remove anything from Today.
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
    case .grabBag: .grabBag
    case .offers: .offer
    default: treatment == .offer || treatment == .grabBag ? treatment : nil
    }
  }

  private func extract(_ candidate: EmailTreatmentCandidate) async throws -> EmailTreatmentOutput {
    let response = try await modelClient.completeStreaming(
      ModelRequest(
        tier: .frontier(.anthropic), system: EmailTreatmentPrompt.system,
        prompt: try EmailTreatmentPrompt.make(candidate: candidate), maxTokens: 2_000,
        responseFormat: .jsonSchema(
          name: "cockpit_email_treatment", schema: EmailTreatmentPrompt.schema(for: candidate.treatment))))
    return try EmailTreatmentResponseDecoder.decode(
      response.text, contentPieceID: candidate.id, treatment: candidate.treatment)
  }

  private func persist(_ output: EmailTreatmentOutput, in db: Database) throws -> EmailTreatmentDetails {
    let details: EmailTreatmentDetails
    switch output {
    case let .offer(contentPieceID, summary, _):
      details = .init(contentPieceID: contentPieceID, offerSummary: summary, grabBagItems: nil)
    case let .grabBag(contentPieceID, items):
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      details = .init(
        contentPieceID: contentPieceID, offerSummary: nil,
        grabBagItems: String(decoding: try encoder.encode(items), as: UTF8.self))
    }
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
  case grabBag(contentPieceID: ContentPiece.ID, items: [GrabBagItem])

  var contentPieceID: ContentPiece.ID {
    switch self {
    case let .offer(contentPieceID, _, _), let .grabBag(contentPieceID, _): contentPieceID
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

      Message:
      \(json)
      """
    case .grabBag:
      return """
      Decompose this manually marked grab-bag issue into the worthwhile contained items. Preserve
      their source order. Each item gets a concise factual title, summary, and source URL when the
      issue supplies one. Do not score, rank, compare, or include boilerplate; an empty list is
      valid when no contained item is worthwhile.

      Message:
      \(json)
      """
    case .personal, .newsletter, .transactional:
      preconditionFailure("Only S8 treatments have model prompts.")
    }
  }

  static func schema(for treatment: EmailTreatment) -> JSONValue {
    let json: String
    switch treatment {
    case .offer:
      json = #"""
      {"type":"object","additionalProperties":false,"properties":{"summary":{"type":"string"},"find":{"type":"object","additionalProperties":false,"properties":{"kind":{"type":"string"},"name":{"type":"string"},"descriptor":{"type":"string"},"rationale":{"type":"string"},"sourceURL":{"type":["string","null"]},"hints":{"type":"object"}},"required":["kind","name","descriptor","rationale","sourceURL","hints"]}},"required":["summary","find"]}
      """#
    case .grabBag:
      json = #"""
      {"type":"object","additionalProperties":false,"properties":{"items":{"type":"array","items":{"type":"object","additionalProperties":false,"properties":{"title":{"type":"string"},"summary":{"type":"string"},"sourceURL":{"type":["string","null"]}},"required":["title","summary","sourceURL"]}}},"required":["items"]}
      """#
    case .personal, .newsletter, .transactional:
      preconditionFailure("Only S8 treatments have schemas.")
    }
    return try! JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
  }
}

private enum EmailTreatmentResponseDecoder {
  private struct OfferResponse: Decodable {
    let summary: String
    let find: JudgmentFind
  }

  private struct GrabBagResponse: Decodable {
    let items: [RawGrabBagItem]
  }

  private struct RawGrabBagItem: Decodable {
    let title: String
    let summary: String
    let sourceURL: String?
  }

  static func decode(
    _ text: String, contentPieceID: ContentPiece.ID, treatment: EmailTreatment
  ) throws -> EmailTreatmentOutput {
    let data = Data(text.utf8)
    switch treatment {
    case .offer:
      let response = try JSONDecoder().decode(OfferResponse.self, from: data)
      guard let summary = oneLine(response.summary), valid(response.find) else {
        throw EmailTreatmentDecodingError.invalidOffer
      }
      return .offer(contentPieceID: contentPieceID, summary: summary, find: response.find)
    case .grabBag:
      let response = try JSONDecoder().decode(GrabBagResponse.self, from: data)
      let items = response.items.compactMap { item -> GrabBagItem? in
        guard let title = item.title.trimmedNonEmpty, let summary = item.summary.trimmedNonEmpty else {
          return nil
        }
        let sourceURL = item.sourceURL?.trimmedNonEmpty
        let id = ContentIdentity.uuidV5(
          namespace: ContentIdentity.cockpitNamespace,
          name: ["grab-bag-item", contentPieceID.uuidString, title, sourceURL ?? ""]
            .map(ContentIdentity.normalizeText)
            .joined(separator: "\u{001F}"))
        return GrabBagItem(id: id, title: title, summary: summary, sourceURL: sourceURL)
      }
      guard items.count == response.items.count else { throw EmailTreatmentDecodingError.invalidGrabBag }
      return .grabBag(contentPieceID: contentPieceID, items: items)
    case .personal, .newsletter, .transactional:
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

  private static func valid(_ find: JudgmentFind) -> Bool {
    find.kind.trimmedNonEmpty != nil
      && find.name.trimmedNonEmpty != nil
      && find.descriptor.trimmedNonEmpty != nil
      && find.rationale.trimmedNonEmpty != nil
  }
}

private enum EmailTreatmentDecodingError: Error {
  case invalidOffer
  case invalidGrabBag
  case unsupportedTreatment
}
