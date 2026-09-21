# M6 Gate 5 — First specialist Find handoff (Yes Chef): the cross-app boundary test (slice plan)

> **Slice plan, not a single-slice spec.** Architect-recorded 2026-09-21, promoting
> `M6-gate5-find-handoff-design.md` to a sliceable plan after the fresh-session investigation answered
> its three open questions against real code. It is normative against `docs/APP-FAMILY-INTERACTION.md`
> (§3/§6/§7/§9) and ADR-0002 D8, inherits the deferred/permanent ledger in
> `M6-decisions-and-sequencing.md`, and does **not** restate the design note's rationale — read it first.
> Gate 5 spans **cockpit + Yes Chef** (`/Users/jon/code/cooking/yes-chef`); the contract is the only
> coupling, so it is frozen first (S0) and the two repos build to it in parallel.

## What Gate 5 proves

The app-to-app referral contract end-to-end with **exactly one** receiver (Yes Chef / recipes),
user-initiated, per APP-FAMILY §7 ("implement exactly one real receiver … do not create a generalized
handoff framework first"). It is the first real signal on extraction *quality*, because a receiver that
can **decline** is the feedback extraction has never had. The load-bearing principle it must not erode:
Cockpit ships **raw text + provenance + a fallible classification hint**; **all** domain intelligence
(parse, LLM, dedup, admission, recipe-cardinality) lives in the receiver. The decline path is what makes
a coarse hint safe.

## What the investigation found (the ground the slices stand on)

- **Cockpit's recipe hint is coarse and untested.** `PendingFind.kind` is a free-form `String`
  (`CockpitCore/Sources/CockpitCore/PendingFind.swift`), populated verbatim from `JudgmentFind.kind`;
  the judgment JSON schema declares `"kind":{"type":"string"}` with **no enum** and the prompt gives no
  recipe-specific guidance (`CockpitCore/Sources/CockpitCore/JudgmentPrompt.swift`). There is **no tested
  "this is a recipe" classification today** — the routing convention must be *established and tested* by
  the cockpit slice, not assumed. This is the correct coarse hint; it just doesn't exist yet as a pinned,
  tested value.
- **Cockpit's Find surface is read-only.** `PendingFindState` already has `.handedOff` / `.dismissed`
  (`PendingFind.swift`), but `PendingFindListModel` only displays rows — no referral or resolution action
  is wired (`CockpitCore/Sources/CockpitCore/PendingFindListModel.swift`). Deltas #3/#4 are greenfield on
  top of existing persistence.
- **Yes Chef's extractor is in-app, LLM-based, single-recipe.**
  `RecipeExtractionClient.extract(text: String) -> RecipeExtraction`
  (`YesChefPackage/Sources/YesChefCore/RecipeExtractionClient.swift`) takes **one** string, returns
  **one** recipe, throws `.emptyRecipe` when it finds no ingredients/instructions. The boundary therefore
  carries raw text, not structured fields (✅), and **1..N isolation is a real receiver-side upgrade**
  (delta #1), correctly Yes Chef's job.
- **The initiate seam already substantially exists.** `CaptureRecipeFromText` is a foregrounding App
  Intent (`allowedExecutionTargets: .main`) taking `text: String` and staging into Create Recipe review
  (`YesChefApp/AppIntents/CaptureRecipeFromTextIntent.swift`) — the design note's transport, missing only
  `provenance` + `referralID`.
- **The platform patterns for the return already exist in Yes Chef, on a different axis.**
  `ExportHandoffContext` returns a value via `some ReturnsValue<HandoffExport>`, and `ImportHandoffResult`
  ingests a returned result keyed by a handoff id (`YesChefApp/AppIntents/HandoffIntents.swift`). But that
  whole `AIHandoff` machinery is Yes Chef's **outboard-to-external-chat** axis (copy prompt / paste
  result), **not** app-to-app. Gate 5 reuses the *pattern*, not the `AIHandoff` types.

## The contract (S0 — frozen first; the only coupling)

Both repos build to this. It is deliberately minimal (APP-FAMILY §9: no shared store/App Group/HandoffKit
for receiver #1).

- **Initiate (Cockpit → Yes Chef), foregrounding App Intent.** Extend the existing
  `CaptureRecipeFromText` shape, do not fork a parallel intent:
  - `rawText: String` — the **whole readable body** (+ chrome). **Never pre-trim to "the recipe"** —
    trimming is parsing, wrong side of the line.
  - `provenance` — source sender/publisher, arrival date, `List-ID`/series, an **opaque** Cockpit
    ContentPiece token, Cockpit's interpretation / why-it-mattered, lightweight §3 hints.
  - `referralID: String` — opaque correlation token, **machine-only, never surfaced to Jon.**
- **Return (Yes Chef → Cockpit), minimal reciprocal mechanism keyed by `referralID`.** A **background
  App Intent exposed by Cockpit that Yes Chef invokes** at the moment of admit/decline — the mirror of
  Yes Chef's own `ImportHandoffResult`, reversed and cross-app. Carries a **set-valued** outcome: for
  each yielded recipe `admitted(recipeRef)`, or the whole referral `declined(reason)` / `duplicate`. No
  id is ever surfaced to Jon. **Not** the initiating intent's return value (see next section), **not** a
  shared store, App Group, or CloudSyncKit.

### Why the return is a reverse App Intent, not `ReturnsValue`

A `ReturnsValue` App Intent returns **synchronously** to its caller. Gate 5's verdict lands *after* Jon
finishes review in the foregrounded Yes Chef app — minutes later, Jon-driven — so it cannot ride the
initiating intent's return. The finish event originates in Yes Chef, so **Yes Chef must initiate the
return** into a Cockpit-exposed background App Intent keyed by `referralID`. This is the smallest concrete
reciprocal mechanism on the platform and keeps §9's "shared infra waits for repeated consumers" intact.
The one failure mode to design out: a Find stranded in "referred, unknown" — so the cockpit side needs a
visible `referred` state that a returning verdict resolves, and that a manual re-check can recover
(**not** silent auto-cleanup).

## Invariants (the gate's acceptance tests)

- **I1 — raw text, no pre-trim.** Cockpit ships the whole readable body + provenance; it never extracts a
  "recipe region." (Core test on the referral payload builder.)
- **I2 — the hint is coarse and tested.** The recipe-candidate routing convention is a **pinned, tested**
  classification (the referral surface shows only these; non-recipe Finds keep waiting, APP-FAMILY §5). A
  wrong hint is *safe* because the receiver can decline.
- **I3 — set-valued verdict; decline is first-class.** One referral may yield **N admitted + M declined**;
  `declined`/`duplicate` is recorded as a valuable outcome, not an error. (Core test on verdict
  consumption.)
- **I4 — the verdict lands on its own; Jon handles no id.** `referralID` never reaches the UI; the Find
  resolves `referred → admitted/declined` from the reciprocal return with **zero Jon housekeeping**. No
  Find is left stranded in "referred, unknown."
- **I5 — custody stays per-app (D8).** On admission Cockpit **retains** its ContentPiece and any
  Later/Library/other Find, untouched; the Yes Chef recipe is a separate record with its own custody. The
  handoff never moves or deletes Cockpit's copy.
- **I6 — cardinality lives in the receiver.** "How many recipes are in here" (0/1/N) is decided entirely
  by Yes Chef; Cockpit never splits an email. (Yes Chef test: one body → two admitted recipes.)
- **I7 — no shared infra (§9).** No family store / App Group / HandoffKit / universal envelope is
  introduced for this receiver; the return is the reverse App Intent only.

## Decomposition (proposed slices)

Contract first, then the two repos in parallel, then the join. Gate 5's **gate review trails Gate 4**
(a Find's provenance/custody story rests on the ContentPiece/Stream separation being settled —
`M6-decisions-and-sequencing.md`), so S-join must not ratify ahead of Gate 4.

0. **S0 — Freeze the contract (both repos).** Land the initiate params (`rawText` / `provenance` /
   `referralID`) and the return shape (set-valued verdict keyed by `referralID`) as a written interface
   both sides code against. No behavior; this is the only coupling. *(This doc's "The contract" section is
   the draft; S0 is its ratification + any type sketch the two repos share by copy, not by a shared
   package.)*
1. **S-c1 (cockpit) — recipe-candidate hint + referral surface.** Establish and **test** the
   recipe-candidate `kind` convention; add the "Send to Yes Chef" action on those Finds only; build the
   provenance payload (whole body, no trim) and invoke the foregrounding intent; move the Find to a
   visible `referred` state. Proves **I1, I2**. (Delta #3.)
2. **S-c2 (cockpit) — consume the set-valued verdict + resolve the Find.** Expose the Cockpit-side
   background return App Intent keyed by `referralID`; resolve `referred → admitted/declined`, recording
   the set outcome; retain custody untouched; recover a stranded referral without silent cleanup. Proves
   **I3, I4, I5.** (Delta #4.)
3. **S-y1 (Yes Chef) — extractor accepts messy/large input and isolates 1..N recipes.** Upgrade
   `RecipeExtractionClient` from "one clean recipe" to "find the recipe(s) in a big block"; improves the
   manual paste path too. Proves **I6.** (Delta #1.)
4. **S-y2 (Yes Chef) — receive the referral + emit the verdict.** Extend `CaptureRecipeFromText` with
   `provenance` + `referralID`, load the review UI with context; on save/decline, invoke Cockpit's return
   App Intent with the set-valued verdict. (Delta #2.)
5. **S-join — round-trip gate review (device; Jon's).** Real multi-recipe email: initiate → finish in Yes
   Chef → verdict lands in Cockpit and resolves the Find with no id handled by Jon; decline path recorded;
   custody survives. Ratify the boundary. **Do not run ahead of Gate 4's close.**

## First checks for the executor

- **Cockpit (this repo):** the recipe-candidate convention is undefined — decide it at S-c1 (a tested
  `kind` value/normalizer, e.g. `kind == "recipe"`), and confirm `PendingFindState` needs a `referred`
  state distinct from `.handedOff` (handed off ≠ admission-known). Wire the first write path through
  `PendingFindListModel` (currently read-only).
- **Yes Chef (`/Users/jon/code/cooking/yes-chef`):** reuse `CaptureRecipeFromText`'s
  `allowedExecutionTargets: .main` foregrounding pattern and `ImportHandoffResult`'s keyed-ingest pattern;
  do **not** reach for the `AIHandoff` token types — that is the outboard-chat axis, not app-to-app.
- **The return mechanism is the highest-risk unknown** — confirm on device that a background App Intent
  invoked *from* Yes Chef *into* Cockpit fires without foregrounding Cockpit and without Jon action. If the
  platform will not deliver that silently, the fallback is still not a shared store — it is a foreground
  hop back that Jon dismisses — but prove the silent path first.

## Deferred within Gate 5 (do not build now — from the design note + ledger)

- **Auto-routing** of recipe Finds (first handoff is user-initiated).
- **A second receiver / any generalized HandoffKit** (APP-FAMILY §7/§9).
- **Any shared family store / App Group / cross-app sync** for the return (APP-FAMILY §9).
- **Yes Chef publishing Current Context back to Cockpit** — separate direction, not this gate.
