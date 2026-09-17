# M4 — The Gmail transport opens, and the daily loop deepens

> **DRAFT for architect review.** Drafted 2026-09-16, immediately after Architecture Gate 2 closed
> (`docs/eval-log.md`, 2026-09-16). This is the proposed sliced build order for M4. The contract
> numbers and definitions cited are not reinterpreted here.

> **Re-centered 2026-09-16 by DECISIONS §24.** The sections below were drafted with Edition as the
> product centerpiece and a Gmail *Today* built on a "Worth Seeing" relevance taxonomy. §24 reverses
> that: **typed triage of curated input is the V1 spine, and the editorial finite-package judgment is
> demoted to the barely-curated tail.** M4 *is* that spine now. S1–S3 and S6 stand as built. **S4 gains
> raw-header retention; S5 is re-scoped from "Worth Seeing" to type/relationship treatment routing; new
> S7–S9 build the hierarchical Today surface, the offer/grab-bag treatments, and the fold of Edition
> into Today.** Where this banner and an older passage below disagree, §24 and the revised slice ledger
> win. The contract amendments §24 obligates (`JUDGMENT-CONTRACT` §1, `IMPLEMENTATION-CONTRACT` §3, the
> `V1-SCOPE` re-sequence, and the `AGENTS.md` shell) are tracked on the `m5/recenter-typed-triage`
> branch and land with S9.

## What M4 is

M3 delivered a real iPad shell and turned the harness's Personal-Knowledge signal into a product
signal: a real 30-claim set moved 278/357 pieces and 58 admissions in the right direction while the
Essential floor held (Gate 2, `docs/eval-log.md`). The morning loop is now genuinely pleasant to live
in — and that lived use exposed the next two jobs.

M4 has two jobs, in the same **dogfooding-first / open-a-new-transport** shape M3 used:

1. **Deepen the existing loop where daily use hurts.** Three things M3 left owed now bite every
   morning: the Reader stops at the summary and sends Jon to Safari to actually read (DECISIONS §20);
   there is no way to keep a piece for a flight or a tunnel (Offline controls, V1-SCOPE §1); and the
   single judgment pass lets Personal Knowledge bleed into the `isSubstantivePrimary` *type* call —
   the Gate-2 finding (0.545 → 0.415 under teaching) whose remedy the architect ratified into M4.
2. **Open the second transport — Gmail read-only Today (V1 Phase 3 → Architecture Gate 3).** Ratified
   out of M3 on 2026-09-15; Phase 2 and Phase 3 have no dependency on each other, so M4 opens Gmail
   as its own milestone with its own gate. The milestone's real architectural deliverable is the
   **Gmail integration ADR written from observed semantics** — not the surface.

```text
read what Cockpit already holds, inline (Reader body)
→ keep it deliberately (Offline until / Keep Offline)
→ stop PK bleeding into the type call (split type from editorial)
→ open Gmail read-only → classify each piece's treatment (personal / newsletter / offer / grab-bag)
→ render a type-differentiated Today hierarchy → treatments (offer summary+Find; grab-bag extract)
→ fold Edition into Today's uncurated tail → Reader → Clear (attention only; no mutation)
→ write the Gmail integration ADR from what the provider actually did
```

M4 ends at **Architecture Gate 3** (`docs/V1-SCOPE-AND-SEQUENCING.md` Phase 3). Only after that gate
does source *mutation* (Phase 4 dispositions) become enabled — read-only comes first by contract
(EMAIL-INTELLIGENCE-MODEL §13; DECISIONS §7).

## The gate before M4 begins

**M4 opens on a closed Gate 2** (`docs/eval-log.md`, 2026-09-16) — done. Two carry-ins are ratified
Gate-2 output rather than fresh decisions:

- **Split the type/classification call from the editorial call** (S1 below). Ratified at Gate 2 as
  the remedy for PK bleeding into `isSubstantivePrimary` (DECISIONS §18 Gate-2 finding). It also
  advances the M2-S1 cost lever — the type/subjects/summary pass is exactly the "mechanical grunt-work"
  a cheaper/onboard model can eventually own once it can emit the schema.
- **Auto-Library stays at Phase 7**, reconciled at Gate 2 (DECISIONS §18) — **not** M4.

The Gmail spine has one standing precondition already met: the D7 auth spike is done and a
production-issued refresh token is in the Keychain (`docs/eval-log.md`, 2026-09-11). D7's remaining
production-longevity question is answered *for free* by the first Gmail read made more than an hour
after authorization (access tokens last ~1h) — S4 confirms it in passing. If that read fails, the
ADR-0001 fallback stands: evaluate IMAP with an app password before Today is designed around the
Gmail API.

