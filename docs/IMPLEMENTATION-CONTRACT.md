# Cockpit Implementation Contract

**Status:** Normative implementation contract
**Date:** 2026-09-08

This is the compact document implementation agents read. It states the schema, the state machines, the invariants, and the definitions of load-bearing words.

The essays in `docs/` remain normative for product reasoning and are consulted by name when a specific area is being changed. This document is consulted **every session**.

If this document and an essay disagree about a *shape*, this document wins and the essay is corrected. If they disagree about *product intent*, `docs/DECISIONS.md` wins and this document is corrected.

---

## 1. Definitions of load-bearing words

These four terms appear throughout the corpus and were previously undefined. They are now fixed.

### Subjects

A **Subject** is a short lowercase topical string attached to a ContentPiece by the judgment pass. Free text, not an entity, not a controlled vocabulary, no alias or hierarchy machinery. Stored as a JSON array on `ContentPiece.subjects` and mirrored into the FTS index. Target three to eight per piece.

A Subject never gains an ID, a detail screen, or a merge operation in V1. When retrieval failures prove strings insufficient, that is evidence, and the decision is amended.

### Substantive primary material

The trigger condition for the Essential guarantee. A ContentPiece is **substantive primary material** when it is the Stream's own authored publication rather than an accessory to it.

Substantive: an original post, article, issue, episode, or report.
Not substantive: a link roundup with no original argument, a subscriber-housekeeping notice, a paywall teaser with no body, a comment-thread digest, a promotional or fundraising message from the publisher.

The judgment pass returns this as a boolean with a one-line reason. It is inspectable and correctable from the Reader.

This flag is the **primary-vs-accessory** axis only. It gates *attention* non-loss — the Essential guarantee in §3 — and auto-Library qualification. It does **not** mean "keep this forever": durable retention is the user's explicit **Add to Library** act. Whether a piece is *worth keeping* (durable/reference vs ephemeral) is a separate axis this field does not carry — a topical news recap is substantive primary **and** ephemeral — and auto-Library must not treat primary-ness as durable-worth (`docs/DECISIONS.md` §18). "Has a real body" is likewise a separate axis (`bodyCompleteness`, S5): a body-less teaser is not substantive today, but once completeness exists that fact belongs to it and this flag stays purely primary-vs-accessory.

### Body completeness

`bodyCompleteness` records how much readable body Cockpit actually holds for a ContentPiece. Its
values are `full`, `truncated`, and `teaser`. It is derived from source content at ingest, never
from subscription state: deterministic paywall/cutoff markers win, and the judgment pass may only
classify an otherwise unresolved value as a fallback. The stored field is nullable only for legacy
or otherwise unresolved rows awaiting ingest/fallback classification; classified values are always
one of the three values above. A `teaser` with no body is not substantive;
a `truncated` real body may still be substantive. This is a completeness/custody axis, not a
primary-vs-accessory judgment.

### Qualifying

Used only in the auto-Library policy. A future ContentPiece **qualifies** for automatic Library admission when it is substantive primary material from the Stream carrying the policy. Nothing else. This is deliberately not a rules language.

### Judgment

The single structured LLM pass that turns a set of new ContentPieces into an Edition. Fully specified in `docs/JUDGMENT-CONTRACT.md`.

---

## 2. Schema

SQLiteData tables. Names are indicative; the distinctions are normative.

```
InterestArea(id, name, guidance, sortOrder)

Stream(id, name, publisher, interestAreaID, transport, locator,
       handling, handlingGuidance, isEssential, followState, autoLibrary)

StreamPollState(streamID, health, lastReceivedAt,
                consecutiveFailureCount, lastFailureDescription)

Artifact(id, streamID?, transport, providerID, canonicalURL,
         acquiredAt, payloadRef?, rawSourceText?, contentPieceID?)

ContentPiece(id, kind, title, creator, publisher, publishedAt,
             canonicalURL, summary, normalizedText, subjects,
             isSubstantivePrimary, bodyCompleteness, createdAt)

Edition(id, date, composedAt, state, targetSize,
        estimatedCostUSD?, promptVersion?, modelName?)

EditionEntry(id, editionID, contentPieceID, section, rank,
             rationale, matchedPersonalKnowledgeClaimID, entryState,
             firstAdmittedEditionID, timesCarried)

LaterMembership(contentPieceID, addedAt)

LibraryMembership(contentPieceID, addedAt, admittedBy)

LocalAvailability(contentPieceID, mode, expiresAt, verifiedAt, payloadRef)

PersonalKnowledgeClaim(id, kind, claim, scope, provenance, teachingID?,
                       status, supersededByID?, createdAt)
PersonalKnowledgeTeaching(id, contentPieceID, reason, createdAt)

PendingFind(id, contentPieceID, kind, name, descriptor, rationale,
            sourceURL, hints, state)

DispositionPolicy(id, description, matcher, action, streamID?)

AppliedDisposition(id, providerMessageID, action, policyID,
                   appliedAt, undoableUntil, reverted)
```

