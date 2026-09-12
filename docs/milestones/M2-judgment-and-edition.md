# M2 — Judgment and Edition

> **DRAFT for architect review.** Drafted 2026-09-12 while the S4 corpus was being harvested.
> Slice boundaries, ordering, and the M2/M3 cutline below are proposals, not ratified. The numbers
> and states are taken from the contracts and are not up for reinterpretation here.

## What M2 is

M1 built the persistence spine and the destinations, and froze a labelled fixture corpus, all
against a **stubbed** judge. M2 turns that corpus and a **real model** into a composed, readable
Edition — and produces the project's first agreement number.

The spine M2 completes:

```text
Personal Knowledge (direct teaching + Jon Brain import)
→ judgment (real model call, per docs/JUDGMENT-CONTRACT.md)
→ Edition + EditionEntries, composed once daily, materialized
→ Reader
→ Seen / Dismiss / carryover / Essential
→ Pending Finds (extraction only)
```

This is the second half of V1 Phase 1. It ends at **Architecture Gate 1** — the first checkpoint
empowered to change the model if reality disagrees, and the first place the real cost of composition
(dollars and seconds) is known.

**M2 is where the model starts costing money and the schema starts mattering.** Every slice here
runs real paid model calls, and the Edition/PersonalKnowledge records become load-bearing. The eval
harness from M1 S4 is what keeps that honest: no prompt or model change ships without a number.

## The gate before M2 begins

**M2/S2 does not start until the S4 labels exist.** The corpus + confirmed labels are the measuring
stick for every judgment decision in this milestone; building judgment against no ground truth is
building blind. S1 (Personal Knowledge) has no such dependency and may begin immediately — it is a
table, a paste box, and a reconciliation pass, and importing the Jon Brain dump before the first
Edition is composed is the whole point of sequencing it first (`docs/V1-SCOPE-AND-SEQUENCING.md`
§3).

## Slice ledger

- [ ] **S1 — Personal Knowledge foundation and Jon Brain import**
- [ ] **S2 — Judgment engine and the first agreement number**
- [ ] **S3 — Edition composition**
- [ ] **S4 — Reader and resolution**
- [ ] **S5 — Content completeness and Pending Find extraction**
- [ ] **Architecture Gate 1 — model review**

## Standing rules for every M2 slice

The M1 standing rules carry over unchanged and are not repeated in full. The four that bite hardest
here:

**Escalate a doc error; do not invent a local fix.** If a slice's done-criteria contradict a
contract, stop and raise it. M1 proved this pays.

**Claim only what you verified.** A green suite is not evidence the judgment is *good* — that is what
the agreement number is for. Report the number, not an impression.

**Read the dependency, not its name.** `LLMClientKit`, the structured-output decoder, and the model
API have real shapes. Read them.

**No UI, simulator, or device testing** (`AGENTS.md`). Reader and Edition behaviour is verified by
testing the `@Observable` model that owns it. The one thing only a device can answer — real
composition cost and latency on a warm device — is named as an unverified risk and handed to Jon's
pass, not closed by going to the device.

Two rules specific to M2:

**The prompt lives in Cockpit, not in `LLMClientKit`** (`docs/JUDGMENT-CONTRACT.md` §4). It is
versioned, and `Edition` records the version used. `LLMClientKit` is transport; the editorial prompt
is Cockpit domain.

**Judgment proposes; it never acts.** Per the AI boundary and JUDGMENT-CONTRACT §8, the judgment
pass does not write Personal Knowledge, apply a Gmail disposition, admit to Library, or hand off a
Find. Deterministic code performs those under established authority.

---

## S1 — Personal Knowledge foundation and Jon Brain import

**Branch:** `m2/s1-personal-knowledge` · **PR title:** `M2 · S1 — Personal Knowledge`

### Read first

`docs/PERSONAL-KNOWLEDGE-MODEL.md`, `docs/PERSONAL-KNOWLEDGE-BOUNDARY.md`, the AI boundary in
`AGENTS.md`, and JUDGMENT-CONTRACT §2 (the projection judgment consumes).

### Scope

The Phase-1 half of Personal Knowledge — everything that has no dependency on a running Edition:

- `PersonalKnowledgeClaim(id, kind, claim, scope, provenance, status, supersededByID?, createdAt)`,
  with `kind` ∈ Fact / Taste / Interest.
- Direct teaching: a claim entered explicitly.
- **Jon Brain** natural-language bulk import: paste a dump, run one LLM reconciliation pass that
  proposes claims, Jon confirms. LLM consolidation/deduplication/rollup of explicit claims is
  allowed **when semantically faithful**; materially new inference requires confirmation and passive
  behaviour never becomes a durable claim.
- Provenance on every claim.
- The **projection** JUDGMENT-CONTRACT §2 names: the current claim set rendered as labelled prose,
  grouped Fact / Taste / Interest. Full set until the claim count exceeds 150; past that, a
  subject-overlap subset with the included claims recorded. The 150 threshold is a guess measured at
  Gate 2.
- Basic inspection under Settings / You.

### Done-criteria

1. A real Jon Brain dump imports; claims persist with provenance and are inspectable.
2. Reconciliation is tested for semantic fidelity: consolidation that preserves meaning is accepted;
   a materially new inference is surfaced for confirmation rather than written silently.
3. Supersession scaffolding exists (`status`, `supersededByID`) even if correction UX is later — a
   corrected claim preserves enough history to know the old one was superseded.
4. The projection renders exactly what §2 specifies and nothing behavioural.

### Out of scope — deferred to M3 (Personal Knowledge deepens)

Correction/supersession UX, "why this matters" teaching from the Reader, the confirmation flow for a
Cockpit-generated hypothesis, and the one visible relevance change driven by PK. Those need a running
Edition to be worth building (`docs/V1-SCOPE-AND-SEQUENCING.md` Phase 2). No salience/confidence/
trajectory machinery.

---

## S2 — Judgment engine and the first agreement number

**Branch:** `m2/s2-judgment` · **PR title:** `M2 · S2 — Judgment`

**Gated on the S4 labels.** Does not start until the corpus is labelled.

### Read first

`docs/JUDGMENT-CONTRACT.md` in full, and the M1 `JudgmentFixtureSupport` harness the real call plugs
into.

### Scope

- The prompt skeleton (§4), held in Cockpit and versioned.
- The real model call through `LLMClientKit`. Sonnet by default (§7).
- **Strict** structured-output decoding (§3): one object per candidate; a decode failure fails that
  piece to `admit: false` with a recorded error — **never a silent drop**.
- Every candidate returns `isSubstantivePrimary`, `subjects`, and `summary` whether or not admitted,
  so quiet material is still searchable and eligible for carryover reconsideration.
- **Wire it into `JudgmentEval`.** Run the frozen corpus + confirmed labels against the real model
  and report the six metrics. Record the run in `docs/eval-log.md` with date, model, prompt version,
  and numbers. This is the first agreement number.
- **Cost and latency measurement** per composition against the §7 budget (< $1.00, < 60s warm).
  Recorded on `Edition` in S3; measured here.
- **Demonstrate PK changes relevance:** show at least one candidate whose admission or rank moves
  when a Personal Knowledge claim is added or removed. If nothing moves, PK is decorative and
  something is wrong (this is the Gate 2 question, surfaced early and cheaply through the harness).

### Done-criteria

1. `swift test --filter JudgmentEval` runs the real model over the corpus and prints the six metrics;
   **false-quiet on Essential substantive-primary material** is the one that gates model changes.
2. A decode failure is proven to fail closed with a recorded error, not vanish.
3. The first eval run is recorded in `docs/eval-log.md`.
4. Composition cost and latency are measured and reported as Gate 1 evidence.

### Out of scope

Edition materialisation (S3), the Reader (S4), Gmail, and any provider mutation. Find *extraction*
shares this call — its structured `finds` output is defined here (§3) but persisted in S5.

---

## S3 — Edition composition

**Branch:** `m2/s3-edition` · **PR title:** `M2 · S3 — Edition`

### Read first

`docs/IMPLEMENTATION-CONTRACT.md` §3 (the state machine), ADR-0001 D5 (materialised, not a live
query), `docs/EDITION-EXPERIENCE.md`, `docs/TODAY-EXPERIENCE.md`.

