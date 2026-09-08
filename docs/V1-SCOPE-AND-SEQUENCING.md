# Cockpit V1 Scope and Sequencing

**Status:** Normative V1 plan  
**Date:** 2026-09-08

V1 should prove Cockpit's complete product loop without maturing every subsystem into a standalone product.

> **follow → understand → surface → defer/retain → learn explicitly → hand off**

The shell is `Today / Edition / Later / Library / Settings`. All five exist in V1, but they do not need equal depth.

---

## 1. V1 product cutline

### Following / Streams

V1 includes:

- Interest Areas;
- Streams;
- Following under Settings;
- one global Add Stream operation;
- paste a known human-facing URL;
- generic RSS/Atom autodiscovery;
- narrow deterministic provider resolvers where justified;
- proposed Publisher/Creator, primary Interest Area, and concise Handling;
- Essential posture;
- pause / stop following;
- basic abnormal health;
- email-delivered Streams once Gmail integration lands;
- optional prospective automatic Library admission after explicit Library works.

V1 does **not** require autonomous source recommendations, a publisher catalog, historical subscription cleanup, or automatic mailbox-wide newsletter discovery.

### Edition

V1 includes:

- finite morning-oriented personalized Edition;
- Reader;
- provenance/source context;
- Seen;
- Clear;
- natural aging/carryover;
- Essential protection from silent aging;
- Save for Later;
- Add to Library;
- contextual Stream Handling access;
- enough ranking/judgment to demonstrate Personal Knowledge can change relevance.

Exact persistence windows, card density, section ordering, and midday behavior should be tuned through use.

### Later

V1 includes:

- explicit Save for Later only;
- no silent expiry;
- simple browse/open;
- remove from Later;
- Add to Library;
- offline controls.

No cleanup assistant, backlog analytics, folders, or elaborate facets until real backlog evidence exists.

### Library

V1 includes:

- ContentPieces only;
- explicit Add to Library;
- one proven Stream-level prospective auto-Library policy after manual flow works;
- basic metadata, provenance, summary/enrichment;
- basic Subjects when useful;
- ordinary text search;
- removal;
- offline controls;
- durable uploaded-payload custody.

No universal entities, folders/collections, vector infrastructure by default, or domain-specific restaurant/wine/product records.

### Today / Gmail

V1 includes:

- current Gmail Inbox intelligence;
- personal/consequential attention;
- summaries;
- a small Worth Seeing surface;
- inspectable quiet handling;
- Gmail provider dispositions `Leave`, `Archive`, and `Trash`;
- explicit Stream-level source disposition where relevant;
- a very small number of explicit non-Stream policies where useful;
- mutation only after retained results are safely committed;
- bounded recent dispositions / Undo where Gmail permits it.

V1 does **not** include a generic rules engine, silent learned deletion, automatic unsubscribe, broad reply/composition, or permanent Delete Forever.

### Personal Knowledge

V1 includes:

- Fact / Taste / Interest;
- direct teaching;
- explicit teaching from a ContentPiece, including why it mattered;
- correction/supersession;
- confirmation of a Cockpit hypothesis before it becomes durable;
- provenance;
- LLM consolidation, deduplication, and rollup of explicit knowledge;
- basic inspection/correction under Settings / You;
- **Jon Brain** natural-language bulk import;
- at least one demonstrable ranking/explanation change caused by Personal Knowledge.

V1 does not derive durable Personal Knowledge from passive clickstream behavior.

### Finds and handoff

V1 includes:

- extraction/recognition of useful domain opportunities from a ContentPiece;
- lightweight Pending Finds when no owner exists;
- enough descriptive/provenance/evidence data to keep an orphan Find useful;
- exactly one complete real handoff to a specialist Jon Universe app;
- receiver-owned identity, validation, deduplication, and canonical persistence.

No universal Find ontology, shared family queue, or generic handoff framework is required.

### Custody and offline

V1 includes:

- reliable upstream sources may remain authoritative;
- lightweight durable Cockpit understanding separate from source payload;
- durable preservation of uploaded sole-source payloads;
- device-local automatic cache versus explicit offline state;
- **Offline until [date]** with visible expiry, initially likely 30 days;
- **Keep Offline** as an indefinite promise.

Trip-aware preparation, bulk travel download, and Stream-wide offline rules wait.

---

## 2. Initial persistence spine

Do not design the entire V1 schema before implementation. The first slice needs only the minimum concepts required to support observed behavior.

Likely foundational Cockpit-local concepts:

- `InterestArea`
- `Stream`
- `Artifact`
- `ContentPiece`
- Edition participation/state
- Later membership
- Library membership
- `PersonalKnowledgeClaim`
- durable `Find` only once independent lifecycle/handoff requires it

Exact names in code are implementation decisions, but the domain distinctions are normative.

### Explicit non-models at bootstrap

Do not create first-class persistence systems merely because these nouns appear in product prose:

- universal Item / Thing;
- canonical Restaurant / Product / Wine / Recipe / Person;
- Opportunity;
- Signal;
- Notice;
- Observation;
- universal Evidence graph;
- generic Disposition Rule engine;
- universal Subject/entity graph;
- family-wide Handoff object.

A concept earns a durable model when real behavior needs stable identity, lifecycle, relationships, or queryability.

---

## 3. Implementation sequence

### Phase 0 — minimum architecture ADR

Before feature work hardens persistence, record only:

- Artifact versus ContentPiece identity;
- provenance expectations;
- Edition/Later/Library membership invariants;
- lifecycle/deletion constraints;
- uploaded-payload custody promise;
- initial Personal Knowledge claim shape.

Do not attempt the final schema for every future source.