`ContentPiece.id` is derived, not random: a UUIDv5 using Cockpit's fixed namespace `4577b834-26f2-58c0-bed6-e73143426dff` over the canonical identity string (canonical URL, else provider stable ID, else RSS GUID, else content hash). Two devices that independently ingest the same item must arrive at the same primary key. See `docs/ADR-0001-PERSISTENCE-AND-EXECUTION.md`.

`Stream.handling` is a posture enum. `Stream.handlingGuidance` is the prose beside it: Jon's own words about why he follows this Stream and what should be done with an issue. It is the Stream-level parallel to `InterestArea.guidance` and is a judgment input, not an annotation — `docs/JUDGMENT-CONTRACT.md` §2 and §4 pass it into the prompt. It is never a rules language and is never parsed; judgment reads it as prose. Ratified 2026-09-11 on the evidence of fifty hand-written drafts in `docs/stream-handling-seeds.md`, which had nowhere to live.

`StreamPollState` is the per-device record of what the last poll of a Stream observed: `health` (`unknown`, `healthy`, `failed`), `lastReceivedAt`, `consecutiveFailureCount`, and the `lastFailureDescription` from the most recent failure. It is one row per Stream, written only by the device that polled, and it is **device-local and never synced** — the same category as Artifacts and `LocalAvailability` in `docs/ADR-0001-PERSISTENCE-AND-EXECUTION.md` D6. Each device polls independently, so health is an observation of that device's own acquisition, not shared canonical state; syncing it would let two devices' independent polls overwrite each other under last-writer-wins. It is regenerable — the next successful poll repopulates it. The split is along intent versus observation: `Stream.followState` (whether to poll) stays on the synced Stream record; `StreamPollState` (what polling found) does not. Poll health is placed here from the start; earlier drafts of the schema carried `health` and `lastReceivedAt` inline on `streams`, corrected before the table shipped to any device.

`LibraryMembership.admittedBy` records what admitted the piece. In M1 the only sanctioned value is `explicit`, meaning direct human admission. The deferred auto-Library policy defines its own value in the slice that introduces it, and until then nothing else writes this column. Ratified from M1 S2, which raised it correctly: the column was named here without ever saying what writes it.

`PersonalKnowledgeTeaching` is the narrow, append-only provenance record for an explicit Reader
teaching. It holds the human-supplied reason and the originating ContentPiece; a Reader-taught
claim records its `teachingID`. This is intentionally not a generalized evidence graph: it exists
because one claim must answer both the exact teaching event and the ContentPiece that gave it
context. It is synced with canonical Personal Knowledge.

`Edition` records how it was composed so a closed Edition explains itself from stored state
(§3): `estimatedCostUSD` is the Gate-1 cost estimate from `JudgmentRun.estimatedCost` (a `Double`
because StructuredQueries has no `Decimal` column binding, and this is an estimate, not a billed
figure); `promptVersion` and `modelName` are the prompt version and model the pass used. Added by
M2 S3, which the build order requires to record composition cost.

`EditionEntry.timesCarried` counts the day boundaries a piece has been carried across to reach this
entry — `0` on first admission, incremented on each re-admission. It makes the carryover budget and
the Essential relief valve (§3) provable from a single stored row rather than by walking the carried
chain. Added by M2 S3. One Edition per day and invariant 4 (no ContentPiece twice in one Edition)
are enforced in composition code, not by unique indexes: SQLiteData's SyncEngine rejects uniqueness
constraints on synchronized tables, and `Edition`/`EditionEntry` sync (ADR-0001 D6).

`LocalAvailability.mode` is one of `cache`, `until`, `pinned`.
`ContentPiece.kind` is a display noun: `article`, `newsletter`, `video`, `podcast`, `report`, `pdf`, `post`.

---

## 3. Edition state machine

`Edition.state`: `composing → open → closed`.

