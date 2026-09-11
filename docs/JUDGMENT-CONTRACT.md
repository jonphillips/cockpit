# Cockpit Judgment Contract

**Status:** Normative
**Date:** 2026-09-08

Judgment is the single structured LLM pass that turns new ContentPieces into an Edition. It is the highest-variance component in Cockpit and the one that makes it different from a feed reader with a read-later list. It therefore gets a contract and an evaluation harness rather than a line in a pipeline diagram.

---

## 1. Invocation

Once per Edition composition, batched. Not per-piece.

```
compose(date):
  candidates = ContentPieces created since last composition
             + carried entries from the previous Edition
  projection = personalKnowledgeProjection()
  context    = currentContextProjections()
  result     = judge(candidates, projection, context, targetSize)
  write Edition + EditionEntries in one transaction
```

Batching is load-bearing: the model is choosing a *finite package* against `Edition.targetSize`, which requires seeing the candidates together. Per-piece scoring followed by a sort produces a ranked feed, which is the product Cockpit is explicitly not.

If the candidate set exceeds roughly 120 pieces, split into batches by Interest Area, then run one short second pass over the survivors to enforce the size target and section balance.

---

## 2. Inputs

**Per candidate:** id, kind, title, creator, publisher, publishedAt, first ~1500 characters of `normalizedText`, Stream name, Stream `handling` and `handlingGuidance`, Stream `isEssential`, Interest Area name and guidance, and — for carried entries — how many times carried and current `entryState`.

**Personal Knowledge projection:** the full set of current claims rendered as labelled prose, grouped Fact / Taste / Interest. Full set until the claim count exceeds 150; past that, retrieve a relevant subset by subject overlap and record which claims were included. This threshold is a guess and is measured at Gate 2.

**Current Context:** small projections from specialist apps, when a concrete slice needs them.

**Target:** `Edition.targetSize`, default 20.

Judgment never receives clickstream, dwell time, or open history. Per Product Law 12 those are not durable knowledge, and admitting them here would launder them into ranking through the back door.

---

## 3. Structured output

One object per candidate. Decoded strictly; a decode failure fails the piece to `admit: false` with a recorded error, never a silent drop.

```json
{
  "contentPieceID": "…",
  "admit": true,
  "isSubstantivePrimary": true,
  "section": "essentials | forYou | interestArea | essentialBacklog",
  "rank": 3,
  "rationale": "From Matthew Yglesias, marked Essential; original argument rather than a roundup.",
  "subjects": ["housing policy", "zoning", "us politics"],
  "summary": "…",
  "finds": [
    {
      "kind": "restaurant",
      "name": "…",
      "descriptor": "…",
      "rationale": "…",
      "sourceURL": "…",
      "hints": { "city": "…" }
    }
  ]
}
```

`rationale` is written for Jon, not for a debugger. It surfaces in the Reader and in "why am I seeing this," and it is what he corrects against. It states product logic — Stream posture, Interest Area, which explicit knowledge matched — and never model scoring internals.

`finds` is populated from Phase 1. Extraction shares this call, so the marginal cost is near zero, and the orphan-Find population starts accumulating on day one rather than in month five. Handoff to a specialist app remains Phase 6; V1 Phase 1 only persists PendingFinds and lists them.

Non-admitted candidates still return `isSubstantivePrimary`, `subjects`, and `summary`. That data is written to the ContentPiece regardless, so quiet material is still searchable in Library and still eligible for carryover reconsideration.

---

## 4. Prompt skeleton

Held in Cockpit, not in `LLMClientKit`. Versioned; `Edition` records the prompt version used.

```
You are composing today's edition of a personal newspaper for one reader.

Editorial posture:
  finite over comprehensive; the reader should finish it
  explicit stated intent constrains inferred relevance
  target ~{targetSize} admitted pieces

What you know about the reader (explicitly taught, never inferred):
  {personal knowledge projection}

Current situation:
  {current context projections}

Streams and why he follows them:
  {stream name, handling, stream handlingGuidance, essential,
   interest area name, interest area guidance}

Candidates:
  {candidates}

Rules:
  Essential Streams: admit all substantive primary material regardless of
    target size. Judge substantive vs accessory honestly.
  Stream handling overrides generic interest matching.
  Prefer omitting a weak piece to padding toward the target.
  Rationale is addressed to the reader.
```

---

## 5. Persistence

`EditionEntry.rationale` holds the rationale. `ContentPiece.subjects`, `.summary`, `.isSubstantivePrimary` are written from the same pass. Judgment output is never re-derived for display; a past Edition explains itself from what was stored.

Re-judgment happens only on explicit user action ("reconsider this"), on a prompt version change, or on the next composition for carried entries. Personal Knowledge changing does not retroactively recompose a past Edition.

---

## 6. Evaluation harness

This exists from Phase 1. It is the highest-leverage artifact in the project and the mechanism by which improving models are actually cashed in.

**Fixture set.** 200 real ContentPieces drawn from Jon's actual Streams across at least two weeks, frozen in `Tests/Fixtures/judgment/`. Real material, not synthetic.

"Across at least two weeks" constrains the **span of the corpus, not when it is collected**. Harvesting two weeks of history is not a weaker substitute for waiting two weeks; it is the better source, because history already carries evidence of what Jon did with each item. Nothing about this fixture set is gated on the calendar. This paragraph exists because the original sentence was once read as a schedule and produced a fourteen-day gate that should never have existed.

**Labels.** Jon labels each `surface` / `quiet` / `never`, plus `isSubstantivePrimary`. Single-user ground truth is a genuine structural advantage here: no product company can get this.

**Harness.** `swift test --filter JudgmentEval` runs the fixture set against the current prompt and model and reports agreement rate, false-quiet rate on Essential material, false-surface rate, substantive-primary accuracy, mean pieces admitted vs target, and cost per composition.

**False-quiet on Essential material is the metric that matters.** It is the one failure that breaks a promise rather than producing a mediocre edition.

**Use.** Run on every prompt change and every model change. A new model is adopted when it improves agreement without regressing false-quiet. Record each run in `docs/eval-log.md` with date, model, prompt version, and numbers.

The fixture set is refreshed when labels drift, which is itself evidence that taste has changed and Personal Knowledge is stale.

---

## 7. Cost and latency budget

Do the arithmetic before Phase 1, not after.

Working estimate: ~40 Streams, ~60 new items/day, ~1500 characters per candidate, plus the PK projection. That lands near 120–150k input tokens per composition, once daily.

Budget: **under $1.00 per composition and under 60 seconds on a warm device.** Composition cost is recorded on `Edition` and shown in Settings.

If the real number materially exceeds the budget, the levers in order are: a cheap deterministic pre-filter (drop items whose Stream handling plainly excludes them before the model sees them), shorter candidate excerpts, a smaller model for the substantive-primary and subject extraction pass with a stronger model reserved for selection, and only then reducing Stream count.

Per house convention, judgment runs on Sonnet by default. The eval harness is what makes changing that decision cheap.

---

## 8. What this contract does not license

Judgment does not write Personal Knowledge, apply Gmail dispositions, admit anything to Library, or hand off a Find. It proposes; deterministic operations act under established authority. `ARCHITECTURE.md` §9 is unchanged.
