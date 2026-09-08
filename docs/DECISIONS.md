# Cockpit Decision Ledger

**Status:** Normative  
**Date:** 2026-09-08

This ledger records decisions that cut across multiple product documents. It exists to prevent design drift and to distinguish settled architecture from questions that should deliberately wait for implementation evidence.

If another live document conflicts with this ledger, this ledger wins until the conflict is explicitly resolved and both are updated.

---

## 1. Product shell and vocabulary — RESOLVED

The current shell is:

```text
Today
Edition
Later
Library
Settings
```

`Edition` is the user-facing rolling newspaper. `Content` remains a broader domain/system word and must not be used as the destination name.

`Following` is the user-facing management label. `Stream` is the precise domain noun. Following lives under Settings and may also be reached contextually from the Reader.

Use `Today` as the product noun. `Daily` may be used adjectivally but is not a competing destination name.

The old broad user-facing `Keep` action is superseded by explicit intent:

- **Save for Later**
- **Add to Library**
- **Offline until [date]**
- **Keep Offline**

The architecture phrase “keep on this device is a promise” remains valid because it refers specifically to local availability.

---

## 2. Content spine — RESOLVED

### Artifact

An **Artifact** is concrete source material Cockpit received, fetched, or imported. It carries provenance, provider identity where applicable, source-access information, and any custody-relevant payload/reference.

### ContentPiece

A **ContentPiece** is Cockpit's stable representation of a distinct piece of published or received material.

Examples: article, newsletter issue, post, video, podcast episode, report, PDF.

The UI should normally use the concrete noun rather than `ContentPiece`.

### Identity and membership

Artifact identity and ContentPiece identity are distinct.

Multiple Artifacts may support the same ContentPiece. One Artifact may eventually yield more than one meaningful ContentPiece or Find. V1 should only build relationship machinery required by real cases.

Edition participation, Later membership, and Library membership attach to the same ContentPiece rather than creating duplicate copies.

### Deduplication

Deduplication is conservative and provenance-preserving. Deterministic strong identity such as canonical URL or provider stable ID should be used when available. Cockpit should tolerate occasional duplicates rather than perform uncertain destructive merges.

### Explicit non-models

Do not create a universal `Item`, `Thing`, or cross-domain entity solely to unify articles, restaurants, wines, products, recipes, events, and other unrelated concepts.

---

## 3. Library and Finds — RESOLVED

**Library contains ContentPieces only.**

It is not a general personal database of restaurants, wines, products, books, people, recipes, places, or other domain things.

A **Find** is something valuable Cockpit identifies within or because of a ContentPiece: a restaurant, recipe, wine, product recommendation, event, book, hotel, and similar opportunity.

When an appropriate Jon Universe specialist app exists, Cockpit hands the Find to that app's admission boundary. The receiver owns canonical identity, domain validation, deduplication, and canonical persistence.

Cockpit may retain a lightweight **Pending Find** when no receiving app exists or the user has not yet chosen disposition. A Pending Find preserves enough faithful descriptive context, provenance, evidence, interpretation, and lightweight structured hints to remain useful later. It must not grow into the missing specialist app.

Examples of legitimate orphan Finds include pantry products, wines, travel clothing, gear, or other product recommendations before a future Shopping / Consumption / Cellar-style app has earned its shape.

Accumulated orphan Finds are evidence about what future Jon Universe app may be needed. Do not predict that app's ontology in advance.

A retained Find may outlive Library membership of the originating ContentPiece; sufficient provenance/evidence must remain to keep the Find intelligible.

`Find` is initially a product concept, not a mandatory universal protocol/class hierarchy. Persist it when an independent lifecycle or handoff requires durable identity.

---

## 4. Streams and Following — RESOLVED

An **Interest Area** describes why Cockpit follows recurring material.

A **Stream** is the recurring flow Cockpit intentionally follows.

A Stream has one primary Interest Area for management/editorial intent. Individual ContentPieces or Finds may be relevant elsewhere.

Publisher/Creator is secondary identity. Transport is technical delivery. Source is reserved for upstream material/provenance/actions.

One global **Add Stream** operation starts from something the user already knows they want to follow. V1 includes generic RSS/Atom autodiscovery from a human-facing URL and may include narrow deterministic provider resolvers.

This is transport discovery for known intent, not autonomous discovery of what the user should follow.

**Essential** is a Stream-level posture. Substantive primary material from an Essential Stream cannot silently age away from Edition.

Stream Handling is editorial intent. Gmail/source disposition is a separate concern.

Optional automatic Library admission is explicit, prospective, and independent of Edition admission. No automatic backfill in V1.

---

## 5. Edition, Later, and Library — RESOLVED

### Edition

Edition is a finite rolling personalized newspaper, not an infinite feed and not an accumulating unread queue.

Opening a ContentPiece means **Seen**, not Clear.