## Slice ledger

- [x] **S1 — Split the type/classification call from the editorial call** *(Gate-2 carry-in)* — merged, PR #25
- [x] **S2 — Reader inline body** *(DECISIONS §20)*
- [x] **S3 — Offline controls: `Offline until [date]` and `Keep Offline`**
- [x] **S6 — Composition latency: parallelize the type pass** *(DECISIONS §23)* — PR #29 (merge is Jon's)
- [x] **S4 — Gmail read-only ingest: Inbox → provider Artifact → email ContentPiece** *(+ raw-header retention for S5; §24)*
- [x] **S5 — Treatment classification: personal / newsletter / offer / grab-bag** *(§24; replaces the "Worth Seeing" taxonomy)*
- [ ] **S7 — The Today hierarchy surface: type-differentiated view, `Clear`** *(§24)*
- [ ] **S8 — Treatments: offer → summary + Pending Find; grab-bag → within-issue extraction** *(§24)*
- [ ] **S9 — Fold Edition into Today; demote the editorial pass to the uncurated tail** *(§24; shell change; contract amendments land here)*
- [ ] **Architecture Gate 3 — write the Gmail integration ADR from observed semantics**

S1–S3 and S6 deepened the existing loop and are built. **Under §24 the remaining spine is ordered and
each slice depends on the one before:** S4 (ingest the curated input, retaining the headers S5 reads)
→ S5 (route each piece to a treatment) → S7 (render the type-differentiated hierarchy) → S8 (the two
treatments that need model work) → S9 (fold Edition in and demote the editorial pass). **Gate 3 (the
Gmail ADR) still closes M4** and still precedes any Phase-4 mutation. The old rationale — "S4 → S5 →
Gate 3 is the Gmail spine" — held; §24 just lengthens the spine and changes what S5 onward *does* with
the ingested mail (organize by type, not judge by relevance).

## Standing rules for every M4 slice

The M1–M3 standing rules carry over unchanged. The ones that bite hardest in M4:

