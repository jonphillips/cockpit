@testable import CockpitCore
import Foundation
import JudgmentFixtureSupport
import LLMClientKit
import Synchronization
import Testing

@Suite("Judgment engine")
struct JudgmentEngineTests {
  @Test("uses Cockpit's Sonnet configuration and strict structured output")
  func buildsStructuredBatchRequest() async throws {
    let request = Mutex<ModelRequest?>(nil)
    let engine = JudgmentEngine(
      modelClient: StubModelClient { modelRequest in
        request.withLock { $0 = modelRequest }
        return ModelResponse(text: response(for: [UUID(1)]))
      }
    )
    let knowledge = PersonalKnowledgeProjection(
      text: "Interest:\n- Burgundy travel and wine.", includedClaimIDs: [], isFullSet: true
    )

    _ = await engine.judge(
      candidates: [candidate(id: UUID(1), normalizedText: String(repeating: "x", count: 1_700))],
      personalKnowledge: knowledge,
      currentContext: "Planning a Burgundy trip.",
      targetSize: 12
    )

    let captured = try #require(request.withLock { $0 })
    #expect(captured.tier == .frontier(.anthropic))
    #expect(captured.maxTokens == 4_096)
    guard case let .jsonSchema(name, _, strict) = captured.responseFormat else {
      Issue.record("Judgment must request structured output.")
      return
    }
    #expect(name == "cockpit_editorial_judgments")
    #expect(strict)
    #expect(captured.system?.contains("never writes Personal Knowledge") == true)
    let prompt = try #require(captured.messages.last?.text)
    #expect(prompt.contains(JudgmentEngine.promptVersion))
    #expect(prompt.contains("Burgundy travel and wine."))
    #expect(prompt.contains("Planning a Burgundy trip."))
    #expect(prompt.contains(String(repeating: "x", count: 1_500)))
    #expect(!prompt.contains(String(repeating: "x", count: 1_501)))
    #expect(JudgmentModel.modelID == "claude-sonnet-5")
  }

  @Test("type classification is PK-free while the editorial pass retains Personal Knowledge")
  func separatesTypeInputsFromEditorialInputs() async throws {
    let requests = Mutex<[ModelRequest]>([])
    let candidateID = UUID(1)
    let engine = JudgmentEngine(
      modelClient: StubModelClient { request in
        requests.withLock { $0.append(request) }
        guard case let .jsonSchema(name, _, _) = request.responseFormat else {
          Issue.record("Judgment must request structured output.")
          return ModelResponse(text: "")
        }
        return switch name {
        case "cockpit_type_classifications":
          ModelResponse(text: self.classificationResponse(for: [candidateID]))
        case "cockpit_editorial_judgments":
          ModelResponse(text: self.response(for: [candidateID]))
        default:
          ModelResponse(text: "")
        }
      })
    let knowledge = PersonalKnowledgeProjection(
      text: "Interest:\n- Burgundy travel and wine.", includedClaimIDs: [], isFullSet: true)

    _ = await engine.judge(candidates: [candidate(id: candidateID)], personalKnowledge: knowledge)

    let captured = requests.withLock { $0 }
    #expect(captured.count == 2)
    let typePrompt = try #require(captured.first?.messages.last?.text)
    let editorialPrompt = try #require(captured.last?.messages.last?.text)
    #expect(typePrompt.contains(JudgmentEngine.typePromptVersion))
    #expect(!typePrompt.contains("Burgundy travel and wine."))
    #expect(!typePrompt.contains("Current situation:"))
    #expect(editorialPrompt.contains(JudgmentEngine.editorialPromptVersion))
    #expect(editorialPrompt.contains("Burgundy travel and wine."))
    #expect(editorialPrompt.contains("already-classified type metadata"))
  }

  @Test("a malformed batch fails every candidate closed with a recorded error")
  func malformedBatchFailsClosed() async {
    let first = candidate(id: UUID(1))
    let second = candidate(id: UUID(2))
    let engine = JudgmentEngine(modelClient: StubModelClient.constant("not JSON"))

    let run = await engine.judge(
      candidates: [first, second],
      personalKnowledge: .init(text: "", includedClaimIDs: [], isFullSet: true)
    )

    #expect(run.outcomes.map(\.contentPieceID) == [first.id, second.id])
    #expect(run.outcomes.allSatisfy { !$0.admit && $0.errorDescription != nil })
    #expect(run.outcomes.allSatisfy { $0.isSubstantivePrimary == nil && $0.summary == nil })
  }

  @Test("a duplicate or missing candidate fails only the affected pieces, not the batch")
  func perPieceFailClosed() async {
    // The model returns two judgments for `first` and none for `second` or `third`.
    // `first` fails closed (ambiguous duplicate), `second`/`third` fail closed (no judgment),
    // but a well-formed judgment for any other candidate would still stand.
    let first = candidate(id: UUID(1))
    let second = candidate(id: UUID(2))
    let third = candidate(id: UUID(3))
    let engine = JudgmentEngine(modelClient: StubModelClient.constant(response(for: [first.id, first.id])))

    let run = await engine.judge(
      candidates: [first, second, third],
      personalKnowledge: .init(text: "", includedClaimIDs: [], isFullSet: true)
    )

    #expect(run.outcomes.map(\.contentPieceID) == [first.id, second.id, third.id])
    #expect(run.outcomes.allSatisfy { !$0.admit && $0.errorDescription != nil })
    #expect(run.outcomes[0].errorDescription?.contains("more than one judgment") == true)
    #expect(run.outcomes[1].errorDescription?.contains("no judgment") == true)
    #expect(run.outcomes[2].errorDescription?.contains("no judgment") == true)
  }

