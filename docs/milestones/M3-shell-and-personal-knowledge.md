# M3 — The iPad shell, and Personal Knowledge deepens

> **DRAFT for architect review.** Drafted 2026-09-15; revised same day after Jon ratified scope
> (iPad shell added as S1; Gmail deferred to M4; S4 hypothesis trigger locked). This is the sliced
> build order. The contract numbers and definitions cited are not reinterpreted here.

## What M3 is

M2 delivered the thinnest morning loop Jon can live with — a real model composes a finite Edition
from real Streams, each entry carries its "why," and Dismiss / Save for Later / Add to Library
resolve it with nothing cared-about silently lost. M2 also proved **in the harness** that Personal
Knowledge is not decorative (a taught interest moved 48–50 pieces and flipped 13–18 admissions;
`docs/eval-log.md`, 2026-09-13).

M3 has two jobs:

1. **Make dogfooding actually pleasant on iPad.** The shell today is a single list with Settings,
   Edition, and Following shoved into the toolbar — "a giant iPhone." That friction is now the main
   thing making daily use less fun, and every M3 PK surface (teach-from-Reader, correctable
   relevance) lands *in* that shell. So the shell comes first (S1), on the same **dogfooding-first**
   principle M2 reprioritised around.
2. **Turn the harness's PK signal into a product signal — V1 Phase 2.** The parts of Personal
   Knowledge deferred out of M2 S1 because they need a *running* Edition: correction/supersession,
   teach-from-Reader, hypothesis confirmation, and the one visible, correctable, PK-driven relevance
   change (S2–S5).

```text
a real iPad shell (tabs + split view)
→ teach / correct in context (Reader, Settings/You)
→ Personal Knowledge changes (provenance, supersession, unobtrusive consolidation)
→ the next Edition's judgment visibly changes
→ the change is explained in the rationale, and correctable from the same place
```

M3 ends at **Architecture Gate 2** (`docs/V1-SCOPE-AND-SEQUENCING.md` Phase 2). Gate 2's headline is
blunt: **did the eval agreement rate move when PK grew?** If not, PK is decorative and something is
wrong.

**Gmail is out of M3.** Ratified 2026-09-15: read-only Today (Phase 3) becomes **M4**. Phase 2 and
Phase 3 have no dependency on each other, so this is purely a sequencing choice — deepen the existing
loop first, open the second transport (and its own Gate 3) as its own milestone. The M4 cutline
carries the Phase-3 shape.

## The gate before M3 begins

**M3 does not start until M2's loop has been lived in and Architecture Gate 1 is closed.** Two things
gate the first PK slice (S2); S1 (the shell) has no such dependency and can start immediately —
building the shell is what makes closing Gate 1 pleasant in the first place.

- **Gate 1 evidence is recorded**, especially the agreement-definition tension the eval log flags:
  the baseline 0.421 is dominated by the model being far more selective than the `surface` labels, and
  Gate 1/2 must decide whether to retune `targetSize`/editorial posture or re-scope what `surface`
  means **before** anyone chases the agreement figure by growing PK. S5's Gate-2 proof is meaningless
  on top of an agreement number nobody trusts.
- **Real teaching has happened through the M2 S1 surfaces** — the Jon Brain import ran, direct
  teaching works, and there is a real claim set (not just fixtures) for correction, consolidation, and
  relevance-change to act on.

## Model cost — the decision for now

The latest real edition cost **~$0.45** (up from the $0.181 recorded at the M2 S2 baseline — the
drift is real and roughly what was predicted; a richer prompt and more candidates compound). At one a
day that is ~$160/year, near the threshold where the honest question "is this worth it versus just
reading my own email?" starts to bite.

**Decision (2026-09-15): do not pre-optimise the model now.** A frontier-vs-onboard investigation
buys little until there are more capabilities and a real A/B whose quality difference *carries*
enough to judge against. Recorded direction, not a slice:

- **Keep frontier for the editorial call** — the finite-package judgment (admit / rank / section
  against `targetSize`, weighing PK and taste) is the hard, taste-laden reasoning that makes Cockpit
  not-a-feed-reader.
