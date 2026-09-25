# M6 Gate 5 — First specialist Find handoff (Yes Chef): the cross-app boundary test (slice plan)

> **Slice plan, not a single-slice spec.** Architect-recorded 2026-09-21, promoting
> `M6-gate5-find-handoff-design.md` to a sliceable plan after the fresh-session investigation answered
> its three open questions against real code. It is normative against `docs/APP-FAMILY-INTERACTION.md`
> (§3/§6/§7/§9) and ADR-0002 D8, inherits the deferred/permanent ledger in
> `M6-decisions-and-sequencing.md`, and does **not** restate the design note's rationale — read it first.
> Gate 5 spans **cockpit + Yes Chef** (`/Users/jon/code/cooking/yes-chef`); the contract is the only
> coupling, so it is frozen first (S0) and the two repos build to it in parallel.
>
> **Revised 2026-09-24 after Yes Chef PR #322 (`jonphillips/yes-chef`, merged `94819d7`).** That PR built
> the receiver's compute half and established that **no public API lets one app invoke another app's App
> Intent** — which breaks this plan's transport in *both* directions, not just the return. The transport is
> redrafted below as **Option A: a pair-scoped App Group mailbox + a `yeschef://` open**. **Jon ratified
> Option A and the §9 exception on 2026-09-24 (S0 ✅).** The exception now lives in
> `docs/APP-FAMILY-INTERACTION.md` §9.

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
- **Cockpit's Find surface now has write paths (S-r6, 2026-09-23).** `PendingFindState` is
  `pending | confirmed | handedOff | dismissed`, and `PendingFindListModel` has `confirm` / `dismiss`
  (`CockpitCore/Sources/CockpitCore/PendingFindListModel.swift`). S-r6 also made the `offerWithFind`
  auto-Trash barrier count **`confirmed` or `handedOff`** as Jon's authority (DECISIONS, "Confirmed-Find
  barrier amendment"). Any new referral state must take an explicit position on that barrier (see
  "Cockpit Find states" below). Deltas #3/#4 build on these write paths, not on a read-only list.
- **Yes Chef's receiver compute is built (PR #322).** Shipped on Yes Chef `main`:
  - **S-y1 done.** `RecipeExtractionClient` accepts messy/large text and returns 0, 1, or N complete
    recipes; 0 is a clean decline, not a thrown `.emptyRecipe` that strands the cook.
  - **S-y2 compute half done.** `CaptureRecipeFromText` accepts `rawText`, `provenance` (a
    **JSON-encoded string**), and `referralID`, and stages a `FindReferral` into Create Recipe review with
    provenance shown. `CreateRecipeCoordinator` emits exactly one `FindVerdict` per referral: admitted on
    save; `dismissed` on leaving Create Recipe, on **scene background** (`RecipeLibraryView.swift`), or
    when a newer intake supersedes; `noRecipeFound` / `extractionFailed` from extraction.
  - **Contract types frozen as Swift shapes** in `YesChefPackage/Sources/YesChefCore/`: `FindReferral` /
    `FindProvenance` (`sender`, `publisher`, `arrivalDate`, `seriesID`, `contentPieceToken`, `note`,
    `hints: [String: String]`), `FindVerdict(referralID:outcomes:)`, `FindOutcome` =
    `.admitted(FindRecipeRef) | .declined(FindDeclineReason)`, `FindDeclineReason` =
    `.noRecipeFound | .duplicate | .dismissed | .extractionFailed(String)`. `FindVerdict` is **not
    `Codable`** — the wire encoding is not yet frozen.
  - **v1 review is admit-one-of-N.** The cook picks one candidate; the referral clears after the first
    admitted save; **unselected candidates are not reported as declines.** The verdict shape stays
    set-valued for a later multi-admit UI.
  - **The return is a stub.** `FindReturnEmitter.liveValue` logs to `AppLog.handoff` and delivers nothing;
    the real transport is a one-line dependency override once S0 decides it.
