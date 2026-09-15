# Cockpit Decision Ledger

**Status:** Normative  
**Date:** 2026-09-08

This ledger records decisions that cut across multiple product documents. It exists to prevent design drift and to distinguish settled architecture from questions that should deliberately wait for implementation evidence.

If another live document conflicts with this ledger, this ledger wins until the conflict is explicitly resolved and both are updated.

The ledger states **intent**. `docs/IMPLEMENTATION-CONTRACT.md` states **shape**. They answer different questions; where both speak to the same thing, the ledger governs what the product means and the contract governs what the code looks like.

Sections 13 to 17 were added on review, and amend earlier sections where noted.

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

**Amended by §13.** ContentPiece identity is *derived* from that strong identity rather than randomly assigned, so the common cases converge on one row without any merge operation at all. Merging remains reserved for the genuinely uncertain cases, where the conservative posture above still applies.

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

Opening a ContentPiece means **Seen**, not resolved.

**Amended by §14 and §15.** Edition is a materialized entity composed once per day, not a live query over per-ContentPiece flags. Its resolution action is **Dismiss**, not Clear. V1 must support admission, Seen, Dismiss, carryover, Essential protection, the Essential backlog, and resolution through Save for Later. The states and legal transitions are settled in `docs/IMPLEMENTATION-CONTRACT.md` §3; only the durations, sizes, and visual treatment are learned from use.

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

### Normalized text

**Amended by §16.** `normalizedText` is stored for every ContentPiece with textual substance, unconditionally, and indexed for search. The earlier conditional phrasing was always true for anything searchable and only licensed inconsistent implementation.

Promise-based custody continues to govern **payloads** — media, PDFs, uploaded sole-source files, exact layout fidelity. Text is not a payload.

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

The UI word is no longer shared: Edition resolves with `Dismiss`. See §15.

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

## 13. Execution model and derived identity — RESOLVED

Ingestion, judgment, and enrichment run **on device**. No server, no hosted worker.

The morning Edition was considered as the product requirement that might justify one, and rejected: putting Gmail ingest on a third-party server converts a defensible personal-use exemption for restricted scopes into a plausible annual security-assessment obligation, which is a four-figure recurring cost for a single-user app.

Morning stability is achieved by *materializing* the Edition at first launch after the day boundary, not by composing it early. `BGProcessingTask` pre-warms opportunistically and is never relied upon.

One device is designated as ingester to avoid duplicated model cost. Correctness does not depend on it: `ContentPiece.id` is a UUIDv5 over a canonical identity string, so concurrent ingest on two devices converges on one row rather than producing duplicates.

Composition cost and latency are recorded and reviewed at Gate 1. Budget: under $1.00 and under 60 seconds. Exceeding it materially reopens this decision with evidence.

Gmail authorization viability is spiked in Phase 0, not discovered in Phase 3.

Detail: `docs/ADR-0001-PERSISTENCE-AND-EXECUTION.md`.

---

## 14. Edition is a materialized entity — RESOLVED

`Edition` and `EditionEntry` are real tables.

Edition was previously modeled only as per-ContentPiece state, which is a live query. A live query cannot hold a package stable through the day, cannot answer what was seen on a given date, and leaves nowhere durable to record why a piece was surfaced — which `EDITION-EXPERIENCE.md` §7 requires.

`EditionEntry.rationale` is the sanctioned record of a surfacing decision, written for Jon rather than for a debugger. It is not the beginning of a `Signal`/`Observation` evidence graph and gains no query surface beyond its own Edition. The explicit non-models in `V1-SCOPE-AND-SEQUENCING.md` §2 stand.

`Edition.targetSize` defaults to 20. "Finite" with no number gives judgment no objective.

---

## 15. Essential relief valve, and Dismiss — RESOLVED

Two corrections to Edition vocabulary and semantics.

**Essential versus finite.** Product Law 3 (Edition is finite) and Product Law 9 (Essential material cannot silently age away) are in direct tension: an Essential Stream that outpaces reading produces a monotonically growing unresolved set inside the surface that is supposed to feel calm. Within months, Edition acquires the permanent guilt column that Later was carefully designed to avoid.

Resolution: an unresolved Essential entry carried more than 14 times moves to a distinct `essentialBacklog` section, reachable and visible but outside the daily package and outside `targetSize`. Nothing silently ages away; the daily Edition stays finite. The threshold is tunable.

**Dismiss, not Clear.** Edition's resolution action is `Dismiss`. Today's Gmail attention action remains `Clear`. Four documents previously carried warnings that the two operations must be implementation-distinct; when a spec has to repeat a warning four times, the word is wrong. Those warnings are removed.

---

## 16. Normalized text — RESOLVED

Stored for every ContentPiece with textual substance, at ingest, unconditionally, and indexed.

Library search is a V1 requirement, so the earlier condition "when it materially improves durability, search, or offline use" was always satisfied for anything Library could contain, and served only to license inconsistent implementation. A long article is roughly 30KB.

Syncs through CloudKit for Library members; device-local otherwise. Promise-based custody is unchanged and continues to govern payloads.

