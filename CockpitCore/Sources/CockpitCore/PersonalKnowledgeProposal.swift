import Foundation
import LLMClientKit

public enum ReconciliationError: Error, Equatable {
  case unknownCurrentClaimID(String)
  case invalidAction
  /// The model returned something the reconciliation decoder could not read. `status`
  /// distinguishes an on-device fallback to prose from a malformed frontier reply.
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

struct ReconciliationResponse: Decodable {
  var proposals: [RawProposal]
}

struct RawProposal: Decodable {
  var kind: PersonalKnowledgeKind
  var claim: String
  var scope: String
  var action: String
  var replacesClaimIDs: [String]
  var semanticFidelity: Bool
  var rationale: String
}