  @Test("one malformed judgment object fails only its own piece; valid siblings survive")
  func oneBadObjectDoesNotSinkTheBatch() async {
    let good = candidate(id: UUID(1))
    let bad = candidate(id: UUID(2))
    // A batch whose second object is missing required fields (only an id), alongside a valid first.
    let batch = """
      {"judgments":[\(judgmentObject(id: good.id)),{"contentPieceID":"\(bad.id.uuidString)"}]}
      """
    let engine = JudgmentEngine(modelClient: StubModelClient.constant(batch))

    let run = await engine.judge(
      candidates: [good, bad],
      personalKnowledge: .init(text: "", includedClaimIDs: [], isFullSet: true)
    )

    #expect(run.outcomes[0].admit == true)
    #expect(run.outcomes[0].errorDescription == nil)
    #expect(run.outcomes[1].admit == false)
    #expect(run.outcomes[1].errorDescription?.contains("did not match the required shape") == true)
  }

  @Test("a truncated envelope salvages its complete objects; the cut tail fails closed, not fabricated")
  func truncatedEnvelopeSalvagesLeadingObjects() throws {
    let (first, second, third) = (UUID(1), UUID(2), UUID(3))
    // Valid objects for the first two; the third is cut off mid-value, as a model hitting its
    // output cap would produce. The envelope is not valid JSON as a whole.
    let truncated =
      "{\"judgments\":[\(editorialObject(first)),\(editorialObject(second)),"
      + "{\"contentPieceID\":\"\(third.uuidString)\",\"admit\":tr"
    let judgments = try JudgmentResponseDecoder.decodeEditorial(
      truncated, expectedCandidateIDs: [first, second, third], allowedPersonalKnowledgeClaimIDs: [])
    let byID = Dictionary(uniqueKeysWithValues: judgments.map { ($0.contentPieceID, $0) })

    #expect(byID[first]?.errorDescription == nil)
    #expect(byID[second]?.errorDescription == nil)
    // The lost tail is never invented: it fails closed as "no judgment", which the engine re-requests.
    #expect(byID[third]?.admit == false)
    #expect(byID[third]?.errorDescription?.contains("no judgment") == true)
  }

