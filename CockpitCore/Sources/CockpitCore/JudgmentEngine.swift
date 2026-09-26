import Foundation
import LLMClientKit

// The pass orchestration stays together so the failure/retry boundaries are auditable in one place.
// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
public struct JudgmentEngine: Sendable {
  /// The stored Edition version identifies its editorial decision. The type pass has its own
  /// version because it is a distinct, PK-free prompt and can later move to a cheaper model.
  public static let editorialPromptVersion = "m6-s-r13-editorial-v1"
  public static let typePromptVersion = "m4-s1-type-v1"
  public static let promptVersion = editorialPromptVersion
  public static let singlePassControlPromptVersion = "m6-s-r13-control-v1"

  /// How many follow-up calls each pass will make to recover candidates silently omitted from a
  /// batch. A bounded retry repairs per-piece omissions and failed type batches.
  static let maxReRequestRounds = 2

  /// The type pass has no finite-package constraint, unlike the editorial pass. Composition-sized
  /// chunks keep individual responses bounded, and the modest window stays below the provider's
  /// normal request ceiling while materially reducing wall time.
  static let typePassBatchSize = 30
  static let typePassConcurrency = 4

  let modelClient: any ModelClient
  let now: @Sendable () -> Date

  public init(
    modelClient: any ModelClient = JudgmentModel.makeClient(),
    now: @escaping @Sendable () -> Date = Date.init
  ) {
    self.modelClient = modelClient
    self.now = now
  }

  /// Runs the PK-free type pass. The signature deliberately excludes Personal Knowledge and
  /// Current Context: callers cannot accidentally reintroduce those editorial inputs.
  public func classify(candidates: [JudgmentCandidate]) async -> JudgmentClassificationRun {
    guard !candidates.isEmpty else {
      return .init(classifications: [], metrics: .empty)
    }
    let startedAt = now()
    let firstPasses = await classifyBatches(candidates.chunked(into: Self.typePassBatchSize))
    let firstPass = Self.merged(firstPasses)
    var classificationsByID = Dictionary(
      firstPass.classifications.map { ($0.contentPieceID, $0) },
      uniquingKeysWith: { existing, _ in existing })
    var metrics = firstPass.metrics

    var round = 0
    while round < Self.maxReRequestRounds {
      let omitted = candidates.filter { classificationsByID[$0.id]?.errorDescription != nil }
      guard !omitted.isEmpty else { break }
      round += 1

      let retry = Self.merged(
        await classifyBatches(omitted.chunked(into: Self.typePassBatchSize)))
      var recovered = false
      for classification in retry.classifications where classification.errorDescription == nil {
        classificationsByID[classification.contentPieceID] = classification
        recovered = true
      }
      metrics = Self.merged(metrics, retry.metrics)
      if !recovered { break }
    }

    // Batches run concurrently, so the type-pass metric is its actual elapsed wall time rather
    // than the sum of independent request durations. Usage and cost above still sum every call.
    metrics = .init(
      usage: metrics.usage, estimatedCost: metrics.estimatedCost,
      latency: now().timeIntervalSince(startedAt), modelName: JudgmentModel.displayName)
    return .init(
      classifications: candidates.map {
        classificationsByID[$0.id]
          ?? .failed(contentPieceID: $0.id, error: "The model returned no judgment for this candidate.")
      },
      metrics: metrics)
  }

  /// Runs the independent PK-free type batches with a bounded sliding window. Results may arrive
  /// out of order, but `classify` reassembles them by ContentPiece identity before returning.
  private func classifyBatches(
    _ batches: [[JudgmentCandidate]]
  ) async -> [JudgmentClassificationRun] {
    guard !batches.isEmpty else { return [] }
    return await withTaskGroup(of: JudgmentClassificationRun.self) { group in
      var runs: [JudgmentClassificationRun] = []
      var next = 0
      let window = min(Self.typePassConcurrency, batches.count)

      while next < window {
        let batch = batches[next]
        group.addTask { await classifyBatch(batch) }
        next += 1
      }

      while let run = await group.next() {
        runs.append(run)
        if next < batches.count {
          let batch = batches[next]
          group.addTask { await classifyBatch(batch) }
          next += 1
        }
      }
      return runs
    }
  }

