import Foundation
import LLMClientKit

public struct JudgmentEngine: Sendable {
  public static let promptVersion = "m2-s2-v1"

  private let modelClient: any ModelClient
  private let now: @Sendable () -> Date

  public init(
    modelClient: any ModelClient = JudgmentModel.makeClient(),
    now: @escaping @Sendable () -> Date = Date.init
  ) {
    self.modelClient = modelClient
    self.now = now
  }

  public func judge(
    candidates: [JudgmentCandidate],
    personalKnowledge: PersonalKnowledgeProjection,
    currentContext: String = "",
    targetSize: Int = 20
  ) async -> JudgmentRun {
    guard !candidates.isEmpty else { return .empty }

    let startedAt = now()
    do {
      let response = try await modelClient.complete(
        ModelRequest(
          tier: .frontier(.anthropic),
          system: JudgmentPrompt.system,
          prompt: try JudgmentPrompt.make(
            candidates: candidates,
            personalKnowledge: personalKnowledge,
            currentContext: currentContext,
            targetSize: targetSize
          ),
          // One judgment object carries a ≤70-word summary, a ≤40-word rationale, 3–8
          // subjects, and any finds — realistically ~250–350 output tokens. Budget 400 per
          // candidate for headroom; a too-small cap truncates the JSON mid-array and fails
          // the whole batch closed. 64k is Sonnet's output ceiling, so a batch must stay
          // composition-sized (see `JudgmentEval`) to fit — ~150 candidates max here.
          maxTokens: min(64_000, max(4_096, candidates.count * 400)),
          responseFormat: .jsonSchema(name: "cockpit_judgments", schema: JudgmentPrompt.schema)
        )
      )
      return JudgmentRun(
        outcomes: try JudgmentResponseDecoder.decode(response.text, expectedCandidateIDs: candidates.map(\.id)),
        usage: response.usage,
        estimatedCost: JudgmentCostEstimator.estimate(
          usage: response.usage, requestedProvider: .anthropic
        ),
        latency: now().timeIntervalSince(startedAt),
        requestedProvider: .anthropic,
        modelName: JudgmentModel.displayName
      )
    } catch {
      return JudgmentRun.failed(
        candidates: candidates,
        error: JudgmentResponseDecoder.errorMessage(for: error),
        latency: now().timeIntervalSince(startedAt)
      )
    }
  }
}