- **App Intents cannot carry the handoff in either direction.** App Intents surface to *system*
  experiences (Shortcuts/Siri/Spotlight/widgets), never to peer apps (Yes Chef architect re-review,
  2026-09-21). The re-review applied this to the return; it applies equally to the **initiate**:
  Cockpit cannot invoke `CaptureRecipeFromText` any more than Yes Chef can invoke a Cockpit intent. Today
  Yes Chef has **no URL scheme** and its share extension accepts only web pages/URLs, so there is
  currently *no* path from Cockpit into Yes Chef. The transport is a joint S0 decision, not a device
  question.
- **Both apps are iOS, same team (`7MQEE539G9`).** Yes Chef already has an App Group
  (`group.com.jonphillips.yeschef`) for its own share extension; Cockpit has none. Cockpit's only URL
  scheme is the Google Sign-In callback.

## The contract (S0 — ratified 2026-09-24; the only coupling)

Both repos build to this. It is deliberately minimal: one pair-scoped mailbox, two message types, one URL.
The §9 exception it needs is recorded narrowly in APP-FAMILY §9, not smuggled in as a reinterpretation.

- **Channel: a pair-scoped App Group mailbox.** A **new** group, `group.com.jonphillips.cockpit-yeschef`,
  entitled on both apps. **Not** Yes Chef's existing `group.com.jonphillips.yeschef` — joining it would put
  Cockpit inside Yes Chef's share-extension container. Layout:
  - `find-referrals/<referralID>.json` — written by Cockpit, consumed by Yes Chef.
  - `find-verdicts/<referralID>.json` — written by Yes Chef, consumed by Cockpit.
  - **The consumer deletes a message once it has persisted what it needs.** Writers write atomically
    (temp file + rename). The mailbox holds only messages in transit, never records. Custody stays
    per-app (D8).
- **Initiate (Cockpit → Yes Chef).** Cockpit writes the referral message, then opens
  **`yeschef://find-referral?id=<referralID>`**. Yes Chef's URL handler reads and consumes the message and
  stages it through the **same** `CreateRecipeCoordinator.stage(referral:)` path `CaptureRecipeFromText`
  already uses (one staging path; the intent keeps serving Shortcuts). Jon lands in Create Recipe review
  and finishes in the moment. The body travels as a file, so there is no URL-length risk.
  - `rawText` — the **whole readable body** (+ chrome). **Never pre-trim to "the recipe"** — trimming is
    parsing, wrong side of the line.
  - `provenance` — Yes Chef's `FindProvenance` fields. `contentPieceToken` is opaque Cockpit custody
    state, round-tripped untouched.
  - `referralID` — opaque correlation token, **machine-only, never surfaced to Jon** (a URL query
    parameter Jon never sees is fine).
- **Return (Yes Chef → Cockpit), silent.** `FindReturnEmitter`'s real conformance writes the verdict
  message. Cockpit drains `find-verdicts/` on launch and on every `scenePhase == .active`, records the
  outcomes, and deletes each message. Nothing opens Cockpit. Jon switches back when he's done, and the
  Find has already resolved.
- **Wire format (both messages).** UTF-8 JSON, `"version": 1`, dates **ISO-8601** (never `JSONEncoder`'s
  default `.deferredToDate`, which silently disagrees across two hand-maintained copies). Each repo
  **hand-writes** `Codable` for its copy; synthesized enum coding (`{"admitted":{"_0":…}}`) is banned.
  Each repo pins the fixtures below with a golden-JSON test, copied verbatim, not shared via a package.

  ```json
  { "version": 1, "referralID": "…", "rawText": "…",
    "provenance": { "sender": "…", "publisher": "…", "arrivalDate": "2026-09-24T12:00:00Z",
                    "seriesID": "…", "contentPieceToken": "…", "note": "…", "hints": {} } }
  ```
  ```json
  { "version": 1, "referralID": "…",
    "outcomes": [ { "kind": "admitted", "recipeRef": "<UUID string>" },
                  { "kind": "declined", "reason": "noRecipeFound" },
                  { "kind": "declined", "reason": "extractionFailed", "detail": "…" } ] }
  ```
  `reason` ∈ `noRecipeFound | duplicate | dismissed | extractionFailed`. `detail` appears only on
  `extractionFailed` and is diagnostic, never shown to Jon. A per-message `version` is not the §9
  "universal envelope". It versions these two message types between these two apps, nothing more.

