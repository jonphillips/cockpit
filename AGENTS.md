# AGENTS.md

This file is normative guidance for implementation and architecture agents working in `jonphillips/Cockpit`.

## Read first

Every session, read:

1. `docs/IMPLEMENTATION-CONTRACT.md` — schema, Edition state machine, invariants, definitions
2. `docs/V1-SCOPE-AND-SEQUENCING.md` — what phase we are in and what its gate asks

Then, only as the work requires:

3. `docs/ADR-0001-PERSISTENCE-AND-EXECUTION.md` when touching persistence, identity, sync, or ingest
4. `docs/JUDGMENT-CONTRACT.md` when touching relevance, ranking, extraction, or any model call
5. `docs/DECISIONS.md` when a cross-cutting product decision appears to be in question
6. the focused essay in `docs/` for the area being changed
7. `ARCHITECTURE.md` and `PLATFORM-ADOPTION.md` when shared infrastructure or platform boundaries are involved

Do not read the whole corpus before every task. It is roughly 25,000 words and reading it wholesale costs more context than the work. The contract exists so that it does not have to be read.

Documents under `docs/archive/` are historical evidence only. They must not be used to resurrect superseded product language or architecture.

## Current shell

The user-facing shell is:

```text
Today
Edition
Later
Library
Settings
```

Do not reintroduce `Content` as the destination name. `Content` is a broader subsystem/domain term.

Following lives under Settings. `Following` is the friendly management label; `Stream` is the domain noun.

## Core domain boundaries

### Artifact

Concrete source material received, fetched, or imported, with provenance/provider identity where applicable.

### ContentPiece

Stable representation of distinct published/received material such as an article, newsletter issue, video, podcast episode, report, or PDF.

Edition, Later, and Library operate on the same ContentPiece identity.

ContentPiece identity is derived, not random — UUIDv5 over a canonical identity string, so two devices ingesting the same item converge on one row. See `docs/ADR-0001-PERSISTENCE-AND-EXECUTION.md` D3.

Do not introduce a universal `Item`/`Thing` to unify ContentPieces with restaurants, products, wines, recipes, events, people, or other domain concepts.

### Find

A valuable thing discovered within/because of a ContentPiece. Finds are candidates for specialist Jon Universe apps. Library contains ContentPieces only.

A Pending Find may preserve enough descriptive/provenance/evidence data to survive before a specialist app exists. Do not add domain-rich product/place/wine/etc. modeling to Cockpit merely to enrich Pending Finds.

## Product laws

- Today is orientation/attention.
- Edition is a finite rolling personalized newspaper, not an infinite feed or unread backlog. It is a materialized entity composed once per day, not a live query.
- Edition's resolution action is `Dismiss`. Today's Gmail attention action is `Clear`. They are different words for different operations.
- Later is explicit deferred attention; nothing enters automatically and nothing silently expires.
- Library is durable retained ContentPieces, not a universal knowledge base.
- Essential is a Stream-level promise that substantive primary material cannot silently age away.
- Stream Handling is editorial intent; upstream source disposition is separate.
- Personal Knowledge is explicit durable understanding, not clickstream inference.
- Personal Knowledge does not grant agency.
- Current Context is separate from Personal Knowledge.
- Reliable upstream repositories may remain authoritative; uploaded sole-source material creates strong Cockpit custody.
- Explicit offline availability is a user promise, not cache policy.

## AI boundary

Use `LLMClientKit` for model access.

> **AI may interpret, propose, summarize, classify, reconcile, or extract. Deterministic application code performs canonical writes and provider mutations under established user authority.**

Do not let model output silently become durable Personal Knowledge, provider policy, source deletion authority, or receiver-owned canonical state.

For Personal Knowledge:

- durable claims come from direct teaching, correction, explicit “why this matters” input, or user-confirmed hypotheses;
- passive behavior may trigger a question but may not silently become durable knowledge;
- LLM consolidation/deduplication of explicit claims is allowed when semantically faithful;
- materially new inference requires confirmation.

