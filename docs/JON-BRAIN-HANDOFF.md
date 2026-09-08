# Jon Brain Handoff

**Status:** Normative V1 workflow  
**Date:** 2026-09-08

V1 supports a deliberately simple, human-mediated way to bootstrap Cockpit Personal Knowledge from ChatGPT or another AI system.

This lands in **Phase 1**, before the first Edition is composed. It is the cheapest way to give judgment real taste to work with on day one instead of month two.

This is **not** a direct integration with ChatGPT memory/accounts. Clipboard is the initial transport.

---

## 1. Goal

Jon already has substantial explicit durable personal context in AI conversations. Cockpit should not require relearning all of it one claim at a time.

The V1 workflow is:

```text
ChatGPT / another AI
→ produce explicit synthesized personal claims
→ Jon copies them
→ Cockpit “Teach / Import Personal Knowledge”
→ semantic reconciliation against current PK
→ review meaningful changes
→ commit durable Personal Knowledge
```

Authority remains clear:

- external AI proposes what it understands;
- Jon explicitly transfers the material;
- Cockpit reconciles it with Cockpit's own canonical Personal Knowledge;
- Cockpit remains authoritative for its durable PK state.

---

## 2. Standing ChatGPT convention

Jon may place the following instruction in ChatGPT's standing personal instructions/memory guidance:

> When I say **“Jon Brain”**, produce a compact, copyable export of durable things you currently understand about me that would be useful to another personal AI system.
>
> Use one bullet per distinct claim and prefix each bullet with exactly one of:
>
> - **[Fact]** — durable factual information or constraints
> - **[Taste]** — durable preferences, likes, dislikes, or decision tendencies
> - **[Interest]** — subjects or domains I have explicitly stated or confirmed meaningful interest in
>
> Rules:
>
> - Include only information grounded in things I have explicitly told you, explicitly corrected, or clearly confirmed in conversation.
> - Do not infer durable knowledge merely from clicks, browsing behavior, frequency of questions, or other weak behavioral signals.
> - Synthesize and deduplicate overlapping statements rather than reproduce conversation history.
> - Preserve important scope and nuance. Do not turn a contextual preference into a broad universal claim.
> - Prefer the current understanding when I have corrected or refined something previously.
> - Exclude temporary Current Context such as where I am today, a trip happening this week, or a short-lived task unless I specifically ask for it.
> - Exclude sensitive information unless I explicitly ask you to include it in that export.
> - Return only copyable bullets unless I request explanation.
> - Aim for useful semantic claims rather than exhaustive trivia.
>
> Example:
>
> - [Fact] Home airport is RDU.
> - [Taste] Prefers smaller, characterful countryside luxury hotels over large corporate-feeling properties.
> - [Taste] For dry Riesling, generally prefers some fruit and generosity rather than severe austerity.
> - [Interest] Has a meaningful ongoing interest in Burgundy travel and wine.

The exact wording may evolve outside Cockpit. The product contract is the natural-language claim set, not a proprietary export schema.

---

## 3. Cockpit import surface

V1 should expose a simple natural-language bulk-teaching surface, conceptually:

> **Teach Cockpit / Import Personal Knowledge**

Paste text.

Cockpit should accept ordinary bullet prose and not require a versioned JSON format.

The `[Fact]`, `[Taste]`, `[Interest]` prefixes are helpful hints for the initial workflow, not a permanent protocol requirement. Cockpit should be capable of interpreting equivalent natural-language claims from another AI or document.

---

## 4. Reconciliation behavior

Cockpit compares incoming claims semantically against existing Personal Knowledge.

Possible outcomes:

### Duplicate / reinforcement

No new user decision needed. Preserve useful provenance if appropriate.

### Clerical consolidation

Cockpit may automatically merge/rephrase compatible explicit claims when semantic meaning is preserved.

### Refinement

An incoming claim materially improves scope/precision of an existing understanding.

Show the meaningful change when review is warranted.

### New substantive claim

Show for acceptance before it becomes durable Personal Knowledge.

### Contradiction / correction

Surface clearly. Jon decides/corrects; accepted correction supersedes the old current understanding while preserving provenance.

The UI should avoid forcing review of dozens of obvious duplicates merely because the import contained many bullets.

---

## 5. Example reconciliation

Existing Cockpit claim:

> Prefers small luxury hotels.

Imported Jon Brain claim:

> Prefers smaller, characterful countryside luxury hotels over large corporate-feeling properties.

Desired behavior:

> **Refine existing Taste**
>
> From: Prefers small luxury hotels.
>
> To: Prefers smaller, characterful countryside luxury hotels over large corporate-feeling properties.

Cockpit should not create two near-duplicate durable claims.

---

## 6. What the LLM may do automatically

During import, the LLM may:

- parse natural language;
- identify Fact/Taste/Interest intent;
- detect semantic duplicates;
- consolidate compatible claims;
- preserve/propose appropriate scope;
- generate a cleaner wording;
- identify possible contradictions.

It may not silently turn ambiguous text into materially broader durable claims.

Canonical writes remain deterministic application operations after the relevant explicit user authority/review.

---

## 7. Why V1 stays manual

Do not add for V1:

- ChatGPT account authentication;
- direct access to ChatGPT memory/profile data;
- two-way Personal Knowledge synchronization;
- a formal `JonBrainExport` JSON protocol;
- shared external-AI handoff infrastructure;
- background synchronization between AI systems.

The manual copy/paste boundary is useful because it is explicit, inspectable, portable, and keeps ownership unambiguous while Cockpit's PK model is still being proven.

---

## 8. Product test

A successful Jon Brain import should feel like:

> “Cockpit learned a meaningful amount about me without making me curate dozens of duplicate profile rows.”

It should not let the imported text dictate or expand the Personal Knowledge schema merely because external AI phrased something richly.
