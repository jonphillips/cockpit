# M1 — Persistence and Destinations

**Status:** Active build order
**Role:** Architect-authored contract. Per `jon-platform/docs/agent-collaboration.md`, this
document is what to build; the executor discovers it from the repo and opens one PR per slice.
**Date:** 2026-09-11

---

## What M1 is

M1 builds the durable substrate: the tables, the identity rules, the custody rules, and the
sync posture — plus real content flowing into them. It ends when Cockpit holds real Streams,
real ContentPieces, and explicit destinations, synced correctly across devices.

M1 deliberately contains **no intelligence**. Judgment, Edition, and Personal Knowledge are
M2. The reason is sequencing, not scope-timidity: `docs/V1-SCOPE-AND-SEQUENCING.md` §3 requires
Personal Knowledge to be imported before the first Edition is ever composed, so building Edition
now would mean tuning judgment against no preferences and then rebuilding it against them.

## Slice ledger

The executor ticks its slice's box in the PR that completes it. Canonical status is GitHub PR
state; this ledger is the at-a-glance summary.

- [x] **S1 — Persistence spine** · [#2](https://github.com/jonphillips/cockpit/pull/2) · merged
- [ ] **S2 — Later and Library, normalized-text custody, CloudKit sync**
- [ ] **S3 — Add Stream, live acquisition, and abnormal health**
- [ ] **S4 — Judgment fixture set, harvested from history**

---

## Standing rules for every M1 slice

These are not slice-specific and are not restated below.

**Escalate contract conflicts; do not route around them.** If a slice's requirements and
`docs/IMPLEMENTATION-CONTRACT.md` disagree, stop and say so in the PR description, labelled
`question-for-architect`. S1 did this four times and was right each time. Inventing a local
reconciliation is the failure mode; a blocked slice is not.

**Claim only what you verified.** A green suite is not evidence that behaviour is correct. S1
shipped passing tests over code that silently wiped judgment output on every re-poll, and over a
test that asserted the bug *was* the correct behaviour. Write adversarial fixtures against the
real database for anything you assert. If you state a fact about git, the toolchain, or an API,
check it first — an S1 report claimed a branch name was impossible because of a ref that did not
exist.

**Read the dependency, not its name.** Both S2 defects were the same failure: our code against
what the package actually does. A `SET NULL` foreign key was used as a semantic signal, unaware
that SQLiteData fires the identical statement as CloudKit error recovery; and a sync enablement
gate was declared and then never consulted, against CloudSyncKit's own doc comment saying to
construct the engine stopped. Neither was a Swift problem and neither was catchable by a test that
did not know to look. When you rely on a package's behaviour, read its source and cite the line in
the PR. `.build/checkouts/` is right there.

**Constants carry a rationale.** Derive a threshold from the constraint it comes from and show
the derivation, or say plainly that you have no honest basis for the value. Surface any
non-trivial constant in the PR description rather than burying it in the diff. See Constants
below for M1's, and `docs/ADR-0001-PERSISTENCE-AND-EXECUTION.md` D3 for the worked example.

**A slice enforces only the invariants whose tables exist.** `docs/IMPLEMENTATION-CONTRACT.md`
§5 states twelve invariants as permanent truths about the finished system, not as a per-slice
checklist. Where an invariant names a table a slice does not have, that clause is owned by the
slice that introduces the table, and this document says so explicitly in the done-criteria. Never
weaken the contract to fit a slice; narrow the slice's criterion and name who inherits the rest.

**Green before ready.** `swift test` and `swiftlint lint --strict` pass locally, and CI is
genuinely green before the PR leaves draft. The CI test job **skips green** when the runner's
Swift is below the manifest floor — a skip is not a pass; check which one you got.

---

## S1 — Persistence spine ✅

Merged. SQLiteData schema for InterestArea / Stream / Artifact / ContentPiece; derived UUIDv5
ContentPiece identity; RSS/Atom/RDF discovery and parsing on `XMLParser`; idempotent
provenance-preserving ingest; inspection-only iPad list. House drift-control pipeline adopted
(SwiftLint gate, CI, pre-commit hook).

Two pieces of debt it created deliberately, both discharged by S2:

- `CockpitCloudSync.makeSyncEngine` **throws** `normalizedTextRequiresLibraryChildRecord`, with a
  test pinning the refusal, because syncing inline `normalizedText` would violate D6.
- Invariants 3 and 12 are untested because the membership tables they constrain do not exist.

---

## S2 — Later and Library, normalized-text custody, CloudKit sync

**Branch:** `m1/s2-destinations-and-sync` · **PR title:** `M1 · S2 — Destinations and sync`

### Read first

`AGENTS.md`; `docs/IMPLEMENTATION-CONTRACT.md` §2, §5, §6; `docs/ADR-0001-PERSISTENCE-AND-EXECUTION.md`
D4 and D6; `docs/LATER-LIBRARY-EXPERIENCE.md`; `docs/V1-SCOPE-AND-SEQUENCING.md` §1;
`docs/handoff-1-report.md`; `jon-platform/docs/ios/persistence-and-sync.md` and `swift-style.md`.

### Scope

**Membership.** `LaterMembership(contentPieceID, addedAt)` and
`LibraryMembership(contentPieceID, addedAt, admittedBy)` per contract §2. Explicit add and remove
only. Nothing enters either destination automatically in this slice and nothing silently expires.

**Normalized-text custody.** `normalizedText` is currently an inline column on `contentPieces`.
D6 requires it in a **child record** rather than inline, and requires it to sync **for Library
members only** — non-Library pieces keep it device-locally. Design that shape, migrate the
existing column into it, and make the Library-only sync rule expressible rather than aspirational.

**Sync on.** Remove the guard, register the syncable set D6 names, delete or invert the test
pinning the refusal. Artifacts and raw source text are **not** synced: device-local evidence,
regenerable.

**The previously untestable invariants.** 3 and 12.

**Minimal UI.** Enough to add, view, and remove membership from the existing inspection list.
Not a design pass.

### Done-criteria

1. Both membership tables exist and match contract §2. Add and remove work from the UI.
2. Normalized text lives in its child-record shape. The migration is **lossless against a
   populated database** — seeded rows, migrated, asserted — not only against an empty one.
3. Invariant 11 still holds: every ContentPiece with textual substance has normalized text
   populated at ingest, unconditionally, whatever table it physically lives in.
4. Invariant 7 still holds: `mode = until` expiry would remove only `payloadRef`; normalized text
   survives. (LocalAvailability itself is out of scope — the shape must not foreclose this.)
5. `makeSyncEngine` constructs an engine. It registers exactly the **intersection of D6's
   syncable list with the tables that exist at the end of this slice** — InterestArea, Stream,
   ContentPiece, both membership tables, and the normalized-text child record under the rule in
   criterion 6. D6 also names Editions, EditionEntries, PersonalKnowledgeClaims, PendingFinds and
   DispositionPolicies: those are the destination, not this slice's scope, and each later slice
   registers its own tables as it introduces them. The exclusions are the load-bearing half —
   Artifacts and `rawSourceText` must be absent, and a test should fail if either appears.
6. `normalizedText` syncs for Library members only, and there is a test that would fail if a
   non-Library piece's text were sent.
7. Invariant 3, to the extent this slice can enforce it: removing Later or Library membership
   deletes no ContentPiece, no Artifact, and no provenance. The invariant's PendingFind clause is
   **not testable in this slice** — that table does not exist and is out of scope — so it is owned
   by the slice that introduces PendingFind. What *is* enforceable now is the structural guarantee
   behind it: membership removal deletes the membership row and nothing else, and neither
   membership table carries an `ON DELETE CASCADE` to anything. Get that right and the PendingFind
   clause holds for free when the table arrives.
8. Invariant 12 has a test: Library contains ContentPieces only.
9. No `database.write` / `database.read` in any `*View.swift` — persistence logic lives in an
   `@Observable` model. The lint gate fails the build on this.
10. `docs/handoff-2-report.md` written in the voice of `docs/handoff-1-report.md`: prose, what
    you refused to build and why, every contract conflict, every constant with its derivation,
    and what you verified versus what you assumed.

### Hazards specific to this slice

**The migration is one-way and runs against real data.** The iPad holds live Gmail authorization
state and may hold real rows. A migration that moves normalized text must be safe on a populated
database. Verify it against a seeded database in `swift test`; the upgrade on Jon's actual iPad
is his to run, and remains an unverified risk the handoff report must name. Do not go to the
device — see `AGENTS.md`, No UI, simulator, or device testing.

**CloudKit schema hardens once records exist.** `PLATFORM-ADOPTION.md` §1 says respect ownership
and FK constraints *before* the schema hardens. Today the container is empty. This slice is the
last cheap moment to get the record graph right.

**`admittedBy` is undefined in the corpus.** Contract §2 names the column; nothing says what
writes it. It is the seam where the deferred auto-Library policy will eventually record that it,
rather than a person, admitted the piece. Do not invent an elaborate enum. Propose the narrowest
representation that distinguishes explicit human admission from everything else, and raise it in
the PR as a decision for the architect to ratify or amend into the contract.

### Out of scope — do not build to "prepare" for these

Edition and EditionEntry. Judgment. Personal Knowledge. PendingFind. LocalAvailability and
offline payload custody. The auto-Library policy — `Stream.autoLibrary` exists as a column;
the policy does not. Live Stream capture (that is S3). Anything Gmail.

---

## S3 — Add Stream, live acquisition, and abnormal health

**Branch:** `m1/s3-live-streams` · **PR title:** `M1 · S3 — Live Streams`

### Read first

`AGENTS.md`; `docs/IMPLEMENTATION-CONTRACT.md` §2; `docs/ADR-0001-PERSISTENCE-AND-EXECUTION.md`
D1, D2, D3; `docs/CONTENT-STREAM-MODEL.md` (Health); `docs/STREAM-MANAGEMENT-EXPERIENCE.md`;
`docs/V1-SCOPE-AND-SEQUENCING.md` §1 Following/Streams; `docs/JUDGMENT-CONTRACT.md` §6;
`docs/stream-handling-seeds.md`; `docs/handoff-2-report.md`.

### This slice is larger than its name

Nothing in the shipping app has ever called `FeedIngestor.ingest`. S1 built the acquisition
engine and tested it thoroughly; it was never wired to a launch, a button, or a schedule. Cockpit
on device today cannot acquire a single ContentPiece — the inspection list has always been empty
in the only place that matters. S3 is not "add more Streams." It is the first time the engine runs
outside a test.

### Why this is separate from the fixture set

`docs/JUDGMENT-CONTRACT.md` §6 requires the eval fixture set to be 200 real ContentPieces "drawn
from Jon's actual Streams across at least two weeks." That constrains the **span of the corpus,
not when it is collected** — history satisfies it exactly as well as the future does, and better,
because history already carries evidence of what Jon did with each item. S4 harvests backwards.
Nothing waits.

What S3 still owns is accumulation from here on, and not losing it. A feed's backfill is shallow —
most publish between ten and fifty recent items — so the first poll of five Streams is itself a
partial backfill, and everything after it is content that exists nowhere else once it scrolls out.
That is why done-criterion 7 is the load-bearing one.

### Scope

**Add Stream.** One global operation. Paste a human-facing URL → `FeedDiscovery.discover` (exists,
S1) → propose name, publisher, transport and a primary Interest Area → Jon confirms or edits →
the Stream row is written. The proposal is **deterministic**: parsed feed metadata and the URL,
nothing else. No model call — M1 contains no intelligence, and this is exactly the kind of place
one would leak in.

Interest Areas are assignable and creatable by name from this flow, because zero exist today and a
Stream with no Interest Area cannot be judged later.

**Seed the five Streams from work already done.** `docs/stream-handling-seeds.md` holds Jon's own
Handling text for twenty-one feed-backed publications, extracted from a real one-week Gmail corpus,
along with the proposed five and why each was chosen for feed shape. Use it. Do not go back to the
archived source it came from — the extraction has already been done, and the archive carries
superseded architecture the extraction deliberately left behind.

**Handling prose gets a column.** `Stream.handlingGuidance`, ratified 2026-09-11 and now in
contract §2. The enum stays a posture; the prose carries intent, as the Stream-level parallel to
`InterestArea.guidance`. Add it in this slice's migration and let Add Stream propose and edit it.
It is a judgment input that M2 reads and this slice never parses — no matcher, no keywords, no
rules language. In M1 it is text that is written, displayed, and stored.

**Acquisition actually runs.** Poll every active Stream on app launch, and on an explicit
pull-to-refresh. Foreground only. **No `BGProcessingTask`** — D1 introduces it as an opportunistic
pre-warm for Edition composition, which does not exist yet. Registering background work with no
consumer is scheduling for its own sake.

**Five real Streams.** Real feeds replace synthetic ones as the evidence that this works. Capture
each feed's actual bytes once into `Tests/Fixtures/streams/`, commit them, and test discovery and
parsing against those recorded bytes. See the hazards below: capture is a scripted one-time fetch,
not a reason to open the app.

**Stop and pause.** `StreamFollowState` gains `paused` and `stopped`; the poll loop honours both.
This is not scope creep. Adding five real Streams without an off switch means a misbehaving feed
can only be removed by deleting a row by hand, and V1 scope §1 names pause/stop anyway.

**Abnormal health, evidence-based only.** `failed` already exists and is written from a real fetch
or parse failure. Surface abnormal health in the Following list and keep healthy Streams quiet.
Record consecutive failure count and lean on `lastReceivedAt`. Do **not** introduce a `stale`
state in this slice — see Constants.

**Protect the fixture pool.** Nothing prunes Artifacts or `rawSourceText` during M1. Those rows are
device-local regenerable evidence in the general case, but an item that has scrolled out of its
feed is not regenerable, and they are the raw material S4 freezes.

### Done-criteria

1. Add Stream works end to end from the UI: paste a URL, see a proposal, edit it, confirm, and the
   Stream persists with an Interest Area. Persistence lives in an `@Observable` model; the lint
   gate still passes.
2. `Stream.handlingGuidance` exists and round-trips: the migration adds it, Add Stream writes it,
   the Following UI shows and edits it, and the five seeded Streams carry their text from
   `docs/stream-handling-seeds.md`. Nothing in M1 reads it for behaviour.
3. Five real Streams are followed, and each one's feed bytes are committed under
   `Tests/Fixtures/streams/`. Discovery and parsing are tested against those recorded bytes, and a
   test fails if a fixture file is missing. At least one fixture is a feed that S1's synthetic
   cases do not resemble — a real feed's malformed dates, entity-escaped bodies, or missing GUIDs.
4. Acquisition runs on app launch and on explicit refresh, both through one tested entry point.
   Re-polling is idempotent over the real fixtures: invariants 1 and 2 are re-asserted against
   recorded real feeds rather than synthetic ones.
5. A `paused` or `stopped` Stream is not polled. Tested.
6. Abnormal health is visible in Following and healthy Streams are silent. A fetch failure sets
   `failed` and preserves the original error (S1 behaviour, re-asserted through the live path).
7. **The fixture pool survives feed turnover.** Poll a Stream, then poll it again with an entry
   removed from the feed, and assert the older ContentPiece, its Artifact, and its `rawSourceText`
   are all still present. This is the adversarial fixture for the one failure that would silently
   cost two weeks.
8. `docs/handoff-3-report.md`, in the established voice.

### Hazards specific to this slice

**Autodiscovery against real sites is the device-testing trap.** "Paste a URL and see what
happens" is inherently interactive, and this slice is where the boundary in `AGENTS.md` is hardest
to hold. Capture each feed's bytes once with a scripted fetch — `curl` into
`Tests/Fixtures/streams/` — and verify everything against those files. Never by driving the app.

**Real feeds break in ways fixtures do not.** S1's parser met synthetic RSS, RDF and Atom. Five
real publishers will produce at least one thing it has not seen. Expect to fix the parser, and
commit the byte fixture that proved the fix.

**Adding a column to a synced table is safe; changing one is not.** `streams` is registered with
CloudKit as of S2, and Jon's device pass may have hardened the container before this slice lands.
Adding `handlingGuidance` is additive and supported — CloudKit creates the field on first save.
Removing or retyping an existing field is the direction that is expensive, so get the name and type
right the first time rather than planning to revise it.

**Losing accumulated content costs two weeks, not an afternoon.** Any change that deletes or
rewrites Artifacts is a fixture-pool risk for the rest of M1. S1's deduplication migration already
deletes Artifact rows; nothing in S3 may add a second such path.

### Out of scope — do not build to "prepare" for these

Judgment and any model call. Edition. The designated-ingesting-device setting (D2 — there is one
device). `BGProcessingTask`. Email-delivered Streams and anything Gmail. A publisher catalog,
source recommendations, or mailbox-wide newsletter discovery — V1 scope §1 excludes all three.
Stream cadence inference. The auto-Library policy. Fixture export, which is S4.

---

## S4 — Judgment fixture set, harvested from history

**Branch:** `m1/s4-fixture-set` · **PR title:** `M1 · S4 — Fixture set`

**Gated on data, not on the calendar.** §6's "across at least two weeks" describes the span of the
corpus. Two weeks of Jon's Gmail already exists, and so does the record of what he did with every
message in it. There is nothing to wait for.

### What history gives that the future does not

Gmail retains disposition. For any message in the last fortnight it is possible to ask whether it
is still in the inbox, was archived, or was trashed, and whether it was ever read. That is evidence
about real decisions Jon already made, on material he actually received — and it is *free*, where
the equivalent from live accumulation would be two weeks of waiting followed by the same labelling
pass.

### The line this slice must not cross

Disposition is a **prior on the label, never a label and never a judgment input.**

The mapping is suggestive and nowhere near exact. Trashed is close to certain `never`. Archived and
read reads as `surface`; archived and unread reads as `quiet` — but archiving is also how a busy
person clears a screen, and a message still sitting in the inbox after two weeks may be important
or may be inbox rot. Only Jon can settle those, and §6's ground truth is his label, not his
behaviour.

So: seed each fixture's label from disposition, have Jon confirm or correct it, and store **only
the confirmed label**. Where his correction disagrees with the prior, that disagreement is the most
interesting row in the set — it is a case where what he did and what he meant came apart, which is
the thing a personal editor exists to fix. Record the prior alongside the label so those rows stay
findable.

And the hard boundary: `docs/JUDGMENT-CONTRACT.md` §2 forbids judgment from receiving clickstream
or open history, and Product Law 12 keeps behaviour out of Personal Knowledge. Disposition may
**seed an eval label for confirmation**. It may never enter the judgment prompt, be written to a
`PersonalKnowledgeClaim`, or reach composition. This is exactly the seam where behavioural data
launders itself into ranking, and it is being opened deliberately, once, for a labelling
convenience.

### Scope

**Harvest.** A one-time read-only pull of the last two weeks of Gmail, capturing each message's
content plus its disposition and read state. It reuses the OAuth the D7 probe already established.

It is a **development tool, not app code** — a test or tool target, run once, never shipped and
never on a launch path. Gmail ingest remains out of M1. This is a data-acquisition script that
happens to speak to Gmail, and the distinction has to survive contact with the keyboard: nothing it
produces may be imported by `CockpitApp` or `CockpitCore`.

**Top up from RSS.** S3's first polls carry whatever backfill the five feeds publish. Use it. If
Gmail plus feed backfill still falls short of 200, say so plainly rather than padding with
synthetic material — a short set is a real finding about corpus volume against §7's assumptions.

**Export.** Deterministic, into `Tests/Fixtures/judgment/`. Real ContentPieces carrying exactly the
fields §2 names as judgment inputs, and nothing else. Frozen, committed, and re-runnable without
re-fetching.

**Label file.** Keyed by ContentPiece ID so a re-export does not orphan the labels. Carries the
confirmed label, `isSubstantivePrimary`, and the disposition prior that seeded it.

**Harness skeleton.** `swift test --filter JudgmentEval` reads fixtures and labels and reports the
six metrics §6 names, over a **stubbed** judge. M1 contains no model calls; M2 plugs the real call
into a harness that already computes numbers. False-quiet rate on Essential material is the metric
that matters and should be the hardest one to misread in the output.

### Hazards specific to this slice

**The harvest is the largest single scope risk in M1.** If the Gmail work turns out to be more than
a script — pagination, MIME bodies, threading — stop and split it rather than absorbing it. A slice
that quietly becomes Gmail ingest has broken the milestone's one firm boundary.

**Two weeks of Gmail is personal mail, not just newsletters.** The harvest is scoped to editorial
material; correspondence, transactional, and account mail are not fixtures and should not be
written to disk. `docs/EMAIL-INTELLIGENCE-MODEL.md` §7 and §9 draw that line.

### Out of scope

The judgment prompt, any model call, Gmail disposition writes of any kind, Today, the attention
model, `docs/eval-log.md` entries (nothing to log until a model runs), and Edition composition.

---

## Jon's device pass

Agents stop at the device boundary (`AGENTS.md`, No UI, simulator, or device testing). This
section is the other half of that rule: where the risks they were told to name instead get picked
up, by whom, and when.

The standing shape is that a slice's handoff report names its unverified device risks, and the
architect turns them into a numbered pass here before the next slice starts. A device pass is a
**gate**, not a chore — the next slice does not begin until it has run.

### After S2 merges — before S3 begins

S3 pours five real Streams of live content into a database and a CloudKit container that S2 has
only ever exercised against fixtures. Both of S2's one-way steps should happen while the data is
still small enough to throw away.

1. **Back up the iPad database before first launch.** The normalized-text migration is one-way and
   SQLite migrations are append-only: anything it gets wrong cannot be fixed by editing the
   migration afterwards, only by adding another one on top.
2. **Launch once and confirm the migration completed** — existing ContentPieces still list, and
   their readable text survived the move out of the inline column.
3. **Confirm sync is still off.** It must not start unbidden; the engine is constructed stopped and
   starts only through the enablement gate.
4. **Then turn sync on deliberately** and let the container take its schema. This is the moment
   `PLATFORM-ADOPTION.md` §1 is about — after it, the record graph is expensive to change.

Multi-device sync stays unverified until the app is on a second device, which is not an M1
deliverable. S2's handoff report says so and that remains the honest position.

One correction to the risk as S2 stated it: nothing in the shipping app has ever called
`FeedIngestor.ingest`, so the iPad database almost certainly holds no ContentPieces at all. The
migration is still one-way and step 1 still applies, but it is migrating an empty table. The real
exposure in this pass is step 4, not step 2.

### After S4 — the labelling pass

Not a device pass, but the same shape: work only Jon can do, gating the slice after it.

`docs/JUDGMENT-CONTRACT.md` §6 needs each of the 200 frozen fixtures labelled `surface` / `quiet` /
`never`, plus `isSubstantivePrimary`. This is the ground truth every judgment decision in M2 is
measured against, and single-user ground truth is the structural advantage no product company can
buy — which also means nobody else can produce it.

S4 seeds every label from Gmail disposition first, so this is a pass of confirmation and
correction rather than 200 cold judgments. Budget it honestly anyway — the rows where the seed is
wrong are exactly the rows that carry the most information, and they are the ones that will take
real thought. M2's first slice does not start until the labels exist.

---

## Constants

M1 introduces **no tunable product constants**. The Edition numbers — carryover budget 3,
Essential backlog relief at 14, `targetSize` 20 — belong to M2 and are not in play here.

Two constraint-derived values are in scope, and both must be derived rather than chosen:

| Value | Where it comes from |
|---|---|
| Identity namespace `4577b834-26f2-58c0-bed6-e73143426dff` | `uuid5(DNS, "cockpit.jonphillips.com")` — reproducible and auditable, not a random literal. Fixed in ADR-0001 D3. Already landed; listed as the worked example of the rule. |
| Any normalized-text chunking or size threshold in S2 | CloudKit's **documented** per-record limit, cited in the PR with a link. Do not pick a round number that "seems safe." If no chunking is needed, say that and show why. |
| A Stream staleness threshold in S3 | **There is no honest basis for one yet, so S3 introduces none.** A weekly newsletter is not stale at eight days; a daily is stale at three. Staleness is only meaningful against a Stream's own observed cadence, and cadence is not observable until content has been accumulating. S3 surfaces `failed`, which is evidence — a fetch or parse actually failed — and records consecutive failures and `lastReceivedAt` as the raw material a later threshold can be derived from. This is the rule working in the direction it is usually not: the right move is to ship no constant. |

The SwiftLint drift-gate thresholds are constants too, but they live in `.swiftlint.yml` with
their derivation in comments, and are re-baselined there rather than here.

---

## Not in M1 at all

Edition, judgment, Personal Knowledge, PendingFind handoff, Gmail ingest and disposition,
offline payload custody, the auto-Library policy, and any specialist-app Find receiver. Several
have columns or enum cases already present in the schema; a column is not a licence to implement
the behaviour behind it.

---

## Amendments

**2026-09-11 — `Stream.handlingGuidance` ratified.** Extracting the Handling seeds surfaced that
fifty hand-written drafts of Stream-level editorial intent had nowhere to live: `handling` is a
posture enum and `guidance` sits on InterestArea, while `docs/JUDGMENT-CONTRACT.md` §4 passed
handling into the prompt as though it carried meaning. A prose column beside the enum, ratified by
Jon the same day. Contract §2 and JUDGMENT-CONTRACT §2 and §4 amended; S3 adds the column. Worth
noting how the gap stayed hidden: the requirement was demonstrated a week earlier and then
normalized out of the corpus, so the evidence and the schema never met.

**2026-09-11 — D7's day-8 check retired.** Raised by Jon while reviewing S4's sequencing. The
seven-day refresh-token expiry belongs to Testing status; the client has been published to
Production since 2026-09-11, so nothing expires on a timer and there was never anything for S4 to
wait behind or protect. Recorded because the failure has the same shape as the one below: a
procedure written under one configuration, kept after the configuration changed, then treated as a
constraint by a reader who did not check whether it still applied. Amended in ADR-0001 D7,
`docs/V1-SCOPE-AND-SEQUENCING.md` §3, `docs/CAPABILITY-REALITY-MAP.md` §8 and `docs/eval-log.md`.

**2026-09-11 — The fixture set is harvested from history, not awaited.** S4 was first written with
a fourteen-day calendar gate, on the reading that §6's "across at least two weeks" described when
fixtures could be collected. It describes the **span of the corpus**. Jon raised it: two weeks of
his Gmail already exists, and so does the record of what he did with every message — still in the
inbox, archived, trashed, read or not. History is strictly better than waiting, because it arrives
already carrying evidence of real decisions. The gate is now data availability, and S4 can start as
soon as S3 lands. The same correction surfaced fifty corpus-derived Handling drafts sitting unused
in the archive, which now seed S3's five Streams. Recorded because the error is a general one: a
constraint on a property of the data was read as a constraint on the schedule.

**2026-09-11 — S3 firmed up and split; S4 added.** The provisional S3 bundled a feature with a
data deliverable that cannot begin for a fortnight: `docs/JUDGMENT-CONTRACT.md` §6 requires
fixtures drawn across at least two weeks of real accumulation. Holding S3 open for a wall-clock
dependency would have delayed the thing that starts the clock. S3 is now the Add Stream operation
and live acquisition; S4 is the fixture freeze, gated on calendar time rather than on review.
Firming it up also surfaced that nothing has ever called `FeedIngestor.ingest` outside a test.

**2026-09-11 — Device testing ruled out; Jon's device pass added.** The S2 migration hazard said
review "sees the diff and not the device," which an executor reasonably read as licence to verify
on device. Nothing in the corpus forbade it. `AGENTS.md` now draws the boundary, that hazard is
rewritten, and the risks agents are told to name are collected into Jon's device pass above with
an owner and a gate.

**2026-09-11 — S2 done-criteria 5 and 7 corrected.** Raised by the executor before implementation,
which is the escalation rule working as intended; both defects were in this document, not in the
corpus.

Criterion 7 required a test that membership removal preserves PendingFinds, while the same slice
forbids PendingFind and no such table exists — the invariant had been copied verbatim from
contract §5 into a slice that cannot satisfy it. Criterion 5 required the syncable set to "match
D6 exactly," but D6's list names five tables that belong to M2, so exact compliance was impossible
by construction.

Both are now scoped to what exists, with the remainder explicitly assigned to the slices that
introduce those tables. The standing rule above generalises the fix. The contract itself is
unchanged and was never at fault.