This removes an entire class of degradation state: loss of provider access can no longer cost Cockpit the text of something it retained.

---

## 17. Judgment has a contract and an evaluation harness — RESOLVED

Judgment — the pass that turns candidate ContentPieces into an Edition — is the component the product promise rests on and was previously specified only as a word in a pipeline diagram.

It is now governed by `docs/JUDGMENT-CONTRACT.md`: batched once per composition rather than scored per piece, strict structured output, rationale and subjects persisted rather than re-derived, and Find extraction sharing the same call.

An evaluation harness exists from Phase 1: 200 real ContentPieces from Jon's own Streams, labelled by Jon, run on every prompt or model change. False-quiet on Essential material is the metric that matters, because it is the one failure that breaks a promise rather than producing a mediocre edition.

This is also how improving models get cashed in deliberately rather than by impression. Single-user ground truth is a structural advantage worth spending effort on.

---

## 18. Substantive-primary is attention-protection, not durable retention — RESOLVED

Surfaced during the M1-S4 labelling pass (2026-09-13), where hand-labelling `isSubstantivePrimary` repeatedly felt like a coin flip on curated aggregators (Techmeme) and topical news. The confusion is real and is a modelling defect, not a labeller error: the name fuses axes that do not move together.

`isSubstantivePrimary` answers **one** structural question: is a ContentPiece the Stream's own **primary authored work**, or an **accessory** to it (a pointer/aggregator, a housekeeping notice, a promo/fundraising message, a body-less teaser)? It is a *type* property, not a judgment of value, interest, or durability. A curated aggregator's arrangement is not by itself an "original argument"; pure curation is an accessory. Original commentary wrapped around links is primary.

Its job is deliberately narrow. It gates two things and nothing else:

- the **Essential guarantee** (§15): substantive-primary material from an Essential Stream is never silently `aged` out of the Edition. This is *attention* non-loss — you are guaranteed to **see** it before it goes — **not** storage.
- **auto-Library qualification**, which is deferred to V1 Phase 2.

