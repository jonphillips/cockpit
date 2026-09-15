import Foundation
import LLMClientKit

/// A model-backed proposal generator. Its output is intentionally not a persistence command:
/// `PersonalKnowledgeOperations` only writes a proposal after the teaching/import UI supplies
/// explicit human confirmation.
public struct PersonalKnowledgeReconciler: Sendable {
  private let modelClient: any ModelClient

  public init(modelClient: any ModelClient) {
    self.modelClient = modelClient
  }

  public func reconcile(
    importText: String,
    existingClaims: [PersonalKnowledgeClaim],
    provider: FrontierProvider? = nil
  ) async throws -> [PersonalKnowledgeProposal] {
    try await propose(
      source: .importText(importText), existingClaims: existingClaims, provider: provider
    )
  }

  private func propose(
    source: ProposalSource,
    existingClaims: [PersonalKnowledgeClaim],
    provider: FrontierProvider?
  ) async throws -> [PersonalKnowledgeProposal] {
    // An explicit, already-configured provider routes there directly; otherwise fall back
    // to the resolver's Anthropic-first order (which itself degrades to on-device when no
    // key is present).
    let tier: ModelTier = provider.map { .frontier($0) } ?? .frontierPreferred
    let response = try await modelClient.complete(
      ModelRequest(
        tier: tier,
        system: Self.systemPrompt,
        prompt: prompt(source: source, existingClaims: existingClaims),
        maxTokens: Self.outputBudget(importText: source.importText, existingClaims: existingClaims),
        responseFormat: .jsonSchema(name: "personal_knowledge_reconciliation", schema: Self.schema)
      )
    )
    let decoded: ReconciliationResponse
    do {
      decoded = try JSONDecoder().decode(ReconciliationResponse.self, from: Data(response.text.utf8))
    } catch {
      throw ReconciliationError.undecodableResponse(
        status: response.responseFormatStatus,
        snippet: String(response.text.prefix(240))
      )
    }
    let currentIDs = Set(existingClaims.filter { $0.status == .current }.map(\.id))
    return try decoded.proposals.map { raw in
      let replacedIDs = try raw.replacesClaimIDs.map { value -> PersonalKnowledgeClaim.ID in
        guard let id = UUID(uuidString: value), currentIDs.contains(id) else {
          throw ReconciliationError.unknownCurrentClaimID(value)
        }
        return id
      }
      let action: PersonalKnowledgeProposal.Action
      switch raw.action {
      case "new":
        guard source.allowsNewClaims, replacedIDs.isEmpty else { throw ReconciliationError.invalidAction }
        action = .newClaim
      case "consolidate":
        guard source.allowsConsolidations, !replacedIDs.isEmpty else {
          throw ReconciliationError.invalidAction
        }
        action = .consolidate(replacing: replacedIDs)
      default:
        throw ReconciliationError.invalidAction
      }
      return PersonalKnowledgeProposal(
        id: UUID(), kind: raw.kind, claim: raw.claim, scope: raw.scope,
        action: action,
        // A purportedly semantic consolidation can be accepted from the review screen; every
        // new or uncertain claim requires a deliberate row-level confirmation.
        requiresConfirmation: raw.action == "new" || !raw.semanticFidelity,
        rationale: raw.rationale
      )
    }
  }

  private func prompt(source: ProposalSource, existingClaims: [PersonalKnowledgeClaim]) -> String {
    let existing = existingClaims.filter { $0.status == .current }.map { claim in
      let scope = claim.scope ?? ""
      return "id: \(claim.id.uuidString) | kind: \(claim.kind.rawValue) | claim: \(claim.claim) | scope: \(scope)"
    }.joined(separator: "\n")
    return """
    Existing current Personal Knowledge claims:
    \(existing.isEmpty ? "(none)" : existing)

    \(source.instruction)

    Return one proposal for each material new claim or semantic-preserving consolidation. Omit
    duplicates. `consolidate` may replace only listed current IDs and only when no meaning is
    broadened or lost. New claims and any uncertain synthesis must set semanticFidelity to false.
    """
  }

  private static let systemPrompt = """
  You reconcile explicit Personal Knowledge for one person. Only use the supplied import text and
  existing claims. Never infer from behavior, browsing, frequency, or unstated implications. Keep
  durable Fact, Taste, and Interest claims narrowly scoped. You may identify exact duplicates and
  semantically faithful consolidation, but any materially new, broader, or uncertain statement
  must be proposed as a new claim for human confirmation. Do not make policy or authorize actions.
  """