  /// Performs the two-pass judgment shape. Type classification is intentionally completed before
  /// the PK-aware editorial call, which receives those facts but cannot revise them.
  public func judge(
    candidates: [JudgmentCandidate],
    personalKnowledge: PersonalKnowledgeProjection,
    currentContext: String = "",
    targetSize: Int = 20,
    onEditorialPassStart: @escaping @Sendable () async -> Void = {}
  ) async -> JudgmentRun {
    guard !candidates.isEmpty else { return .empty }
    let startedAt = now()
    let classificationRun = await classify(candidates: candidates)
    let classificationsByID = Dictionary(
      classificationRun.classifications.map { ($0.contentPieceID, $0) },
      uniquingKeysWith: { existing, _ in existing })
    let editorialCandidates = candidates.compactMap { candidate -> EditorialJudgmentCandidate? in
      guard let classification = classificationsByID[candidate.id],
        classification.errorDescription == nil,
        let isSubstantivePrimary = classification.isSubstantivePrimary,
        let subjects = classification.subjects,
        let summary = classification.summary
      else { return nil }
      return EditorialJudgmentCandidate(
        candidate: candidate,
        classification: .init(
          isSubstantivePrimary: isSubstantivePrimary, subjects: subjects, summary: summary,
          bodyCompleteness: classification.bodyCompleteness))
    }
    // The editorial pass is the finite-package call and is normally the slowest part of a tail
    // compose. Tell the caller exactly when it begins; this does not alter judgment inputs.
    await onEditorialPassStart()
    let editorialRun = await judgeEditorial(
      candidates: editorialCandidates, personalKnowledge: personalKnowledge,
      currentContext: currentContext, targetSize: targetSize)
    let editorialByID = Dictionary(
      editorialRun.judgments.map { ($0.contentPieceID, $0) },
      uniquingKeysWith: { existing, _ in existing })

    let outcomes = mergedOutcomes(
      candidates: candidates, classificationsByID: classificationsByID,
      editorialByID: editorialByID)

    let usage = Self.mergedUsage(classificationRun.metrics.usage, editorialRun.metrics.usage)
    let cost = Self.mergedCost(
      classificationRun.metrics.estimatedCost, editorialRun.metrics.estimatedCost)
    return JudgmentRun(
      outcomes: outcomes, usage: usage, estimatedCost: cost,
      latency: now().timeIntervalSince(startedAt), requestedProvider: .anthropic,
      modelName: JudgmentModel.displayName, typePass: classificationRun.metrics,
      editorialPass: editorialRun.metrics)
  }

  private func mergedOutcomes(
    candidates: [JudgmentCandidate], classificationsByID: [UUID: JudgmentClassification],
    editorialByID: [UUID: EditorialJudgment]
  ) -> [JudgmentOutcome] {
    candidates.map { candidate -> JudgmentOutcome in
      guard let classification = classificationsByID[candidate.id],
        classification.errorDescription == nil
      else {
        let error = classificationsByID[candidate.id]?.errorDescription
          ?? "The model returned no judgment for this candidate."
        return .failed(contentPieceID: candidate.id, error: error)
      }
      guard let editorial = editorialByID[candidate.id], editorial.errorDescription == nil else {
        let error = editorialByID[candidate.id]?.errorDescription
          ?? "The model returned no judgment for this candidate."
        return .init(
          contentPieceID: candidate.id, admit: false,
          isSubstantivePrimary: classification.isSubstantivePrimary,
          section: nil, rank: nil, rationale: nil, matchedPersonalKnowledgeClaimID: nil,
          subjects: classification.subjects, summary: classification.summary,
          bodyCompleteness: classification.bodyCompleteness, finds: nil,
          classificationErrorDescription: nil, errorDescription: error)
      }
      return .init(
        contentPieceID: candidate.id, admit: editorial.admit,
        isSubstantivePrimary: classification.isSubstantivePrimary,
        section: editorial.section, rank: editorial.rank, rationale: editorial.rationale,
        matchedPersonalKnowledgeClaimID: editorial.matchedPersonalKnowledgeClaimID,
        subjects: classification.subjects, summary: classification.summary,
        bodyCompleteness: classification.bodyCompleteness, finds: editorial.finds,
        classificationErrorDescription: nil, errorDescription: nil)
    }
  }

  private func classifyBatch(_ candidates: [JudgmentCandidate]) async -> JudgmentClassificationRun {
    let startedAt = now()
    do {
      let response = try await complete(
        system: JudgmentClassificationPrompt.system,
        prompt: JudgmentClassificationPrompt.make(candidates: candidates),
        responseFormat: .jsonSchema(
          name: "cockpit_type_classifications", schema: JudgmentClassificationPrompt.schema),
        candidateCount: candidates.count)
      return .init(
        classifications: try JudgmentResponseDecoder.decodeClassification(
          response.text, expectedCandidateIDs: candidates.map(\.id)),
        metrics: metrics(response: response, startedAt: startedAt))
    } catch {
      return .init(
        classifications: candidates.map {
          .failed(contentPieceID: $0.id, error: JudgmentResponseDecoder.errorMessage(for: error))
        },
        metrics: .init(
          usage: nil, estimatedCost: nil, latency: now().timeIntervalSince(startedAt),
          modelName: JudgmentModel.displayName))
    }
  }

