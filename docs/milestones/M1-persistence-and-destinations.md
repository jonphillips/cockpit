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
- [ ] **S3 — Live Streams and judgment fixture capture** *(provisional; firms up when S2 lands)*

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
database. This is the one defect class the architect's review cannot catch, because review sees
the diff and not the device.

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

## S3 — Live Streams and judgment fixture capture *(provisional)*

Firms up when S2 lands. Expected shape: the Add Stream operation (paste a human-facing URL,
autodiscovery, proposed publisher and Interest Area), five real Streams rather than fixtures,
basic abnormal health surfacing, and capture of the frozen fixture set that
`docs/JUDGMENT-CONTRACT.md` needs before M2 can tune judgment.

S1 could not do this because the identity namespace was unresolved. It is now fixed in ADR-0001
D3, so the blocker is gone.

---

## Constants

M1 introduces **no tunable product constants**. The Edition numbers — carryover budget 3,
Essential backlog relief at 14, `targetSize` 20 — belong to M2 and are not in play here.

Two constraint-derived values are in scope, and both must be derived rather than chosen:

| Value | Where it comes from |
|---|---|
| Identity namespace `4577b834-26f2-58c0-bed6-e73143426dff` | `uuid5(DNS, "cockpit.jonphillips.com")` — reproducible and auditable, not a random literal. Fixed in ADR-0001 D3. Already landed; listed as the worked example of the rule. |
| Any normalized-text chunking or size threshold in S2 | CloudKit's **documented** per-record limit, cited in the PR with a link. Do not pick a round number that "seems safe." If no chunking is needed, say that and show why. |

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
