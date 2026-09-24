# M6 Gate 5 — First specialist Find handoff (Yes Chef): design note

> **Design note — now promoted.** Architect-recorded 2026-09-21 from the M6 design session, to
> hand a *fresh* session a warm start. It captures every decision we locked so the return-channel
> investigation and the two-repo build don't re-derive them. It is normative against
> `docs/APP-FAMILY-INTERACTION.md` (§3/§6/§7/§9) and ADR-0002 D8, and inherits the deferred/permanent
> ledger in `docs/milestones/M6-decisions-and-sequencing.md`.
>
> **The three open questions below were answered against real code (2026-09-21) and this note is now a
> sliceable plan: `M6-gate5-find-handoff-slice-plan.md` (the frozen contract, invariants, and
> decomposition). This note remains the rationale of record; the slice plan is what the executor builds
> to.**
>
> **Transport superseded (2026-09-24).** The "App Intent to initiate" and "reverse App Intent" return below
> are not implementable: no public API lets one app invoke another's App Intent (established by Yes Chef
> PR #322). The slice plan redrafts the transport as a pair-scoped App Group mailbox + `yeschef://` open,
> ratified 2026-09-24 (APP-FAMILY §9 exception). The *why* here (finish in the moment, no id Jon
> handles, receiver owns intelligence) still stands; only the mechanism changed.

## What Gate 5 proves

