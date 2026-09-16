import Foundation
import LLMClientKit

public struct JudgmentEngine: Sendable {
  public static let promptVersion = "m3-s5-v1"

  /// How many follow-up calls `judge` will make to recover candidates the model omitted from a
  /// batch. Two keeps the worst-case cost bounded (a large batch rarely sheds items twice) while
  /// covering the common single-omission case; the loop also stops early the moment a round
  /// recovers nothing.
  static let maxReRequestRounds = 2

  private let modelClient: any ModelClient
  private let now: @Sendable () -> Date

  public init(
    modelClient: any ModelClient = JudgmentModel.makeClient(),
    now: @escaping @Sendable () -> Date = Date.init
  ) {
    self.modelClient = modelClient
    self.now = now
  }

  /// Judges one composition batch, then makes a bounded re-request pass for any candidates the
  /// model silently omitted or duplicated. A capable model still occasionally returns valid JSON
  /// with a short `judgments` array on a large batch; the decoder marks the missing candidates
  /// fail-closed. Re-asking for just that omitted subset keeps one batch's shed items from being
  /// counted as dropped by the composition — the same silent loss a live Edition would otherwise
  /// suffer. Costs are shaped to the failure: a clean first pass finds nothing missing and returns
  /// immediately, and a *whole-batch* failure is left alone (re-requesting it would only repeat a
  /// transport-level failure at full cost). The re-request judges the omitted pieces among
  /// themselves, so their admit / substantive-primary calls are faithful but their `rank` no
  /// longer reflects the full batch — an acceptable trade against dropping them entirely.
  public func judge(
    candidates: [JudgmentCandidate],
    personalKnowledge: PersonalKnowledgeProjection,
    currentContext: String = "",
    targetSize: Int = 20
  ) async -> JudgmentRun {
    guard !candidates.isEmpty else { return .empty }
    let startedAt = now()

    let firstPass = await judgeBatch(
      candidates, personalKnowledge: personalKnowledge, currentContext: currentContext,
      targetSize: targetSize)
    var outcomesByID = Dictionary(
      firstPass.outcomes.map { ($0.contentPieceID, $0) }, uniquingKeysWith: { existing, _ in existing })
    var usage = firstPass.usage
    var cost = firstPass.estimatedCost

    var round = 0
    while round < Self.maxReRequestRounds {
      let omitted = candidates.filter { outcomesByID[$0.id]?.errorDescription != nil }
      // Only a partial omission is recoverable here; an all-failed batch is transport-level.
      guard !omitted.isEmpty, omitted.count < candidates.count else { break }
      round += 1

      let retry = await judgeBatch(
        omitted, personalKnowledge: personalKnowledge, currentContext: currentContext,
        targetSize: targetSize)
      var recovered = false
      for outcome in retry.outcomes where outcome.errorDescription == nil {
        outcomesByID[outcome.contentPieceID] = outcome
        recovered = true
      }
      usage = Self.mergedUsage(usage, retry.usage)
      cost = Self.mergedCost(cost, retry.estimatedCost)
      if !recovered { break }
    }

    let outcomes = candidates.map {
      outcomesByID[$0.id]
        ?? .failed(contentPieceID: $0.id, error: "The model returned no judgment for this candidate.")
    }
    return JudgmentRun(
      outcomes: outcomes, usage: usage, estimatedCost: cost,
      latency: now().timeIntervalSince(startedAt),
      requestedProvider: .anthropic, modelName: JudgmentModel.displayName)
  }

  /// One model call over `candidates`. Factored out of `judge` so the re-request pass can reuse it
  /// for the omitted subset; the batch-shape/timeout reasoning below is unchanged.
  private func judgeBatch(
    _ candidates: [JudgmentCandidate],
    personalKnowledge: PersonalKnowledgeProjection,
    currentContext: String,
    targetSize: Int
  ) async -> JudgmentRun {
    let startedAt = now()
    do {
      // Stream the pass: a composition batches every candidate into one request whose
      // generated JSON scales with the candidate count, and a non-streaming `complete`
      // receives no bytes until the whole body is done — so a real-corpus batch sits past
      // the idle timeout (and Anthropic's non-streaming ceiling) and fails closed on every
      // candidate at once. Streaming keeps bytes flowing; usage still comes back for cost.
      let response = try await modelClient.completeStreaming(
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
        outcomes: try JudgmentResponseDecoder.decode(
          response.text,
          expectedCandidateIDs: candidates.map(\.id),
          allowedPersonalKnowledgeClaimIDs: Set(personalKnowledge.includedClaimIDs)
        ),
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

  /// Sums token usage across the initial pass and any re-request calls for honest reporting.
  private static func mergedUsage(_ a: ModelUsage?, _ b: ModelUsage?) -> ModelUsage? {
    switch (a, b) {
    case (nil, nil): return nil
    case let (value?, nil): return value
    case let (nil, value?): return value
    case let (left?, right?):
      return ModelUsage(
        inputTokens: left.inputTokens + right.inputTokens,
        outputTokens: left.outputTokens + right.outputTokens,
        cacheReadInputTokens: sum(left.cacheReadInputTokens, right.cacheReadInputTokens),
        cacheCreationInputTokens: sum(left.cacheCreationInputTokens, right.cacheCreationInputTokens))
    }
  }

  /// Adds the estimated cost of a re-request onto the running total, preserving `nil` only when
  /// neither call reported usage (an unpriced run stays unpriced rather than reading as $0).
  private static func mergedCost(_ a: Decimal?, _ b: Decimal?) -> Decimal? {
    guard a != nil || b != nil else { return nil }
    return (a ?? 0) + (b ?? 0)
  }

  private static func sum(_ a: Int?, _ b: Int?) -> Int? {
    guard a != nil || b != nil else { return nil }
    return (a ?? 0) + (b ?? 0)
  }
}
