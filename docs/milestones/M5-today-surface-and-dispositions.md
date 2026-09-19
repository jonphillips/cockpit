# M5 — Today becomes a surface, and the Gmail transport learns to write

> **DRAFT for architect review.** Drafted 2026-09-18, immediately after M4 S9 merged (PR #35) and the
> Today-orientation / email-legibility carry landed on `main` (`da13cc8`). This is the proposed sliced
> build order for M5. The contract numbers and definitions cited are not reinterpreted here.

## What M5 is

M4 built the thing §24 asked for: typed triage of curated Gmail input is the V1 spine, Edition folded
into Today's uncurated tail, and the shell settled to `Today / Later / Library / Settings`. Jon's S7
device pass returned the verdict M4 was betting on — **the type-differentiated hierarchy "feels like
less work" than the flat inbox** (`M4-gmail-today.md`, S7 device pass). The structure is right. But that
same lived use surfaced the next two jobs, and they are the same shape M3 and M4 used: deepen the loop
where daily use hurts, and open the next capability of the transport already in hand.

M5 has two jobs:

1. **Make the built Today loop genuinely usable — read as orientation, not "Gmail, subtly re-sorted."**
   The substance exists — S5 classifies treatment, S7/S8 produce summaries, extracted grab-bag items,
   personal emphasis — but Today still renders as one scrolling `List`, which does not honour Product
   Law 1 ("Today is orientation/attention"). The M4 cutline named this **"consider first in M5"** and
   named the method trap that forces its ordering: **"feel" cannot be device-evaluated against a
   scaffold**, so the presentation slice comes before Today's experience is judged. Three carry-ins
   ride with it: the **email-body legibility defect** (S7/S9 device finding #2, still unfixed) is "the
   other half of enticing"; the **transactional-mail scatter** (S7 device finding #1) is a §24 taxonomy
   gap Jon has now ruled on (add a fifth treatment); and the **tail recompose reads as broken** — a
   multi-minute editorial pass with no progress feedback looked like an indefinite hang until it
   resolved (Jon, 2026-09-18), which is the §23 latency, not a bug, and must at least be made legible.
2. **Open provider mutation — Gmail dispositions (V1 Phase 4).** M4 read Gmail and never touched it.
   M5 crosses the read-only→mutation line the whole architecture has been holding — but only *after*
   Architecture Gate 3 closes. The gate's ADR (`ADR-0002`) is written but **Draft**, with four items
   still open. Closing that gate is the first thing this job requires; only then do `Leave` / `Archive`
   / `Trash`, the disposition barrier, and bounded Undo become buildable.

```text
make the built read-only loop actually usable:
  design the orientation surface (a note, first)
  → fix email-body legibility (the normalizer swallows paragraphs)
  → add the transactional treatment (§24's fifth rung)
  → build the composed Today landing (counts / promote / highlight / per-category entry)
  → make the slow tail recompose legible (honest progress; never a bare indefinite spinner)
then open provider mutation, behind the gate:
  → close Gate 3 (delta sync + partial commit; measure the open items; ratify ADR-0002)
  → Phase 4 dispositions: Leave / Archive / Trash + the disposition barrier + bounded Undo
  → the smallest explicit disposition policy that proves the authority model
```

M5 ends with **Phase 4 complete**. The next architecture gate — **Gate 4, the major model review that
the email-delivered recurring Stream (Phase 5) forces** — opens M6, not M5 (scope decision, 2026-09-18).

## The gate before M5's mutation work — Gate 3

> **Closed 2026-09-19 (S6).** `ADR-0002` is **Accepted**; the three empirical open items were observed
> on the real account (`docs/eval-log.md`). The framing below is the slice's authored premise — the
> gate was open when the mutation job began. S7–S8 now open on a *closed* Gate 3.

**M4's deepening job opens on nothing owed.** S1–S9 are merged; the Today hierarchy, treatments, and
the Edition fold are built and device-passed. The presentation job (S1–S5 below) has no gate in front
of it — it is view-layer composition and reliability on data and paths that already exist.

**M5's mutation job opens on an *open* Gate 3.** Unlike M4 (which opened on a closed Gate 2), the
milestone that owns the read-only→mutation boundary begins with that boundary still unratified:

- `docs/ADR-0002-GMAIL-INTEGRATION-AND-DISPOSITION.md` is **Draft — Gate 3 proposal**. Its policy and
  safety decisions (D1–D8: message is the unit; `historyId` delta sync; the disposition barrier; the
  three label operations; bounded Undo; explicit-per-action authority; single account) are settled from
  S4 evidence and are **not reopened** here.
- Four items sit under **"Open — measure before ratifying."** As of the 2026-09-18 quota correction,
  two of the four turned out to be **documented constants** needing only on-account confirmation (the
  Gmail quota numbers — `messages.get` is 20 units, ceiling 6,000/min/user; and the 30-day Trash purge
  window). The two genuinely **empirical** items — multi-message thread distinctness, and new-reply
  re-entry via `history.list` — need the delta-sync code to exist before they can be observed. So the
  gate is closed by *building* the read side, not by a manual investigation phase.

The mutation job's first slice (**S6**) is therefore the Gate-3 close: build the read-side hardening the
ADR names as *a build requirement of the first mutation slice* (`historyId` delta sync; per-message
partial commit, replacing S4's all-or-nothing read), which is what makes the two empirical items
observable, then ratify. **No provider mutation happens before S6 lands and the ADR is Accepted**
(V1-SCOPE Phase 3→4; DECISIONS §7).

## Slice ledger

**Deepen — make the built Today loop usable (no gate in front; feel is judged only after S2+S4):**

- [x] **S1 — Today orientation-surface design note** *(architect-authored; `TODAY-EXPERIENCE.md`)* — defines the composition before it is built *(merged PR #37; box corrected 2026-09-18)*
- [x] **S2 — Email-body legibility: preserve paragraph structure in the shared normalizer** *(S7/S9 device finding #2)*
- [x] **S2b — Email-body legibility (corrective): strip non-content elements + broaden entity decoding** *(device finding #2 not actually closed; HTML mail still renders `<style>`/`<script>` CSS as body text — Jon, 2026-09-18)*
- [x] **S3 — The transactional treatment: §24's fifth rung** *(S7 device finding #1; Jon's call 2026-09-18 — add a treatment)*
- [x] **S4 — The Today orientation surface: counts / promote / highlight / per-category entry** *(the "consider first in M5" item)*
- [ ] **S5 — Tail composition: honest progress + latency evidence** *(the "recompose looks hung" finding; DECISIONS §23)*

**Open provider mutation — Gmail dispositions (Phase 4), behind the gate:**

- [x] **S6 — Close Gate 3: `historyId` delta sync + per-message partial commit; measure the open ADR-0002 items; ratify** *(read-side hardening + gate close; ADR-0002 Accepted 2026-09-19, real-Inbox items in `docs/eval-log.md`)*
- [ ] **S7 — Phase 4 dispositions: `Leave` / `Archive` / `Trash` + the disposition barrier + bounded Undo** *(the first provider write)*
- [ ] **S8 — The smallest explicit disposition policy that proves the authority model** *(ADR-0002 D7; no rules engine)*

The two jobs are ordered by the method trap, not by preference: **the deepen job (S1–S5) comes first**
because "feel" is only judgeable against a real design, and the mutation job depends on nothing in it.
Within the deepen job, S2 (legibility) and S3 (the transactional tier) land **before** S4 builds the
surface, so Jon's S4 device pass — the real §24 lived-use test, now on a designed surface rather than a
scaffold — judges legible bodies and the full taxonomy; S5 (tail legibility) comes last in the job,
after the surface is usable, per Jon's "don't chase problems until the tool is generically usable."
Within the mutation job each slice depends on the one before: S6 (ratify + delta sync + partial commit)
→ S7 (mutate behind the barrier) → S8 (one explicit policy on top).

## Standing rules for every M5 slice

The M1–M4 standing rules carry over unchanged. The ones that bite hardest in M5:

**The read-only→mutation line is crossed only behind the barrier, and only after Gate 3.** Nothing
mutates Gmail until `ADR-0002` is Accepted (S6). Then the disposition barrier is inviolable: **read →
classify/extract → persist the promised durable result → verify the commit → advance `historyId` →
apply the provider disposition, per message** (ADR-0002 D4; DECISIONS §7). Never Archive/Trash before a
promised retained ContentPiece/Find/result is safely committed. No `Delete Forever`, no generic
rules/Disposition-Rule engine, no learned/auto deletion, no automatic unsubscribe, no broad
reply/composition (DECISIONS §7; V1-SCOPE out-of-scope list).

**Knowledge does not grant agency** (PK-MODEL §11; DECISIONS §8). AI may classify a message to apply an
*already-authorized* policy and may *propose* a policy; destructive authority never arises from observed
behaviour (ADR-0002 D7).

**`Clear` is not a disposition.** Today's `Clear` remains a Cockpit attention action and still must not
touch Gmail; a Gmail disposition (`Archive`/`Trash`) is a separate, explicit action (DECISIONS §7;
ADR-0002 D8; TODAY-EXPERIENCE §6). Clearing a Gmail source in Today is not clearing the ContentPiece
from the tail. Do not unify them.

**Organize, never suppress — still §24, and it now governs a fifth treatment.** The transactional tier
changes *placement*, never *membership*; the model never hides a curated item. A misclassification is a
visible, correctable misplacement, and the S5-era per-sender override is its fix (DECISIONS §24). The
new treatment inherits every §24 guardrail: deterministic-first from retained headers/type, no learned
reputation store, no suppression.

**Feel is judged against a real design, not a scaffold.** The presentation slice (S4) is the first
thing Jon can honestly device-pass for "does the morning read as an inviting brief," and only once S2
has made bodies legible. Do not ask for that judgement against the scrolling-`List` scaffold.

**A slow operation must not read as a broken one.** The tail recompose is minutes long by nature (the
editorial pass, §23); it must always show honest progress and resolve to a definite state, never a bare
indefinite spinner. Reliability/observability of the existing path is in scope; the latency *fix* (the
type-model swap) stays deferred behind the schema blocker (§23) unless S5's evidence moves it.

**Persistence discipline.** The delta-sync cursor, the disposition log, the explicit-policy record, and
the transactional tag are the smallest tables the demonstrated behaviour justifies. No generic
Disposition-Rule engine; no universal policy model (DECISIONS §7; persistence discipline in `AGENTS.md`).

**Verification: model state is tested; pixels and feel are Jon's pass** (`AGENTS.md`). Agents ship the
tested models — the paragraph-preserving normalizer, the transactional classifier, the Today projection,
the tail-compose progress/timeout state, `historyId` delta sync, per-message partial commit, the
disposition barrier, the Undo log. The orientation-surface layout and weighting, the transactional
tier's visual rank, the legible body typography, the "does progress read as progress," and the
disposition affordances are Jon's device pass. **No agent drives the Simulator or a device** (`AGENTS.md`,
"No UI, simulator, or device testing"); a mutation defect only a real Inbox can catch (a live
disposition against real labels, a real Trash purge) is named in the handoff as an unverified risk and
stopped there.

---

## S1 — Today orientation-surface design note

**Branch:** `m5/s1-today-surface-note` · **PR title:** `M5 · S1 — Today orientation-surface note`

Architect-authored: a written note **plus a visual mockup**. The M4 cutline said the orientation
surface "likely wants its own short design note (`TODAY-EXPERIENCE.md` is the existing home) before it
is sliced." This is that note — and, because an orientation *surface* is inherently spatial, a mockup
of the proposed composition to react to. It exists so S4 builds against a settled composition rather
than inventing one, and so Jon's S4 device pass has something concrete to judge.

**Mockup status (2026-09-18).** A first-pass mockup (Claude artifact, "Cockpit Today Surface") was
built and **approved as a starting composition** — the treatment-tiered brief with promote / highlight
/ counts / per-category entry, the low transactional rung, and the Tail with honest recompose progress.
S1's build reproduces it in `docs/` (or as the linked artifact) and refines from there. Two
forward-carries from that review are recorded on their slices rather than left in the PR: **ephemeral
login-code mail should be trashable** (S3 classifies it; S8 is where the disposition lands), and **the
offer tier must roll up at volume** (S4).

### Read first

`docs/TODAY-EXPERIENCE.md` §5–6 (surfaces and `Clear`); DECISIONS §24 (organize-not-select; the
type/relationship hierarchy; "the win is across types, not within them"); the M4 cutline note "Today as
a designed orientation surface" (`M4-gmail-today.md`) and Jon's 2026-09-17 S9 device reflection recorded
there (counts / promote / highlight / per-category entry points); the built `TodayModel` /
`TodayRequest` (what data the surface already has).

### Scope

- **Record the intent as a settled composition.** The morning landing shows **how much** sits in each
  category (counts), **promotes** enticing new arrivals (a new Yglesias / Feed Me / Noahpinion issue;
  the wine report surfaced), **highlights** important personal mail, and offers **per-category entry
  points** — so the morning reads as an inviting brief, not "I'm back in Gmail; do I want to open
  Promotions?"
- **Name where the transactional treatment (S3) sits** in the hierarchy — its rung and its low visual
  weight — so S3 and S4 agree on the shape.
- **Produce a mockup of the proposed surface.** A visual mockup (a published Artifact, or an HTML
  file under `docs/`) rendering the composed landing — the tiers in order, per-category counts, a
  promoted arrival, a highlighted personal item, the low transactional rung, per-category entry, and
  the tail's entry point — with representative fixture content. It is a *proposal to react to*, the
  concrete thing Jon judges the composition against; it is not the built surface and not final pixels.
- **Settle the composition, not the pixels.** This slice is the *product/composition* design — what
  information appears, the cross-type hierarchy, what "promote" and "highlight" concretely select, the
  per-category entry model, and how the always-present-but-slow tail is entered. Neither the note nor
  the mockup fixes final visual styling, spacing, or typography in the app — those stay Jon's device
  pass (`AGENTS.md`); the mockup only pins the *arrangement*. It does **not** introduce new persistence
  or reopen §24's organize/select line.
- **Follow the Documentation rule.** The note lands in `TODAY-EXPERIENCE.md` (its existing home); if it
  sharpens any ratified language, amend deliberately in the same change rather than drifting.

### Done-criteria

1. `TODAY-EXPERIENCE.md` carries a composition note defining counts, promotion, personal highlight,
   per-category entry, the transactional tier's placement, and how the tail is entered — concrete
   enough that S4 can build to it and Jon can judge against it.
2. A mockup renders that composition with representative fixture content — the tiers in order, counts,
   a promoted arrival, a highlighted personal item, the low transactional rung, per-category entry, and
   the tail entry — and is linked from the note. Jon endorses (or redirects) the composition against
   the mockup before S4 builds.
3. The note and mockup stay on the organize side of §24 (no per-item relevance ranking within a type;
   hierarchy by type/relationship) and introduce no new entity or persistence.
4. No app/product code. The build is S4.

### Out of scope

The build itself (S4). The legibility fix (S2). The tail progress work (S5). Any change to
classification beyond naming the S3 tier. Final visual styling in the app — the mockup pins arrangement,
not pixels (Jon's device pass).

---

## S2 — Email-body legibility: preserve paragraph structure in the shared normalizer

**Branch:** `m5/s2-body-legibility` · **PR title:** `M5 · S2 — Body legibility`

The S7/S9 device finding #2, re-confirmed unfixed at the S9 reflection: email bodies render as one
run-on stream. This is "the other half of enticing Today," and it must land before Jon judges the S4
surface — an inviting brief made of unreadable paragraphs is not testable.

### Read first

`M4-gmail-today.md` S7 device-pass finding #2 (the exact defect); `HTMLText.normalizedText(from:)`
([`Feed.swift:210`](../../CockpitCore/Sources/CockpitCore/Feed.swift)) — it inserts `\n` for block
tags and then collapses **every** whitespace run in its final `split`/`joined` pass, discarding those
newlines; the RSS ingest path that shares this normalizer (the reason this is its own small change, not
a Reader-only tweak); ADR-0001 D6 / DECISIONS §16 (normalized text is device-local, derived from
retained `rawSourceText` — this is a normalization choice, not lost data).

### Scope

- **Preserve paragraph structure.** Collapse intra-line whitespace runs but **keep** the `\n` block
  boundaries; squeeze runs of blank lines to a single separator. Nothing is recovered from the network —
  `rawSourceText` already retains the full HTML; this only stops the normalizer from throwing structure
  away.
- **One shared change, both transports.** The fix lives in the shared normalizer and improves the RSS
  Reader body identically; do not fork an email-only path.
- **Deterministic and tested.** Fixture tests over representative block structures (paragraphs, lists,
  headings) asserting preserved boundaries and collapsed intra-line whitespace.

### Done-criteria

1. `HTMLText.normalizedText` preserves paragraph/block boundaries and squeezes blank-line runs;
   intra-line whitespace still collapses. Verified by deterministic fixture tests on the normalizer.
2. The RSS path is unchanged in intent and improved in output by the same change (no email-only fork).
3. No network fetch; derived-from-`rawSourceText` only. `swift test` + `swiftlint --strict` green; the
   read-in-the-Reader legibility judgement is Jon's device pass.

### Out of scope

Reader typography/geometry (still deferred). HTML-fidelity polish beyond block boundaries. The Today
surface (S4).

---

## S2b — Email-body legibility (corrective): strip non-content elements + broaden entity decoding

**Branch:** `m5/s2b-body-legibility-corrective` · **PR title:** `M5 · S2b — Body legibility (corrective)`

S2 preserved paragraph boundaries but left HTML-fidelity polish out of scope. HTML mail still renders
the contents of `<style>` and `<script>` blocks as a wall of CSS or JavaScript above the real text.
This corrective slice closes that device finding in the shared normalizer before the S4 re-judge.

### Scope

- Remove the contents of `<style>`, `<script>`, and `<head>` elements, plus HTML comments including
  Outlook conditional comments, before the existing tag-stripping pass.
- Decode numeric decimal/hex entities and the common named punctuation entities in addition to the
  existing basic entity set.
- Keep the change in `HTMLText.normalizedText`, so RSS and Gmail-derived bodies improve identically;
  do not add an email-only path or structured HTML rendering.
- Verify with the MyUNCChart new-estimate MJML/Outlook fixture, entity fixtures, and S2's existing
  paragraph-boundary tests.

### Done-criteria

1. Normalized text contains no non-content element contents or raw numeric/common named entities;
   the MJML/Outlook fixture contains the real content lead and no CSS/Outlook boilerplate.
2. S2 paragraph boundaries remain unchanged and both transports use the same normalizer.
3. No network fetch; text remains derived from retained `rawSourceText`. `swift test` and
   `swiftlint --strict` are green; Reader legibility remains Jon's device pass.

### Out of scope

Reader typography/geometry, structured HTML rendering, and the Today surface.

---

## S3 — The transactional treatment: §24's fifth rung

**Branch:** `m5/s3-transactional-treatment` · **PR title:** `M5 · S3 — Transactional treatment`

The S7 device finding #1: the four treatments have no clean home for transactional/receipt mail
(shipping notices, an Apple Store `do_not_reply` trade-in notice, a sign-in code, hotel confirmations),
so it scatters into Personal and Newsletters. **Jon's call, 2026-09-18: add a treatment** — a fifth rung
in the §24 hierarchy, not a Find. This slice carries the §24 amendment.

### Read first

DECISIONS §24 (the four-treatment taxonomy this extends; the organize-not-suppress guardrails the fifth
inherits; the deterministic-first / no-learned-store discipline); `M4-gmail-today.md` S7 device finding
#1 (the scatter this fixes; the explicit "add a treatment vs. make it a Find" question, now answered);
`EmailTreatment` ([`EmailTreatmentDomain.swift`](../../CockpitCore/Sources/CockpitCore/EmailTreatmentDomain.swift))
and the deterministic `EmailTreatmentClassifier`
([`EmailTreatment.swift`](../../CockpitCore/Sources/CockpitCore/EmailTreatment.swift)); the S4-retained
provider headers (`GmailArtifactProvenance` / `GmailHeaderParser`) — the deterministic signals; the
existing per-sender override (the correction mechanism the fifth treatment also uses).

### Scope

- **Add `transactional` to the `EmailTreatment` enum**, with a migration (mirroring
  `EmailTreatmentMigration`). It is a per-piece placement tag, not a new entity.
- **Classify it deterministically-first, from retained headers/type** — transactional/notification mail
  carries recognizable machine-sender shape (`do_not_reply`/`no-reply` local-parts, transactional ESP
  domains, receipt/confirmation/shipment type markers) and, unlike think-piece publication mail, is not
  something Jon chose to *read*. Keep it on the deterministic side of §24: no Contacts scope, no learned
  reputation store, no model guess as the primary signal. Where the type pass already produces a signal,
  reuse it; do not add a detector heavier than the one-and-a-half-stream rule allows.
- **Place it low in the hierarchy** per the S1 note — transactional mail is reference, not attention;
  it is present and countable, never suppressed, and never elevated above personal or newsletters.
- **Flag the ephemeral / OTP sub-case** (login and verification codes). Jon (2026-09-18): a login code
  would have been dealt with immediately in a standard reader, so by the morning brief it is stale
  noise. S3 only needs to *recognize* it deterministically (a distinguishable transactional sub-kind) —
  the **disposition (auto-Trash) is Phase 4 and lands in S8** as an explicit user policy, never a
  silent classification-driven delete here (§7; §8; the read-only→mutation line). Classifying it now is
  what lets S8's policy target it cleanly.
- **The per-sender override applies.** A misplacement (a real person's mail caught by a machine-sender
  heuristic, or vice-versa) is corrected by the existing explicit per-sender flip, which wins over the
  default and persists — grown only by correction (DECISIONS §24).
- **Amend §24 in the same change** (Documentation rule): DECISIONS §24 records the fifth treatment and
  its rationale; `IMPLEMENTATION-CONTRACT.md` §3 updates the treatment-shape record; `TODAY-EXPERIENCE`
  and `EMAIL-INTELLIGENCE-MODEL` reflect the new rung. Record the S7 device evidence as the trigger.

### Done-criteria

1. Every ingested email piece still carries exactly one treatment; `transactional` is assigned
   deterministically from retained headers/type, and a piece a human clearly sent 1:1 is never tagged
   `transactional`. Verified through the classification model on fixtures covering each header shape,
   including the real cases from the S7 device pass (UPS shipment, `do_not_reply` notice, sign-in code,
   hotel confirmation).
2. `transactional` changes placement only — no piece is suppressed, declined, or mutated by it; a
   per-sender override flips it and survives recomposition (adversarial test: nothing learned or
   auto-added). Verified through the model.
3. The §24 amendment and the affected live docs (DECISIONS §24, IMPLEMENTATION-CONTRACT §3,
   TODAY-EXPERIENCE, EMAIL-INTELLIGENCE-MODEL) land in this change. `swift test` +
   `swiftlint --strict` green.

### Out of scope

The surface rendering of the tier (S4 places it per the S1 note; S3 assigns the tag). Any Contacts
integration or learned store (§24 — revisit only if headers + overrides prove insufficient). Treating
transactional content as a Find (Jon's ruling was a treatment, not a Find). Gmail dispositions (S7).

---

## S4 — The Today orientation surface

**Branch:** `m5/s4-today-surface` · **PR title:** `M5 · S4 — Today orientation surface`

Build the composition S1 defined: the flat scrolling `List` becomes a landing that reads as a brief.
This is the "consider first in M5" item, and Jon's device pass on it is the real lived-use test of §24 —
now on a designed surface, with legible bodies (S2) and the full five-treatment taxonomy (S3).

### Read first

The S1 design note (`TODAY-EXPERIENCE.md`); DECISIONS §24 (hierarchy by type/relationship; "the win is
across types, not within them"; within a type, arrival order is a mood not a priority); the built
`TodayModel` / `TodayRequest` / `TodayAttention` (the projection to compose; the `Clear` marker to
preserve); `M4-gmail-today.md` S7 out-of-scope + device pass (what S7 deliberately left as a plain row).

### Scope

- **Compose the landing per the S1 note:** per-category **counts**, **promotion** of enticing new
  arrivals, **highlight** of important personal mail, and **per-category entry points** — over the five
  treatments including the S3 transactional rung. The order across tiers stays deterministic; within a
  tier, arrival order (§24) — this slice does not introduce per-item ranking.
- **View-layer on existing data.** S5(M4)/S7/S8 already produce the treatment tags, summaries, extracted
  grab-bag items, and personal emphasis; S3 adds the transactional tag. S4 composes them; it does not
  add persistence or a new judgment call.
- **Roll up the offer tier at volume** (Jon, 2026-09-18). The mockup showed one full capsule per offer,
  which does not scale — five wine offers must not become five large capsules. The offer tier groups
  (by domain/type — e.g. "5 wine offers") into a compact aggregate with drill-in, rather than a capsule
  each. Keep it presentational grouping here; deeper evolution (rolling grouped offers into a single
  grouped Find) is a later Finds concern (Phase 6), not S4.
- **Preserve the built invariants.** `Clear` still resolves Today attention with no Gmail mutation; an
  email piece still opens in the one Reader (now with legible body from S2) and carries no Edition-only
  affordances; the uncurated tail section (S9) still renders within Today.
- **Push the surface's aggregates through the projection.** Counts/promotion selection are computed in
  the tested `TodayModel`/`TodayRequest` layer, not in the view, so they are verified by model tests
  (consistent with "views may not touch the database," `AGENTS.md`). If S9's SQL `kind == .email`
  predicate needs extending for the new aggregates, do it in SQL here.

### Done-criteria

1. Today renders as the composed landing (counts / promotion / personal highlight / per-category entry)
   over the five treatments, with the transactional rung placed per S1. Verified through the Today
   projection model (the aggregates and promotion selection are model-level, not view-only).
2. The built invariants hold: `Clear` writes no provider mutation (adversarial test); an email piece
   opens in the one Reader with legible inline body and no Edition-only affordances; the tail section
   still renders.
3. `swift test` + `swiftlint --strict` green; the layout, weighting, promotion feel, and the §24
   lived-use verdict ("does the morning read as an inviting brief") are Jon's device pass.

### Out of scope

Provider mutation (S6–S8). Any within-tier relevance ranking (§24). New treatments beyond S3. Reader
typography beyond S2's legibility fix. The tail's progress/latency work (S5).

---

## S5 — Tail composition: honest progress + latency evidence

**Branch:** `m5/s5-tail-progress` · **PR title:** `M5 · S5 — Tail progress`

The last deepen slice, and deliberately after the surface is usable (Jon: "I don't want to chase down
problems until we make this tool generically more usable"). The trigger: the "Recomposing Tail" spinner
looked like an indefinite hang — and then **resolved** (Jon, 2026-09-18). So it is not a hang; it is the
known §23 latency (the editorial finite-package pass, minutes long on device) with no progress feedback.
A slow-but-working operation reads as broken. This slice makes it legible and captures the latency
evidence; it does **not** attempt the latency fix.

### Read first

DECISIONS §23 (the ~6-minute / ~360s on-device recompose; the monolithic `composeIfNeeded` path; the
budget clause) and its §24 amendment (the editorial pass now runs **only** over the uncurated tail, so
§23 bites only here); JUDGMENT-CONTRACT §1/§3 (the tail's finite-package pass; per-piece fail-closed and
the `JudgmentEnvelope` salvage — the resilience this must preserve); `EditionComposer.composeIfNeeded` /
`EditionPlanner` (the tail compose path; M4-S6 already parallelized the PK-free type pass, the editorial
pass is the remaining floor); the eval-log §23 device-pass entries.

### Scope

- **Make the tail compose observable and always-resolving.** Whatever the wall time, the tail
  composition surfaces honest progress (it is running; ideally coarse progress against its batches) and
  terminates in a **definite state** — composed / empty (nothing in the tail) / honest error — within a
  bounded timeout. A bare indefinite spinner is no longer reachable; a failed or timed-out compose
  degrades to a visible, retryable error, not a permanent spin.
- **Confirm the diagnosis and record the number.** Instrument the path enough to confirm it is latency
  (not a missed-completion state bug), and record the real on-device tail-recompose latency in
  `docs/eval-log.md` against the §7 60s budget — this is fresh §23 evidence for whether the type-model
  swap moves ahead of its deferred slot.
- **Do not attempt the latency fix.** The type-model swap stays deferred behind the schema blocker
  (§23); this slice produces its trigger evidence, it does not do it. No change to the editorial
  finite-package call itself, and no reshaping of what the tail selects.
- **Preserve the resilience guarantees.** Per-piece fail-closed and the `JudgmentEnvelope` salvage
  (JUDGMENT-CONTRACT §3) still hold; the new timeout/error state is an addition to honest degradation,
  never a way to silently drop the tail.

### Done-criteria

1. The tail composition always resolves to a definite state (composed / empty / honest error) within a
   bounded timeout and shows honest progress while running; an indefinite spinner is unreachable.
   Verified through the composition model (adversarial: a failing/timing-out compose surfaces an error
   state, not a permanent spinner).
2. The diagnosis is confirmed (latency vs. missed-completion) and the real on-device tail-recompose
   latency is recorded in `docs/eval-log.md` against the 60s budget, as §23 evidence.
3. Per-piece fail-closed and the `JudgmentEnvelope` salvage still hold across a bounded/failed compose;
   the tail is never silently dropped. Verified through the model.
4. `swift test` + `swiftlint --strict` green; whether the progress *reads* as progress (and the latency
   is tolerable pending the swap) is Jon's device pass.

### Out of scope

The §23 type-model swap itself (deferred; this slice supplies its evidence). Any change to the editorial
finite-package pass or what the tail selects. Any curated-mail path (the tail is uncurated only, §24).
Provider mutation (S6–S8).

---

## S6 — Close Gate 3: delta sync + partial commit; measure the open items; ratify

**Branch:** `m5/s6-gate3-close` · **PR title:** `M5 · S6 — Gate 3 close`

The mutation job's first slice, and the boundary the whole architecture has been holding. It builds the
read-side hardening `ADR-0002` names as *a build requirement of the first mutation slice*, makes the two
empirical open items observable, and takes the ADR Draft→Accepted. **No provider write happens until
this lands.**

### Read first

`docs/ADR-0002-GMAIL-INTEGRATION-AND-DISPOSITION.md` in full — especially D2 (`historyId` delta sync,
category-scoped, quota budget — note the 2026-09-18 quota correction: `messages.get` = 20 units, ceiling
6,000/min/user), D3 (throttle/retry/partial-failure — S4 is all-or-nothing and must become per-message
partial commit), D4 (the barrier depends on per-message commit), and the **"Open — measure before
ratifying"** items (two documented constants to confirm on-account; two empirical items that need delta
sync to exist); `docs/m4-s4-gmail-observations.md` (the S4 evidence the ADR rests on; superseded by the
ADR once these are recorded); `GmailInboxAPI` / `GmailIngestion` (the S4 read path to harden);
DECISIONS §7 (the disposition barrier and what must be committed before mutation); V1-SCOPE Phase 3→4.

### Scope

- **`historyId` delta sync (ADR D2).** After the bounded backfill, every read asks
  `history.list?startHistoryId=…` for what changed and never re-lists the Inbox; persist the cursor per
  account and advance it only after a sync commits. This is the read consistency the barrier and future
  mutation both depend on (a label change is a history event), and it is what makes the empirical open
  items observable.
- **Per-message partial commit (ADR D3).** Replace S4's all-or-nothing read: a sync commits the messages
  it read successfully, records per-message failures, and lets failures re-enter on the next delta sync.
  The barrier (D4) is per-message and cannot sit on an all-or-nothing read.
- **Confirm/record the open items.** Surface, from Jon's real Inbox: multi-message thread per-message
  `id`/`threadID` distinctness (D1); new-reply re-entry through `history.list` (D3/D4's assumption); and
  confirm the documented quota constants (D2) hold on this account under a real paced backfill
  (429/`userRateLimitExceeded` behaviour at the edge). The Trash-window and `untrash` confirmation is
  D6's, and rides S7 (Trash does not exist until then).
- **Ratify.** Once the items are recorded, take `ADR-0002` Draft→Accepted and land its stated amendments
  (DECISIONS §7 from policy to executable contract referencing the ADR; V1-SCOPE Phase 4;
  EMAIL-INTELLIGENCE-MODEL §5; supersede the `m4-s4-gmail-observations.md` open-questions list).
- **Still no mutation.** S6 hardens the read and closes the gate; the first provider write is S7.

### Done-criteria

1. Delta sync reads through `history.list` from a persisted, commit-advanced `historyId`; a re-read does
   not re-list or re-cost the Inbox. Verified through the ingest/sync model (fixture history events;
   cursor advances only on commit).
2. Reads commit per message with recorded per-message failures; a failed message keeps its `INBOX` label
   and re-enters on the next delta sync. Verified through the model (adversarial: one failure in a batch
   does not discard the batch).
3. The open ADR-0002 items are recorded from Jon's real Inbox in `docs/eval-log.md` (or the ADR itself)
   — thread distinctness, new-reply re-entry, and quota behaviour under load — and `ADR-0002` is moved
   to **Accepted** with its amendments applied in the same change.
4. Nothing mutates Gmail. `swift test` + `swiftlint --strict` green; the real-Inbox observations are
   Jon's device pass (they gate ratification).

### Out of scope

The dispositions themselves (S7). Any explicit policy (S8). Multi-account (ADR D8 — deferred). Reading
Promotions/Social on their own budget (later stage; S6 hardens the Primary read + the delta mechanism).

---

## S7 — Phase 4 dispositions: `Leave` / `Archive` / `Trash` + the disposition barrier + bounded Undo

**Branch:** `m5/s7-dispositions` · **PR title:** `M5 · S7 — Gmail dispositions`

The first time Cockpit writes to a provider. Message-level, reversible, and behind the barrier — the
safe core of Phase 4. Depends on S6's per-message commit and delta sync, and on the ratified ADR.

### Read first

`ADR-0002` (now Accepted) D1 (message is the unit), D4 (the barrier ordering), D5 (the three label
operations; no `Delete Forever`; idempotence), D6 (the bounded, inspectable Undo log; the 30-day Trash
window to confirm here); DECISIONS §7 (the disposition barrier; source disposition is independent of
Stream Handling and of Today `Clear`); EMAIL-INTELLIGENCE-MODEL §5; the S6 delta-sync / partial-commit
path (the read side the barrier sits on).

### Scope

- **The three dispositions map to label operations (D5):** `Leave` = no-op; `Archive` =
  `messages.modify` removing `INBOX` (reversible by re-adding); `Trash` = `messages.trash` (reversible by
  `messages.untrash` within Gmail's ~30-day purge window). `Delete Forever` is **not** implemented.
  Requesting a disposition already in effect is idempotent success.
- **The disposition barrier (D4), per message:** read → classify/extract → persist the promised durable
  result → **verify the commit** → advance `historyId` → apply the disposition. A disposition is
  attempted only against a message whose promised results are already durable; if commit fails the
  message keeps `INBOX` and the disposition is a no-op that re-enters next sync.
- **Bounded Undo as an inspectable local log (D6):** every applied disposition writes `providerID`, the
  operation, the timestamp, and the inverse; recent dispositions are inspectable and individually
  reversible where Gmail permits (Archive always; Trash until purge). Undo issues the inverse label
  operation and records that it did — not a parallel thread-resolution state (§7). Lean device-local
  first (ADR D6 open item; ADR-0001 D2). Confirm the 30-day `untrash` recovery here (D6's empirical part).
- **Explicit per-action only in this slice.** The user resolves a message and its disposition applies;
  no policy, no automation (that is S8). `Clear` stays attention-only and does not mutate.

### Done-criteria

1. `Leave`/`Archive`/`Trash` apply as the D5 label operations; Archive and Trash are individually
   reversible via the Undo log; `Delete Forever` is absent; re-applying is idempotent. Verified through
   the disposition model against a fake Gmail label API.
2. The barrier holds: an adversarial test proves **no disposition is applied before the promised durable
   result is committed and verified**, and a failed commit leaves the message in `INBOX` with the
   disposition a no-op that re-enters on delta sync.
3. The Undo log records each disposition with its inverse and reverses it where Gmail permits; Undo is
   not a parallel resolution state. Verified through the log model.
4. `Clear` still writes no provider mutation (adversarial test, carried from S4). `swift test` +
   `swiftlint --strict` green; the disposition affordances, the trust of "nothing was lost," and the
   live `untrash` recovery within the 30-day window are Jon's device pass — a live disposition against
   real labels / a real Trash purge is named as a device-only risk in the handoff.

### Out of scope

Any explicit recurring policy (S8). Multi-account disposition (ADR D8). `Delete Forever`, a rules
engine, learned/auto deletion, automatic unsubscribe (DECISIONS §7). Promotions/Social sifting at scale.

---

## S8 — The smallest explicit disposition policy that proves the authority model

**Branch:** `m5/s8-explicit-policy` · **PR title:** `M5 · S8 — Explicit disposition policy`

Phase 4's authority test: prove that a *user-established* policy can carry a disposition without opening
the door to a rules engine or to learned deletion. One policy, explicit, proposable-not-automatic.

### Read first

`ADR-0002` D7 (explicit-per-action first; the only automation is an explicit user-established policy; AI
classifies-to-apply and proposes, never acquires destructive authority from behaviour); DECISIONS §7 (no
generic rules engine; smallest explicit policies only) and §8 ("knowledge does not grant agency");
V1-SCOPE Phase 4 ("add only the smallest explicit recurring policies necessary to prove the authority
model"); the S7 disposition barrier + Undo log (the policy rides them).

### Scope

- **One explicit, user-established policy** — the canonical case is "Trash disposable retail offers after
  extracting a Find" (the wine-offer / promo case): the user authorizes it explicitly, and thereafter a
  message the classifier matches is disposed **through the same barrier** (Find committed and verified
  first). The policy is a small explicit record, not a rule in an engine.
- **Candidate to prove the model: auto-Trash login/verification codes** (the S3 ephemeral sub-case;
  Jon, 2026-09-18). It is arguably the cleanest demonstration — an OTP has *no* promised durable result
  to retain, so the barrier is trivially satisfied (nothing to commit before Trash) and it isolates the
  authority question on its own. The wine-offer case exercises the commit-then-Trash barrier more fully;
  either (or both) can be the "smallest explicit policy" — still explicit, still logged and reversible,
  never a silent learned delete. Which one proves the model is Jon's / the architect's call at S8.
- **AI classifies to apply, and may propose — never authorizes.** The model may tag a message as
  matching an authorized policy, and may *surface a proposal* for a new policy, but the policy only
  exists once Jon establishes it explicitly; no destructive authority is inferred (D7; §8).
- **Everything the barrier and Undo guarantee still holds.** A policy disposition is still per-message,
  still behind commit+verify, still logged and reversible. A policy can be turned off; turning it off
  stops future dispositions and does not un-dispose past ones (those are Undo's job).
- **Persistence discipline.** The policy is the smallest table the one demonstrated case justifies — not
  a generalized condition/action engine (DECISIONS §7; `AGENTS.md`).

### Done-criteria

1. An explicit user-established policy disposes matching messages **only through the barrier** (promised
   result committed and verified first); with the policy absent or off, no disposition occurs.
   Verified through the model.
2. No policy is created, and no disposition is authorized, without an explicit user action — AI may
   classify and propose but never authorizes (adversarial test: no policy or destructive action appears
   from observed behaviour alone).
3. Policy dispositions are logged and reversible like per-action ones; turning a policy off halts future
   dispositions without un-disposing past ones. Verified through the log model.
4. The persistence is a single small explicit-policy record, not a rules engine. `swift test` +
   `swiftlint --strict` green; whether the one policy *feels* trustworthy in daily use is Jon's device
   pass.

### Out of scope

A generic rules/Disposition-Rule engine, multiple policy types, learned or automatic deletion, automatic
unsubscribe (DECISIONS §7; V1-SCOPE). Email-delivered recurring Streams (Phase 5 / M6). Any second
policy beyond the one the authority model needs.

---

## Jon's manual and device pass

Same shape as M1–M4: the work only Jon can do, gating what follows.

### During S2 + S4 — whether Today reads as a brief (the real §24 lived-use test)

The method trap is the point: **"feel" cannot be evaluated against a scaffold.** S4 is the first surface
Jon can honestly judge for "does the morning read as an inviting brief, or as Gmail subtly re-sorted,"
and only once S2 has made bodies legible — an inviting brief of unreadable paragraphs is not testable.
Two knobs to judge inside that test: whether **promotion** (which new arrivals get surfaced) and
**highlight** (which personal mail is elevated) pick the right things on real morning mail, and whether
the **counts** read as orientation rather than noise. If the composed surface still does not feel like
less work than scrolling, the composition is wrong, not just the styling — the S1 note is what gets
revised.

### During S3 — whether the transactional split is right on real mail

The four real cases (UPS shipment, `do_not_reply` trade-in notice, sign-in code, hotel confirmation)
that scattered at the S7 pass should now land in the transactional rung, and nothing a human sent 1:1
should. Where the deterministic heuristic misses, the per-sender override is the fix — and whether the
miss rate is low enough that the override is a rare correction (versus a constant chore) is a lived-use
judgement, not a scored one.

### During S5 — whether the slow tail now reads as working, not broken

Agents make the tail compose always-resolving and add progress; whether that progress actually reads as
progress — and whether a multi-minute recompose is *tolerable* pending the deferred type-model swap, or
whether the recorded latency is bad enough to pull the swap forward — is your device-pass and product
call. The number S5 records against the 60s budget is the §23 evidence for that decision.

### During S6 — the Gate-3 items are yours, and they gate ratification

`ADR-0002` cannot move Draft→Accepted until multi-message thread distinctness and new-reply re-entry are
observed on your real Inbox, and the documented quota constants are confirmed to hold under a real paced
backfill. Agents build delta sync and partial commit (which make those observable); you run a real sync
and confirm the behaviour. Ratification waits on these — do not let the ADR be accepted from design
intent.

### During S7–S8 — whether mutation is trustworthy

The disposition barrier, Undo, and the one explicit policy are model-tested, but whether a real
`Archive`/`Trash` against your live labels does exactly what the affordance promised — and whether
`untrash` recovers a message within Gmail's 30-day window — is a device-only observation. It is also the
last safety check before Phase 5 wires email into Streams. If a live disposition behaves differently from
the fake-API tests, that is evidence for the ADR to reopen, not a styling note.

---

## Not in M5 — the M6+ cutline

- **Email-delivered recurring Stream (Phase 5) → Architecture Gate 4.** The always-read newsletters
  (Yglesias, Puck, Sepinwall) flowing from Gmail into the uncurated tail / Stream Handling / Essential.
  This is the **critical separation test** — that Transport, Artifact, ContentPiece, Stream Handling,
  source disposition, and Edition state are genuinely separate — and it carries **Gate 4, the major
  model review**. It is a milestone-sized architectural test, which is why the 2026-09-18 scope decision
  put it in M6, not M5. **Read first at that time:** DECISIONS §21 (now *absorbed by §24*) — the
  reachable-first vs. promote-into-the-package question; do not silently assume `Essential` means
  "promote." §24 already dissolved the *promotion* effect for curated streams, so this phase inherits
  "reachable-first" as the working default, to be confirmed against real use.
- **The type-call model swap.** Moving the M4-S1 PK-free classification pass to a faster/cheaper model
  once it can emit the schema. **Largely dissolved for the curated path** by §24 (curated mail never
  runs the editorial pass; the two-pass latency §23 tracked applies only to the uncurated tail). Its
  trigger to move ahead of its deferred slot is **S5's recorded tail latency**: if a real on-device tail
  recompose stays well over the §7 60s budget and the progress affordance does not make that tolerable,
  the swap moves up. Measure (S5) before scheduling it.
- **Auto-Library policy (Phase 7).** After explicit Library + custody are trustworthy; one proven
  Stream-level prospective policy. Must **not** reuse `isSubstantivePrimary` as the keep-criterion
  (DECISIONS §18, reconciled at Gate 2).
- **First specialist Find handoff (Phase 6) → Architecture Gate 5.** The receiver for the Pending Finds
  that have accumulated since M2-S5 (and now the M4 offer-treatment Finds). Extraction exists; the
  receiver (whichever of Galavant / Yes Chef exposes the cleanest real admission boundary) is later.
- **Promotions/Social at scale.** Reading the large non-Primary categories on their own budget/cadence
  for promo sifting and retail/wine Finds (ADR-0002 D2 names them in scope for a later stage; S6 hardens
  only the Primary read and the delta mechanism).