  @Test("a response with no recoverable objects still fails the whole pass closed")
  func unrecoverableResponseThrows() {
    #expect(throws: (any Error).self) {
      try JudgmentResponseDecoder.decodeEditorial(
        "the model apologises and returns prose", expectedCandidateIDs: [UUID(1)],
        allowedPersonalKnowledgeClaimIDs: [])
    }
  }

  @Test("a truncated editorial first pass re-requests only the pieces it lost")
  func truncatedEditorialFirstPassIsRecovered() async {
    let first = candidate(id: UUID(1))
    let second = candidate(id: UUID(2))
    // The type pass classifies both; the editorial pass truncates after the first object, then the
    // re-request returns the piece the truncation dropped.
    let truncatedEditorial =
      "{\"judgments\":[\(editorialObject(first.id)),"
      + "{\"contentPieceID\":\"\(second.id.uuidString)\",\"admit\":tr"
    let retryEditorial = "{\"judgments\":[\(editorialObject(second.id))]}"
    let editorialCalls = Mutex(0)
    let engine = JudgmentEngine(modelClient: StubModelClient { request in
      guard case let .jsonSchema(name, _, _) = request.responseFormat else { return ModelResponse(text: "") }
      if name == "cockpit_type_classifications" {
        return ModelResponse(text: self.classificationResponse(for: [first.id, second.id]))
      }
      let call = editorialCalls.withLock { count -> Int in count += 1; return count }
      return ModelResponse(text: call == 1 ? truncatedEditorial : retryEditorial)
    })

    let run = await engine.judge(
      candidates: [first, second],
      personalKnowledge: .init(text: "", includedClaimIDs: [], isFullSet: true))

    #expect(editorialCalls.withLock { $0 } == 2)
    #expect(run.outcomes.map(\.contentPieceID) == [first.id, second.id])
    #expect(run.outcomes.allSatisfy { $0.errorDescription == nil })
  }

  @Test("provider usage is priced with Anthropic's separate cache buckets")
  func pricesAnthropicUsage() {
    let cost = JudgmentCostEstimator.estimate(
      usage: ModelUsage(
        inputTokens: 1_000_000, outputTokens: 1_000_000,
        cacheReadInputTokens: 1_000_000, cacheCreationInputTokens: 1_000_000
      ),
      requestedProvider: .anthropic
    )
    #expect(cost == 14.7)

    let unsupported = JudgmentCostEstimator.estimate(
      usage: ModelUsage(inputTokens: 10, outputTokens: 10), requestedProvider: .openai
    )
    #expect(unsupported == nil)
  }

  @Test("Personal Knowledge can alter the proposed relevance of the same candidate")
  func personalKnowledgeChangesRelevance() async {
    let id = UUID(1)
    let engine = JudgmentEngine(
      modelClient: StubModelClient { request in
        let knowsAboutBurgundy = request.messages.last?.text.contains("Burgundy travel and wine.") == true
        return ModelResponse(text: self.response(for: [id], admitted: knowsAboutBurgundy))
      }
    )
    let candidate = candidate(id: id, normalizedText: "A new guide to Burgundy growers.")

    let withoutKnowledge = await engine.judge(
      candidates: [candidate],
      personalKnowledge: .init(text: "", includedClaimIDs: [], isFullSet: true)
    )
    let withKnowledge = await engine.judge(
      candidates: [candidate],
      personalKnowledge: .init(
        text: "Interest:\n- Burgundy travel and wine.", includedClaimIDs: [], isFullSet: true
      )
    )

    #expect(withoutKnowledge.outcomes[0].admit == false)
    #expect(withKnowledge.outcomes[0].admit == true)
  }

  @Test("A claim-driven rationale reports the exact projected claim")
  func claimDrivenRationaleReportsMatchedClaim() async {
    let candidateID = UUID(1)
    let claimID = UUID(2)
    let rationale = "Because you explicitly care about adaptive-reuse hotels, this opening appears unusually relevant."
    let engine = JudgmentEngine(
      modelClient: StubModelClient.constant(
        """
        {"judgments":[{
          "contentPieceID":"\(candidateID.uuidString)","admit":true,
          "isSubstantivePrimary":true,"section":"forYou","rank":1,
          "rationale":"\(rationale)","matchedPersonalKnowledgeClaimID":"\(claimID.uuidString)",
          "subjects":["hotels","adaptive reuse","travel"],"summary":"A hotel opening.","finds":[]
        }]}
        """
      )
    )

    let run = await engine.judge(
      candidates: [candidate(id: candidateID)],
      personalKnowledge: .init(
        text: "Interest:\n- [Claim ID: \(claimID.uuidString)] Cares about adaptive-reuse hotels.",
        includedClaimIDs: [claimID], isFullSet: true
      )
    )

    #expect(run.outcomes[0].rationale == rationale)
    #expect(run.outcomes[0].matchedPersonalKnowledgeClaimID == claimID)
  }

  @Test("Judgment fails closed when it names a claim outside the projection")
  func unprojectedMatchedClaimFailsClosed() async {
    let candidateID = UUID(1)
    let claimID = UUID(2)
    let unprojectedID = UUID(3)
    let engine = JudgmentEngine(
      modelClient: StubModelClient.constant(
        """
        {"judgments":[{
          "contentPieceID":"\(candidateID.uuidString)","admit":true,
          "isSubstantivePrimary":true,"section":"forYou","rank":1,"rationale":"why",
          "matchedPersonalKnowledgeClaimID":"\(unprojectedID.uuidString)",
          "subjects":["one","two","three"],"summary":"summary","finds":[]
        }]}
        """
      )
    )

    let run = await engine.judge(
      candidates: [candidate(id: candidateID)],
      personalKnowledge: .init(text: "Interest: claim", includedClaimIDs: [claimID], isFullSet: true)
    )

    #expect(!run.outcomes[0].admit)
    #expect(run.outcomes[0].errorDescription?.contains("did not match the required shape") == true)
  }

  @Test("re-requests candidates the model omits from a batch")
  func reRequestsOmittedCandidates() async {
    let first = candidate(id: UUID(1))
    let second = candidate(id: UUID(2))
    let third = candidate(id: UUID(3))
    // The first pass silently drops `second`; the re-request asks for just the omitted candidate.
    let firstPassText = response(for: [first.id, third.id])
    let retryText = response(for: [second.id])
    let typeCalls = Mutex(0)
    let editorialCalls = Mutex(0)
    let engine = JudgmentEngine(modelClient: StubModelClient { request in
      guard case let .jsonSchema(name, _, _) = request.responseFormat else { return ModelResponse(text: "") }
      if name == "cockpit_type_classifications" {
        let call = typeCalls.withLock { count -> Int in count += 1; return count }
        return ModelResponse(text: call == 1 ? firstPassText : retryText)
      }
      let call = editorialCalls.withLock { count -> Int in count += 1; return count }
      return ModelResponse(text: call == 1 ? firstPassText : retryText)
    })

    let run = await engine.judge(
      candidates: [first, second, third],
      personalKnowledge: .init(text: "", includedClaimIDs: [], isFullSet: true))

    #expect(typeCalls.withLock { $0 } == 2)
    #expect(editorialCalls.withLock { $0 } == 2)
    #expect(run.outcomes.map(\.contentPieceID) == [first.id, second.id, third.id])
    #expect(run.outcomes.allSatisfy { $0.errorDescription == nil })
  }

  @Test("stops re-requesting when the model keeps omitting the same candidate")
  func stopsReRequestingUnrecoverableOmission() async {
    let first = candidate(id: UUID(1))
    let second = candidate(id: UUID(2))
    // The model never returns `second`, on the first pass or any re-request.
    let alwaysOmits = response(for: [first.id])
    let typeCalls = Mutex(0)
    let editorialCalls = Mutex(0)
    let engine = JudgmentEngine(modelClient: StubModelClient { request in
      guard case let .jsonSchema(name, _, _) = request.responseFormat else { return ModelResponse(text: "") }
      if name == "cockpit_type_classifications" {
        typeCalls.withLock { $0 += 1 }
      } else {
        editorialCalls.withLock { $0 += 1 }
      }
      return ModelResponse(text: alwaysOmits)
    })

    let run = await engine.judge(
      candidates: [first, second],
      personalKnowledge: .init(text: "", includedClaimIDs: [], isFullSet: true))

    // The type pass retries its omission once; editorial then judges only the one classified piece.
    #expect(typeCalls.withLock { $0 } == 2)
    #expect(editorialCalls.withLock { $0 } == 1)
    #expect(run.outcomes[0].errorDescription == nil)
    #expect(run.outcomes[1].errorDescription?.contains("no judgment") == true)
  }

  private func candidate(id: UUID, normalizedText: String = "A concrete original article.") -> JudgmentCandidate {
    JudgmentCandidate(
      id: id, kind: "article", title: "Fixture \(id)", publisher: "Publisher",
      normalizedText: normalizedText,
      stream: StreamContext(
        name: "Stream", handling: "following", handlingGuidance: "Read original arguments.",
        isEssential: false
      ),
      interestArea: InterestAreaContext(name: "General", guidance: "Useful context.")
    )
  }

  private func judgmentObject(id: UUID, admitted: Bool = true) -> String {
    """
    {"contentPieceID":"\(id.uuidString)","admit":\(admitted),"isSubstantivePrimary":true,"section":"forYou","rank":1,"rationale":"You follow this original argument.","subjects":["policy","cities","housing"],"summary":"A concise summary.","finds":[]}
    """
  }

  private func response(for ids: [UUID], admitted: Bool = true) -> String {
    let judgments = ids.map { judgmentObject(id: $0, admitted: admitted) }.joined(separator: ",")
    return "{\"judgments\":[\(judgments)]}"
  }

  private func classificationResponse(for ids: [UUID]) -> String {
    let classifications = ids.map {
      "{\"contentPieceID\":\"\($0.uuidString)\",\"isSubstantivePrimary\":true,\"subjects\":[\"policy\",\"cities\",\"housing\"],\"summary\":\"A concise summary.\"}"
    }.joined(separator: ",")
    return "{\"classifications\":[\(classifications)]}"
  }

  /// A single, minimal, valid editorial-pass object — enough for the decoder's required shape.
  private func editorialObject(_ id: UUID) -> String {
    "{\"contentPieceID\":\"\(id.uuidString)\",\"admit\":true,\"section\":\"forYou\",\"rank\":1,\"rationale\":\"r\",\"matchedPersonalKnowledgeClaimID\":null,\"finds\":[]}"
  }

}