### Why a mailbox, not App Intents or URLs both ways

- **App Intents (the original draft):** not implementable. There is no public API for a peer app to
  invoke another app's intent, in either direction. The `ReturnsValue` shape was already ruled out,
  because the verdict lands minutes after initiation.
- **Option B, `yeschef://` out + `cockpit://` back (x-callback style):** rejected for two reasons.
  (1) The whole body would ride in a URL, and the practical size limit is unverified. (2) Yes Chef emits
  verdicts from the background (abandonment, supersession), and a backgrounded app cannot open a URL.
  Every abandoned referral would strand its Find, which breaks **I4**. The "hop back lands Jon where he
  was" upside is real, and is kept as a deferred convenience on top of the silent path (see Deferred).
- **Option A** is the only option that keeps I4 honest: silent delivery, verdicts from any app state, and
  bodies of any size. Its cost is a named, narrow exception to §9's "App Group acceleration", ratified
  in S0.

**The one failure mode left to design out: a Find stranded in "referred, unknown."** Under A, Yes Chef
guarantees exactly one verdict per *staged* referral, so a strand can only come from delivery. Either the
open failed (Yes Chef not installed), or Yes Chef never consumed the message (killed before handling the
URL). Both are **detectable on Cockpit's side**: the open call reports failure, or the referral message is
still sitting in `find-referrals/` at Cockpit's next foreground. Surface either visibly, offering re-send
or return-to-confirmed. **Never** clean it up silently.

## Cockpit Find states (proposed; S-c1 confirms)

`pending | confirmed → referred → handedOff | declined`, plus a return to `confirmed` for non-judgment
outcomes:

- **`referred`** (new): sent, verdict not yet in. Visible in the Find list as "Sent to Yes Chef".
- **`handedOff`** (existing) now means **admitted by the receiver**, which is admission-known.
- **`declined`** (new): the **receiver judged** it, `noRecipeFound` or `duplicate`. This is the quality
  signal, recorded as a valuable outcome, not an error.
- **`dismissed` / `extractionFailed` verdicts return the Find to `confirmed`**, re-sendable, with the last
  outcome recorded. These say nothing about the hint's quality. `dismissed` means Jon didn't finish;
  `extractionFailed` is an extraction failure. Neither may be stored as a decline.
- **Referral log.** Each send records `referralID`, Find, sent-at, resolved-at, and the raw outcome set,
  so the quality signal survives state changes.
- **S-r6 barrier:** `referred`, `handedOff`, and `declined` all satisfy the `offerWithFind` barrier.
  Sending is a confirming act, and a receiver's decline does not revoke Jon's confirmation. Add this to
  the DECISIONS barrier amendment in S-c1.
- "Send to Yes Chef" is offered on recipe-candidate Finds in `pending` or `confirmed`; sending from
  `pending` confirms implicitly.

## Invariants (the gate's acceptance tests)

- **I1 — raw text, no pre-trim.** Cockpit ships the whole readable body + provenance; it never extracts a
  "recipe region." (Core test on the referral message builder.)
- **I2 — the hint is coarse and tested.** The recipe-candidate routing convention is a **pinned, tested**
  classification (the referral surface shows only these; non-recipe Finds keep waiting, APP-FAMILY §5). A
  wrong hint is *safe* because the receiver can decline.
- **I3 — set-valued verdict; decline is first-class; outcomes are classified.** Cockpit consumes any
  N admitted + M declined. Receiver judgments (`noRecipeFound` / `duplicate`) are recorded as quality
  signal. `dismissed` / `extractionFailed` are recorded but return the Find to re-sendable. Under v1's
  admit-one-of-N, **one admitted outcome from a multi-recipe body is a complete verdict**, not a partial
  one. (Core test on verdict consumption, including the golden fixtures.)