Edition state is a relationship to a ContentPiece. V1 must support admission, Seen, Clear, natural aging/carryover, Essential protection, and resolution through Save for Later. Exact persistence windows and visual treatment should be learned from use.

### Later

Later means explicit deferred attention.

Nothing enters Later automatically. Nothing silently expires. V1 should keep Later simple and should not build cleanup machinery before a real backlog exists.

### Library

Library means durable retained reference to a ContentPiece. Edition admission and Library admission are independent.

Library should begin with metadata, provenance, useful derived understanding, and ordinary text search. Subjects may enrich retrieval. Vector search, folders/collections, advanced facets, and other retrieval machinery must be earned by corpus evidence.

---

## 6. Custody and offline availability — RESOLVED

Custody is promise-based, not universally payload-based.

Cockpit distinguishes:

1. **identity** — what the ContentPiece/source is;
2. **understanding** — metadata, provenance, summary/enrichment, and other lightweight semantic representation;
3. **reacquisition** — how the substantive source can be fetched again;
4. **payload custody** — whether Cockpit itself must preserve substantive bytes/text.

Reliable upstream repositories can legitimately remain authoritative. Gmail Archive is a sufficiently reliable long-term repository for ordinary Gmail-backed material; loss of account/provider access is reported as degradation rather than insured against by duplicating everything.

Uploaded sole-source material creates a strong Cockpit custody obligation. If Cockpit accepts an uploaded file into Library and cannot rely on a durable external original, it must preserve the payload.

External hosted media such as YouTube or podcasts does not imply permanent duplication of video/audio payloads.

For web/RSS/text material, preserve normalized readable substance when it materially improves durability, search, or offline behavior; do not make duplicate permanent payload storage a universal requirement when a reliable source already holds the substance.

### Device availability

Device-local availability is independent of Edition, Later, Library, and source custody.

Three conceptual local states are sufficient:

- automatic cache — Cockpit may evict;
- **Offline until [date]** — explicit temporary promise with visible expiry; a 30-day default is a reasonable V1 starting point;
- **Keep Offline** — indefinite user-controlled promise; Cockpit must not silently evict it.

Expiration removes only the redundant local payload, never the ContentPiece, its memberships, provenance, or semantic understanding.

Trip-aware bulk preparation and Stream-wide offline rules are future affordances, not V1 architecture requirements.

---

## 7. Gmail authority and source disposition — RESOLVED

Cockpit owns its own attention state. Gmail read/unread remains separate provider state.

`Clear` is a Cockpit attention action. The upstream Gmail disposition is resolved independently as:

- **Leave in Inbox**
- **Archive**
- **Trash**

These must be implementation-distinct from Edition Clear even if the UI word is shared contextually.

Valuable editorial source material commonly Archives. Disposable operational/promotional mail may Trash. Cockpit does not need permanent `Delete Forever` authority in V1; Gmail's Trash lifecycle is sufficient.

Stream Handling and Gmail Source Disposition are separate concepts.

Non-editorial email such as Amazon shipping notices does not need to become a Stream merely to have a disposition policy.

Automatic Archive/Trash may occur only under an explicit user-established policy. AI may classify messages to apply an authorized policy and may later propose new policies, but it does not silently acquire destructive authority from observed behavior.

External mutation happens only after Cockpit successfully commits any ContentPiece, Find, or other result it promises to retain.

Recent dispositions should be inspectable and reversible for a bounded period where Gmail permits it.

New replies naturally re-enter if Gmail returns the thread/message to Inbox; Cockpit should not invent a permanent parallel thread-resolution state.

A generalized rules engine, learned auto-deletion, automatic unsubscribe, broad reply/composition, and permanent deletion are out of V1.

---

## 8. Personal Knowledge — RESOLVED

Durable Personal Knowledge comes from **explicit human intent**, not passive clickstream inference.

V1 coarse kinds are:

- **Fact**
- **Taste**
- **Interest**

Valid durable inputs include direct teaching, correction, explicit explanation of why a ContentPiece matters, and confirmation of a hypothesis Cockpit asks about.

Behavior may be used transiently for ranking or to produce a question such as “Is this something you want me to know?” It must not silently become durable Personal Knowledge.

Ordinary annotation does not automatically mean “learn this about me”; the user's teaching intent must be clear.

The LLM may summarize, deduplicate, consolidate, roll up, and reorganize explicit knowledge without routine approval, provided semantic fidelity and provenance are preserved and no materially new substantive claim is invented.

New substantive inferences require confirmation.

Correction has strong authority. Old understandings may be superseded rather than erased. Scope/context is more important than artificial numeric confidence.

Personal Knowledge should retain enough provenance to answer why an understanding exists without becoming a giant behavioral evidence warehouse.

**Current Context is separate from Personal Knowledge.**

**Knowledge does not grant agency.** Provider mutation, purchases, subscriptions, notifications, and other actions require separate policy/mandate.