### Scope

- `Edition` + `EditionEntry`, **materialised once per day** at first launch after the day boundary —
  not a live query. A past Edition explains itself from what was stored.
- Composition drives the S2 judgment pass over the day's new candidates and writes `section`
  (`essentials` / `forYou` / `interestArea` / `essentialBacklog`), `rank`, and `rationale`;
  `ContentPiece.subjects` / `.summary` / `.isSubstantivePrimary` are written from the same pass.
- The state machine exactly as §3 specifies: `Edition.state` `composing → open → closed`; once
  `open`, the entry set is stable for the day except intraday **append-only** admission of Essential
  / time-critical material, which never reorders.
- `EditionEntry.entryState` transitions and **only** these: `admitted→seen`, `admitted/seen→
  dismissed`, `admitted/seen→resolved`, `admitted/seen→aged`, any-non-terminal→`carried` at the day
  boundary. Terminal: `dismissed`, `resolved`, `aged`. Add to Library is orthogonal and never changes
  `entryState`.
- **Carryover budget 3**, then `aged` (non-Essential only). Carried entries re-admit as a new
  `EditionEntry` with `firstAdmittedEditionID` preserved.
- **Essential guarantee and relief valve:** substantive-primary material from an Essential Stream is
  never `aged`; an unresolved Essential entry carried more than **14** times moves to
  `section = essentialBacklog`, which renders separately and does not count against `targetSize`.
- `Edition.targetSize` default **20**, the objective judgment optimises against.
- Re-judgment only on explicit "reconsider," a prompt-version change, or the next composition for
  carried entries. Personal Knowledge changing does not retroactively recompose a past Edition.

### Done-criteria

1. A real Edition composes from real Streams; the `@Observable` model owning it is tested for every
   legal transition and rejects every illegal one.
2. Carryover budget and Essential backlog thresholds behave per §3; an Essential substantive-primary
   piece is provably never aged.
3. Composition cost is recorded on `Edition`.
4. A closed Edition renders entirely from stored state with no re-derivation.

### Constants introduced here

M1 introduced no tunable product constants; M2 S3 is where they arrive, all from
IMPLEMENTATION-CONTRACT §3 and all tunable: **carryover budget 3, Essential backlog relief 14,
`targetSize` 20**. Cite the contract; do not pick new round numbers.

### Out of scope

Reader resolution UX (S4), Offline, Gmail-delivered candidates (that transport is a later
milestone), the auto-Library policy.

---

## S4 — Reader and resolution

**Branch:** `m2/s4-reader` · **PR title:** `M2 · S4 — Reader`

### Read first

`docs/CONTENT-EXPERIENCE.md`, `docs/EDITION-EXPERIENCE.md`, IMPLEMENTATION-CONTRACT §3–4 (Dismiss,
not Clear).

### Scope

- The Reader: opening a piece transitions `admitted → seen`; provenance / source context; the
  rationale surfaced as "why am I seeing this."
- Resolution actions, each mapping to exactly one legal transition: **Dismiss** (`→dismissed`),
  **Save for Later** (`→resolved`, writes `LaterMembership`), **Add to Library** (orthogonal, writes
  `LibraryMembership` with `admittedBy = explicit`, leaves `entryState` unchanged).
- `isSubstantivePrimary` is inspectable and correctable from the Reader (IMPLEMENTATION-CONTRACT §1).
- Contextual Stream Handling access from a piece.
- The minimal **Pending Finds** list surface (rows persisted in S5) lives under the shell.

### Done-criteria

1. Every resolution action is driven through the owning `@Observable` model and tested; illegal
   transitions are rejected.
2. Save for Later and Add to Library write the correct memberships and nothing else.
3. Verified through model tests, not the device (`AGENTS.md`).

### Out of scope

Per-piece Offline controls (candidate M3), Gmail Today, any handoff of a Find.

---

## S5 — Content completeness and Pending Find extraction

**Branch:** `m2/s5-completeness-and-finds` · **PR title:** `M2 · S5 — Completeness and Finds`

Two small deliverables that both ride the ingest/judgment pass. May be split, or completeness may
move earlier if judgment wants it as an input.