An Edition is composed once per day at first app launch after the day boundary. Once `open`, its entry set is stable for the day except for intraday admission of Essential or time-critical material, which appends and never reorders.

`EditionEntry.entryState`:

```
admitted ──open──▶ seen ──dismiss──▶ dismissed
    │                │
    │                ├──saveForLater──▶ resolved
    │                └──addToLibrary──▶ (state unchanged)
    │
    └──dayBoundary──▶ carried  (re-admitted to the next Edition
                                as a new EditionEntry with
                                firstAdmittedEditionID preserved)
```

Legal transitions and only these:

- `admitted → seen` — the Reader opened the piece.
- `admitted → dismissed`, `seen → dismissed` — explicit Dismiss.
- `admitted → resolved`, `seen → resolved` — Save for Later.
- `admitted → aged`, `seen → aged` — carryover budget exhausted, non-Essential only.
- any state → `carried` at the day boundary if not terminal.

Terminal: `dismissed`, `resolved`, `aged`.
Add to Library is orthogonal and never changes `entryState`.

**Carryover budget.** A non-Essential entry may be carried at most 3 times, then `aged`. Tunable.

**Essential guarantee and its relief valve.** An entry whose ContentPiece is substantive primary material from an Essential Stream is never `aged`. To keep the daily Edition finite, an unresolved Essential entry that has been carried more than 14 times moves to `section = "essentialBacklog"`, which renders as a separate reachable group and does not count against `Edition.targetSize`. It remains unresolved and visible until Jon dismisses or defers it. Nothing silently ages away; the daily package stays finite. Both numbers are tunable.

`Edition.targetSize` defaults to 20 and is the objective the judgment pass optimizes against.

---

## 4. Vocabulary correction: Dismiss, not Clear

Edition's resolution action is **Dismiss**. Today's Gmail attention action remains **Clear**. They were previously both called Clear, which forced four documents to warn that the two must be implementation-distinct. The warning is now unnecessary and those paragraphs are removed.

---

## 5. Invariants

Enforced by tests, not by prose.

1. `Artifact.id ≠ ContentPiece.id`. Multiple Artifacts may reference one ContentPiece.
2. ContentPiece identity is derived and stable across devices and across edits to title, summary, or subjects.
3. Removing Later or Library membership never deletes a ContentPiece, its Artifacts, its provenance, or a PendingFind referencing it.
4. `EditionEntry` never duplicates a ContentPiece within one Edition.
5. An Essential substantive primary entry never reaches `aged`.
6. `LocalAvailability.mode = pinned` is never evicted by Cockpit.
7. `mode = until` expiry removes only `payloadRef`; the ContentPiece, memberships, provenance, summary, and normalizedText survive.
8. No Gmail Archive or Trash is applied before every promised ContentPiece, PendingFind, and derived result for that message has committed.
9. A `PersonalKnowledgeClaim` is only written by a deterministic operation carrying explicit user authority. Model output alone never writes one.
10. Superseding a claim sets `status = superseded` and `supersededByID`; it never deletes.
11. `normalizedText` is populated for every ContentPiece with textual substance at ingest. See §6.
12. Library contains ContentPieces only. No table joins a domain thing into Library.

---

## 6. Normalized text is stored for everything textual

At ingest, every ContentPiece with textual substance gets `normalizedText` populated and indexed. Not conditional.

The earlier "retain normalized readable substance when it materially improves durability, search, or offline use" was always true for anything searchable, and licensed inconsistent implementation. A long article is roughly 30KB; the storage argument does not survive arithmetic.

Sync rule: `normalizedText` syncs through CloudKit for Library members only. Non-Library pieces keep it device-locally.

The promise-based custody model is unchanged and still governs **payloads** — media, PDFs, uploaded sole-source files, exact layout fidelity. Text is not a payload.

---

## 7. Persistence discipline

Before adding a table, type, or protocol: name the stable identity, lifecycle, relationship, or query requirement that demands it.

Still explicitly not modeled: universal `Item`/`Thing`, canonical Restaurant/Product/Wine/Recipe/Person, Opportunity, Signal, Observation, universal evidence graph, generic rules engine, universal Subject graph, family-wide Handoff object.

`EditionEntry.rationale` is the sanctioned place for why-surfaced explanation. When a rationale
names an explicit Personal Knowledge claim, `matchedPersonalKnowledgeClaimID` preserves its exact
current-claim reference so the Reader can route correction to that understanding. It is not the
beginning of an evidence graph and gains no query surface beyond its own Edition.