### Phase 1 — RSS/Atom → Edition → Later/Library → Offline

Build the safest complete product spine first:

```text
known human URL
→ feed autodiscovery
→ Stream
→ ingest Artifact
→ ContentPiece
→ basic judgment
→ Edition
→ Reader
→ Seen / Clear
→ Later / Library
→ Offline until / Keep Offline
```

This phase should use several real Streams, not only fixtures.

#### Architecture Gate 1

Stop and inspect:

- Did Artifact and ContentPiece boundaries hold?
- What real deduplication cases appeared?
- Did any Artifact yield multiple meaningful outputs?
- What Edition state is actually required?
- What source text must be retained?
- Is Subjects + text search enough for early Library retrieval?
- Does Stream/Handling/Essential feel correct?

Change the model now if reality disagrees.

### Phase 2 — Personal Knowledge changes judgment

Add:

- direct teaching;
- correction;
- “why this matters” teaching from a ContentPiece;
- Jon Brain paste/import;
- synthesis/reconciliation against existing claims;
- one visible relevance/explanation change driven by PK.

#### Architecture Gate 2

Ask:

- Are Fact/Taste/Interest enough?
- What scope data was genuinely required?
- Is provenance sufficient and useful?
- Is the LLM overgeneralizing?
- Does bulk import reconcile cleanly without schema inflation?

Do not add salience/confidence/trajectory machinery without evidence.

### Phase 3 — Gmail read-only Today

Integrate the current Inbox without provider mutation first:

```text
Gmail Inbox
→ provider Artifact normalization
→ analysis
→ Today / Worth Seeing / quiet presentation
→ Reader
```

Learn actual message/thread/account semantics before finalizing the Gmail contract.

#### Architecture Gate 3 — write Gmail integration ADR

From real provider behavior, settle:

- message versus thread identity/actions;
- account identity and multi-account behavior if required;
- refresh/pagination/delta strategy;
- provider IDs retained;
- re-entry on new replies;
- partial failures/retries;
- undo capabilities;
- what must be committed before mutation;
- relationship from email Artifact to email-delivered ContentPiece.

Only after this gate should source mutation become enabled.

### Phase 4 — Gmail dispositions

Enable deterministic:

- Leave in Inbox;
- Archive;
- Trash.

Start with explicit per-action/known-policy behavior. Add only the smallest explicit recurring policies necessary to prove the authority model.

Implement the disposition barrier and bounded recent dispositions/Undo.

### Phase 5 — email-delivered Stream

Join the two halves:

```text
Gmail Artifact
→ recurring Stream identity
→ ContentPiece
→ Stream Handling / Essential
→ Edition
→ source disposition
→ Later / Library
```

This is a critical architecture test because it proves Transport, Artifact, ContentPiece, Stream Handling, source disposition, and Edition state are genuinely separate.

#### Architecture Gate 4 — major model review

Stop before Finds/handoffs. If the model is fighting actual email + RSS behavior, fix it while Cockpit is still pre-production.

### Phase 6 — Finds and first specialist handoff

Prove two outcomes:

```text
ContentPiece
→ Find with known owner
→ one receiver-owned admission boundary
```

and:

```text
ContentPiece
→ orphan product/wine/etc. Find
→ Pending
```

The first receiver should be whichever of Galavant or Yes Chef exposes the cleanest real admission boundary at implementation time. Do not choose based on desire for symmetry.

#### Architecture Gate 5 — handoff review

Inspect what the real receiver needed, ignored, rejected, or reinterpreted. Only then consider a minimal stable cross-app contract. Do not extract shared infrastructure until a second real receiver provides evidence.

### Phase 7 — Stream automatic Library admission

After explicit Library behavior and custody are trustworthy, allow an explicit Stream policy to add qualifying future ContentPieces to Library automatically.

No automatic historical backfill in V1.

### Phase 8 — daily use and tuning

Use Cockpit rather than treating code-complete as product-complete.

Tune from evidence:

- Edition size and persistence;
- Essential friction;
- Later backlog behavior;
- Library retrieval needs;
- Gmail policy usefulness/trust;
- PK prompting frequency and overgeneralization;
- orphan Find population;
- offline behavior and expiration;
- iPad/iPhone composition.

---

## 4. Architecture gates, not feature gates

At each checkpoint ask:

> **Did implementation invalidate an assumption underneath the next slice?**

Do not require every current surface to be visually mature before proceeding. Do require foundational identity, custody, and mutation semantics to be trustworthy before building on them.

---

## 5. Platform posture during V1

Start all new Cockpit domain concepts inside Cockpit.

Use existing proven jon-platform infrastructure:

- SQLiteData conventions;
- CloudKit / CloudSyncKit;
- Point-Free Dependencies;
- `LLMClientKit`;
- semantic-fidelity and actionable-AI doctrines.

Add `WebExtractorKit` only when a concrete web-capture workflow requires it.

Do not begin V1 by building a generic ingestion framework, transport framework, AI pipeline, content repository package, handoff framework, rules engine, semantic graph, or vector store.

> **Cockpit nouns stay in Cockpit until repeated real use proves a domain-neutral abstraction.**

---

## 6. What can still be rough at V1

V1 may legitimately ship with:

- RSS/Atom and Gmail as the only meaningful transports;
- basic Subjects;
- no embeddings;
- no monthly PK review;
- no autonomous following discovery;
- no sophisticated Later cleanup;
- one handoff receiver;
- a minimal Pending Finds view;
- per-piece rather than bulk offline controls;
- imperfect Edition tuning;
- iPad-first depth with simpler iPhone presentation.

If the fundamental product loops are trustworthy and useful, Cockpit has reached V1.