### Content completeness

Raised by Jon 2026-09-12: some followed Substacks are paid, so an issue may arrive truncated unless
it is a free post, and he wants to know a piece is incomplete **before** reading it — without
tracking which subscriptions are active.

- A **derived** per-`ContentPiece` signal computed from the content itself at ingest — not
  subscription state. Deterministic detection of paywall/truncation boilerplate first (the "this
  post is for paid subscribers" marker, a subscribe CTA where the body stops, an RSS
  `content:encoded` teaser cutoff), with the judgment pass as a fallback classifier.
- A field on `ContentPiece` (proposed `bodyCompleteness` ∈ `full` / `truncated` / `teaser`).
- Distinguish it from `isSubstantivePrimary`: a **teaser with no body** is already *not substantive*
  (IMPLEMENTATION-CONTRACT §1); a **truncated but real** paid post is substantive **and** incomplete.
  They are different axes.
- Surface it as a Reader badge; make it available to judgment so the rationale can note it.
- Record the decision in `docs/CONTENT-PIECE-MODEL.md` §8 (custody reflects the substance actually
  held) and add the field to IMPLEMENTATION-CONTRACT §1–2 in the same change.

### Pending Find extraction

- Persist the `finds` the judgment pass already emits (JUDGMENT-CONTRACT §3) as `PendingFind` rows.
- A minimal list surface (rendered by S4's shell). Orphan finds accumulate from day one — that
  population is the evidence for what specialist app the Jon Universe builds next.
- **Extraction only.** No receiver, no admission boundary, no cross-app work, no domain-rich
  product/place/wine modelling in Cockpit. Handoff is a later milestone (V1 Phase 6).

### Done-criteria

1. Completeness is detected deterministically on real paid-Substack samples (the harvest corpus
   already contains some) and rendered distinctly from `isSubstantivePrimary`.
2. Finds persist from the judgment output with no additional model pass, and list.

---

## Jon's manual and device pass

Same shape as M1: the work only Jon can do, gating what follows.

### Before S2 — the labelling pass

Already specified in `docs/milestones/M1-persistence-and-destinations.md` ("After S4 — the labelling
pass"). The 200 fixtures must carry a confirmed `label` and `isSubstantivePrimary`. **This gates
S2.** When you hit a paywall teaser with no body, the contract's own definition says
`isSubstantivePrimary = false` (IMPLEMENTATION-CONTRACT §1) — that is a rule, not a judgment call.

### After S3 — composition cost on a warm device

Agents measure cost and latency in the harness and in tests, but the number that reopens ADR-0001 D1
— **what does composing a real Edition cost in dollars and seconds on a warm device every morning?**
— can only be taken on the device. S3's handoff report names the harness estimate; Jon's pass records
the real figure. This is Architecture Gate 1's load-bearing evidence.

---

## Architecture Gate 1 — model review

The first real checkpoint (`docs/V1-SCOPE-AND-SEQUENCING.md`, Architecture Gate 1). Stop and inspect
before broadening the model:

- Did the Artifact / ContentPiece boundaries hold? Did derived identity converge across devices and
  Streams? What real deduplication cases appeared? *(This is the gate that may revise the synced core
  types — which is why CloudKit sync-enablement was deferred to here; see the M1 amendment
  2026-09-11.)*
- Which Edition states and transitions were actually exercised, and did the carryover budget (3) and
  Essential backlog threshold (14) feel right?
- Is Subjects + FTS enough for early Library retrieval?
- **What did composition cost, in dollars and seconds?**
- **What is the judgment agreement rate, and the false-quiet rate on Essential material?**
- Are Pending Finds accumulating, and what shape are the orphans?

Change the model now if reality disagrees.

---

## Not in M2 — the M3 cutline (proposed)

- Personal Knowledge deepening (correction/supersession UX, "why this matters," hypothesis
  confirmation, the one visible PK-driven relevance change) — Phase 2, needs a running Edition.
- Offline: `Offline until [date]` and `Keep Offline`.
- The auto-Library policy.
- Anything Gmail: read-only Today, dispositions, the email-delivered Stream — Phases 3–5.
- The first specialist handoff — Phase 6.
