# M6 Gate 4 — Email-delivered recurring Stream: the separation test (slice plan)

> **Slice plan, not a single-slice spec.** Architect-recorded 2026-09-21. Gate 4 is milestone-sized and
> carries the major model review, so this is a decomposition + the separation invariants + the concrete
> first checks — not a line-by-line spec. It inherits: **reachable-first is the default** (§24; settled
> with Jon 2026-09-21), the ledger in `M6-decisions-and-sequencing.md`, and the S1/D9 down payment.

## What Gate 4 proves

The whole content model claims **Transport / Artifact / ContentPiece / Stream Handling / source
disposition / Edition state are genuinely separable.** Gate 4 forces the claim under a real recurring
email newsletter that is itself a followed Stream (Yglesias, Puck, Sepinwall) and proves the layers do
not secretly couple. It is the separation test, and it carries the model review.

## The concrete coupling this gate must break

`EditionPlanner` (uncurated-tail candidate gathering) **excludes tail candidates by transport**: any
ContentPiece that has a Gmail `Artifact` is excluded ("a Gmail Artifact is the durable marker that a
ContentPiece came from curated inbox input", `EditionPlanner.swift` ~line 102–110). So **curation role
is currently derived from transport** — Gmail ⇒ curated ⇒ kept out of the tail; RSS/atom ⇒ tail.

That rule conflates *how it was delivered* with *what curation role it plays*. An email-delivered
**followed Stream** is Gmail-transport content that should behave as curated-Stream content (reachable
via Stream Handling), not be excluded for being Gmail and not be dumped into Today's Primary triage as
loose inbox mail. **The discriminator must become Stream membership, not transport:**

- Gmail Artifact **linked to a followed Stream** (`streamID` set, `followState == .active`) → curated
  *Stream* content → reachable-first via Stream Handling.
- Gmail Artifact **with no followed Stream** → loose Primary mail → Today typed triage (unchanged).
- RSS/atom followed Stream → unchanged (modulo the reachable-first model question below).

The schema is already ready for this: `Stream.transport` includes `.gmail`, `Artifact.streamID` links
either transport, and `GmailStreamResolver` already resolves a Gmail Artifact to a configured Stream by
its **locator** (normalized List-ID / sender) using the **same `GmailSeriesKey.locatorKeys` normalizer**
the S1 series key uses. So the recurring-email-series identity is *already unified* — confirm it stays
unified and is not forked into a parallel email-Stream locator.

## Separation invariants (the gate's acceptance tests)

These are the "does the seam hold" assertions. Most are test-backed in core; I5 is device-eval.

- **I1 — transport ≠ curation role.** A Gmail Artifact on a followed Stream is treated as curated-Stream
  content (reachable via its Stream), not excluded-because-Gmail and not routed into Primary Today
  triage. A loose Gmail Primary message (no followed Stream) still goes to Today triage.
- **I2 — disposition ⊥ content.** Archiving/trashing the Gmail source leaves the ContentPiece in its
  Stream and its Edition/Essential state intact (ADR-0002 D8; extends the S1/D9 custody proof).
- **I3 — Stream membership ⊥ transport.** Membership is computed from the provenance locator (List-ID /
  sender), identically for RSS and Gmail; Stream Handling guidance applies regardless of transport.
- **I4 — Edition state ⊥ transport & disposition.** A piece's admission / carry / Essential state is
  independent of transport and of whether its source email is still in `INBOX`.
- **I5 — reachable-first is the default (§24).** A followed Gmail Stream is *reachable* via its Stream,
  not force-promoted into the Edition package. **Essential ≠ promote** (do not silently assume Essential
  means promote — Jon's note). Confirmed on device with real newsletters, after the mechanics land.
- **I6 — §18 guard.** `isSubstantivePrimary` is never used as a Stream / keep / promotion criterion. It
  is a piece-level *attention* signal, not a *durability* or *curation* signal.

## Decomposition (proposed slices)

Ordered so the **mechanics precede the feel** (the recurring method trap: feel can't be judged against a
scaffold, so the gate's architecture ratification must not wait on the placement verdict).

1. **S-a — Decouple curation role from transport.** Replace the transport-based tail exclusion with
   Stream-membership discrimination; audit every other place curation role is derived from transport
   (grep `transport.eq(.gmail)` in routing/curation paths). Prove **I1, I3**. Confirm the identity stays
   unified (`GmailStreamResolver` ↔ `GmailSeriesKey`).
2. **S-b — Route followed-Gmail-Stream pieces to Stream Handling / reachable-first**; confirm loose
   Primary still lands in Today. Establishes the surface; the reachable-first *feel* (I5) is evaluated
   in S-d, on device.
3. **S-c — Prove disposition ⊥ content ⊥ Edition state for a Gmail Stream.** Extend the S1/D9 tests to
   assert Stream membership and Edition/Essential state survive an archive/trash of the source. Prove
   **I2, I4, I6**.
4. **S-d — Gate 4 model review + device eval.** Real Yglesias/Puck/Sepinwall through the whole path;
   confirm reachable-first (I5) feels right; ratify into ADR-0002 / DECISIONS §24. This is where the
   "major model review" happens.

## First checks for the executor

- **The transport exclusion in `EditionPlanner`** (~line 102–110) is the concrete target; enumerate
  every sibling (`grep -rn "transport.eq(StreamTransport.gmail)"` in curation/routing code, not just
  ingest).
- **Can a Gmail Stream be *configured/followed* today?** `GmailStreamResolver` resolves to an
  "explicitly configured Gmail Stream," and `Stream.transport` supports `.gmail` — but confirm the
  follow UI (`FollowingModel` / `StreamOperations`) can actually create/follow a `.gmail` Stream. If not,
  that configuration path is part of S-a/S-b.
- **`EditionCandidateContext.isFromEssentialStream`** already exists (Essential is a Stream-level
  protection in judgment). Confirm Essential is treated as *reachable-first protection*, not
  promote-into-package, and stays separate from `isSubstantivePrimary` (I6).

## Open model questions (settled at the Gate 4 review, not pre-decided here)

1. **Does reachable-first apply to *all* followed Streams (RSS included) now, or only the new Gmail
   ones?** §24 "dissolved the promotion effect for curated streams" in general — which may change the
   *existing* RSS tail-promotion behavior, not just add a Gmail path. This is the central model-review
   question. Do not pre-decide it in S-a; surface it for the review.
2. **Where does a followed-Gmail-Stream piece live relative to Today?** Reachable-first implies reachable
   *via the Stream*, not present in the daily Primary triage — confirm it leaves Today's triage rather
   than appearing in both.
3. **The always-read case.** Yglesias/Puck/Sepinwall are "always read" — does reachable-first serve that,
   or do always-read Streams want a stronger surface than merely reachable? (Answer on device; if it
   pulls hard toward promotion, that reopens I5 — but as an additive keep-side policy *after* the gate,
   never inside it.)
4. **Grab-bag / Feed Me digests became reachable-only (introduced by S-b, PR #57).** A manually-created
   Gmail Stream defaults to `followState == .active` (`Domain.swift` ~line 100), so a grab-bag digest
   (e.g. Feed Me) now *leaves Today entirely* and is reachable only via its Stream. Extraction stays
   durable (`decodedGrabBagItems` still persists), but the digest no longer fans its extracted items
   out into Today triage — the whole issue collapses to a single Stream row that surfaces none of its
   items in any list. This is a genuine surfacing change, not just a routing one, and it answers
   question #3 for grab-bags by side effect of the `.active` default rather than by decision. Confirm at
   the review: is a Feed Me digest a followed Stream (reachable-first is correct), or does an
   items-bearing digest want its extracted items surfaced somewhere (Today, or a richer Stream row)?
   Do not let this ride in silently.

## Gate 4 model review — agenda (architect-recorded 2026-09-22)

> **The mechanics landed; the surface is a stub.** S-a/S-b/S-c (PRs #56/#57/#58) prove the seams hold in
> the model — I1–I4, I6 are test-backed. But a device look at Today (2026-09-22) shows the gate's
> load-bearing concepts have **no legible UI expression**, so the S-d "reachable-first *feel*" eval (I5)
> cannot run yet: there is nothing to feel. This is the recurring-method trap named at the top of this
> doc — feel can't be judged against a scaffold. **Resolve this agenda first, then a surface slice
> (S-d0), then the device eval.** These are review decisions, not implementation choices; do not
> pre-decide them in the surface slice.
>
> **RESOLVED 2026-09-22** — Q-A–Q-D were resolved with Jon against a shared iPad mockup. See
> **Gate 4 surface decisions** below (D-A–D-G) and `docs/mockups/M6-gate4-daily-surface.html`. The
> agenda text is kept for provenance; the decisions supersede it.

**What the device look showed (the evidence).** Today (`CockpitApp/TodayLandingView.swift`) is still the
M5 treatment-typed triage: sections are `EmailTreatment` buckets (Personal / Newsletter / offer /
grab-bag / transactional, via `orientationSummary`), rows show raw sender addresses. **No row is a
Stream and none is labeled by transport.** The only home for reachable-first is `StreamHandlingView`,
reachable *only* from Settings → a stream (`CockpitApp/SettingsView.swift` ~line 68). A followed Gmail
Stream (The Washington Post) appeared in **both** "Fresh this morning" and "Newsletters 64" — the
"appears in both" failure from open question #2, live. So reachable-first, Stream identity, and transport
are all invisible on the surface the user actually reads.

**Q-A — Where do followed Streams live as a first-class place?** Not Settings. Reachable-first only means
something if there is a Streams surface that is a peer to Today / Later / Library. Absent that, "reachable"
degrades to "buried in Settings." Decide whether Streams becomes a top-level surface (and what it is
called) before the surface slice is scoped.

**Q-B — Does the promotion band survive?** "Fresh this morning" is `model.promotedRows`
(`TodayLandingView.swift` ~line 100), a horizontal *promotion* carousel — the exact effect §24 /
reachable-first says to **dissolve** for curated streams. It is the live contradiction with I5. Either it
is the sanctioned always-read surface (Yglesias/Puck/Sepinwall — see Q from open question #3) and we stop
calling promotion dissolved, or it goes. A one-card carousel also reads as a bug, not a feature. Do not
let the band and reachable-first coexist unexamined.

**Q-C — What marks Stream identity on Today, and should followed-Stream issues be on Today at all?** A
followed-Stream issue showing on Today (as WaPo does now, in two places) may mean routing has not actually
removed it, or may mean Today should carry a Stream affordance. Reachable-first (open question #2) implies
it leaves the daily triage and is reachable via its Stream. Decide: does a followed-Stream piece leave
Today, and if any Stream identity shows on Today, what is the mark?

**Q-D — Does the Edition package have a standing entry point, or is compose-on-demand the model?** The
Edition/tail is composed on demand (sparkles control, `TodayView.swift` ~line 79); there is no standing
Edition entry point on the landing screen, which is why "I don't see an Edition package" is the correct
read of what is built. Decide whether that is intended or a missing surface.

These fold in the earlier open model questions (RSS scope #1, appears-in-both #2, always-read #3, grab-bag
#4): #2 is now evidence under Q-C, #3 is the deciding input to Q-B, #4 is a Q-A/Q-C surfacing case.

**Sequencing consequence.** S-d as originally written (model review + device eval in one) splits: the
**model review is this agenda** (resolve Q-A–Q-D on the shipped mechanics); a **surface slice (S-d0)**
builds the resolved surface; the **device eval (the real I5)** runs against S-d0, not against the current
Settings-buried stub.

## Gate 4 surface decisions (resolved 2026-09-22 with Jon)

> Resolved against a shared iPad mockup, not prose. The mockup is the acceptance test for S-d0:
> `docs/mockups/M6-gate4-daily-surface.html` (supersedes `today-orientation-surface.html`). Sections
> are content role, publishers pick apart, and reading is a real list/detail split. These answer the
> Q-A–Q-D agenda above.

- **D-A — No Streams tab. The daily surface is the place (answers Q-A).** A separate Streams
  destination was rejected outright — "they'll go there to die." Reachable-first is delivered *on the
  one daily surface*, not via a peer tab. Q-A's "where do Streams live" is answered: here, sorted in
  front of you, not somewhere you must choose to visit.

- **D-B — Sections are content *role*, not transport and not sender (reframes I1; answers Q-C).** The
  surface's organizing axis is a third axis the original doc did not name: **content role**. Sections
  are: **For you** (personal) · **Transactional** (account, finance, and reference mail) · **Daily
  news** (roundups/briefings) · **Opinion** (author voices) · **Grab-bag** (digests, items fanned out) ·
  **Food** (food and recipe reading) · **Wine** (wine reading) · **Offers** (retail roll-ups). This
  splits the old M5 treatment buckets (Personal/Newsletter/offer/grab-bag/transactional) into
  reading-role sections. I1 strengthens from "transport ≠ curation role" to **"transport ≠ curation
  role ≠ surface placement"** — three separable things. **Device-eval finding (2026-09-22):**
  transactional mail must be its own second section and overrides locator routing, including mute;
  this deliberately amends S-d0a's "no section derived from treatment alone" for this per-message
  finance-safety exception. Device-eval correction: “Move to section” is the sole correction UI;
  transactional stays detection-only, while moving a locator to Grab-bag or Offers also enables its
  matching extraction schema without changing treatment-based Gmail disposition safety.

- **D-C — Publishers pick apart; authors stay whole (answers Q-C; scopes the classifier fork).** A
  *sender is not a Stream and a Stream is not a section.* An author feed (Yglesias) is 1:1 sender =
  Stream = section. A publisher (Washington Post) **fans into multiple sections at once** — Morning
  roundup → Daily news, an op-ed → Opinion, recipe promos → muted. Jon: WaPo-in-two-sections "100%
  reads as clarity, keep it." **Mechanism: deterministic List-ID routing**, configured once in
  Settings → Sub-feed routing (`GmailSeriesKey.locatorKeys` normalizer already keys on List-ID). This
  is one-time, no-mistake, no ML. A receiver-side **classifier is deferred** — needed *only* for
  publishers that jam every content role through a single List-ID, and never blocks shipping the
  pick-apart. This narrows the open model-review fork from "routing vs. classifier" to "deterministic
  routing now, classifier later only where List-ID can't split."

- **D-D — Promotion band → pointer-only Highlights (answers Q-B; resolves the I5 contradiction).** The
  M5 "Fresh this morning" promotion carousel is **dissolved**, per §24/I5. It is replaced by a
  **Highlights** row that only *points down* to items already present in the sections below — a
  navigational sampler, never an insertion into the Edition package. Invariant for the surface: **a
  Highlights card must always resolve to an item already in a section; the moment it surfaces something
  not otherwise present, it is promotion again and violates I5.**

- **D-E — Interaction model: list/detail split, not full-screen + half-sheet.** Today's full-screen
  Today with a half-sheet sliding *over* each piece is replaced by a two-state model:
  1. **Orientation** — full-width "This morning": categories, Highlights, Offers, standing Edition
     entry (answers Q-D: Edition gets a standing entry point, still compose-on-demand behind it).
  2. **Reading** — a `NavigationSplitView`-style split: list on the left, **draggable divider**
     (clamped, remembered, with a full-width read toggle), reader on the right. Consistent with the
     existing `StreamHandlingView` (already a split view) and `ReaderView`; the half-sheet was the
     outlier. Draggable-divider-with-remembered-width is modest custom work, not free from SwiftUI.
  **Dogfood amendment (2026-09-24, Jon):** Highlights cards are the one exception. A Highlight is a
  sampler, so it opens the Reader in a sheet over Orientation instead of entering Reading. Section rows
  and the tail still open the split. Slice: `M6-reader-dogfood-slices.md` S-r11.

- **D-F — Reading is ONE ordered queue across all sections, not per-section lists.** Categorization
  runs twice: to **orient** (grouping shows the shape of the morning) and to **order** (one linear
  priority queue for reading). On entering Reading, the left pane is the *entire* morning in decided
  priority order (For you → Daily news → Opinion → Grab-bag → Food → Offers), with sections as headers you
  pass, not lists you re-enter. Once oriented, you march straight down — no clicking in and out of
  sections. Emergent property: the order decays must-read → skimmable → bulk-trash, so the queue ends
  where attention should; Offers roll-ups sit at the bottom as a natural stop cliff.
  **Amendment (2026-09-26, Jon; DECISIONS §30):** offer pieces leave the reading queue and its
  section rail. Each offer role gets a door on Orientation that opens a review mode for batch Keep and
  Trash all. The queue now ends with the last non-offer section. Slice: `M6-today-additions.md` S-t6.

- **D-G — Disposition is surfaced in the reading moment (makes I2/S-c visible).** The reader carries
  Save-for-later / Add-to-library / Trash actions and a standing custody line ("when you leave, the
  source email trashes automatically — this issue stays in its stream, custody intact"). Row swipe =
  disposition. This is where the shipped S-c separation work (I2/I4) finally has a legible UI. The
  device eval (real I5) runs against this surface (S-d0), not the Settings-buried stub.
  **Dogfood amendment (2026-09-22, Jon):** a followed-Stream issue whose source is disposed (in Cockpit
  or externally) leaves the Today reading queue and stays in its Stream — the queue is attention, not
  membership, so I2/I4 hold. Slices: `M6-reader-dogfood-slices.md`.

- **Grab-bag surfacing (answers open question #4).** An items-bearing digest (Feed Me) does **not**
  collapse to one dead row: its extracted items fan out inside the Grab-bag section and each is
  individually readable in the queue. `decodedGrabBagItems` durability is unchanged; the surfacing
  question is answered "fan the items out."

**Still open for the model review (S-d):** open question #1 (does reachable-first change *existing* RSS
tail-promotion, or only add the Gmail path) is untouched by these surface decisions and remains the
central §24 question. The always-read case (open question #3) is now expressed as the "always read"
group/tag within Opinion and the Highlights sampler; confirm on device (S-d0 eval) whether that is a
strong enough surface or whether it reopens I5 as an additive keep-side policy *after* the gate.

## S-d0 executor slices (Codex-ready)

> Decomposition of the surface slice. Order is **mechanics before feel**. Dependency shape:
> **S-d0a → (S-d0b ∥ S-d0c) → S-d**, with **S-d0d** floating. Each block below is self-contained —
> send it to the executor as-is. The mockup `docs/mockups/M6-gate4-daily-surface.html` is the visual
> acceptance test for S-d0b/c. The per-piece **classifier stays deferred** (only single-List-ID
> publishers need it; never blocks the gate).

### S-d0a — Content-role routing engine (mechanics; gates everything)

**Goal.** Assign every surfaced ContentPiece a *content role* (surface section) by **deterministic
locator routing**, extending the existing membership routing. No UI. This is the load-bearing
decouple: it takes I1 from "transport ≠ curation role" to the three-axis **"transport ≠ curation role
≠ surface placement."**

**Build.**
- Add a `ContentRole` enum (eight cases: `forYou`, `transactional`, `dailyNews`, `opinion`, `grabBag`,
  `food`, `wine`, `offers`) in
  `CockpitCore` (near `EmailTreatmentDomain.swift`). It is the *surface placement* axis — keep it
  distinct from `EmailTreatment` (attention/treatment) and from `Stream` membership.
- Extend `CurationRouting.swift`: add a locator → `ContentRole` resolver keyed on the **same**
  `GmailSeriesKey.locatorKeys` normalizer `GmailStreamResolver` uses. Add a seeded routing table
  (List-ID/locator → role, plus per-locator follow/mute). One publisher's distinct List-IDs map to
  distinct roles; a mute maps to no section.
- Provide the roles as a snapshot alongside `CurationRoutingSnapshot` (do not fork the locator
  identity — reuse the resolver, per the "identity stays unified" requirement).
- Transactional is the one per-message exception: `emailTreatment == .transactional` wins over any
  locator role or mute; Wine remains pure locator routing.

**Prove (extend `Gate4DispositionSeparationTests.swift` or a sibling).**
- WaPo Morning List-ID → `dailyNews`; WaPo Opinion List-ID → `opinion`; WaPo food List-ID → `food`
  (unmuted). **One publisher, ≥3 roles from distinct locators** — the pick-apart, at the model layer.
- An author locator (Yglesias) → exactly one role (`opinion`).
- Role is derived from locator, not transport (I1/I3): an RSS and a Gmail locator with the same
  configured role resolve identically.

**Do not.** Do not use `isSubstantivePrimary` as a role/keep/promotion input (I6/§18). Do not build a
per-piece classifier — locator routing only; leave single-List-ID publishers unresolved (they fall to
`forYou`/triage default) and note them for the deferred classifier.

**Done when.** Every surfaced piece resolves to a role deterministically; WaPo fans to ≥2 roles in
tests; grep shows no section derived from transport or treatment alone except the documented
transactional per-message safety override.

### S-d0b — Orientation surface (full-width; consumes S-d0a)

**Goal.** Replace the M5 treatment-bucket Today with the content-role orientation screen from the mockup.

**Build.**
- Rebuild `TodayLandingView.swift` (+ `TodayModel.swift`, `TodaySurfaceRows.swift`): sections are
  `ContentRole` (For you / Transactional / Daily news / Opinion / Grab-bag / Food / Wine / Offers), not
  `EmailTreatment.todayHierarchy`.
  Retire `orientationSummary`'s treatment counts for a role-based summary.
- **Roll-up rows** for Offers and Grab-bag: collapse a publisher/digest to one row with a count;
  Grab-bag digest items fan out (`decodedGrabBagItems` unchanged — surfacing change only).
- **Standing Edition entry** card (answers Q-D): a persistent entry point; compose-on-demand stays
  behind it (`TodayView.swift` sparkles control / `EditionModel`).
- **Highlights** row: pointer-only sampler.

**Prove.** Snapshot/unit test the I5 invariant: **every Highlights card resolves to an item already
present in a section below** (assert card IDs ⊆ union of section item IDs). A followed-Gmail-Stream
piece appears in its role section and **not** in a promotion band and **not** twice (kills the
"appears in both" bug, open question #2).

**Do not.** Do not reintroduce `model.promotedRows` as a promotion carousel (D-D); Highlights is
navigation, not promotion.

**Done when.** Today renders the eight role sections full-width, WaPo shows in three sections, offers/
grab-bag roll up, matches the mockup.

### S-d0c — Reading split + ordered queue (parallel with S-d0b)

**Goal.** The list/detail reading state: one ordered queue, draggable divider, reader with disposition.

**Build.**
- A split reading surface (`NavigationSplitView`), following the existing `StreamHandlingView.swift`
  pattern and `ShellModel.swift`'s `streamHandling` route. Detail reuses `ReaderView.swift` +
  `ReaderDispositionToolbar.swift`.
- **One ordered queue across all sections** in priority order (For you → Daily news → Opinion →
  Grab-bag → Food → Offers), sections as headers, not re-enterable lists. Back it with a new request/model
  that flattens the role sections into the decided order; entry point selects+scrolls to the tapped item.
- **Draggable divider** (custom): clamped min/max, remembered width, plus a full-width read toggle.
- Reader carries Save-for-later / Add-to-library / Trash and the trash-after-read custody line — this
  is where I2/I4 become visible.

**Prove.** The queue order matches role priority across section boundaries; disposition of the source
(archive/trash) leaves the piece in its queue/stream and Edition state intact (reuses S-c/I2/I4
assertions, now through the reading surface).

**Do not.** Do not make the left pane per-section (D-F): it is the whole morning in order.

**Done when.** Tapping any piece opens the split reader with the global ordered queue; divider drags
and remembers; disposition surfaced; matches the mockup.

### S-d0d — Settings → Sub-feed routing UI (floating; can trail)

**Goal.** Make S-d0a's routing table user-editable.

**Build.** A routing editor in `SettingsView.swift` (List-ID → role, follow/mute), wired through
`FollowingModel.swift` / `StreamOperations.swift`. S-d0a ships seeded; this makes it editable.

**Prove.** Editing a locator's role/mute re-routes its pieces on next surface load (deterministic).

**Done when.** A user can move a sub-feed between sections or mute it from Settings.

### S-d — Model review + device eval (the original S-d; now unblocked)

Real Yglesias/Puck/WaPo/Feed Me through S-d0b/c on device; confirm reachable-first **feel** (I5) and
the always-read case (open question #3); **decide open question #1** (does reachable-first dissolve the
*existing* RSS tail-promotion, or only add the Gmail path — the central §24 call, untouched by the
surface decisions). Ratify into ADR-0002 / DECISIONS §24.

## Continuity with shipped work

- **S1 + D9 are the down payment.** They already proved *source disposition independent of custody*
  (trash the Gmail source; Later/Library/Find survive). Gate 4 extends the same separation to **Stream
  Handling and Edition state**, so I2 builds directly on the S1/D9 tests rather than starting cold.
- **The series identity is already unified.** A followed Gmail Stream and an S1 series-trash declaration
  key on the *same* normalized List-ID/sender identity. The richest single test of the whole model is
  their composition: a followed Gmail Stream that is *also* declared trash-after-reading — read it
  (reachable via the Stream), the source trashes, and the ContentPiece remains in its Stream/Edition,
  custody intact. That one case exercises all six invariants at once.