  private static let schema: JSONValue = .object([
    "type": "object",
    "additionalProperties": .bool(false),
    "properties": .object([
      "proposals": .object([
        "type": "array",
        "items": .object([
          "type": "object",
          "additionalProperties": .bool(false),
          "properties": .object([
            "kind": .object(["type": "string", "enum": ["fact", "taste", "interest"]]),
            "claim": .object(["type": "string"]),
            "scope": .object(["type": "string"]),
            "action": .object(["type": "string", "enum": ["new", "consolidate"]]),
            "replacesClaimIDs": .object([
              "type": "array", "items": .object(["type": "string"]),
            ]),
            "semanticFidelity": .object(["type": "boolean"]),
            "rationale": .object(["type": "string"]),
          ]),
          "required": [
            "kind", "claim", "scope", "action", "replacesClaimIDs", "semanticFidelity", "rationale",
          ],
        ]),
      ]),
    ]),
    "required": ["proposals"],
  ])
}

extension PersonalKnowledgeReconciler {
  public func consolidate(
    existingClaims: [PersonalKnowledgeClaim],
    provider: FrontierProvider? = nil
  ) async throws -> [PersonalKnowledgeProposal] {
    try await propose(source: .accumulatedClaims, existingClaims: existingClaims, provider: provider)
  }

  /// Reader teaching is one explicit reason in the context of one ContentPiece. It may propose
  /// at most one narrowly scoped new claim; it never silently rewrites existing understanding.
  public func teachFromReader(
    reason: String,
    contentTitle: String,
    publisher: String,
    summary: String?,
    existingClaims: [PersonalKnowledgeClaim],
    provider: FrontierProvider? = nil
  ) async throws -> PersonalKnowledgeProposal? {
    let proposals = try await propose(
      source: .readerTeaching(
        reason: reason, contentTitle: contentTitle, publisher: publisher, summary: summary
      ),
      existingClaims: existingClaims,
      provider: provider
    )
    guard proposals.count <= 1 else { throw ReconciliationError.invalidAction }
    return proposals.first
  }

  /// The structured output must hold one JSON object per proposed claim; a fixed cap
  /// truncates a real Jon Brain dump mid-array. Size it to the import, plus headroom for
  /// consolidations that reference existing claims. `maxTokens` is a ceiling, not a bill.
  static func outputBudget(importText: String, existingClaims: [PersonalKnowledgeClaim]) -> Int {
    let importLines = importText.split(whereSeparator: \.isNewline).filter {
      !$0.trimmingCharacters(in: .whitespaces).isEmpty
    }.count
    let estimatedProposals = importLines + existingClaims.count
    return min(16_000, max(4_000, estimatedProposals * 120))
  }
}

private enum ProposalSource {
  case importText(String)
  case accumulatedClaims
  case readerTeaching(reason: String, contentTitle: String, publisher: String, summary: String?)

  var importText: String {
    switch self {
    case let .importText(text): text
    case .accumulatedClaims: ""
    case let .readerTeaching(reason, _, _, _): reason
    }
  }

  var allowsNewClaims: Bool {
    switch self {
    case .importText, .readerTeaching: true
    case .accumulatedClaims: false
    }
  }

  var allowsConsolidations: Bool {
    switch self {
    case .importText, .accumulatedClaims: true
    case .readerTeaching: false
    }
  }

  var instruction: String {
    switch self {
    case let .importText(text):
      """
      Explicitly taught Jon Brain import text:
      \(text)
      """
    case .accumulatedClaims:
      """
      There is no new teaching. Review the existing current claims only for consolidations that
      preserve every claim's meaning and scope. Return no `new` actions.
      """
    case let .readerTeaching(reason, contentTitle, publisher, summary):
      """
      Jon explicitly used the Reader's Teach Cockpit action while reading this ContentPiece:
      title: \(contentTitle)
      publisher: \(publisher)
      summary: \(summary ?? "(none)")

      His explicit reason:
      \(reason)

      Propose at most one new Taste or Interest claim. Scope it to what Jon explicitly says, not
      to this one ContentPiece, and do not turn a contextual example into a general preference.
      Return no `consolidate` actions. The proposal will require Jon's confirmation.
      """
    }
  }
}