- **Move mechanical grunt-work to the onboard model when it can** — subjects, summary,
  `isSubstantivePrimary` extraction are classification, not editorial judgment, and doing them onboard
  (free, and latency-irrelevant if composition runs in the background) is a clear win Jon wants. The
  blocker is concrete and already known: **the onboard model can't emit this structured schema yet**
  (M2 S1 amendment). Revisit when that changes.
- **Cheapest lever first, when the time comes:** a Haiku-vs-Sonnet eval pass — no schema problem,
  trivial swap — before any onboard investigation. Adopt only if it holds essential-false-quiet at or
  below the 0.068 floor.

Two small observability gaps to keep in mind (candidates, not required M3 scope): **there is no
cost/latency figure shown in the UI**, and you cannot A/B what you do not measure — surfacing the
per-composition number (even in Settings) is what makes the eventual comparison possible. This is a
cheap addition that could ride S1.

## Slice ledger

- [x] **S1 — iPad shell: iOS 27 tabs + split view** *(dogfooding-first; no PK dependency)*
- [x] **S2 — Correction, supersession, and unobtrusive consolidation**
- [ ] **S3 — Teach from the Reader ("why this matters")**
- [ ] **S4 — Hypothesis confirmation** *(trigger locked: explicit-action recurrence)*
- [ ] **S5 — The visible, correctable, PK-driven relevance change** *(the Gate-2 product proof)*
- [ ] **Architecture Gate 2 — Personal Knowledge review**

## Standing rules for every M3 slice

The M1/M2 standing rules carry over unchanged and are not repeated in full. The ones that bite
hardest in M3:

**Durable Personal Knowledge comes from explicit human intent, not passive inference**
(`docs/PERSONAL-KNOWLEDGE-MODEL.md` §1). The judgment pass never receives clickstream, dwell, or open
history (JUDGMENT-CONTRACT §2). Behaviour may *trigger a question*; it never *becomes* a durable
claim. S4's locked trigger (explicit-action recurrence) is deliberately on the safe side of this line.

**LLM synthesis is housekeeping, not authority expansion** (PK-MODEL §6). Consolidation, dedup, and
rollup are allowed without asking **only when semantic meaning is preserved**; a materially new
inference is a new claim and requires confirmation. This is Gate 2's "is the LLM overgeneralizing?"
and it fails silently if you let it.

**Knowledge does not grant agency** (PK-MODEL §11). Teaching that Jon likes Burgundy authorises
nothing — not a Gmail disposition, not a subscription, not a notification.

**Current Context is not Personal Knowledge** (PK-MODEL §10). A transient situation must not silently
harden into durable Taste/Interest.

**Claim only what you verified — and for PK that means a number.** Answer Gate 2 through `JudgmentEval`
against the frozen corpus + confirmed labels, recorded in `docs/eval-log.md`. The M2 rule stands:
**adopt a PK/prompt change only when it lifts agreement without regressing essential-false-quiet above
the 0.068 baseline.**

**Verification: model state is tested; pixels are Jon's pass** (`AGENTS.md`, adapted for S1). The
standing "no UI/simulator/device testing" rule still holds for S2–S5 (correction, teaching,
hypothesis, and relevance behaviour are verified via the `@Observable` models). **S1 is the deliberate
exception**: navigation *state* (selected destination, selected piece — enum-modelled, see below) is
modelled and unit-tested, but the split-view/tab *layout itself* is verified by Jon's device pass, not
by agents. Don't claim a layout works; claim the navigation state machine works and hand the look to
Jon.

**Escalate a doc conflict; do not invent a local fix.** One is live in M3: the auto-Library phase
placement (DECISIONS §18 says Phase 2; V1-SCOPE §3 Phase 7 — see *Not in M3*). Raise it at Gate 2.

---

## S1 — iPad shell: iOS 27 tabs + split view

**Branch:** `m3/s1-ipad-shell` · **PR title:** `M3 · S1 — iPad shell`