- **I4 — the verdict lands on its own; Jon handles no id.** `referralID` never reaches the UI; the Find
  resolves from the mailbox with **zero Jon housekeeping**. No Find is *silently* left in `referred`:
  failed opens and unconsumed referrals are surfaced (core test on strand detection).
- **I5 — custody stays per-app (D8).** On admission Cockpit **retains** its ContentPiece and any
  Later/Library/other Find, untouched; the Yes Chef recipe is a separate record with its own custody. The
  handoff never moves or deletes Cockpit's copy. The mailbox holds messages, never records.
- **I6 — cardinality lives in the receiver.** "How many recipes are in here" (0/1/N) is decided entirely
  by Yes Chef; Cockpit never splits an email and never expects a particular count back. (Yes Chef test,
  shipped in #322: one body → N isolated candidates; 0 → clean decline.)
- **I7 — the only shared infra is the pair mailbox (§9 exception).** A single pair-scoped App Group
  carrying two message types, consumer-deletes, no records, no third app. No family store / shared queue
  / HandoffKit / universal envelope / shared package. A second receiver does **not** join this group; it
  reopens the question under §7.

## Decomposition (proposed slices)

Contract first, then the two repos in parallel, then the join. Gate 5's **gate review trails Gate 4**
(a Find's provenance/custody story rests on the ContentPiece/Stream separation being settled —
`M6-decisions-and-sequencing.md`), so S-join must not ratify ahead of Gate 4.

0. **S0 — Ratify the transport + freeze the wire format. ✅ Done 2026-09-24 (this plan's PR).** Jon
   ratified Option A. The §9 exception is recorded in `docs/APP-FAMILY-INTERACTION.md`, and this doc's
   "The contract" section, including both golden fixtures, is frozen. Nothing remains for an executor.
   The per-repo mechanical work (entitlement, URL scheme, fixture copies) opens S-c1 and S-y3.
   **Architect follow-up in yes-chef (gates S-y3):** update `docs/efforts/cockpit-find-handoff-receiver.md`
   to match. The transport fork is resolved, the initiate path is now URL + mailbox rather than the intent,
   and S-y3 replaces the old "prove the silent App Intent" check. Assign the Yes Chef ADR number there,
   since the transport choice is what makes this ADR-worthy.
1. **S-c1 (cockpit) — recipe-candidate hint + referral send.**
   - Add the `group.com.jonphillips.cockpit-yeschef` App Group entitlement to Cockpit (`project.yml` +
     entitlements).
   - Copy both golden fixtures into `CockpitCoreTests`, and hand-write `Codable` against them.
   - Establish and **test** the recipe-candidate `kind` convention.
   - Add "Send to Yes Chef" on those Finds only.
   - Build the referral message (whole body, no trim; provenance per the fixture), write it atomically to
     the mailbox, and open `yeschef://find-referral`.
   - Move the Find to `referred` and start the referral log.
   - Handle a failed open visibly: delete the message, keep the Find `confirmed`, and say Yes Chef isn't
     available.
   - Extend the S-r6 barrier.
   - Proves **I1, I2**. (Delta #3.)
2. **S-c2 (cockpit) — drain verdicts + resolve the Find.**
   - Drain `find-verdicts/` on launch and on active, decoding per the fixture.
   - Resolve `referred → handedOff | declined | confirmed` per the outcome classification, recording the
     set; retain custody untouched.
   - Detect unconsumed referrals and surface them (re-send / return to confirmed); no silent cleanup.
   - Proves **I3, I4, I5.** (Delta #4.)
3. **S-y1 (Yes Chef) — ✅ done in #322.** Extractor isolates 0/1/N from messy/large input. Proves **I6.**
4. **S-y2 (Yes Chef) — ✅ compute done in #322.** Referral staged with provenance; exactly-one verdict per
   referral; emitted through the `FindReturnEmitter` seam (still a stub).
5. **S-y3 (Yes Chef) — the transport.** Starts after the architect's effort-doc update (S0 follow-up).
   - Add the `group.com.jonphillips.cockpit-yeschef` App Group to the Yes Chef app target (alongside its
     existing group, which stays share-extension-only).
   - Register the `yeschef` URL scheme and handle `yeschef://find-referral`.
   - The URL handler reads and consumes `find-referrals/<id>.json` and calls `stage(referral:)`.
   - Replace `FindReturnEmitter.liveValue` with the mailbox writer.
   - Hand-write `Codable` for `FindReferral` / `FindVerdict` against the golden fixtures.
   - **Reconsider abandon-on-scene-background.** It was needed while the transport might be a URL hop,
     which can't fire later. Under A a verdict can be written at any time, and today a quick glance back
     at Cockpit mid-review emits `dismissed`, clears the referral, and orphans a save made after
     returning.
   - Prefer abandoning on leaving Create Recipe, on superseding intake, or on a relaunch that can't
     restore the review. Yes Chef's call; Cockpit tolerates either, because `dismissed` is re-sendable.
6. **S-join — round-trip gate review (device; Jon's).**
   - Use a real multi-recipe email: send → pick one in Yes Chef → switch back → the Find shows admitted
     with no id handled and no hop.
   - Check the decline path (a non-recipe email → `declined`, `noRecipeFound`).
   - Check that dismiss returns the Find to re-sendable.
   - Kill Yes Chef before it handles the URL → Cockpit surfaces the strand.
   - Confirm custody survives.
   - Ratify the boundary. **Do not run ahead of Gate 4's close.**

S-c1 and S-y3 build in parallel against the fixtures. Neither needs the other to pass its own tests. Only
S-join needs both.

## Executor status

- [x] S-c1 — implemented and verified in this PR.

## First checks for the executor

- **Cockpit (this repo):**
  - The recipe-candidate convention is undefined. Decide it at S-c1 (a tested `kind` value or normalizer,
    e.g. `kind == "recipe"`).
  - Confirm the state proposal above against S-r6's write paths.
  - Adding the App Group entitlement touches `project.yml` and the entitlements file; confirm CloudKit
    sync (`CockpitCloudSync`) is unaffected.
  - **The new group needs registering on the developer portal once**, by whichever app builds first
    (team `7MQEE539G9`). If automatic signing can't register it from the command line, stop and ask Jon
    to add it in Xcode's Signing & Capabilities. Don't work around it.
  - The readable-body source for `rawText` must be the same text the Reader shows, not a re-parse.
- **Yes Chef (`/Users/jon/code/cooking/yes-chef`):**
  - Stage through `CreateRecipeCoordinator.stage(referral:)`; don't add a second staging path.
  - Keep `FindReturnEmitter` as the seam; the mailbox writer is its `liveValue`.
  - Do **not** reach for the `AIHandoff` token types — that is the outboard-chat axis, not app-to-app.
- **Highest-risk unknown (replaces "prove the silent App Intent on device", which #322 resolved: no).**
  - Cold-launch ordering: Yes Chef launched *by* the URL must read the mailbox after its dependencies
    are prepared.
  - Cockpit's active-phase drain must not race its own launch-time database setup.
  - Both are deterministic and testable in each repo's app target. S-join confirms on device.

## Deferred within Gate 5 (do not build now — from the design note + ledger)

- **Auto-routing** of recipe Finds (first handoff is user-initiated).
- **A second receiver / any generalized HandoffKit** (APP-FAMILY §7/§9). A second receiver does not join
  the pair mailbox.
- **Any family store / shared queue / cross-app sync** beyond the S0 pair-mailbox exception (APP-FAMILY §9).
- **Multi-admit** (N admitted from one referral): Yes Chef's follow-up UI. Cockpit already consumes it.
- **"Back to Cockpit" hop** (`cockpit://` after save): a convenience layered on the silent return, never
  the delivery path.
- **"Open in Yes Chef"** from an admitted Find via `recipeRef`: wants a Yes Chef deep link; after S-join.
- **Yes Chef publishing Current Context back to Cockpit**: a separate direction, not this gate.