The receiver for the Pending Finds that have accumulated open-loop since M2 S5 (plus the M4 offer
Finds). Extraction exists; the **admission boundary** does not. Gate 5 proves the app-to-app referral
contract end-to-end with **one** receiver — deliberately, per APP-FAMILY §7 ("implement exactly one
real receiver … do not create a generalized handoff framework first"). Closing the loop is also the
first real signal on extraction *quality*, because a receiver that can decline is the feedback
extraction has never had.

## Receiver: Yes Chef (recipes)

Chosen because recipes are the **most widely-understood structure** across the family, so the contract
proven here is the template for the fuzzier receivers (a "place"/"reservation" for Galavant has soft
edges; a recipe does not) — and because **Yes Chef already has an in-app raw-text → recipe extractor**,
so the receiver-side intelligence largely exists. Proving the contract on the easy domain de-risks the
hard ones.

## The boundary principle (load-bearing — do not erode)

Cockpit says *"this text looks like an X"* and ships the **raw text + provenance + a fallible
classification hint**. **All** domain intelligence — deterministic parsing, LLM consultation,
deduplication, admission — lives in the receiver (APP-FAMILY §3/§6). Cockpit never learns recipe (or
reservation, or …) schema. This is not a preference; it is what keeps Cockpit from becoming the
family's god-parser and what lets each specialist stay sovereign over its domain. Cockpit's
classification is a *routing hint that is allowed to be wrong* — the receiver is the authority on
whether it is really an X, and the **decline path is what makes a coarse hint safe.**

## Transport: an App Intent to *initiate*, finished in the moment

The referral must **begin a process Jon finishes now, with context fresh** — never deposit into a queue
he drains later (that is the open-loop problem in a new costume: disambiguating recipes from an email
he no longer remembers). This tilts to an **App Intent**, not a share extension:

- The in-the-moment finish (parse, LLM review, save to a cookbook) wants the **full Yes Chef app**
  foregrounded, not an extension's cramped modal.
- The boundary should be an **explicit, named contract with a named app** — which is exactly the seam
  Gate 5 exists to prove. (Share-sheet content-type routing is a virtue *later*, with many receivers.)
- The verdict return rides a typed Intent contract far more naturally than a fire-and-forget extension.

So: **Cockpit invokes a foregrounding App Intent** carrying `rawText + provenance + referralID`; Yes
Chef opens into its own extraction/review UI with the context loaded; Jon finishes there.

## The return: a data event Jon never handles

**Hard constraint (Jon):** the return must be effortless — **no copying an id, no housekeeping.** The
`referralID` is machine-only correlation plumbing; it must never be surfaced to Jon. The reframe:
**there is no "return trip" Jon performs — there is only a verdict that lands back in Cockpit on its
own** and resolves the Find (referred → admitted/declined). The one failure mode to design out is a
Find stranded in "referred, unknown" that needs manual cleanup.

**Return channel — steered by APP-FAMILY §9.** There is **no CloudSyncKit store between these apps
today**, and §9 lists shared family stores/queues, App-Group containers, and cross-app sync as
infrastructure that *deliberately waits* until repeated consumers prove it. So the return should be the
**smallest concrete reciprocal mechanism** — e.g. a background App Intent from Yes Chef back into
Cockpit keyed by `referralID` — **not** a newly-built shared store or App Group. Building family
handoff/sync infrastructure for the *first* receiver is explicitly out (APP-FAMILY §7/§9). The fresh
session's first job is to find the minimal available reciprocal mechanism on the platform, not to
decide whether to build a shared store (the answer to that is "not for receiver #1").

## The verdict is set-valued; decline is first-class

Not a scalar admit/decline. A single referral may yield **N admitted (+ ids) and M declined** — because
one email can contain more than one recipe (see below), and because the receiver may decline, merge
with an existing recipe, or ask for review (APP-FAMILY §6). A **decline (including "duplicate")** is a
first-class, valuable outcome — it is the extraction-quality signal.

## One email, two recipes: the referral unit is the ContentPiece, not "a recipe"

A real email had two recipes. Cockpit must **not** split them — finding recipe boundaries in text is
parsing, i.e. domain intelligence, i.e. the receiver's job. So:

- The referral carries the **whole readable body** (+ provenance) once. **Never pre-trim to "the
  recipe"** — trimming is parsing, wrong side of the line. Newsletter chrome/ads are fine; Yes Chef's
  extractor already eats messy raw text.
- **Yes Chef decides the cardinality:** 0 → decline, 1 → admit, 2 → admit both (or Jon picks in the
  review UI). "How many recipes are in here" lives entirely on the receiver side.
- This is a second argument *for* the in-the-moment flow: the messy multi-recipe case resolves
  naturally in Yes Chef's review UI with context fresh; a queue would make it miserable.
- **Receiver-side work exists and is expected:** Yes Chef's extractor moves from "paste the clean
  recipe" to "find the recipe(s) in a big block." This is correctly on the Yes Chef side, and it is a
  capability upgrade Yes Chef wants regardless (it improves the manual paste path too).

## Custody stays per-app (ADR-0002 D8 across the app line)

When Yes Chef admits, Cockpit **retains its own ContentPiece** — it was Jon's mail — and records
`referred → admitted/declined`. The Yes Chef recipe is a **separate** record with its own custody. The
handoff must never move or delete Cockpit's copy; that would couple custody across the app boundary.
Handoff is an *admission request, not shared ownership* (APP-FAMILY §6).

## First handoff is user-initiated, not auto-routed

"Send to Yes Chef" is one deliberate act — same agency discipline as the disposition work. Auto-routing
mail into another app is a later, authority-flavored thing (ledger bucket A) and would make Gate 5
about routing policy instead of about the boundary. Prove the seam manually first.

## The contract (the interface both repos build to)

Define this **first**, then Cockpit-side and Yes Chef-side build in parallel (it is the only coupling):

- **Initiate (Cockpit → Yes Chef), foregrounding App Intent:**
  `rawText: String`, `provenance` (source sender/publisher, arrival date, `List-ID`/series, Cockpit
  ContentPiece reference as an opaque token, Cockpit interpretation/why-it-mattered, lightweight hints
  per APP-FAMILY §3), `referralID` (opaque correlation token).
- **Return (Yes Chef → Cockpit), minimal reciprocal mechanism keyed by `referralID`:**
  an outcome set — for each yielded recipe `admitted(recipeRef)` or the whole referral
  `declined(reason)` / `duplicate`. No id is ever surfaced to Jon.

## Four deltas, split by repo (Gate 5 spans cockpit + jon-platform)

- **jon-platform / Yes Chef:** (1) extractor accepts messy/large input and isolates 1..N recipes;
  (2) expose the receiving App Intent and emit the verdict via the reciprocal mechanism.
- **cockpit:** (3) "Send to Yes Chef" referral surface on recipe-candidate Finds + the Intent
  invocation; (4) consume the set-valued verdict and resolve the Find (retain custody, record outcome).

## Deferred within Gate 5 (do not build now)

- **Auto-routing** of recipe Finds (first handoff is user-initiated).
- **A second receiver / any generalized HandoffKit** (APP-FAMILY §7/§9 — one receiver end-to-end
  first; a second receiver is the earliest credible evidence for shared infrastructure).
- **Any shared family store / App Group / cross-app sync** for the return (APP-FAMILY §9).
- **Yes Chef publishing Current Context back to Cockpit** (APP-FAMILY §1/§2) — separate direction, not
  this gate.

## Open questions for the fresh session

1. **The minimal reciprocal return mechanism** on the platform: background App Intent both directions?
   A URL-scheme callback? What actually lets Yes Chef hand a verdict to Cockpit with zero Jon action
   and no shared store? (Investigate in `jon-platform`; do **not** reach for shared infra — §9.)
2. **Where Yes Chef's extractor lives** — confirm it is in-app (so the boundary carries raw text, not
   structured fields) and what its current input assumptions are.
3. **How Cockpit currently tags recipe-candidate Finds** — the referral surface shows only these, so
   confirm the existing Find kind/classification is precise enough to route (and that non-recipe Finds
   keep waiting, per APP-FAMILY §5).

## Acceptance tests (when this becomes a slice)

- Round trip: initiate → finish in Yes Chef → verdict lands in Cockpit and resolves the Find, **with no
  id handled by Jon**.
- Multi-recipe email: one referral yields two admitted recipes; Cockpit records the set outcome.
- Decline path: Yes Chef declines (incl. duplicate); Cockpit records it and the Find is not lost.
- Custody: Cockpit's ContentPiece (and any Later/Library/other Find) survives admission untouched (D8).
- No pre-trim: Cockpit ships the whole readable body, not an extracted recipe region.