Personal Knowledge should not require daily grooming. Teaching/correction should happen mainly in context.

---

## 9. Jon Brain bulk teaching — RESOLVED FOR V1

V1 includes a natural-language bulk Personal Knowledge ingestion surface.

The initial ChatGPT workflow is a standing personal convention: when Jon invokes **“Jon Brain”**, ChatGPT produces copyable bullets labeled `[Fact]`, `[Taste]`, or `[Interest]`, synthesized from explicit durable understanding rather than weak behavior.

Jon manually pastes those bullets into Cockpit. Cockpit compares them semantically with existing Personal Knowledge, automatically handles clerical deduplication/consolidation, and surfaces meaningful additions, refinements, or contradictions for review.

This is intentionally human-mediated and natural-language based. V1 does not require a ChatGPT account integration, memory API, two-way sync, or versioned JSON interchange format.

The Cockpit feature should remain generic enough to accept equivalent synthesized natural-language knowledge from another AI or document.

---

## 10. App-family boundary — RESOLVED

Specialist apps may publish small read-only **Current Context projections** that Cockpit can consume for relevance.

Handoff is the opposite direction: Cockpit sends faithful material, provenance, interpretation, and user intent to a receiver-owned admission boundary. The receiving app owns canonical domain state.

Do not build a universal family queue, family ontology, or shared entity graph.

Personal Knowledge may eventually become family-owned/shared, but Cockpit should implement the first real version app-locally behind a movable seam. Extract only after a second real consumer proves the shared shape.

---

## 11. jon-platform boundary — RESOLVED

Cockpit consumes proven domain-neutral infrastructure from `jon-platform` and keeps Cockpit product/domain semantics in Cockpit.

Adopt SQLiteData conventions, CloudKit/CloudSyncKit, `LLMClientKit`, Point-Free Dependencies, and the platform semantic-fidelity/actionable-AI doctrines.

Adopt `WebExtractorKit` only when a concrete web workflow earns it.

Do not adopt current `LLMHandoffKit` session/persistence semantics; they remain Galavant-shaped.

Do not create `ContentStreamKit`, `PersonalKnowledgeKit`, `FamilyContextKit`, `JonLibraryKit`, or another Cockpit-derived shared package on first use.

> **First use establishes a requirement. Repeated use may establish an abstraction.**

---

## 12. V1 cutline — RESOLVED

V1 proves the complete loop rather than maturing every subsystem equally:

> follow → understand → surface → defer/retain → learn explicitly → hand off

Required V1 capabilities are defined in `V1-SCOPE-AND-SEQUENCING.md`.

The shell is complete, but Edition and Today may be substantially deeper than Later, Library, Settings, and Pending Finds.

---

# Deliberately deferred decisions

These are **not unresolved blockers**. They should wait for implementation/use evidence.

## Edition

- exact Seen treatment;
- exact aging/carryover windows;
- section ordering and card density;
- midday admission volume;
- Essential review tooling;
- Reader geometry details.

## Later

- default sort;
- filters;
- cleanup thresholds and cleanup UI;
- bulk maintenance.

## Library

- vector similarity versus FTS/Subjects;
- folders/collections;
- recent searches;
- sophisticated facets;
- Stream/Publisher grouping prominence;
- always-download Stream rules.

## Following

- publisher catalog/browser;
- autonomous recommendations for what to follow;
- subscription cleanup;
- automatic newsletter discovery from the mailbox;
- rich pause/health UX beyond demonstrated need.

## Personal Knowledge

- monthly review;
- rich Notices;
- emerging/sustained/fading trajectories;
- generalized contradiction analysis;
- numeric confidence systems;
- passive behavior warehouse;
- shared PersonalKnowledgeKit.

## App family

- Family Context Store mechanics;
- shared envelope/queue infrastructure;
- App Group acceleration;
- notifications versus snapshots;
- generalized handoff kit.

## Offline/custody

- trip-aware temporary downloads;
- bulk Edition/Later travel preparation;
- Stream-wide offline policy;
- exact CloudKit Asset/file-storage implementation.

---

# Build it and learn

The following questions should be answered through vertical slices and daily use, not another abstract design round:

- whether Artifact ↔ ContentPiece multiplicity needs rich persistence beyond observed cases;
- which deterministic deduplication rules are actually required;
- exact Edition state representation;
- whether normalized source text deserves durable preservation for particular source classes;
- whether Subjects + full-text search are sufficient before embeddings;
- how quickly Later becomes a backlog and whether cleanup is needed at all;
- how often orphan Finds occur and what future specialist app their population suggests;
- what Gmail message/thread semantics require after a read-only integration spike;
- how much Personal Knowledge structure is actually necessary once it changes ranking/explanation;
- which cross-app handoff fields survive contact with the first real receiver.

When implementation evidence contradicts a ratified decision, stop, record the evidence, and deliberately amend this ledger rather than silently drifting the model.