The shell today is `CockpitApp → CockpitRootView → ContentPieceListView`, where
`ContentPieceListView` is a `NavigationStack` that reaches `SettingsView`, `EditionView`, and
`FollowingView` from `.topBarTrailing` toolbar items (plus a Gmail-probe sheet). There is no TabView,
no split view, and Today / Later / Library are not real destinations. This slice replaces that with the
device-appropriate structure `docs/IPAD-FIRST-EXPERIENCE.md` has specified since day one, so the app
stops teaching the wrong thing every morning and the M3 PK surfaces land somewhere pleasant.

### Read first

`docs/IPAD-FIRST-EXPERIENCE.md` (§1 the five destinations, §4 sidebar/navigation, §5 Edition on iPad,
§7 Reader); the current `CockpitApp/CockpitApp.swift`, `ContentPieceListView.swift`, `EditionView.swift`
(note it already embeds `ReaderView(model:entryID:)` via an internal `NavigationStack`), `ReaderView.swift`
(currently **Edition-bound** — takes `EditionModel` + `entryID`), `SettingsView.swift` (already nests
`AISettingsView` and `PersonalKnowledgeView`), `FollowingView.swift`.

**Then the updated Point-Free skills** — `pfw-swift-navigation` (now recommends `@CaseBindable` for
enum bindings) and its companion `pfw-case-paths` for the enum routes below, `pfw-modern-swiftui`,
`pfw-lazy-state` (`@LazyState` for a detail view whose state derives from an id passed at init) — and
the `swiftui-whats-new-27` skill. Two 27-specific notes from that skill that will bite here:
`references/state-macro.md` (`@State` is now a macro; if a new shell view fails to compile with "used
before being initialized," the fix is **not** to reorder init — read the reference), and
`references/toolbar.md` (the constrained-space toolbar APIs, for the per-destination detail toolbars).

### Architecture

**One `@Observable` `ShellModel` owns top-level navigation; feature models keep their own detail
selection.** This matches the repo's existing shape (`EditionModel`, `FollowingModel`,
`ContentPieceListModel` are already the owners of their surfaces) and keeps everything that carries
logic unit-testable per the standing rule.

```
ShellModel (@Observable)
  selection: Destination            // enum: today, edition, later, library, settings
Destination                         // plain enum, no payload → bind directly to TabView(selection:)
SettingsRoute (enum, @CaseBindable) // following, interestAreas, personalKnowledge(claimID?), ai, pendingFinds
EditionModel.selectedEntryID: EditionEntry.ID?   // drives the Edition split view's detail column
```

`@CaseBindable` earns its place on the **enum routes that carry a payload** (a `SettingsRoute` case
like `.personalKnowledge(claimID?)`), not on the flat top-level `Destination` (a plain `Binding` to
`selection` is enough for `TabView(selection:)`). Do not sprinkle it where there is no associated
value — consult `pfw-case-paths` for the route enums.

Destination → view mapping (all reachable, none in the toolbar):

| Destination | View in S1 | Notes |
|---|---|---|
| Today | thin container: the M2 Edition summary + Essential backlog | Gmail substance is M4 (`TODAY-EXPERIENCE.md` intro) |
| Edition | `EditionView` as a `NavigationSplitView` (entry list ∥ `ReaderView` detail) | convert its internal `NavigationStack`; detail driven by `EditionModel.selectedEntryID` |
| Later | minimal browse of `LaterMembership` (list only) | thin in S1; deep Later/offline is M4 |
| Library | `ContentPieceListView` as list ∥ detail | detail = the ContentPiece-driven Reader (see decision below) |
| Settings | `SettingsView` + a `NavigationStack(path:)` over `SettingsRoute` | Following / Interest Areas / You / Pending Finds nest here (§4), not as peers |

### Scope

- **One adaptive navigation structure for both device families** using the `Tab` / `TabView` API with
  `.tabViewStyle(.sidebarAdaptable)`: iPad renders the sidebar `IPAD-FIRST-EXPERIENCE.md` §4 calls for;
  iPhone renders a standard tab bar. Five first-class destinations — **Today, Edition, Later, Library,
  Settings** — with **Following / Interest Areas / You / Pending Finds under Settings** (§1, §4). This
  is the direct fix for "we keep shoving things into the toolbar." (`Tab`/`sidebarAdaptable` and
  `NavigationSplitView` are established APIs, not 27-new — safe to lean on.)
