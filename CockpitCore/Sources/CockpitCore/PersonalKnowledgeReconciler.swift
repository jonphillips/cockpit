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
    existingClaims: [PersonalKnowledgeClaim]
  ) async throws -> [PersonalKnowledgeProposal] {
    let response = try await modelClient.complete(
      ModelRequest(
        tier: .frontierPreferred,
        system: Self.systemPrompt,
        prompt: prompt(importText: importText, existingClaims: existingClaims),
        maxTokens: 2_000,
        responseFormat: .jsonSchema(name: "personal_knowledge_reconciliation", schema: Self.schema)
      )
    )
    let decoded = try JSONDecoder().decode(ReconciliationResponse.self, from: Data(response.text.utf8))
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
