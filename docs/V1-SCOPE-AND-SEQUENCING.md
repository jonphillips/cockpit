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
- Dismiss;
- natural aging/carryover;
- Essential backlog relief valve;
- Essential protection from silent aging;
- Save for Later;
- Add to Library;
- contextual Stream Handling access;
- judgment per `docs/JUDGMENT-CONTRACT.md`, with the evaluation harness standing up in the same phase;
- enough ranking/judgment to demonstrate Personal Knowledge can change relevance.

Exact persistence windows, card density, section ordering, and midday behavior should be tuned through use. The Edition states and transitions themselves are settled, not tuned.

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

- extraction/recognition of useful domain opportunities from a ContentPiece, from Phase 1, sharing the judgment call;
- lightweight Pending Finds when no owner exists, from Phase 1;
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

The concrete schema is in `docs/IMPLEMENTATION-CONTRACT.md` §2. It is deliberately minimal and is expected to change at the gates.

Foundational Cockpit-local concepts:

- `InterestArea`
- `Stream`
- `Artifact`
- `ContentPiece` — identity derived, not random (ADR-0001 D3)
- `Edition` and `EditionEntry` — materialized, not a live query (ADR-0001 D5)
- Later membership
- Library membership
- `LocalAvailability`
- `PersonalKnowledgeClaim`
- `PendingFind`

Exact names in code are implementation decisions, but the domain distinctions are normative.

Note the two corrections against earlier drafts of this plan. Edition is now a real entity rather than per-ContentPiece state, because the product promises a stable daily package and an explanation for why a piece appeared. And `PendingFind` is in the first slice rather than deferred, because Find extraction shares the judgment call and costs almost nothing, while the orphan-Find population is the evidence that tells the Jon Universe what app to build next — evidence that only accumulates with time.

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

### Phase 0 — implementation contract, ADR-0001, and the Gmail auth spike

Before feature work hardens persistence:

1. Write `docs/IMPLEMENTATION-CONTRACT.md` — schema, Edition state machine, invariants, and definitions of `Subjects`, `substantive primary material`, `qualifying`, and `judgment`. **Done.**
2. Write `docs/ADR-0001-PERSISTENCE-AND-EXECUTION.md` — execution model, ingest ownership, derived identity, normalized-text rule, CloudKit posture. **Done.**
3. Write `docs/JUDGMENT-CONTRACT.md` and freeze the evaluation fixture set. **Contract done; fixtures pending real Streams.**
4. **Run the Gmail authorization spike** (ADR-0001 D7). One day. Create the OAuth client for `gmail.modify`, publish unverified under the personal-use exemption, and obtain a refresh token. **Done 2026-09-11.** Token longevity needs no dedicated check: the seven-day expiry belongs to Testing status, and a published client's refresh tokens do not expire on a timer. The first slice that reads mail confirms it in passing. If it does fail, evaluate IMAP as the transport before Today is designed around the Gmail API.

Do not attempt the final schema for every future source. Do settle identity, execution, and provider viability, because those are the decisions that are expensive to reverse.

The Gmail spike sits in Phase 0 rather than Phase 3 for one reason: failing it in Phase 3 wastes a phase.

### Phase 1 — RSS/Atom → Personal Knowledge → judgment → Edition → Later/Library/Finds → Offline

Build the complete product spine, including the two things that make Cockpit distinctive:

```text
known human URL
→ feed autodiscovery
→ Stream
→ ingest Artifact
→ ContentPiece (normalized text stored)
→ Personal Knowledge: direct teaching + Jon Brain bulk import
→ judgment (per `docs/JUDGMENT-CONTRACT.md`)
→ Edition + EditionEntries, composed once daily
→ Reader
→ Seen / Dismiss / carryover / Essential
→ Later / Library / Pending Finds
→ Offline until / Keep Offline
```

This phase should use several real Streams, not only fixtures.

**Personal Knowledge moves into Phase 1** from Phase 2. It is a table, a paste box, and a reconciliation pass, and it has no dependency on Edition. Building it second means judgment gets built and tuned against no preferences and then rebuilt against them. Import the Jon Brain dump before the first Edition is ever composed.

**Pending Find extraction moves into Phase 1** from Phase 6. Extraction shares the judgment call, so the marginal cost is near zero. Persist PendingFinds and give them a minimal list. Handoff to a specialist app stays in Phase 6 — this is extraction only, with no receiver, no admission boundary, and no cross-app work.

Stand up the evaluation harness in this phase, not later. Once several real Streams are running, freeze 200 real ContentPieces, label them, and get the first agreement number. It is what makes every subsequent prompt and model change measurable rather than a matter of taste.

#### Architecture Gate 1

Stop and inspect:

- Did Artifact and ContentPiece boundaries hold?
- Did derived identity actually converge across devices and across Streams?
- What real deduplication cases appeared?
- Did any Artifact yield multiple meaningful outputs?
- Which Edition states and transitions were actually exercised, and did the carryover budget and Essential backlog threshold feel right?
- Is Subjects + text search enough for early Library retrieval?
- Does Stream/Handling/Essential feel correct?
- **What did composition actually cost, in dollars and in seconds?** This is the evidence that reopens the on-device execution decision in ADR-0001 D1. If composition is a minute-long foreground wait every morning, the server question is live again.
- **What is the judgment agreement rate, and the false-quiet rate on Essential material?**
- Are Pending Finds accumulating, and what shape are the orphans?

Change the model now if reality disagrees.

### Phase 2 — Personal Knowledge deepens and demonstrably changes judgment

Basic teaching and Jon Brain import land in Phase 1. Phase 2 adds the parts that need a running Edition to be worth building:

- correction and supersession;
- “why this matters” teaching from a ContentPiece in the Reader;
- LLM consolidation, deduplication, and rollup of explicit claims;
- confirmation flow for a Cockpit hypothesis;
- one visible, correctable relevance/explanation change driven by PK.

#### Architecture Gate 2

Ask:

- Are Fact/Taste/Interest enough?
- What scope data was genuinely required?
- Is provenance sufficient and useful?
- Is the LLM overgeneralizing?
- Does bulk import reconcile cleanly without schema inflation?
- How many claims exist, and is the full-projection threshold in `docs/JUDGMENT-CONTRACT.md` §2 still holding?
- Did the eval agreement rate move when PK grew? If it did not, PK is decorative and something is wrong.

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

### Phase 6 — First specialist handoff

Find extraction and Pending Finds already exist from Phase 1. This phase adds the receiver.

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
