import Foundation
import LLMClientKit

extension JudgmentEngine {
  /// The frozen M3 single-pass control for `JudgmentEval` only. Normal Edition composition always
  /// uses the PK-free type pass followed by `judge`'s PK-aware editorial pass.
  public func judgeSinglePassControl(
    candidates: [JudgmentCandidate], personalKnowledge: PersonalKnowledgeProjection,
    currentContext: String = "", targetSize: Int = 20
  ) async -> JudgmentRun {
    guard !candidates.isEmpty else { return .empty }
    let startedAt = now()
    let firstPass = await judgeSinglePassControlBatch(
      candidates, personalKnowledge: personalKnowledge, currentContext: currentContext,
      targetSize: targetSize)
    var outcomesByID = Dictionary(
      firstPass.outcomes.map { ($0.contentPieceID, $0) },
      uniquingKeysWith: { existing, _ in existing })
    var metrics = firstPass.metrics

    var round = 0
    while round < Self.maxReRequestRounds {
      let omitted = candidates.filter { outcomesByID[$0.id]?.errorDescription != nil }
      guard !omitted.isEmpty, omitted.count < candidates.count else { break }
      round += 1
      let retry = await judgeSinglePassControlBatch(
        omitted, personalKnowledge: personalKnowledge, currentContext: currentContext,
        targetSize: targetSize)
      var recovered = false
      for outcome in retry.outcomes where outcome.errorDescription == nil {
        outcomesByID[outcome.contentPieceID] = outcome
        recovered = true
      }
      metrics = Self.merged(metrics, retry.metrics)
      if !recovered { break }
    }

    return .init(
      outcomes: candidates.map {
        outcomesByID[$0.id]
          ?? .failed(contentPieceID: $0.id, error: "The model returned no judgment for this candidate.")
      },
      usage: metrics.usage, estimatedCost: metrics.estimatedCost,
      latency: now().timeIntervalSince(startedAt), requestedProvider: .anthropic,
      modelName: JudgmentModel.displayName, typePass: .empty, editorialPass: metrics)
  }

  private func judgeSinglePassControlBatch(
    _ candidates: [JudgmentCandidate], personalKnowledge: PersonalKnowledgeProjection,
    currentContext: String, targetSize: Int
  ) async -> SinglePassControlRun {
    let startedAt = now()
    do {
      let response = try await complete(
        system: JudgmentSinglePassControlPrompt.system,
        prompt: JudgmentSinglePassControlPrompt.make(
          candidates: candidates, personalKnowledge: personalKnowledge,
          currentContext: currentContext, targetSize: targetSize),
        responseFormat: .jsonSchema(
          name: "cockpit_judgments", schema: JudgmentSinglePassControlPrompt.schema),
        candidateCount: candidates.count)
      return .init(
        outcomes: try JudgmentResponseDecoder.decodeSinglePassControl(
          response.text, expectedCandidateIDs: candidates.map(\.id),
          allowedPersonalKnowledgeClaimIDs: Set(personalKnowledge.includedClaimIDs)),
        metrics: metrics(response: response, startedAt: startedAt))
    } catch {
      return .init(
        outcomes: candidates.map {
          .failed(contentPieceID: $0.id, error: JudgmentResponseDecoder.errorMessage(for: error))
        },
        metrics: .init(
          usage: nil, estimatedCost: nil, latency: now().timeIntervalSince(startedAt),
          modelName: JudgmentModel.displayName))
    }
  }
}

private struct SinglePassControlRun: Sendable {
  let outcomes: [JudgmentOutcome]
  let metrics: JudgmentPassMetrics
}