/// The paid, real-model eval. Gated on `COCKPIT_RUN_JUDGMENT_EVAL=1` so it is *skipped*
/// (not silently passed) in an ordinary `swift test`; the key comes from the environment or
/// the stored Keychain key. Enable it to produce the first agreement number for `docs/eval-log.md`.
@Suite("JudgmentEval")
struct JudgmentEvalLiveTests {
  /// One composition-sized batch → two model calls (type then editorial). §7's working estimate is
  /// ~60 new items/day. The M4 split makes the editorial call carry ~2× the input of the old single
  /// pass (full bodies + the PK projection + type metadata), and a taught 50-candidate editorial
  /// call ran ~176s and timed a whole batch closed (eval-log, 2026-09-16). 30 keeps each editorial
  /// call inside a workable latency while still exercising a realistic finite package; the type call
  /// is cheaper and tolerates more. The deeper lever — trimming the body the editorial pass resends,
  /// or an Interest-Area split with a second pass (JUDGMENT-CONTRACT §1) — is parked for Jon.
  // Override with COCKPIT_EVAL_BATCH to probe a different size without a rebuild.
  static let compositionSize = ProcessInfo.processInfo.environment["COCKPIT_EVAL_BATCH"].flatMap(Int.init) ?? 30

  /// The frozen corpus has a few rows Jon never fully labelled (no confirmed `label` +
  /// `isSubstantivePrimary`). They are permanently `incomplete` for scoring and are a property of
  /// the corpus, not of the split, the model, or fail-closed — so the reports carry them every run.
  /// Asserting exactly zero would wrongly claim the corpus is fully labelled; we gate on "no worse
  /// than the known unlabelled floor" so re-labelling can only lower it.
  static let knownUnlabelledFixtureCount = 3

  private static let enabled = ProcessInfo.processInfo.environment["COCKPIT_RUN_JUDGMENT_EVAL"] == "1"