It does **not** mean "keep this forever." Durable retention is an explicit human act — **Add to Library** — orthogonal to entry state. A topical piece (yesterday's news recap) is substantive-primary **and** ephemeral: it earns attention protection, then ages or is dismissed, and is never stored unless the user explicitly keeps it. The live system therefore already decouples primary-ness from retention; the confusion comes from the name and from the (deferred) auto-Library use reading as a storage gate.

**Open axis — do not conflate.** "Worth keeping / durable-reference / timeless" is a **third** axis, distinct from primary-vs-accessory (this flag) and complete-vs-teaser (`bodyCompleteness`, S5). It is currently unmodeled because its only would-be machine consumer — the auto-Library policy — is deferred precisely because its criteria are unproven. When auto-Library is designed it must **not** reuse `isSubstantivePrimary` as the keep-criterion: primary-ness is not durable-worth. See "Build it and learn."

Housekeeping: the "paywall teaser with no body" example in `docs/IMPLEMENTATION-CONTRACT.md` §1 is really the completeness axis. Until S5 lands, a body-less teaser is labelled not-substantive; afterward that fact belongs to `bodyCompleteness` and this flag stays purely primary-vs-accessory. A rename to `isPrimaryWork` is a candidate but is deferred (it touches schema, harness, and in-flight labels); the sharpened definition holds the field name for now.
---

## 19. Read vs. skim content, and per-digest commentary — OPEN HYPOTHESIS

Raised 2026-09-13 from the M2 S2 labelling exercise. **Not resolved — to be decided by dogfooding, recorded here so a future implementation does not quietly pick one reading.**

Some content is a *read* (an original argument or report — a Yglesias essay); some is a *skim* (a digest/roundup that points at other things — the NYT Morning Briefing, "top 7 things to know"). The model already distinguishes these on the `isSubstantivePrimary` axis — and §18 sharpens exactly this: a digest/aggregator is an **accessory**, not primary work, so a digest is the canonical **non-substantive-primary** piece.

The open question is what a skim piece *does* in the surfaces:

- **Hypothesis (to live with first):** a digest is still Edition-worthy, but as a **skim entry, not a read entry** — admitted, marked `isSubstantivePrimary = false`, and rendered by the Reader (S4) as a compact summarized card rather than a full read. It stays in the one Edition surface rather than getting its own lane, because a skim card costs little attention (so it does not consume the finite edition's read budget) and because fragmenting the morning across Today + Edition + a briefings lane should wait until lived use asks for it. Fully reversible: if a skim entry keeps wanting its own scan lane, that is the signal to split it.

- **The genuinely new behavior this surfaces:** for a digest, useful AI commentary is about *what is inside it against Jon's interests* ("today's Briefing leads with X; the item likely to matter to you is the housing-policy piece"), not about what the piece is. Every other kind: the `summary` describes the piece; for a digest, the `summary`/`rationale` should describe its **contents** — a preview that lets Jon decide whether to open the source at all. This is a small per-kind addition to the judgment prompt, not new architecture, and is the strongest form of "commentary before I open it."

- **Caution for later:** de-duplication. If Jon also follows sources a digest covers, the digest and the originals can crowd each other in one edition. A ranking/dedup nuance, not a launch blocker.

Resolve by: living with digests as skim cards, and watching whether (a) they want a separate scan lane, (b) the contents-commentary is worth its prompt cost, and (c) dedup against directly-followed sources becomes annoying. Relates to `docs/EDITION-EXPERIENCE.md` (Reader rendering, S4) and `docs/JUDGMENT-CONTRACT.md` §3–4 (per-kind summary/rationale).

---

## 20. The Reader renders the body Cockpit holds; Open Original is the fallback — RESOLVED

Raised 2026-09-15 from the M3 S1/S3 device pass. The Reader stops at the `summary` and offers **Open Original** as the primary way to actually read a piece — so the one "investigate this item" surface repeats the sidebar card and then sends Jon out of the app to read. That is backwards: the product law is that the Reader makes **ContentPiece substance primary** (`docs/IPAD-FIRST-EXPERIENCE.md` §7), and leaving the app to read the substance is the opposite.

**Decision:** the Reader renders the readable body Cockpit already holds, inline beneath the summary. **Open Original stops being the default action and becomes the honest fallback** for the cases where Cockpit does not hold the body.

This is not new capability bolted on — it is surfacing what the model already records. `ContentPiece.bodyCompleteness` (`full` / `truncated` / `teaser`; `docs/IMPLEMENTATION-CONTRACT.md` §Body completeness) exists precisely to tell the Reader "what substance is actually held," and it drives the three honest cases:

- **`full`** → render the held body inline. Open Original is a convenience, not the way to read.
- **`truncated`** → render the held body, then Open Original for the remainder ("Cockpit holds the opening; the rest is at the source").
- **`teaser`** → summary/preview only; Open Original is the sole path, because a paywalled or body-less teaser is all Cockpit is permitted to have.

**Where the body lives, and the custody honesty this forces.** The readable text is `LocalNormalizedText` — **device-local**, derived from the (also device-local, unsynced) Artifact; neither syncs (D6/ADR-0001). Only `bodyCompleteness` rides on the synced ContentPiece. So a piece that **synced in from another device** can read `bodyCompleteness = full` while this device holds no `LocalNormalizedText` for it. The Reader must therefore key the inline render on **whether this device actually holds the text**, and use `bodyCompleteness` to frame the promise — never assume completeness implies local substance. When completeness says a body exists but this device lacks it, the Reader says so and offers Open Original (the text re-derives on this device's next ingest of that piece). This is the same custody fact §16 and ADR-0001 D6 already ratified; the Reader now has to show it honestly rather than hide behind Open Original.

**Hard boundary — this is not a browser.** The Reader renders **only text Cockpit already holds or derived**, as sanitized/attributed content. No JavaScript, no navigation, no cookies, and — critically — **no live fetch-and-scrape of the original to fill a `truncated`/`teaser`**. The moment reading would require going and getting the page, the answer is Open Original, which hands off to the system browser. Cockpit renders its own custody; it does not reimplement the web.

**Relationships.** This is the reading half of the same surface as **offline** (`Offline until [date]` / `Keep Offline`, currently M4-cutline): the body rendered inline is exactly the substance an offline promise must retain, so the two belong to one slice or adjacent ones (`docs/IPAD-FIRST-EXPERIENCE.md` §8). It also reconciles with §19: a **digest / skim** piece (non-substantive-primary) still renders as the compact contents-preview card §19 describes, **not** a full inline body — inline body is for read pieces with a real `full`/`truncated` body. And it does not touch the AI boundary: rendering held text is deterministic display, not judgment.

**Not decided here:** exact typography/reader geometry (deferred, "Reader geometry details" below), HTML-vs-plain rendering fidelity, and the milestone placement of the slice (proposed M4-adjacent; see `docs/milestones/M3-shell-and-personal-knowledge.md` M4 cutline).

---

# Deliberately deferred decisions

These are **not unresolved blockers**. They should wait for implementation/use evidence.

## Edition

- exact Seen treatment;
- exact carryover budget, Essential backlog threshold, and target size — the numbers, not the states;
- section ordering and card density;
- midday admission volume;
- Essential backlog review tooling beyond a plain reachable list;
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
- which canonicalization rules the derived-identity function actually needs;
- what composition really costs in dollars and seconds, and whether that reopens §13;
- whether the judgment agreement rate is good enough to trust, and what moves it;
- whether normalized source text deserves durable preservation for particular source classes;
- whether Subjects + full-text search are sufficient before embeddings;
- how quickly Later becomes a backlog and whether cleanup is needed at all;
- how often orphan Finds occur and what future specialist app their population suggests;
- what Gmail message/thread semantics require after a read-only integration spike;
- how much Personal Knowledge structure is actually necessary once it changes ranking/explanation;
- what signal auto-Library needs to decide durable retention, given that `isSubstantivePrimary` is primary-ness, not durable/reference worth (§18);
- which cross-app handoff fields survive contact with the first real receiver.

When implementation evidence contradicts a ratified decision, stop, record the evidence, and deliberately amend this ledger rather than silently drifting the model.