- **`NavigationSplitView` for Edition** (§5): the entry list beside the `ReaderView` detail column so
  reading exploits iPad width instead of push/pop. On compact width (iPhone) `NavigationSplitView`
  collapses to a stack on its own — the compact behaviour comes for free.
- **Library and Later get the same list ∥ detail** treatment, feeding the one ContentPiece-driven
  Reader (see decision below). No list anywhere pushes a full-width row to its own screen.
- **Navigation state is modelled and tested.** `ShellModel.selection`, `SettingsRoute`, and
  `EditionModel.selectedEntryID` are the testable surface — including "no Edition today" and
  empty Later/Library, which must render honestly (M2's real-vs-empty distinction).
- **iPhone stays compact, not a mechanical shrink** (§3, §9): same destinations, compact treatment, no
  parity requirement. iPhone polish is explicitly **not** a gate (§9).
- *(Optional, cheap, if it fits):* surface the per-composition cost/latency figure in Settings — see
  *Model cost* above; it is what makes the eventual model A/B measurable.

### Migration — what the tree becomes

- `CockpitRootView` becomes the `TabView`/`ShellModel` host; the launch tasks it runs today
  (`followingModel.acquireOnLaunchOrRefresh()`, and the app's `CockpitCloudSync.startIfEnabled()`) are
  preserved.
- The `.topBarTrailing` toolbar block in `ContentPieceListView` that presents Settings / Edition /
  Following is **removed** — those become destinations/routes. The Gmail-probe sheet moves under
  Settings (it is developer plumbing, `IPAD-FIRST` §7's "not a debug surface" rule).
- `EditionView`'s internal `NavigationStack { … ReaderView }` becomes the split view's two columns.
- `EditionView`'s existing behaviour is preserved; the one substantive (non-re-parenting) change is
  the **Reader generalisation** — re-parameterising `ReaderView` to *(ContentPiece substance +
  optional Edition context)* and adding the ContentPiece projection that feeds the non-Edition lists
  (see the decision below). Everything else is re-parenting existing views under the new
  `ShellModel`/route enums.

### Decision — the Reader is ContentPiece-driven, with Edition context as an optional layer

**Ratified 2026-09-15.** There is exactly **one** Reader in Cockpit, and it is keyed on a
`ContentPiece`, not on an Edition entry. This is the product's single "investigate one item" surface —
the same view whether the piece was reached from Edition, Library, Later, or (in M4) Mail/Today. Every
list is a `NavigationSplitView` (list ∥ this Reader); **no destination pushes a full-width row to a
separate screen** — the standing anti-requirement for iPad.

The factoring is small because `ReaderView` is already ~90% ContentPiece-intrinsic. Of what it renders
today from `CurrentEditionRequest.Row`, only three things are Edition-specific:

- **ContentPiece-intrinsic (the Reader core):** title, publisher, `summary`, `isSubstantivePrimary`
  (+ its Correct action), `bodyCompleteness` badge, `canonicalURL` / Open Original. Plus the universal
  actions **Save for Later** and **Add to Library** (membership writes, keyed on `contentPieceID`,
  idempotent — they belong to any piece).
- **Edition context (an optional adornment, present only when opened from an `EditionEntry`):** the
  "why you're seeing this" **rationale**, **Dismiss** (`entryState → dismissed`), and **mark-Seen on
  open** (`admitted → seen`). A Library/Later piece with no Edition entry simply omits these — it is
  not "seen" in the Edition sense and cannot be Dismissed, because `entryState` is Edition-only
  (IMPLEMENTATION-CONTRACT §3).

Concrete shape for the slice:

- Introduce a small **ContentPiece projection** (analogous to `CurrentEditionRequest.Row`, keyed on
  `contentPieceID`) to feed the Reader from the non-Edition lists; the Edition path keeps its existing
  Row (which already carries rationale) and passes the `EditionEntry` as the optional context.
- The Reader takes *(ContentPiece substance)* + *(optional Edition context)* rather than
  `(EditionModel, entryID)`. Edition-only affordances render only when the context is present.
- This is deliberately foundational: M3 S3 (teach-from-Reader) and S5 (correctable rationale) both
  build on this one Reader, so generalising it now is what keeps those slices thin.

**Scope honesty:** this is slightly more than re-parenting — it adds the ContentPiece projection and
re-parameterises the Reader — but it is bounded (the substance rendering already exists) and it is the
thing that makes the whole shell cohere. It is the right home for the work; do not defer it and fork a
second reader.

### Test plan

- `ShellModel` selection transitions (each destination; default at launch).
- `SettingsRoute` push/pop, including `.personalKnowledge(claimID?)` with and without a claim.
- `EditionModel.selectedEntryID`: selecting an entry, clearing it, and the empty/absent-Edition state
  (reuse M2's real-zero-vs-no-Edition distinction).
- The Reader with **and without** Edition context: with an `EditionEntry`, rationale / Dismiss /
  mark-Seen fire; with a bare ContentPiece (Library/Later), those are absent and Save for Later / Add
  to Library still write their memberships correctly (idempotent).
- No snapshot/UI assertion of the split-view or sidebar **layout** — that is Jon's device pass.

### Done-criteria

1. Five destinations as one adaptive `Tab`/`TabView` (`.sidebarAdaptable`) — sidebar on iPad, tab bar
   on iPhone — with Following / Interest Areas / You / Pending Finds nested under Settings; **nothing
   primary remains in the toolbar.**
2. The Reader is ContentPiece-driven; Edition, Library, and Later are each `NavigationSplitView`
   list ∥ Reader. An Edition entry shows rationale / Dismiss / Seen-on-open; a Library or Later piece
   with no Edition entry omits exactly those and still offers Save for Later / Add to Library.
3. `ShellModel`, `SettingsRoute`, and `EditionModel.selectedEntryID` are unit-tested for the
   transitions and empty/absent states above; **the visual composition is handed to Jon's device
   pass**, not asserted by agents.
4. iPhone renders the same destinations compactly with **no regression to any M2 behaviour** (Edition
   composition, resolution actions, real-vs-empty rendering).
5. `swift test` and `swiftlint lint --strict` green; CI genuinely green (not a Swift-floor skip).

### Out of scope

Today's Gmail substance (M4 — Today shows the M2 Edition summary / Essential backlog for now,
`docs/TODAY-EXPERIENCE.md` intro). Offline controls in the Reader (M4). Any change to judgment, PK, or
composition. Deep Later browsing. Final pixel geometry / card density (§5, §10 — learned from use, not
encoded now). Sidebar customisation/reordering.

---

## S2 — Correction, supersession, and unobtrusive consolidation

**Branch:** `m3/s2-correction-and-consolidation` · **PR title:** `M3 · S2 — Correction and consolidation`

### Read first

`docs/PERSONAL-KNOWLEDGE-MODEL.md` §6, §8, §9, §12, §14; the M2 S1 PR (which built
`PersonalKnowledgeClaim` with `status` / `supersededByID` scaffolding and the import reconciliation
pass); JUDGMENT-CONTRACT §2 (the projection, and the 150-claim threshold consolidation protects).

### Scope

The stewardship half of Phase 2 — keeping the claim set trustworthy as it grows, without a daily chore:

- **Correction and supersession made real.** M2 S1 left `status` and `supersededByID` as scaffolding;
  this builds the path: a correction establishes the new current claim and marks the old one
  `superseded`, preserving lineage to answer "why did you think that?" (PK-MODEL §9). No silent
  erasure; no numeric-confidence resolution demanded of Jon.
- **Retirement/removal** of a claim simply no longer wanted (distinct from supersession).
- **Settings / You matures** from M2 S1's basic inspection into deliberate stewardship: inspect, teach
  directly, correct, retire (PK-MODEL §12) — landing in S1's `You` destination. Not monthly review, not
  a Notice inbox, not trajectories.
- **Unobtrusive LLM consolidation over the accumulated set.** M2 S1 already runs consolidation/dedup
  *on import*; Phase 2 extends it to claims that accumulate through ongoing teaching — as housekeeping
  (triggered, not a daily prompt), rewriting **only when semantic meaning is preserved** (PK-MODEL §6).
  A materially new inference is surfaced for confirmation, never written silently; rollup preserves
  provenance back to the explicit claims it consolidated (PK-MODEL §8).

### Done-criteria

1. A correction supersedes the prior claim through the owning `@Observable` model, lineage preserved
   and inspectable; the old claim is discoverable as superseded, not gone.
2. Consolidation is tested adversarially for semantic fidelity against real claims: a meaning-
   preserving merge is accepted; a materially new inference is surfaced rather than written.
3. Settings / You supports inspect / teach / correct / retire, verified through the model.
4. Provenance survives correction, supersession, retirement, and consolidation.

### Out of scope

The Reader teaching affordance (S3). Hypothesis confirmation (S4). Any change to what judgment *does*
with the claims (S5). Numeric confidence / salience / half-life / trajectory (PK-MODEL §14).

---

## S3 — Teach from the Reader ("why this matters")

**Branch:** `m3/s3-teach-from-reader` · **PR title:** `M3 · S3 — Teach from Reader`

### Read first

`docs/PERSONAL-KNOWLEDGE-MODEL.md` §3, §5, §7, §8; `docs/CONTENT-EXPERIENCE.md`;
`docs/IPAD-FIRST-EXPERIENCE.md` §7 (the affordance sits with Dismiss / Save / Add to Library in the
Reader); the M2 S4 Reader PR.

### Scope

The highest-quality durable input Cockpit has — Jon supplying the *reason*, in context (PK-MODEL §5):

- A Reader teaching affordance on a ContentPiece: **Tell Cockpit why this matters** / **Teach
  Cockpit** / **Correct this understanding** (the last reuses S2's correction path from the Reader).
- Cockpit synthesises the free-text reason into an **appropriately scoped** durable Taste/Interest
  claim (PK-MODEL §7 — "when drinking dry Riesling, generally prefers some fruit" over "likes fruity
  wines"), **retaining provenance back to the teaching event and the originating ContentPiece**
  (PK-MODEL §8). The canonical shape: *"I'm not interested in this specific hotel, but I care about
  this kind of adaptive reuse"* → a scoped Interest claim, not a claim about that one hotel.
- The synthesis **proposes**; a materially new/broad claim is confirmed before it becomes durable
  (PK-MODEL §6). Ordinary annotation is not automatically teaching — intent to have Cockpit learn must
  be explicit (PK-MODEL §3).
- A taught claim is a first-class citizen of S2's stewardship.

### Done-criteria

1. Teaching from a ContentPiece produces a scoped claim with provenance linking both the teaching
   event and the ContentPiece; verified through the owning model.
2. Over-broad synthesis is caught: a real teaching input that would produce an overgeneral claim is
   proposed-and-confirmed rather than written silently (adversarial test, PK-MODEL §6/§7).
3. Provenance distinguishes a Reader-taught claim from a directly-taught or imported one (PK-MODEL §8).

### Out of scope

The relevance *effect* of the new claim (S5 proves that). Any action authority (PK-MODEL §11).
Passive/behavioural capture of "what Jon read" (forbidden, PK-MODEL §1).

---

## S4 — Hypothesis confirmation

**Branch:** `m3/s4-hypothesis` · **PR title:** `M3 · S4 — Hypothesis confirmation`

### Read first

`docs/PERSONAL-KNOWLEDGE-MODEL.md` §1, §4, §10; DECISIONS §8 (Personal Knowledge — valid durable
inputs).

### Trigger — locked

**The hypothesis trigger is explicit-action recurrence** (ratified 2026-09-15): repeated **explicit**
Save for Later / Add to Library / teach on the same subject raises the question. These are deliberate
acts, not passive behaviour, so this stays firmly on the safe side of PK-MODEL §1 — and it matches
Jon's stated intent: *"I'm happy to teach the model rather than be terrified to click on something for
fear of what it might do to my algorithm."* Clicking should teach, not frighten. Subject-recurrence in
what was merely *surfaced* is explicitly **not** a trigger (too close to laundering "what Cockpit
showed" into "what Jon wants").

### Scope (minimal by design)

- A single inline confirmation affordance — **not** a Notice inbox, not a review queue (PK-MODEL §4,
  §12). Cockpit asks once; Jon confirms, dismisses, or ignores.
- Until confirmed, the observation is a transient hypothesis, **never** durable PK. Confirmation is the
  only path across the line; confirmed claims carry provenance "confirmed from a Cockpit hypothesis"
  (PK-MODEL §8).
- A transient situation stays Current Context, not durable Interest, unless explicitly confirmed
  (PK-MODEL §10).

### Done-criteria

1. Explicit-action recurrence is the **only** thing that raises a hypothesis, and it is proven that no
   unconfirmed hypothesis ever writes durable PK (adversarial test against PK-MODEL §1).
2. Confirmation writes a claim with correct provenance and it enters S2 stewardship; dismissal leaves
   no durable trace.
3. Verified through the owning model.

### Out of scope

A Notice inbox, monthly review, trajectories, contradiction-resolution engine (PK-MODEL §12, §9). Any
behavioural signal reaching judgment.

---

## S5 — The visible, correctable, PK-driven relevance change

**Branch:** `m3/s5-relevance-change` · **PR title:** `M3 · S5 — Relevance change`

The slice Phase 2 exists for. M2 proved PK moves relevance *in the harness*; S5 makes the change
**visible in the product** and **correctable from where it appears**, and produces the Gate-2 number.

### Read first

`docs/PERSONAL-KNOWLEDGE-MODEL.md` §13 (the behavioural proof) and §5; JUDGMENT-CONTRACT §2–4 (the
projection in, the rationale out); the M2 S2 eval-log entry (the baseline every change is measured
against) and M2 S3 (rationale is already written per composition and surfaced in the Reader).

### Scope

- **The rationale names the explicit claim that mattered.** Judgment already writes `rationale`
  (JUDGMENT-CONTRACT §3), surfaced in the Reader as "why am I seeing this." Phase 2's addition: when a
  Personal Knowledge claim drove admission or rank, the rationale says so in Jon's terms — *"Because
  you explicitly care about adaptive-reuse hotels, this opening appears unusually relevant"*
  (PK-MODEL §13). A small, versioned addition to the judgment prompt and to what the structured output
  reports — **never** model scoring internals (JUDGMENT-CONTRACT §3).
- **The explanation is correctable from the same interaction** (PK-MODEL §13). Correcting it routes
  into S2's correction path (and may teach via S3): "no, it's not adaptive reuse I care about, it's X."
  This closes the loop — the product's explanation is the surface Jon steers PK from.
- **The Gate-2 measurement.** Re-run `JudgmentEval` with the grown/edited claim set and record it in
  `docs/eval-log.md` (date, model, prompt version, numbers), so *did agreement move when PK grew?* has
  a real answer, under the standing no-regression rule.

### Done-criteria

1. A claim-driven admission/rank change produces a rationale that names the matched claim in product
   terms, verified through the judgment output — not a hand-written string.
2. Correcting the explanation drives S2's correction path and is tested end-to-end through the owning
   models.
3. A recorded `JudgmentEval` run shows the agreement / essential-false-quiet effect of a PK change, in
   `docs/eval-log.md`, under the M2 baseline discipline.

### Out of scope

Retroactive recomposition of a past Edition when PK changes (forbidden — Editions are materialised;
IMPLEMENTATION-CONTRACT §3 / ADR-0001 D5; the change shows up in the *next* composition or on explicit
reconsider). Any new judgment machinery beyond the rationale/claim-match addition.

---

## Jon's manual and device pass

Same shape as M1/M2: the work only Jon can do, gating what follows.

### Before S2 — close Gate 1

S2 is gated on Gate 1 being closed (see *The gate before M3 begins*). The owed items — the
agreement-definition resolution and the warm-device cost/latency reading — are Jon's/the architect's,
not a code change. S1 does not wait on this.

### During S1 — the layout call is yours

By rule, agents ship the tested navigation-state model and hand the *look* to Jon. Whether the iPad
split view and the adaptive sidebar/tab treatment actually feel calm and iPad-first (`IPAD-FIRST`
§5, §10) is a device-pass judgment — the exact card density and section navigation are meant to be
learned from real content, not encoded now.

### During S2–S5 — real teaching, not fixtures

Phase 2's surfaces only prove out against real teaching over a real claim set. Agents verify the
models and the eval effect; Jon's pass confirms the teaching *feels* unobtrusive rather than like
profile-maintenance chore-work (PK-MODEL §8, §12) — the one thing the harness cannot measure.

---

## Architecture Gate 2 — Personal Knowledge review

The checkpoint M3 ends at (`docs/V1-SCOPE-AND-SEQUENCING.md`, Architecture Gate 2). Stop and inspect
before deepening the knowledge model:

- **Did the eval agreement rate move when PK grew? If it did not, PK is decorative and something is
  wrong.** S5's recorded runs are the evidence.
- Are Fact / Taste / Interest enough, or did real teaching want a distinction they can't carry?
- What scope data was genuinely required (PK-MODEL §7)? Was provenance sufficient and useful?
- Is the LLM overgeneralizing (PK-MODEL §6)? What did consolidation get wrong on the real set?
- Does bulk import + ongoing teaching reconcile cleanly **without schema inflation**?
- How many claims exist, and is the 150-claim full-projection threshold (JUDGMENT-CONTRACT §2) still
  holding, or is it time to measure the subject-overlap subset for real?
- *(Carried from the cost decision):* has anything changed the frontier-vs-onboard calculus — can the
  onboard model now emit the schema, and is a Haiku pass worth running?

Do not add salience / confidence / trajectory machinery without evidence (V1-SCOPE §Phase 2).

---

## Not in M3 — the M4 cutline (proposed)

- **Gmail read-only Today (Phase 3, → Gate 3).** Ratified out of M3. The ground is ready: the auth
  spike is done (Phase 0, refresh token in hand), read-only comes first by contract (no mutation until
  the Gmail ADR — EMAIL-INTELLIGENCE-MODEL §13; DECISIONS §7), and `Clear` is Today's action, distinct
  from Edition's `Dismiss` (DECISIONS §7, §15; TODAY-EXPERIENCE §6). Shape:

  ```text
  Gmail Inbox → provider Artifact normalization → analysis
  → Today: Worth Seeing / Personal-Consequential / quiet handling (TODAY-EXPERIENCE §5)
  → Reader → Clear (attention only; no mutation)
  ```

  The slice's real deliverable is the **Gmail integration ADR written from observed semantics**
  (message vs thread, account boundary, pagination/delta, new-reply re-entry, failure/retry, the
  Artifact→email-ContentPiece relationship — V1-SCOPE §Phase 3; EMAIL-INTELLIGENCE-MODEL §10, §13).
  Mutation (Phase 4) stays behind that ADR.
- **Gmail dispositions and the email-delivered Stream** — Phases 4–5, Gate 4. Follow Phase 3.
- **Offline:** `Offline until [date]` (visible expiry, ~30 days) and `Keep Offline` (V1-SCOPE §1;
  IPAD-FIRST §8 — especially important on mobile). Per-piece, not bulk, in V1.
- **The auto-Library policy.** *Doc conflict to resolve, do not pick silently:* DECISIONS §18 defers
  it "to V1 Phase 2," while V1-SCOPE §3 places it in **Phase 7** (after explicit Library + custody are
  trustworthy). Treated as not-M3 on the strength of §3; reconcile the two docs at Gate 2.
- **The first specialist handoff** — the receiver for Pending Finds (Phase 6, Gate 5). Extraction
  already accumulates orphans from M2 S5; the receiver is later.
- **Edition UX papercuts** (candidates, below a phase): richer top-of-Edition summaries; triage-in-
  place from the Edition list without opening the Reader. Refinements of the existing surface — could
  ride S1 or wait for lived use.