  private func judgeEditorial(
    candidates: [EditorialJudgmentCandidate], personalKnowledge: PersonalKnowledgeProjection,
    currentContext: String, targetSize: Int
  ) async -> EditorialJudgmentRun {
    guard !candidates.isEmpty else { return .init(judgments: [], metrics: .empty) }
    let firstPass = await judgeEditorialBatch(
      candidates, personalKnowledge: personalKnowledge, currentContext: currentContext,
      targetSize: targetSize)
    var judgmentsByID = Dictionary(
      firstPass.judgments.map { ($0.contentPieceID, $0) },
      uniquingKeysWith: { existing, _ in existing })
    var metrics = firstPass.metrics

    var round = 0
    while round < Self.maxReRequestRounds {
      let omitted = candidates.filter { judgmentsByID[$0.candidate.id]?.errorDescription != nil }
      guard !omitted.isEmpty, omitted.count < candidates.count else { break }
      round += 1

      let retry = await judgeEditorialBatch(
        omitted, personalKnowledge: personalKnowledge, currentContext: currentContext,
        targetSize: targetSize)
      var recovered = false
      for judgment in retry.judgments where judgment.errorDescription == nil {
        judgmentsByID[judgment.contentPieceID] = judgment
        recovered = true
      }
      metrics = Self.merged(metrics, retry.metrics)
      if !recovered { break }
    }

    return .init(
      judgments: candidates.map {
        judgmentsByID[$0.candidate.id]
          ?? .failed(contentPieceID: $0.candidate.id, error: "The model returned no judgment for this candidate.")
      },
      metrics: metrics)
  }

  private func judgeEditorialBatch(
    _ candidates: [EditorialJudgmentCandidate], personalKnowledge: PersonalKnowledgeProjection,
    currentContext: String, targetSize: Int
  ) async -> EditorialJudgmentRun {
    let startedAt = now()
    do {
      let response = try await complete(
        system: JudgmentEditorialPrompt.system,
        prompt: JudgmentEditorialPrompt.make(
          candidates: candidates, personalKnowledge: personalKnowledge,
          currentContext: currentContext, targetSize: targetSize),
        responseFormat: .jsonSchema(
          name: "cockpit_editorial_judgments", schema: JudgmentEditorialPrompt.schema),
        candidateCount: candidates.count)
      return .init(
        judgments: try JudgmentResponseDecoder.decodeEditorial(
          response.text, expectedCandidateIDs: candidates.map(\.candidate.id),
          allowedPersonalKnowledgeClaimIDs: Set(personalKnowledge.includedClaimIDs)),
        metrics: metrics(response: response, startedAt: startedAt))
    } catch {
      return .init(
        judgments: candidates.map {
          .failed(contentPieceID: $0.candidate.id, error: JudgmentResponseDecoder.errorMessage(for: error))
        },
        metrics: .init(
          usage: nil, estimatedCost: nil, latency: now().timeIntervalSince(startedAt),
          modelName: JudgmentModel.displayName))
    }
  }

  func complete(
    system: String, prompt: String, responseFormat: ModelResponseFormat, candidateCount: Int
  ) async throws -> ModelResponse {
    try await modelClient.completeStreaming(
      ModelRequest(
        tier: .frontier(.anthropic), system: system, prompt: prompt,
        // Both structured responses remain bounded by the same 400-token-per-piece allowance.
        maxTokens: min(64_000, max(4_096, candidateCount * 400)), responseFormat: responseFormat))
  }

  func metrics(response: ModelResponse, startedAt: Date) -> JudgmentPassMetrics {
    .init(
      usage: response.usage,
      estimatedCost: JudgmentCostEstimator.estimate(
        usage: response.usage, requestedProvider: .anthropic),
      latency: now().timeIntervalSince(startedAt), modelName: JudgmentModel.displayName)
  }

  static func merged(_ a: JudgmentPassMetrics, _ b: JudgmentPassMetrics) -> JudgmentPassMetrics {
    .init(
      usage: mergedUsage(a.usage, b.usage), estimatedCost: mergedCost(a.estimatedCost, b.estimatedCost),
      latency: a.latency + b.latency, modelName: JudgmentModel.displayName)
  }

  static func merged(_ runs: [JudgmentClassificationRun]) -> JudgmentClassificationRun {
    runs.reduce(
      .init(classifications: [], metrics: .empty)
    ) { partial, run in
      .init(
        classifications: partial.classifications + run.classifications,
        metrics: merged(partial.metrics, run.metrics))
    }
  }

  static func mergedUsage(_ a: ModelUsage?, _ b: ModelUsage?) -> ModelUsage? {
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

  static func mergedCost(_ a: Decimal?, _ b: Decimal?) -> Decimal? {
    guard a != nil || b != nil else { return nil }
    return (a ?? 0) + (b ?? 0)
  }

  static func sum(_ a: Int?, _ b: Int?) -> Int? {
    guard a != nil || b != nil else { return nil }
    return (a ?? 0) + (b ?? 0)
  }
}

private struct EditorialJudgmentRun: Sendable {
  let judgments: [EditorialJudgment]
  let metrics: JudgmentPassMetrics
}

private extension Array {
  func chunked(into size: Int) -> [[Element]] {
    guard size > 0 else { return [self] }
    return stride(from: 0, to: count, by: size).map {
      Array(self[$0..<Swift.min($0 + size, count)])
    }
  }
}