  @Test("runs the frozen corpus against Claude Sonnet 5 in composition-sized batches", .enabled(if: enabled))
  func runFrozenCorpus() async throws {
    let apiKey = try #require(
      ProcessInfo.processInfo.environment["COCKPIT_ANTHROPIC_API_KEY"] ?? APIKeyStore.live().key(.anthropic),
      "Set COCKPIT_ANTHROPIC_API_KEY (or store an Anthropic key) before the paid JudgmentEval run.")

    let fixtures = try load(JudgmentFixtureExport.self, named: "fixtures")
    let labels = try load(JudgmentLabelExport.self, named: "labels")
    let engine = JudgmentEngine(
      modelClient: AnthropicModelClient(apiKey: apiKey, model: JudgmentModel.modelID))
    let candidates = fixtures.fixtures.map(Self.candidate(from:))

    let empty = PersonalKnowledgeProjection(text: "", includedClaimIDs: [], isFullSet: true)
    let control = await Self.judgeCorpus(
      candidates, personalKnowledge: empty, engine: engine, singlePassControl: true)
    let split = await Self.judgeCorpus(candidates, personalKnowledge: empty, engine: engine)
    let controlReport = Self.report(for: control, fixtures: fixtures.fixtures, labels: labels.labels)
    let splitReport = Self.report(for: split, fixtures: fixtures.fixtures, labels: labels.labels)
    let splitFailClosed = split.outcomesByID.values.filter { $0.errorDescription != nil }

    print("""
      JudgmentEvalControl singlePass=[\(controlReport.rendered)] split=[\(splitReport.rendered)] \
      splitTypeCost=\(split.typeCost) splitEditorialCost=\(split.editorialCost) \
      singlePassLatencyMaxSeconds=\(String(format: "%.3f", control.maxLatency)) \
      splitLatencyMaxSeconds=\(String(format: "%.3f", split.maxLatency)) \
      failClosed(single/split)=\(control.failClosedCount)/\(splitFailClosed.count) \
      model=\(JudgmentModel.displayName) singlePassPromptVersion=\(JudgmentEngine.singlePassControlPromptVersion) \
      typePromptVersion=\(JudgmentEngine.typePromptVersion) editorialPromptVersion=\(JudgmentEngine.editorialPromptVersion)
      """)