## Gmail boundary

Cockpit attention state is not Gmail read/unread state.

Provider disposition is explicitly one of the supported actions such as Leave in Inbox, Archive, or Trash and is independent of Stream Handling.

Never perform Archive/Trash before any promised retained ContentPiece/Find/result has been safely committed.

Do not add permanent Delete Forever, broad reply/composition, silent learned deletion, or a generalized rules engine to V1 without an explicit product decision.

## Custody and offline

Do not collapse custody, Library membership, local cache, and offline availability into one `isSaved`/`isDownloaded` flag.

Conceptually distinguish:

- reliable upstream reacquisition;
- durable Cockpit understanding;
- Cockpit-owned payload custody;
- device-local automatic cache;
- explicit temporary offline availability;
- explicit indefinite offline availability.

`Offline until [date]` may expire according to its visible promise. `Keep Offline` may not be silently evicted by Cockpit.

## Persistence discipline

Use SQLiteData and the jon-platform local-first architecture.

Before adding a table/type/protocol, ask what stable identity, lifecycle, relationship, or query requirement has been demonstrated.

Do not create canonical persistence systems merely because a noun appears in design prose.

In particular, do not bootstrap:

- universal Item/Thing;
- generic Source hierarchy where Stream/Artifact/provider concepts are sufficient;
- universal Subject/entity graph;
- Opportunity/Signal/Notice model hierarchy;
- generic rules engine;
- family-wide Handoff queue;
- canonical Restaurant/Product/Wine/Recipe models in Cockpit.

Use conservative deterministic deduplication first. Preserve provenance. Prefer an occasional duplicate to an uncertain destructive merge.

## jon-platform rule

Cockpit consumes proven domain-neutral infrastructure and owns Cockpit domain semantics locally.

> **First use establishes a requirement. Repeated use may establish an abstraction.**

Do not create or extract `ContentStreamKit`, `PersonalKnowledgeKit`, `FamilyContextKit`, `JonLibraryKit`, or another shared package based on a single Cockpit use.

Before proposing a jon-platform change:

1. inspect the relevant jon-platform package/docs/seam ledger;
2. identify existing Galavant and Yes Chef consumers;
3. determine whether Cockpit is actually blocked;
4. prefer an app-local implementation until repeated evidence proves a neutral seam;
5. preserve/migrate existing consumers deliberately.

`LLMHandoffKit` is not an approved full Cockpit dependency in its current Galavant-shaped form.

## V1 sequencing

Follow `docs/V1-SCOPE-AND-SEQUENCING.md` rather than building destination-by-destination.

The first major vertical slice is:

```text
known URL
→ RSS/Atom autodiscovery
→ Stream
→ Artifact
→ ContentPiece
→ Personal Knowledge + Jon Brain import
→ judgment
→ Edition
→ Reader
→ Later / Library / Pending Finds
→ Offline
```

Stop at each architecture gate and inspect what reality taught before broadening the model.

Do not proceed from Gmail read-only to provider mutation until the Gmail identity/retry/undo/disposition contract has been written from actual provider behavior.

## Testing expectations

Make deterministic business behavior cheap to test. Prioritize:

- identity and deduplication;
- database transactions/lifecycle;
- Edition membership/state transitions;
- Essential behavior;
- Later/Library invariants;
- custody and local-availability transitions;
- semantic-fidelity boundaries;
- model structured-output decoding;
- Personal Knowledge reconciliation/supersession;
- provider disposition barriers and failure recovery;
- cross-app handoff boundaries;
- migration behavior.

External frameworks/services/models should sit behind injectable clients.

## Documentation rule

When implementation evidence changes a ratified decision, do not silently drift code away from docs.

1. record the evidence;
2. amend `docs/DECISIONS.md` deliberately;
3. update affected live docs in the same change;
4. leave archive material untouched.

Do not add another broad conceptual essay when the missing artifact is a focused ADR, implementation contract, or testable invariant.