**Read-only before mutation — by contract.** M4 reads Gmail and never mutates it. No Archive, no
Trash, no read/unread writes. `Clear` is a **Cockpit attention** action, not a provider action
(DECISIONS §7; TODAY-EXPERIENCE §6) — it must not touch Gmail state. Provider mutation is Phase 4,
behind the Gate-3 ADR (DECISIONS §7: "external mutation happens only after Cockpit successfully
commits any result it promises to retain").

**`Clear` is Today's action; `Dismiss` is Edition's.** Different words for different operations
(DECISIONS §7, §15; TODAY-EXPERIENCE §6). Do not unify them.

**The ADR is written from observed behaviour, not designed up front.** The whole point of a read-only
phase is to learn message-vs-thread identity, account boundary, pagination/delta, new-reply re-entry,
and failure/retry from the real provider before committing the contract (V1-SCOPE §Phase 3;
EMAIL-INTELLIGENCE-MODEL §10, §13). Do not pre-freeze the Gmail schema in S4/S5.

**Knowledge does not grant agency** (PK-MODEL §11). Nothing in Gmail analysis — not a classification,
not a "quiet handling" — may acquire disposition authority. Automatic Archive/Trash exists only under
an explicit user policy, and not until Phase 4 (DECISIONS §7).

**The eval floor still gates the judgment change.** S1 alters the judgment pass, so it is measured
through `JudgmentEval` against the frozen corpus under the **paired** essential-false-quiet discipline
ratified at Gate 2 (DECISIONS §22.2): a same-session control run (old single-pass vs new split-pass),
floor not regressed. Substantive-primary accuracy is the metric S1 is trying to move — record it.

**Verification: model state is tested; pixels are Jon's pass** (`AGENTS.md`). The Today layout, the
Reader body typography, and the offline-badge presentation are Jon's device pass. Agents ship the
tested models (the Gmail ingest/normalization, the Today projection, the Reader join, the offline
state machine) and hand the look to Jon.

---

## S1 — Split the type/classification call from the editorial call

**Branch:** `m4/s1-type-editorial-split` · **PR title:** `M4 · S1 — Type/editorial split`

The Gate-2 finding made concrete: the M3-S5 paired run showed `isSubstantivePrimary` accuracy falling
**0.545 → 0.415** when the same corpus was taught (`docs/eval-log.md`, 2026-09-15). PK moved a *type*
property it has no business touching (DECISIONS §18). The single judgment pass conflates the
classification question (*is this the Stream's primary authored work, or an accessory?*) with the
editorial question (*of what arrived, which ~20 deserve this morning, ranked, sectioned, deduped?*).

### Read first

`docs/JUDGMENT-CONTRACT.md` §2–4 (the projection in, the structured output, per-piece fail-closed);
DECISIONS §18 (type vs value, and the Gate-2 finding) and §22 (the paired floor); the M2-S2 judgment
engine and the M3-S5 re-request pass; `docs/eval-log.md` (the baseline this is measured against).

### Scope

- **`isSubstantivePrimary` (and the mechanical subjects/summary extraction) become a separate
  classification pass** that does **not** receive the Personal-Knowledge projection — it is a type
  call, PK-free by construction (JUDGMENT-CONTRACT §2). The editorial pass keeps PK and does admission
  / rank / section against `targetSize`.
- **Frontier stays on the editorial call** (the taste-laden finite-package judgment); the type pass is
  where a cheaper/onboard model can later live *when it can emit the schema* (M2-S1 cost decision).
  M4 does the split; the model swap is not required here and stays behind the schema blocker.
- **No new judgment machinery** beyond separating the two calls and their prompts/versions.

### Done-criteria

1. The type/classification pass receives no PK projection; a `JudgmentEval` run shows
   substantive-primary accuracy no longer moves bare-vs-taught (the bleed is closed), verified through
   the judgment output.
2. Recorded `JudgmentEval` run: substantive-primary accuracy improves against the M3-S5 baseline, and
   essential-false-quiet does not regress against a **same-session control** (single-pass vs split-pass),
   per DECISIONS §22.2, in `docs/eval-log.md`.
3. Cost/latency of the two-pass shape recorded (a second call has a cost; confirm it stays within the
   §7 budget or note the lever).

### Out of scope

The actual onboard/Haiku model swap (behind the schema blocker; a later cheapest-lever eval).
Auto-Library's use of the type flag (Phase 7). Any change to what the editorial call *does* with PK.

---

## S2 — Reader inline body

**Branch:** `m4/s2-reader-inline-body` · **PR title:** `M4 · S2 — Reader inline body`

Ratified intent, DECISIONS §20. Today the one investigate-this-item surface stops at the `summary` and
Open Original is the only way to actually read — so the Reader sends Jon out of the app every morning.
The substance is already modelled: `LocalNormalizedText` holds the text (device-local) and
`bodyCompleteness` already rides the Reader projection. The work is a `leftJoin` plus honest rendering,
**not** a browser.

### Read first

`docs/DECISIONS.md` §20; `docs/IPAD-FIRST-EXPERIENCE.md` §7–8; `docs/IMPLEMENTATION-CONTRACT.md`
§Body completeness; `ContentPieceReaderRequest` / `ContentPieceReaderModel` (the projection to extend);
`LocalNormalizedText`; ADR-0001 D6 (why the text is device-local and completeness is the synced signal).

### Done-criteria

1. A ContentPiece whose device holds `LocalNormalizedText` renders that body inline beneath the
   summary: `bodyCompleteness = full` reads inline; `truncated` reads inline **plus** Open Original for
   the remainder; `teaser` shows preview only with Open Original as the sole path. Verified through the
   Reader model's projection, not a UI snapshot.
2. A piece that synced in with `bodyCompleteness = full` but **no local text on this device** renders
   honestly — states the body is not held here, offers Open Original, asserts no substance it lacks
   (the D6 custody case; adversarial test on the projection).
3. Open Original is the fallback, not the default: absent/secondary when a full body reads inline.
4. A digest / non-substantive-primary piece keeps its compact contents-preview card (DECISIONS §19),
   not a full inline body.
5. **No** network fetch of the original to fill body (no scrape) — held/derived text only.
   `swift test` + `swiftlint --strict` green; typography/geometry handed to Jon's device pass.

### Out of scope

Reader typography/geometry (deferred), HTML-fidelity polish, and the offline *controls* themselves
(S3 — this slice renders the substance those controls retain).

---

## S3 — Offline controls: `Offline until [date]` and `Keep Offline`

**Branch:** `m4/s3-offline-controls` · **PR title:** `M4 · S3 — Offline controls`

V1-SCOPE §1 and IPAD-FIRST §8 — especially important on mobile. Per-piece, not bulk, in V1.

### Read first

`docs/V1-SCOPE-AND-SEQUENCING.md` §1 (Custody and offline); `docs/IPAD-FIRST-EXPERIENCE.md` §8;
ADR-0001 D6 (`LocalAvailability` / normalized-text custody, device-local); `docs/IMPLEMENTATION-CONTRACT.md`
(`LocalAvailability` state); DECISIONS §6 (custody and offline availability).

### Scope

- **`Offline until [date]`** — a per-piece explicit offline promise with **visible expiry** (initially
  ~30 days). Distinct from device-local automatic cache: this is a user promise, not cache policy
  (V1-SCOPE §1; a Product law).
- **`Keep Offline`** — an indefinite per-piece promise.
- Both are explicit state on `LocalAvailability`, surfaced in the Reader; nothing silently expires
  before its date, and expiry is honest and visible.

### Done-criteria

1. A piece marked `Offline until [date]` carries visible expiry and retains its device-local substance
   until that date; `Keep Offline` retains indefinitely. Verified through the `LocalAvailability` model.
2. Automatic cache eviction never removes a piece under an active offline promise (adversarial test:
   eviction pass respects the promise).
3. Expiry is visible and honest; a lapsed promise degrades to the ordinary cache/Open-Original story
   without asserting substance it no longer holds.
4. Per-piece only; `swift test` + `swiftlint --strict` green; badge/affordance presentation to Jon.

### Out of scope

Bulk / Stream-wide offline rules, trip-aware preparation, travel download (all deferred, V1-SCOPE §1).

---

## S4 — Gmail read-only ingest: Inbox → provider Artifact → email ContentPiece

**Branch:** `m4/s4-gmail-ingest` · **PR title:** `M4 · S4 — Gmail read-only ingest`

The first half of the Gmail spine: read the Inbox and normalize it into the existing Artifact →
ContentPiece spine, **read-only**. This is where the real provider semantics are first observed — the
raw material for the Gate-3 ADR.

### Read first

`docs/EMAIL-INTELLIGENCE-MODEL.md` §10, §13; ADR-0001 D7 (the auth spike, refresh token, `gmail.modify`
scope — read-only usage of it now); `docs/ADR-0001-PERSISTENCE-AND-EXECUTION.md` D3 (derived identity —
how an email becomes a ContentPiece without a random id); DECISIONS §7 (source disposition is separate
and not yet enabled); the existing RSS ingest path (the Artifact → ContentPiece shape to reuse, not
re-invent).

### Scope

- **Confirm the token in passing** — the first read >1h after authorization answers D7's production
  question for free (`docs/eval-log.md`, 2026-09-11). Record the result.
- **Read the current Inbox** (read-only) and **normalize each message into a provider Artifact**, then
  project to an **email ContentPiece** through the existing spine (derived identity, ADR-0001 D3). No
  new universal entity; the email ContentPiece is a ContentPiece.
- **Retain the raw classification headers as provider Artifact provenance** — `List-Unsubscribe`,
  `List-ID`, `Precedence`, the sending domain / DKIM `d=`, and `To`/`Cc` cardinality. These are the
  deterministic signals S5 splits personal from publication on (§24); capturing them at ingest is why
  S5 needs no Contacts scope and no learned reputation store. Provenance only — S4 does not classify.
- **Observe and record the semantics the ADR will settle** — message vs thread, account boundary,
  pagination/delta, provider IDs retained, new-reply re-entry, partial failure/retry. This slice's job
  is to *surface* them, not to freeze them.
- **No mutation, no `Clear` yet** — ingest and normalization only.

### Done-criteria

1. Gmail Inbox reads through the stored authorization; the D7 production-longevity result is recorded
   in `docs/eval-log.md`. (On failure: stop and evaluate the IMAP fallback per ADR-0001 D7 before S5.)
2. A message becomes a provider Artifact and an email ContentPiece via the existing derived-identity
   spine — no random id, no new universal entity — verified through the ingest model.
3. The observed provider semantics (message/thread, account, pagination/delta, IDs, re-entry, failure)
   are captured as notes toward the Gate-3 ADR, in the PR and/or a scratch doc.
4. The raw classification headers (`List-Unsubscribe`, `List-ID`, `Precedence`, sending domain/DKIM,
   recipient cardinality) are retained on the provider Artifact and readable by the ingest model — the
   signals S5 classifies on (§24). Verified through the ingest model.
5. Nothing mutates Gmail. `swift test` + `swiftlint --strict` green.

### Out of scope

Any provider mutation (Phase 4). Treatment classification (S5) and the Today surface (S7). Finalizing
the Gmail contract (Gate 3). Email-delivered recurring **Streams** (Phase 5).

---

## S5 — Treatment classification: personal / newsletter / offer / grab-bag

**Branch:** `m4/s5-treatment-classification` · **PR title:** `M4 · S5 — Treatment classification`

The triage brain. §24 replaced the "Worth Seeing / Personal-Consequential" relevance taxonomy — the
judge-by-relevance framing §24 demotes — with a **treatment tag per piece** that decides how Today
renders it (S7). Classification only: no surface here, and no cross-item editorial call over curated
mail.

### Read first

DECISIONS §24 (the whole slice exists to serve it; the header-classifier and per-sender-override
decisions); `docs/EMAIL-INTELLIGENCE-MODEL.md` (analysis/quiet handling, reread through §24's lens —
organize, don't select); the surviving type pass (`JudgmentEngine.classify` — kind,
`isSubstantivePrimary`, subjects, summary: the interpretive work §24 keeps); the S4 provider Artifact
headers (the deterministic signals); DECISIONS §8 and the AI boundary (`AGENTS.md`) — the model tags,
it never suppresses.

### Scope

- **Assign each ingested piece one treatment: `personal`, `newsletter`, `offer`, or `grab-bag`.** A
  per-piece routing tag, not a new entity — the smallest thing that drives S7's hierarchy.
- **Personal vs. publication is deterministic first, from the S4 headers.** Bulk/publication mail
  carries `List-Unsubscribe` / `List-ID` / `Precedence: bulk` / an ESP sending domain; 1:1 human mail
  essentially never does. Absence of those + narrow recipient cardinality → `personal`. This gets the
  overwhelming majority right with **no Contacts scope, no learned store, no model guess** (§24, the
  header-classifier decision — Contacts is both too blunt and too big for the signal a header gives free).
- **`offer` and `grab-bag` sit on top of the publication set.** `offer` is promotional/commercial
  publication mail (the wine-offer case) — a cheap type signal (type-pass `kind` + promotional markers).
  `grab-bag` is a **manual per-Stream flag** (Feed Me → grab-bag; §24 forbids a detector for
  one-and-a-half streams). Everything else in the publication set is `newsletter` (the think-piece default).
- **An explicit per-sender override, not a whitelist.** When the deterministic tag is wrong, Jon flips
  that sender and the flip persists as an explicit, user-authored fact that wins over the default —
  corrections-on-top-of-a-default, seeded by nothing and grown only by correction, never a curated
  reputation store (§24; persistence discipline: the smallest table a demonstrated misclassification
  justifies).
- **The model tags; it never hides.** A treatment tag changes *placement*, never *membership*. No piece
  is suppressed, declined, or archived by classification (AI boundary; §24). A miss is a visible,
  correctable misplacement, not lost mail — which is why the cheap classifier + override is proportionate.

### Done-criteria

1. Every ingested email piece carries exactly one treatment tag; the personal/publication split is
   computed deterministically from the retained headers (a piece with `List-Unsubscribe` is never
   `personal`). Verified through the classification model on fixtures covering each header shape.
2. `offer` and `grab-bag` are assigned (offer from type/promotional signal; grab-bag from the Stream
   flag); everything else in the publication set is `newsletter`. Verified on fixtures.
3. An explicit per-sender override changes the tag and survives recomposition; nothing is learned or
   auto-added (adversarial test: no override appears without an explicit user action).
4. Classification writes no provider mutation and hides nothing. `swift test` + `swiftlint --strict` green.

### Out of scope

The Today surface and rendering (S7). The offer/grab-bag *treatments* — summary, Find, extraction (S8).
`Clear` (S7). Any Contacts integration or learned reputation store (§24 — revisit only if headers +
overrides prove insufficient). Gmail dispositions (Phase 4).

---

## S6 — Composition latency: parallelize the type pass

**Branch:** `m4/s6-composition-latency` · **PR title:** `M4 · S6 — Composition latency`

Discovered in S1's device pass, not planned up front. A real recompose ran **~6 minutes ($0.48) on
iPad** — ~6× the §7 60s budget (DECISIONS §23, triggered; `docs/eval-log.md`, 2026-09-16 device pass).
The split's *quality* is proven; its *latency* is now a live problem, and the Gmail spine (S4–S5)
compounds it, so this lands **before** S4.

Root cause: `EditionComposer.composeIfNeeded` sends the whole day's candidates to `engine.judge` as
one large type call then one large editorial call, sequentially — none of the batching/concurrency the
eval harness already uses.

### Read first

DECISIONS §23 (triggered) and §13 (the budget clause it reopens); JUDGMENT-CONTRACT §1 (batching is
load-bearing for the editorial *finite package*; the type pass is not); `EditionComposer.composeIfNeeded`
and `JudgmentEngine.judge` / `classify` (the monolithic path); `JudgmentEvalLiveTests.judgeCorpus`
(the bounded-concurrency pattern already proven for the eval — reuse its shape, don't reinvent it).

### Scope

- **Parallelize the PK-free type pass inside the engine.** `classify` chunks candidates into
  composition-sized batches run under bounded concurrency, reassembling per-piece. The type pass
  carries **no** finite-package constraint (§1), so this changes only wall time, not outcomes. Smaller
  per-call responses also cut truncation risk (the `JudgmentEnvelope` salvage fires less often).
- **The editorial pass stays one call** over the full candidate set — the finite-package property
  (§1). For >120 candidates the existing Interest-Area split + second pass applies; do **not** shard
  editorial into independent batches (that produces a ranked feed, the product Cockpit is not).
- **Measure on device** before/after; record the real recompose latency against the 60s budget.
- **The type-model swap stays deferred** (§23; behind the schema blocker). S6 is the safe wall-time
  win, not the model change.

### Done-criteria

1. Production composition parallelizes the type pass under bounded concurrency; a real on-device
   recompose is materially faster than the ~360s S1 baseline, recorded in `docs/eval-log.md` against
   the 60s budget. If still over, the residual gap is quantified and the model swap re-scoped with
   evidence rather than left implicit.
2. **Outcomes are unchanged by parallelization** — a `JudgmentEval` run shows essential-false-quiet
   and substantive-primary accuracy within same-session noise of the pre-S6 split, and the editorial
   finite-package selection is untouched (still one call; `targetSize` honored). Parallelizing per-piece
   classification must not move judgments.
3. Per-piece fail-closed and the `JudgmentEnvelope` salvage still hold across the batched type pass: a
   failed or omitted type batch degrades per-piece and is re-requested, never silently dropped.
4. `swift test` + `swiftlint --strict` green; the device latency number is Jon's pass.

### Out of scope

The type-model swap (§23; behind the schema blocker; M5+). Trimming the editorial pass's resent bodies
(a finds/rationale-quality trade-off — a separate measured lever only if S6 leaves the budget
breached). Any change to the editorial finite-package call itself.

---

## S7 — The Today hierarchy surface

**Branch:** `m4/s7-today-hierarchy` · **PR title:** `M4 · S7 — Today hierarchy`

Render the treatment tags (S5) as the product: a **hierarchical, type-differentiated Today** that
replaces the flat, arrival-ordered inbox §24 indicts. Lands in the Today destination the M3 shell built
(currently a placeholder Edition summary).

### Read first

DECISIONS §24 (the flat-inbox critique and the hierarchy contract — hierarchy is by type/relationship,
deterministic; within a type it is arrival order, "mood not priority"); `docs/TODAY-EXPERIENCE.md` §5–6
(surfaces and `Clear`, reread through §24); the M3-S1 Today container and the one ContentPiece-driven
Reader.

### Scope

- **Group Today by treatment into a fixed cross-type hierarchy:** personal (highlighted) → newsletters
  (listed) → offers (summarized, S8) → grab-bags (extracted, S8). Order across tiers is deterministic;
  **within a tier, arrival order** (§24 — ranking peers is a mood, not Cockpit's job).
- **Each tier's rendering is its treatment's visual rank** — a personal note reads as elevated, a
  newsletter as a compact list row — by tier, not by a per-item score.
- **The one Reader serves email pieces** (IPAD-FIRST §7; S2 inline body where held). An email piece
  carries no Edition affordances (no rationale, no Dismiss).
- **`Clear` resolves Today attention** — a Cockpit attention action, **no Gmail mutation** (DECISIONS
  §7; TODAY-EXPERIENCE §6). Distinct from Edition's `Dismiss`.

### Done-criteria

1. Today renders the four tiers in the fixed order, each piece placed by its S5 tag; within a tier,
   arrival order. Verified through the Today projection model.
2. `Clear` resolves Today attention and provably does not mutate Gmail (adversarial test: no provider
   write on `Clear`).
3. An email piece opens in the one Reader with inline body where held and carries no Edition-only
   affordances.
4. `swift test` + `swiftlint --strict` green; the tier layout and visual weighting are Jon's device pass.

### Out of scope

The offer/grab-bag model treatments (S8 — S7 renders a plain row until S8 fills them). Edition's fold
into Today (S9). Gmail dispositions (Phase 4).

---

## S8 — Treatments: offer summary + Pending Find; grab-bag extraction

**Branch:** `m4/s8-treatments` · **PR title:** `M4 · S8 — Treatments`

The two treatments that need model work. Personal-highlight and newsletter-list are presentation done
in S7; this slice fills the offer and grab-bag tiers with their content.

### Read first

DECISIONS §24 (offers summarized now, handoff later — Jon's call 2026-09-16; grab-bag = within-issue
extraction, the one place sifting runs on curated input); DECISIONS §3 (Finds — the offer becomes a
Pending Find); the existing Find-extraction path (Phase 1); the type-pass summary.

### Scope

- **`offer` → a one-line summary and a Pending Find** (the wine-offer case). Reuse the existing
  Find-extraction path (Phase 1); the Find is the specialist-app candidate. **Summary + Find now;
  specialist handoff stays its later phase (Phase 6)** — the offer tier is useful before any receiver
  exists (§24; DECISIONS §3, Pending Finds survive without a receiver).
- **`grab-bag` → within-issue item extraction.** Decompose the flagged issue into its contained items
  and list the worthwhile ones inside the grab-bag tier. This is the **only** editorial-style sifting
  that runs on curated input, and it runs **inside one piece**, never across pieces (§24).
- **No cross-item editorial finite-package call over curated mail** — that pass is demoted in S9 and
  never runs here.

### Done-criteria

1. An `offer` piece produces a one-line summary and a Pending Find via the existing extraction path;
   the Find persists with no receiver (Phase 6 unaffected). Verified through the model.
2. A `grab-bag` piece is decomposed into its contained items and rendered within its tier; extraction
   is per-piece and never ranks across pieces. Verified on a Feed Me fixture.
3. `swift test` + `swiftlint --strict` green; the offer/grab-bag tier presentation is Jon's device pass.

### Out of scope

Specialist handoff / the Find receiver (Phase 6). A grab-bag detector (§24 — grab-bag is the manual
Stream flag from S5). Any within-tier ranking (§24).

---

## S9 — Fold Edition into Today; demote the editorial pass to the uncurated tail

**Branch:** `m4/s9-edition-into-today` · **PR title:** `M4 · S9 — Edition into Today`

The re-centering's structural close. Edition stops being a top-level destination and becomes the
**uncurated-tail section within Today**; the editorial finite-package pass runs only there. This slice
carries the contract amendments §24 obligates.

### Read first

DECISIONS §24 (Edition folds into Today, dropped from the shell — decided 2026-09-16); §5/§14 (Edition
remit and `targetSize`, amended in remit here); JUDGMENT-CONTRACT §1 (finite package — now scoped to
the tail); `EditionComposer` / `EditionPlanner` (the composition path to re-scope); `AGENTS.md`
"Current shell".

### Scope

- **Edition becomes a section within Today**, fed only by the **barely-curated tail** — aggregator
  Streams the user has not pre-curated (the "Technology stories" case), where ruthless screening is
  wanted. The shell becomes `Today / Later / Library / Settings`; drop Edition as a destination.
- **The editorial finite-package pass runs only over that tail.** `EditionComposer` is re-scoped to
  compose the tail section, not the whole day; curated mail never enters it. `targetSize` scopes the
  tail (§14, amended in remit); curated finiteness is intrinsic (§24).
- **Land the contract amendments in the same change** (Documentation rule): `JUDGMENT-CONTRACT` §1
  demotes the editorial pass to the tail; `IMPLEMENTATION-CONTRACT` §3 records the two-treatment shape;
  `AGENTS.md` "Current shell" drops Edition; the `V1-SCOPE` re-sequence is reconciled. §5/§14/§22 carry
  "amended by §24" remit notes, not deletion.
- **S6's parallelization stays** and now applies to the tail composition.

### Done-criteria

1. The shell no longer lists Edition; the uncurated tail renders as a Today section. Verified through
   the shell/Today models.
2. `EditionComposer` composes only the tail; curated email pieces provably never enter the editorial
   pass (test: a curated-mail corpus triggers zero editorial calls).
3. The affected live docs are updated in this change (JUDGMENT-CONTRACT §1, IMPLEMENTATION-CONTRACT §3,
   AGENTS.md shell, V1-SCOPE); §5/§14/§22 carry the remit notes.
4. `swift test` + `swiftlint --strict` green; the Today-with-tail layout is Jon's device pass.

### Out of scope

Deleting the judgment engine or eval harness (they serve the tail and the surviving type pass). Any
change to how the tail's finite package is chosen beyond scoping it to the tail. Gmail dispositions
(Phase 4).

---

## Jon's manual and device pass

Same shape as M1–M3: the work only Jon can do, gating what follows.

### During S1 — the eval read is yours to endorse

Agents produce the paired `JudgmentEval` run; whether the split-pass edition *feels* right (and that
substantive-primary is being called correctly on real morning content, not just scoring better) is a
lived-use judgment.

### During S2–S3 — the reading and offline feel

Whether the inline body reads well and whether the offline promise feels trustworthy (visible expiry,
honest degradation) are device-pass calls (IPAD-FIRST §7–8).

### During S6 — the latency number is yours

Agents ship the parallelized type pass with the eval floor held; whether a real morning composition
now lands acceptably (against the §7 60s budget) is only answerable by a recompose on your device.
That on-device number is what decides whether the type-model swap stays deferred or moves up (§23).

### During S4–S9 — real Inbox semantics, and whether the hierarchy beats the flat inbox

The Gmail semantics that feed the Gate-3 ADR only appear against Jon's real Inbox (S4). Agents ship the
tested ingest/classification/Today models; Jon's use is what surfaces message/thread, account, and
re-entry behaviour the ADR must settle. Two §24 judgments are Jon's alone and cannot be scored: (1)
whether the **personal / newsletter / offer / grab-bag** classification is right on real morning mail —
especially the personal-vs-publication split, where a miss is visible and the per-sender override is the
fix (S5); and (2) the decision that makes or breaks the whole re-centering — **does the type-differentiated
hierarchy actually read better than the flat, arrival-ordered inbox** (S7)? That is the lived-use test of
§24's thesis; if the hierarchy does not feel like less work than scrolling a flat list, the treatment
axis is wrong, not just the styling.

---

## Architecture Gate 3 — write the Gmail integration ADR from observed semantics

The checkpoint M4 ends at (`docs/V1-SCOPE-AND-SEQUENCING.md`, Architecture Gate 3;
EMAIL-INTELLIGENCE-MODEL §13). This gate's deliverable is **a written ADR**, settled from what the
provider actually did in S4–S5, not from design intent. Settle:

- message vs thread identity/actions;
- account identity and multi-account behaviour if required;
- refresh / pagination / delta strategy;
- which provider IDs are retained;
- re-entry on new replies (without inventing a permanent parallel thread-resolution state, DECISIONS §7);
- partial failures / retries;
- undo capabilities where Gmail permits;
- what must be committed before any mutation (the disposition barrier, DECISIONS §7);
- the relationship from email Artifact to email-delivered ContentPiece.

**Only after this gate does source mutation (Phase 4 dispositions) become enabled.**

---

## Not in M4 — the M5+ cutline (proposed)

- **Gmail dispositions** — `Leave` / `Archive` / `Trash`, the disposition barrier, and bounded recent
  dispositions / Undo (Phase 4, Gate 4-adjacent). Follows Gate 3; mutation stays behind the ADR.
- **Email-delivered recurring Stream** (Phase 5) — the always-read newsletters (Yglesias, Puck,
  Sepinwall) flowing from Gmail into Edition under Stream Handling / Essential. **Read first at that
  time:** DECISIONS §21 (OPEN HYPOTHESIS) — do not silently assume `Essential` means "promote into
  Edition"; the reachable-first vs promote question is parked there. This phase is the critical test
  that Transport / Artifact / ContentPiece / Stream Handling / source disposition / Edition state are
  genuinely separate (Gate 4, major model review).
- **The type-call model swap** — moving the S1 classification pass to a cheaper/onboard model once it
  can emit the schema (M2-S1 cost decision; cheapest lever is a Haiku-vs-Sonnet eval first). Deferred
  behind the known schema blocker. **Now also the resolution for the two-pass latency tracked in
  DECISIONS §23:** S1 measured 114.9s/composition (over the §7/§13 60s budget) because type-then-
  editorial run sequentially on Sonnet; the swap cuts the type pass's latency and cost together. Its
  trigger to move ahead of M5+ is Today/Gmail volume (S4–S5) or Jon's device pass showing a real
  morning over 60s.
- **Auto-Library policy** — Phase 7, reconciled at Gate 2 (DECISIONS §18). After explicit Library +
  custody are trustworthy; must **not** reuse `isSubstantivePrimary` as the keep-criterion.
- **First specialist Find handoff** — the receiver for Pending Finds (Phase 6, Gate 5). Extraction has
  been accumulating orphans since M2 S5; the receiver is later.
