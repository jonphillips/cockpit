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
    // An explicit, already-configured provider routes there directly; otherwise fall back
    // to the resolver's Anthropic-first order (which itself degrades to on-device when no
    // key is present).
    let tier: ModelTier = provider.map { .frontier($0) } ?? .frontierPreferred
    let response = try await modelClient.complete(
      ModelRequest(
        tier: tier,
        system: Self.systemPrompt,
        prompt: prompt(importText: importText, existingClaims: existingClaims),
        maxTokens: Self.outputBudget(importText: importText, existingClaims: existingClaims),
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
        guard replacedIDs.isEmpty else { throw ReconciliationError.invalidAction }
        action = .newClaim
      case "consolidate":
        guard !replacedIDs.isEmpty else { throw ReconciliationError.invalidAction }
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

  /// The structured output must hold one JSON object per proposed claim; a fixed cap
  /// truncates a real Jon Brain dump mid-array (a valid-JSON-but-incomplete decode
  /// failure). Size it to the import — roughly one proposal per non-empty import line,
  /// plus headroom for consolidations that reference existing claims, at ~120 tokens each
  /// — floored so a tiny import still has room and capped so it stays within model limits.
  /// `maxTokens` is only a ceiling; billing is for tokens actually generated.
  static func outputBudget(importText: String, existingClaims: [PersonalKnowledgeClaim]) -> Int {
    let importLines = importText.split(whereSeparator: \.isNewline).filter {
      !$0.trimmingCharacters(in: .whitespaces).isEmpty
    }.count
    let estimatedProposals = importLines + existingClaims.count
    return min(16_000, max(4_000, estimatedProposals * 120))
  }

  private func prompt(importText: String, existingClaims: [PersonalKnowledgeClaim]) -> String {
    let existing = existingClaims.filter { $0.status == .current }.map { claim in
      let scope = claim.scope ?? ""
      return "id: \(claim.id.uuidString) | kind: \(claim.kind.rawValue) | claim: \(claim.claim) | scope: \(scope)"
    }.joined(separator: "\n")
    return """
    Existing current Personal Knowledge claims:
    \(existing.isEmpty ? "(none)" : existing)

    Explicitly taught Jon Brain import text:
    \(importText)

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

public enum ReconciliationError: Error, Equatable {
  case unknownCurrentClaimID(String)
  case invalidAction
  /// The model returned something the reconciliation decoder could not read. `status`
  /// distinguishes an on-device fall-back to prose (`.fellBack`) from a frontier reply
  /// that was simply malformed; `snippet` is the start of what actually came back.
  case undecodableResponse(status: ModelResponseFormatStatus?, snippet: String)
}

extension ReconciliationError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case let .unknownCurrentClaimID(value):
      return "The model referenced a claim that is not a current one (\(value))."
    case .invalidAction:
      return "The model proposed an action Cockpit does not support."
    case let .undecodableResponse(status, snippet):
      let lead = status == .fellBack
        ? "The model could not produce the required structured format and returned plain text instead — the on-device model cannot handle this import. Choose a frontier provider in AI Settings."
        : "The model's response was not valid structured data."
      return "\(lead) It began: \(snippet)"
    }
  }
}

public struct PersonalKnowledgeProposal: Equatable, Identifiable, Sendable {
  public enum Action: Equatable, Sendable {
    case newClaim
    case consolidate(replacing: [PersonalKnowledgeClaim.ID])
  }

  public let id: UUID
  public var kind: PersonalKnowledgeKind
  public var claim: String
  public var scope: String
  public var action: Action
  public var requiresConfirmation: Bool
  public var rationale: String

  public init(
    id: UUID,
    kind: PersonalKnowledgeKind,
    claim: String,
    scope: String,
    action: Action,
    requiresConfirmation: Bool,
    rationale: String
  ) {
    self.id = id
    self.kind = kind
    self.claim = claim
    self.scope = scope
    self.action = action
    self.requiresConfirmation = requiresConfirmation
    self.rationale = rationale
  }
}

private struct ReconciliationResponse: Decodable {
  var proposals: [RawProposal]
}

private struct RawProposal: Decodable {
  var kind: PersonalKnowledgeKind
  var claim: String
  var scope: String
  var action: String
  var replacesClaimIDs: [String]
  var semanticFidelity: Bool
  var rationale: String
}