    #expect(splitReport.incompleteFixtureCount <= Self.knownUnlabelledFixtureCount)
    #expect(
      splitFailClosed.isEmpty,
      "\(splitFailClosed.count) split pieces failed closed: \(splitFailClosed.compactMap(\.errorDescription).prefix(3).joined(separator: " | "))")
    #expect(
      (splitReport.essentialFalseQuietRate ?? 1) <= (controlReport.essentialFalseQuietRate ?? 0) + 0.001,
      "Split pass regressed essential-false-quiet versus its same-session single-pass control.")
    #expect(split.costPerComposition < 1, "Gate 1 cost estimate must stay below $1.00 per composition.")
    // Latency is RECORDED, not hard-gated at 60s here (DC-3: "confirm within the §7 budget or note
    // the lever"). The split runs type-then-editorial sequentially per composition — editorial needs
    // the type metadata first — so it inherently ~doubles per-composition latency versus single-pass,
    // and the offsetting win (moving the PK-free type pass to a faster/cheaper model) is deferred
    // behind the schema blocker. The §7 "<60s on a warm device" budget is Jon's device-pass call on
    // real hardware, not this Mac+API+concurrency measurement. We still guard against a pathological
    // hang (a true timeout fails a batch closed and is caught above); a lone composition over ~4min
    // is a regression worth surfacing.
    #expect(
      split.maxLatency < 240,
      "Split composition latency \(String(format: "%.1f", split.maxLatency))s is pathological, not just the two-pass cost — investigate a hang or model-side slowdown.")
  }

  @Test("Personal Knowledge moves at least one real admission or rank", .enabled(if: enabled))
  func personalKnowledgeMovesRealRelevance() async throws {
    let apiKey = try #require(
      ProcessInfo.processInfo.environment["COCKPIT_ANTHROPIC_API_KEY"] ?? APIKeyStore.live().key(.anthropic))
    let fixtures = try load(JudgmentFixtureExport.self, named: "fixtures")
    let engine = JudgmentEngine(
      modelClient: AnthropicModelClient(apiKey: apiKey, model: JudgmentModel.modelID))
    // One composition-sized slice keeps this probe cheap (two calls).
    let slice = Array(fixtures.fixtures.prefix(Self.compositionSize).map(Self.candidate(from:)))
    let empty = PersonalKnowledgeProjection(text: "", includedClaimIDs: [], isFullSet: true)

    let bare = await engine.judge(candidates: slice, personalKnowledge: empty)
    // Teach an interest built from a piece the bare pass did NOT admit, so a change is meaningful.
    let seed = bare.outcomes.first { $0.admit == false && !($0.subjects ?? []).isEmpty }
      ?? bare.outcomes.first
    let taughtSubjects = (seed?.subjects ?? ["technology"]).prefix(4).joined(separator: ", ")
    let taught = await engine.judge(
      candidates: slice,
      personalKnowledge: .init(
        text: "Interest:\n- Strong, active interest in \(taughtSubjects).",
        includedClaimIDs: [], isFullSet: true))

    let bareByID = Dictionary(uniqueKeysWithValues: bare.outcomes.map { ($0.contentPieceID, $0) })
    let moved = taught.outcomes.filter { after in
      guard let before = bareByID[after.contentPieceID] else { return false }
      return before.admit != after.admit || before.rank != after.rank
    }
    print("PKSensitivity taughtSubjects=\"\(taughtSubjects)\" movedPieces=\(moved.count) admissionFlips=\(moved.filter { bareByID[$0.contentPieceID]?.admit != $0.admit }.count)")
    #expect(
      !moved.isEmpty,
      "No admission or rank moved when Personal Knowledge was added — PK may be decorative (Gate-2 question).")
  }

  // The S5 / Architecture Gate 2 measurement (DECISIONS §22). Unlike the probe above, this judges
  // the WHOLE frozen corpus twice — bare, then with a REAL grown claim set projected in through
  // `PersonalKnowledgeProjector` (so the `[Claim ID: …]` lines and the S5 matched-claim path are
  // exercised on real data) — and reports what the claim set moved. Opt in by pointing
  // COCKPIT_PK_CLAIMS_JSON at a JSON array of {"kind":"interest|taste|fact","claim":"…","scope":"…"?}.
  // Cost is ~2× a single corpus run (bare + taught); cap it for a cheap first pass with
  // COCKPIT_PK_EVAL_LIMIT=N. The headline to hold is essential-false-quiet ≤ 0.068 WITH the grown
  // set; agreement is reported as context only (§22).
  private static let pkClaimsPath = ProcessInfo.processInfo.environment["COCKPIT_PK_CLAIMS_JSON"]
  private static let pkGrownEnabled = enabled && (pkClaimsPath.map { !$0.isEmpty } ?? false)

  @Test(
    "measures the frozen corpus against a real grown claim set (bare vs taught)",
    .enabled(if: pkGrownEnabled))
  func runFrozenCorpusWithGrownPersonalKnowledge() async throws {
    let apiKey = try #require(
      ProcessInfo.processInfo.environment["COCKPIT_ANTHROPIC_API_KEY"] ?? APIKeyStore.live().key(.anthropic),
      "Set COCKPIT_ANTHROPIC_API_KEY (or store an Anthropic key) before the paid JudgmentEval run.")
    let claimsPath = try #require(
      Self.pkClaimsPath, "Set COCKPIT_PK_CLAIMS_JSON to a claims file to run the grown-PK eval.")

    let claims = try Self.loadClaims(fromJSONAt: claimsPath)
    let projection = PersonalKnowledgeProjector.project(claims)
    #expect(!projection.includedClaimIDs.isEmpty, "The claims file produced no current claims to project.")

    let fixtures = try load(JudgmentFixtureExport.self, named: "fixtures")
    let labels = try load(JudgmentLabelExport.self, named: "labels")
    var candidates = fixtures.fixtures.map(Self.candidate(from:))
    if let limit = ProcessInfo.processInfo.environment["COCKPIT_PK_EVAL_LIMIT"].flatMap(Int.init) {
      candidates = Array(candidates.prefix(limit))
    }

    let engine = JudgmentEngine(
      modelClient: AnthropicModelClient(apiKey: apiKey, model: JudgmentModel.modelID))
    let empty = PersonalKnowledgeProjection(text: "", includedClaimIDs: [], isFullSet: true)

    let bare = await Self.judgeCorpus(candidates, personalKnowledge: empty, engine: engine)
    let taught = await Self.judgeCorpus(candidates, personalKnowledge: projection, engine: engine)

    // Metrics for each run. essential-false-quiet on the TAUGHT run is the floor to hold (§22);
    // the bare run is computed from stored outcomes at no extra model cost, for the delta.
    let bareReport = Self.report(for: bare, fixtures: fixtures.fixtures, labels: labels.labels)
    let taughtReport = Self.report(for: taught, fixtures: fixtures.fixtures, labels: labels.labels)

    // What the grown claim set actually moved, and how often the model attributed an admission to
    // a specific projected claim (the S5 surface Jon steers from).
    let moved = taught.outcomesByID.values.filter { after in
      guard let before = bare.outcomesByID[after.contentPieceID] else { return false }
      return before.admit != after.admit || before.rank != after.rank
    }
    let admissionFlips = moved.filter { bare.outcomesByID[$0.contentPieceID]?.admit != $0.admit }
    let attributed = taught.outcomesByID.values.filter { $0.admit && $0.matchedPersonalKnowledgeClaimID != nil }
    let distinctCitedClaims = Set(attributed.compactMap(\.matchedPersonalKnowledgeClaimID))
    let taughtFailClosed = taught.outcomesByID.values.filter { $0.errorDescription != nil }.count
    let bareFailClosed = bare.outcomesByID.values.filter { $0.errorDescription != nil }.count

    print("""
      JudgmentEvalPKGrown taught=[\(taughtReport.rendered)] bare=[\(bareReport.rendered)] \
      claims=\(claims.count) includedClaimIDs=\(projection.includedClaimIDs.count) \
      movedPieces=\(moved.count) admissionFlips=\(admissionFlips.count) \
      attributedAdmissions=\(attributed.count) distinctCitedClaims=\(distinctCitedClaims.count) \
      failClosed(taught/bare)=\(taughtFailClosed)/\(bareFailClosed) \
      taughtFailClosedReasons=\(Self.failClosedReasons(taught)) \
      bareFailClosedReasons=\(Self.failClosedReasons(bare)) \
      costTotal=\(bare.totalCost + taught.totalCost) \
      latencyMaxSeconds=\(String(format: "%.3f", max(bare.maxLatency, taught.maxLatency))) \
      batchSize=\(Self.compositionSize) \
      model=\(JudgmentModel.displayName) typePromptVersion=\(JudgmentEngine.typePromptVersion) \
      editorialPromptVersion=\(JudgmentEngine.editorialPromptVersion)
      """)

    #expect(taughtReport.incompleteFixtureCount <= Self.knownUnlabelledFixtureCount)
    // Reliability gate, checked BEFORE the floor. A fail-closed piece is scored not-admitted, so it
    // lands as false-quiet and inflates essential-false-quiet — a reliability failure would otherwise
    // masquerade as a PK floor regression (as it did at batchSize 50: one editorial batch timed out,
    // 50 pieces failed closed, and essential-false-quiet read 0.169 vs a true bare 0.051). The floor
    // comparison below is only trustworthy when both runs fully resolved.
    #expect(
      taughtFailClosed == 0 && bareFailClosed == 0,
      """
      Pieces failed closed (taught \(taughtFailClosed) / bare \(bareFailClosed)); the floor number is \
      not a clean PK measurement until this is 0. Reasons — taught: \(Self.failClosedReasons(taught)); \
      bare: \(Self.failClosedReasons(bare)).
      """)
    // The reframed gate (DECISIONS §22), measured as a PAIRED delta rather than an absolute
    // constant: growing PK must not push essential-false-quiet above the *same-session bare run*.
    // essential-false-quiet is a small-count metric here (~3–6 pieces of ~59 Essential-substantive),
    // so it swings run-to-run on model nondeterminism (0.051 / 0.068 / 0.102 across clean runs); a
    // hardcoded absolute threshold would pass or fail on that noise. The bare run is the control.
    // Only meaningful when fail-closed is 0 above.
    let epsilon = 0.001
    #expect(
      (taughtReport.essentialFalseQuietRate ?? 1) <= (bareReport.essentialFalseQuietRate ?? 0) + epsilon,
      "Grown PK regressed essential-false-quiet vs the paired bare run (taught \(taughtReport.essentialFalseQuietRate.map { "\($0)" } ?? "nil") > bare \(bareReport.essentialFalseQuietRate.map { "\($0)" } ?? "nil")).")
    // "Not decorative": the real claim set has to move at least something.
    #expect(
      !moved.isEmpty,
      "The grown claim set moved no admission or rank — PK reads as decorative (Gate-2 question).")
  }

  private struct CorpusRun {
    var outcomesByID: [UUID: JudgmentOutcome]
    var totalCost: Decimal
    var costPerComposition: Decimal
    var maxLatency: TimeInterval
    var typeCost: Decimal
    var editorialCost: Decimal
    var failClosedCount: Int
  }

  /// How many compositions judge concurrently within one corpus run. The batches are independent
  /// (each is a self-contained composition; nothing is shared or mutated), so judging them in
  /// parallel only trades wall time for in-flight requests at identical dollar cost. Capped, and
  /// deliberately modest: a rate-limit rejection would fail a batch closed and trip the reliability
  /// gate, so the default stays well under Anthropic's ceiling. Override with COCKPIT_EVAL_CONCURRENCY.
  /// Runs (bare/taught, control/split) stay sequential so total in-flight is exactly this number.
  static let evalConcurrency = ProcessInfo.processInfo.environment["COCKPIT_EVAL_CONCURRENCY"].flatMap(Int.init) ?? 4

  private static func judgeOneComposition(
    _ batch: [JudgmentCandidate], personalKnowledge: PersonalKnowledgeProjection,
    engine: JudgmentEngine, singlePassControl: Bool
  ) async -> JudgmentRun {
    if singlePassControl {
      await engine.judgeSinglePassControl(candidates: batch, personalKnowledge: personalKnowledge)
    } else {
      await engine.judge(candidates: batch, personalKnowledge: personalKnowledge)
    }
  }

  private static func judgeCorpus(
    _ candidates: [JudgmentCandidate],
    personalKnowledge: PersonalKnowledgeProjection,
    engine: JudgmentEngine,
    singlePassControl: Bool = false
  ) async -> CorpusRun {
    let batches = candidates.chunked(into: compositionSize)
    // Bounded-concurrency sliding window: keep at most `evalConcurrency` compositions in flight,
    // starting the next batch each time one finishes. `run.latency` is each composition's own wall
    // time, so the per-composition budget stays honest under parallelism.
    let runs = await withTaskGroup(of: JudgmentRun.self) { group -> [JudgmentRun] in
      var collected: [JudgmentRun] = []
      var next = 0
      let window = max(1, min(evalConcurrency, batches.count))
      while next < window {
        let batch = batches[next]
        group.addTask {
          await judgeOneComposition(
            batch, personalKnowledge: personalKnowledge, engine: engine, singlePassControl: singlePassControl)
        }
        next += 1
      }
      while let run = await group.next() {
        collected.append(run)
        if next < batches.count {
          let batch = batches[next]
          group.addTask {
            await judgeOneComposition(
              batch, personalKnowledge: personalKnowledge, engine: engine, singlePassControl: singlePassControl)
          }
          next += 1
        }
      }
      return collected
    }

    var outcomesByID: [UUID: JudgmentOutcome] = [:]
    var totalCost: Decimal = 0
    var maxLatency: TimeInterval = 0
    var typeCost: Decimal = 0
    var editorialCost: Decimal = 0
    for run in runs {
      for outcome in run.outcomes { outcomesByID[outcome.contentPieceID] = outcome }
      totalCost += run.estimatedCost ?? 0
      maxLatency = max(maxLatency, run.latency)
      typeCost += run.typePass.estimatedCost ?? 0
      editorialCost += run.editorialPass.estimatedCost ?? 0
    }
    let per = runs.isEmpty ? 0 : totalCost / Decimal(runs.count)
    return CorpusRun(
      outcomesByID: outcomesByID, totalCost: totalCost, costPerComposition: per, maxLatency: maxLatency,
      typeCost: typeCost, editorialCost: editorialCost,
      failClosedCount: outcomesByID.values.count(where: { $0.errorDescription != nil }))
  }

  /// Groups fail-closed error messages with counts so a paid run tells us *why* pieces dropped
  /// (whole-batch timeout vs transport vs an unprojected-claim rejection) without another run.
  private static func failClosedReasons(_ run: CorpusRun) -> String {
    let reasons = run.outcomesByID.values.compactMap(\.errorDescription)
    guard !reasons.isEmpty else { return "none" }
    return Dictionary(grouping: reasons, by: { $0 })
      .map { "\($0.value.count)×\"\($0.key)\"" }
      .sorted()
      .joined(separator: ", ")
  }

  private static func report(
    for run: CorpusRun, fixtures: [JudgmentFixture], labels: [JudgmentFixtureLabel]
  ) -> JudgmentEvaluationReport {
    JudgmentEvaluation.evaluate(fixtures: fixtures, labels: labels, costPerComposition: run.costPerComposition) {
      fixture in
      let outcome = run.outcomesByID[fixture.id]
      // A fail-closed piece has no classification; count it not-admitted / not-substantive so it
      // cannot silently improve the numbers.
      return StubJudgment(
        admits: outcome?.admit ?? false,
        isSubstantivePrimary: outcome?.isSubstantivePrimary ?? false, cost: 0)
    }
  }

  private struct PKClaimSeed: Decodable {
    let kind: PersonalKnowledgeKind
    let claim: String
    let scope: String?
  }

  /// Builds current claims from a hand-authored / Jon-Brain-pasted JSON file. IDs are deterministic
  /// so the projection's `[Claim ID: …]` lines — and therefore the recorded run — are reproducible;
  /// provenance is cosmetic here (the projection never reads it).
  private static func loadClaims(fromJSONAt path: String) throws -> [PersonalKnowledgeClaim] {
    let seeds = try JSONDecoder().decode([PKClaimSeed].self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    let base = Date(timeIntervalSince1970: 1_700_000_000)
    return seeds.enumerated().map { index, seed in
      PersonalKnowledgeClaim(
        id: UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", index + 1))") ?? UUID(),
        kind: seed.kind, claim: seed.claim, scope: seed.scope,
        provenance: .directTeaching, status: .current,
        createdAt: base.addingTimeInterval(Double(index)))
    }
  }

  private static func candidate(from fixture: JudgmentFixture) -> JudgmentCandidate {
    JudgmentCandidate(
      id: fixture.id, kind: fixture.kind, title: fixture.title, creator: fixture.creator,
      publisher: fixture.publisher, publishedAt: fixture.publishedAt,
      normalizedText: fixture.normalizedText,
      stream: .init(
        name: fixture.stream.name, handling: fixture.stream.handling,
        handlingGuidance: fixture.stream.handlingGuidance, isEssential: fixture.stream.isEssential),
      interestArea: .init(name: fixture.interestArea.name, guidance: fixture.interestArea.guidance),
      carriedEntry: fixture.carriedEntry.map {
        .init(timesCarried: $0.timesCarried, entryState: $0.entryState)
      })
  }

  private func load<T: Decodable>(_ type: T.Type, named name: String) throws -> T {
    let url = try #require(
      Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/judgment")
    )
    // The corpus stores dates as ISO8601 strings (matching the harvest's `FixtureFiles`).
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(T.self, from: Data(contentsOf: url))
  }

}

private extension Array {
  func chunked(into size: Int) -> [[Element]] {
    guard size > 0 else { return [self] }
    return stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
  }
}
