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

**Clarified 2026-09-25 (Jon, from dogfooding the Finds list).** A Find is a *thing*: something a specialist app could admit, meaning a place, a product, a dish, a bottle, a book, an event, a stay. A piece of software or a hardware tool is a product and counts. An idea does not count: a technique, capability, pattern, practice, argument, insight, trend, or tip is understanding, not a thing. It stays with its ContentPiece (Later, Library), and becomes Personal Knowledge only when Jon teaches it. The evidence came from tech newsletters, which filled the list with Techniques and Capabilities that no app could ever take, so they could never resolve. They also polluted the orphan-Find evidence this section relies on. Extraction prompts carry this definition, and a deterministic guard declines idea kinds at persist (M6 S-r13).

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

**Amended by §14, §15, and §24.** Edition is a materialized entity composed once per day, not a live query over per-ContentPiece flags. Its resolution action is **Dismiss**, not Clear. V1 must support admission, Seen, Dismiss, carryover, Essential protection, the Essential backlog, and resolution through Save for Later. Since §24, this remit is the barely-curated tail only; it renders as a Today section and never screens curated Gmail input. The states and legal transitions are settled in `docs/IMPLEMENTATION-CONTRACT.md` §3; only the durations, sizes, and visual treatment are learned from use.

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

**Amended by §28 (2026-09-26):** Cockpit now mirrors Gmail's read state and marks a message read when
Jon opens it in the Reader. Read state is still not attention state.

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

The executable contract for all of the above is **`ADR-0002` (Accepted 2026-09-19; amended D10 2026-09-21)**: D1 (message is the unit), D4 (the per-message barrier — read → classify/extract → persist the promised durable result → verify the commit → advance `historyId` → apply the disposition), D5 (Leave/Archive/Trash map to label operations; no `Delete Forever`; idempotent), D6 (the bounded, inspectable Undo log), D7 (explicit-per-action first; policies are explicit and user-established), and D10 (a user-declared newsletter series may Trash its piece only after a human Reader leave). This §7 states the policy; the ADR is where it is settled against real provider behaviour, and it governs the Phase 4 mutation slices (M5 S7–S8 and M6 S1).

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

`Edition.targetSize` defaults to 20. "Finite" with no number gives judgment no objective. **Amended by §24:** this objective applies only to the barely-curated tail; curated mail is intrinsically finite and organized without a cutoff.

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
- **auto-Library qualification**, which is deferred to V1 **Phase 7**.

It does **not** mean "keep this forever." Durable retention is an explicit human act — **Add to Library** — orthogonal to entry state. A topical piece (yesterday's news recap) is substantive-primary **and** ephemeral: it earns attention protection, then ages or is dismissed, and is never stored unless the user explicitly keeps it. The live system therefore already decouples primary-ness from retention; the confusion comes from the name and from the (deferred) auto-Library use reading as a storage gate.

**Open axis — do not conflate.** "Worth keeping / durable-reference / timeless" is a **third** axis, distinct from primary-vs-accessory (this flag) and complete-vs-teaser (`bodyCompleteness`, S5). It is currently unmodeled because its only would-be machine consumer — the auto-Library policy — is deferred precisely because its criteria are unproven. When auto-Library is designed it must **not** reuse `isSubstantivePrimary` as the keep-criterion: primary-ness is not durable-worth. See "Build it and learn."

**Gate-2 reconciliation (2026-09-16) — auto-Library is Phase 7, not Phase 2.** The
milestone doc flagged a live doc conflict: this section deferred auto-Library "to
V1 Phase 2" while `docs/V1-SCOPE-AND-SEQUENCING.md` §3 places it in **Phase 7**
(after explicit Library + custody are trustworthy). Reconciled in favour of Phase 7
— it is the safer placement and matches this section's own argument that the
keep-criteria are unproven. V1-SCOPE §3 is authoritative; the "Phase 2" phrasing
above is corrected.

**Gate-2 finding (2026-09-16) — the single judgment pass lets PK bleed into the
type call; splitting it is ratified M4 scope.** The M3-S5 paired run showed
substantive-primary accuracy falling **0.545 → 0.415** when the same corpus was
taught (`docs/eval-log.md`, 2026-09-15). `isSubstantivePrimary` is a *type*
property, independent of taste/interest — PK must not move it. That it does is
evidence the one editorial pass conflates the type classification with the
finite-package judgment. Remedy ratified for M4: **separate the type/classification
call from the editorial call**, aligning with the M2-S1 cost decision's
"mechanical grunt-work moves to a cheaper/onboard pass" direction. The metric is
noisy (small count) but the direction is a real signal; the fix is scoped as an M4
slice, not gate-blocking.

Housekeeping: the "paywall teaser with no body" example in `docs/IMPLEMENTATION-CONTRACT.md` §1 is really the completeness axis. Until S5 lands, a body-less teaser is labelled not-substantive; afterward that fact belongs to `bodyCompleteness` and this flag stays purely primary-vs-accessory. A rename to `isPrimaryWork` is a candidate but is deferred (it touches schema, harness, and in-flight labels); the sharpened definition holds the field name for now.
---

## 19. Read vs. skim content, and per-digest commentary — ABSORBED BY §24

Raised 2026-09-13 from the M2 S2 labelling exercise. **Absorbed by §24 (2026-09-16):** the read/skim
axis becomes the treatment axis — think-pieces are *listed*, digests/grab-bags are *extracted* — and
the "commentary about what is inside a digest" this entry describes is exactly the grab-bag extract
treatment. The text below is retained as the origin of that insight. **Not resolved — to be decided by dogfooding, recorded here so a future implementation does not quietly pick one reading.**

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

> **Updated 2026-09-18 — the HTML-vs-plain fidelity question is now resolved for email by §25:** the email Reader renders the held **original HTML** in an in-app WKWebView (reader-mode re-render dropped), a scoped, mitigated crossing of the "no remote fetch" boundary above. The non-email path described here is unchanged. Build targeted M6.

---

## 21. Always-read Streams: reachable completeness vs. Edition promotion — ABSORBED BY §24

Raised 2026-09-15 from Jon's product note on paid, always-read newsletters (Matthew Yglesias, Puck, Alan Sepinwall). **Absorbed by §24 (2026-09-16):** this entry's "promotion is a cost, not a benefit; just list these for me" is the general case §24 resolves — an always-read Stream is curated input, so its treatment is *listed*, and the anti-forget guarantee (§15) stands while the promotion effect dissolves. The text below is retained as the origin of that insight. **Not resolved on its own terms — it cannot be validated until email-delivered Streams are real (Phase 5), because these Streams arrive through Gmail. Recorded here so the Phase 5 build does not quietly assume `Essential` means "promote into the daily Edition."**

`Essential` currently bundles two effects that this note pulls apart:

1. an **anti-forgetting guarantee** — substantive primary material cannot silently age away (Product Law 9; §15); and
2. a **promotion effect** — Essential posture is a judgment/ranking input (`docs/EDITION-EXPERIENCE.md` §5) that pushes the Stream's pieces into the finite daily package.

For a Stream Jon reads *regardless* — a paid subscription he opens every issue — effect (2) is a **cost, not a benefit**. It spends one of ~20 `targetSize` slots (§14) promoting something that needed no promotion, and Edition's scarce curation is better spent on discovery and on pieces Jon might otherwise miss or delete. In his words, Edition should "help me find things I might have missed/deleted," not re-surface what he would have read anyway. The guarantee (1) is exactly what he wants; the promotion (2) is what feels like a wasted slot.

- **Hypothesis (to live with once Phase 5 makes it real):** a Stream can be **reachable-first**. Its substantive primary material is guaranteed listed and sweepable — the anti-forget half of §15 stands in full — but it does **not** consume a daily-package slot or `targetSize` budget by default. The existing `essentialBacklog` section (§15) is already this exact shape: reachable, visible, outside the package and outside `targetSize`. Today it is reached only as *overflow*, after 14 unresolved carries. The hypothesis is that for an always-read Stream this reachable list should be the **primary** treatment from the first issue, not the fallback after fourteen misses. Concretely this is a Stream-level Handling nuance ("just list these for me to sweep; don't spend Edition slots on them"), not a new entity or a new entry state.

- **Guardrail — this is not a "paid" flag.** The trigger is editorial intent Jon sets ("I will read all of these"), not price or subscription state. `docs/CONTENT-PIECE-MODEL.md` already forbids inferring behavior from paid-vs-free (completeness "must not be inferred from whether a Stream is paid"); the same discipline applies here. It rides on Handling, not on a derived `isPaid`.

- **Guardrail — grab-bag Streams are a separate thing.** Feed Me stays a mixed Stream whose value is the Finds pulled from each issue (`docs/CONTENT-STREAM-MODEL.md` §3). "That's okay" is already the model; this hypothesis is not about it.

- **Does not weaken §15.** Nothing silently ages away. This only changes whether "reachable" *begins* as the list-first default or is only reached after overflow.

Resolve by: living with Phase 5. Watch whether (a) always-read Streams promoted into Edition genuinely feel like wasted slots, (b) a list-first "sweep these" surface for a Stream is what Jon actually reaches for, and (c) it expresses as Handling without a new posture enum. If all three hold, it likely folds into §15's Essential model as a per-Stream default rather than a new axis. Relates to §15 (Essential relief valve — the existing reachable-list primitive), §14 (`targetSize`), `docs/EDITION-EXPERIENCE.md` §4–5, `docs/CONTENT-STREAM-MODEL.md` (Handling / Essential), and `docs/V1-SCOPE-AND-SEQUENCING.md` Phase 5.

---

## 22. What the judgment eval measures — agreement is not the headline — RESOLVED

Raised 2026-09-15 from the M2-S2 baseline (`docs/eval-log.md`, 2026-09-13) while
scoping the S5 Gate-2 run. **Amends §17 and resolves the agreement-definition
tension the eval-log and `docs/milestones/M3-shell-and-personal-knowledge.md`
flagged for Gate 1/2.**

The baseline read `agreement 0.421` and treated it as the number to move. On
inspection it is close to meaningless as a headline, for a structural reason, not
a model-quality one:

- The frozen corpus is **89% `surface`** (316/357). The model admits ~35%. So the
  low agreement is almost entirely the model *declining pieces Jon labelled
  `surface`* — and a model that admitted everything would score **0.89 agreement
  trivially**. A metric maximised by admitting everything cannot gate a surface
  whose whole purpose is finite selection.
- The `surface` / `quiet` / `never` taxonomy is **Gmail-triage vocabulary**
  (seeded in M1 from `dispositionPrior` + Gmail metadata). It answers *"would I
  ever want this / did I subscribe to this?"* — a statement about the **source**,
  made once. For a deliberately curated inbox that answer is ~always `surface`.
  It is not a statement about **this issue, this morning**.

These are two different questions wearing one label. The Edition does not answer
"is this junk" — for curated Streams almost nothing is. It answers: *of the 40–120
pieces that arrived, which ~20 deserve this morning's attention, in what order and
section, deduplicated, and why.* The Edition is an **editor**, not a bouncer: its
value is ranking, sectioning, substance-vs-accessory (§18), dedup, and finiteness
under an attention budget (§14) — not garbage rejection. Measuring it against a
"would I ever want this" label measures the wrong job.

**Decision:**

1. **Agreement-vs-`surface` is demoted from headline and gate.** It measures
   source endorsement, rewards over-admission, and does not reflect editorial
   quality. It may be reported as context but never chased.
2. **Essential false-quiet remains the one hard floor, measured as a paired
   delta.** §17's "the one failure that breaks a promise rather than producing a
   mediocre edition" is exactly right and is *why* this survives as the gate. But it
   is **not** a fixed constant: the M3-S5 runs (2026-09-15, `docs/eval-log.md`)
   showed essential-false-quiet reading 0.051 / 0.068 / 0.102 across *clean* runs of
   the same prompt — it is a small-count metric (~3–6 pieces of ~59
   Essential-substantive), so an absolute threshold passes or fails on model
   nondeterminism. The gate is therefore: **a PK/prompt/model change must not
   regress essential-false-quiet relative to a same-session control run** (bare vs
   taught, or old-prompt vs new). The ~0.068 baseline is the order-of-magnitude
   reference, not the pass line. No change ships that regresses the paired control.
3. **The eval's quality headline is re-scoped to selection-and-ordering on the
   contested set** — how the finite package is chosen and ranked among the pieces
   where attention is actually rationed — together with **substantive-primary
   accuracy** (0.534 at baseline, a genuine weakness). Not agreement with a
   subscribe-or-not label.
4. **Consequence for S5 / Architecture Gate 2.** "Did agreement move when PK grew?"
   is no longer the Gate-2 headline. The honest question is whether PK growth
   **changed admission/ranking among contested pieces in a direction Jon
   endorses** — measured on that set, with essential-false-quiet held as the floor.
   The M3 milestone's Gate-2 phrasing is updated to match.

**Ratified at Architecture Gate 2 (2026-09-16).** Point 2's paired-delta floor is
the standing definition of the essential-false-quiet gate — a PK/prompt/model
change must not regress essential-false-quiet relative to a same-session control
run (bare vs taught, or old-prompt vs new); the ~0.068 figure is an
order-of-magnitude reference, not a pass line. The eval-log's open flag
(`docs/eval-log.md`, 2026-09-15 M3-S5 primary entry) is closed by this ratification.

**Guardrail — this is not a licence to admit everything, and it is the opposite of
clickstream.** Finiteness (§14) and the anti-forget guarantee (§15) stand in full;
demoting agreement removes a bad *metric*, not the discipline of a small package.

**Amended by §24 (2026-09-16).** This selection-and-ordering measurement governs only the
barely-curated tail. Curated Gmail input is never admitted, declined, or cross-item ranked; it is
organized by deterministic treatment instead.
And the relevance signal remains explicit taught knowledge (§8) — never inferred
behaviour. This decision sharpens what "not decorative" means for PK; it does not
loosen where PK comes from.

**Still to measure at Gate 2 (do not pre-build).** The current labels cannot
express "top-of-mind for this morning" or a ranking preference — they are the
subscribe-or-not axis this decision just demoted. Whether the re-scoped headline
needs a **new labelling axis** (a per-morning "this one mattered" / relative-order
signal) or a different judgment target is deferred to the Gate-2 measurement, not
designed here. Relates to §14, §15, §17, §18, §19 and §21 — all of which already
carry the same insight from other angles: not every endorsed piece needs a daily
slot.

---

## 23. The two-pass split's per-composition latency, and the §13 budget — OPEN (TRIGGERED)

Raised 2026-09-16 from the M4 S1 measurement (`docs/eval-log.md`, batch-30 `runFrozenCorpus`). §13
records the composition budget as **under $1.00 and under 60 seconds**, and says exceeding it
materially "reopens this decision with evidence." The M4 type/editorial split does exceed the latency
half, so this entry reopens it — and tracks the resolution, which is already known and deferred, not
newly designed here.

- **Evidence.** Split latency **114.9s per composition** at batch 30 on the frozen corpus, well over
  the 60s figure. Cost is fine ($0.211/composition, under $1.00). The split runs the type pass then
  the editorial pass *sequentially* — editorial consumes the type metadata, so they cannot overlap —
  and both currently run on Sonnet, with the editorial call carrying ~2× input (full bodies + PK +
  type metadata, JUDGMENT-CONTRACT §7). So per-composition latency roughly doubled versus the single
  pass. This is the **accepted, deliberate cost** of closing the substantive-primary bleed (§18,
  Gate 2): the same run improved substantive-primary accuracy 0.551 → 0.681 and false-surface
  0.179 → 0.051 with the floor held (0.034). **The split itself is not reopened — only its latency.**

- **Caveat — this is a proxy, not yet a confirmed production breach.** 114.9s is measured on a Mac
  against the API under eval concurrency, not a warm iPad composing one real morning. The §7 budget is
  a *warm-device* target; the real number is Jon's device pass on actual hardware. Treat this as a
  flag to verify, not a settled regression.

- **Resolution (deferred, not designed here): move the PK-free type pass to a faster/cheaper model**
  once it can emit the schema — the M2-S1 cost lever, already parked in the M4 milestone's M5+ cutline
  (`docs/milestones/M4-gmail-today.md`). That cuts the type pass's cost *and* latency at once, and the
  editorial frontier call stays on Sonnet. It sits behind the known schema blocker (the cheap/onboard
  model must reliably emit the classification schema first).

- **Trigger to act.** This becomes load-bearing when Today/Gmail (M4 S4–S5) adds message volume to the
  daily composition, or when Jon's device pass shows a real morning composition over 60s. If the
  warm-device number is under budget, this rests as recorded; if over, the type-model swap moves ahead
  of its current M5+ slot. Interim levers, if needed before the swap: trim the body the editorial pass
  resends (a finds/rationale-quality trade-off), or the Interest-Area split + second pass
  (JUDGMENT-CONTRACT §1). None chosen now.

**Triggered — on-device confirmation, 2026-09-16.** The device pass fired the trigger above. A real
recompose on an iPad took **~6 minutes (~360s) at $0.48** — cost comfortably under budget, latency
**~6× the 60s §7 target**, on the warm hardware the budget is actually about. The proxy caveat is now
resolved: the breach is real, not a Mac-over-API artifact. Two facts sharpen the resolution:

- **The production composer is monolithic — and that is the biggest *safe* lever.** `EditionComposer.composeIfNeeded`
  calls `engine.judge` with the **whole day's candidates at once**, so `judge` makes one large type
  call then one large editorial call, sequentially, with no batching or concurrency. The eval harness
  already parallelizes composition-sized batches; production does not. The **type pass is per-piece and
  carries no finite-package constraint (§1)**, so it can be chunked and run concurrently inside the
  engine with no change to outcomes — pure wall-time reduction, no schema blocker. The **editorial pass
  must stay one call** over the candidate set to preserve the finite-package property (§1; >120 uses the
  Interest-Area split + second pass), so its latency is the harder floor.
- **The durable win is still the type-model swap** (a fast/cheap model for the PK-free type pass),
  which cuts both cost and latency but sits behind the schema blocker.

Sequencing: this is now scheduled as **M4 · S6 — Composition latency**
(`docs/milestones/M4-gmail-today.md`), sequenced **before the Gmail spine (S4–S5)** because Gmail
volume compounds the same monolithic composition. S6 does the safe near-term work (parallelize the
type pass; measure on device); the model swap remains deferred to its M5+ slot unless S6 leaves the
budget still breached.

**Amended by §24 (2026-09-16).** The curated inbox does not run the editorial finite-package pass at
all, so the latency breach this entry tracks largely dissolves for the common case rather than
requiring the type-model swap. §23 now governs only the barely-curated tail (§24), where the editorial
pass still runs and S6's parallelization applies.

---

## 24. Cockpit organizes curated input; it does not judge it — RESOLVED

Raised 2026-09-16, in conversation, while re-scoping §23's composition latency. The latency work kept
getting cheaper the harder we looked at *what* was being judged — and the bottom of that thread is not
a performance decision, it is a product one. **This resolves and absorbs §19 and §21, extends §22, and
largely dissolves §23 for the curated path.** It re-centers the V1 spine.

**The distinction: select-from-uncurated vs. organize-curated.** The Edition — finite-package judgment,
admit/decline, cross-item ranking — earns its keep when the input is a firehose the user has *not*
curated: a pile of RSS, an aggregator. There, a machine sifting signal from noise is real work. But
Jon's inbox is the *output* of curation he already did: he subscribed, he knows these senders. Running
a "here is what we decided is worthy for you" layer over input he already chose is redundant — and
worse, it is the engagement move content feeds have made since 1995: manufacture the *feeling* of
curation to justify an attention surface. Applied to curated mail it inserts a model's editorial
authority between Jon and material he deliberately asked to receive. §22 already reached the edge of
this ("the Edition is an editor, not a bouncer; for curated Streams almost nothing is junk") and §21
reached it from the always-read angle ("promotion is a cost, not a benefit"). §24 states the general
form: **for curated input the job is organization, not selection.**

**The failure it replaces: the flat inbox.** Every mail client renders each message with identical
visual weight and stacks them in arrival order. That is the *worst* prioritization — it is *no*
prioritization: it makes a note from your kid and a wine promotion look the same and sorts them by
accident of timing. Cockpit's deliverable is the opposite — a **hierarchical, type-differentiated
view**, in which the treatment a piece receives (highlighted / summarized / listed / extracted) *is* its
visual rank. Crucially, that hierarchy is by **type and relationship** — deterministic and stable (a
personal email is elevated because it *is* personal, not because a model scored it high this morning) —
which is exactly why it stays on the organize side of the line and never becomes the per-item relevance
ranking this decision demotes. Within a type, order stays arrival-based: choosing between two
newsletters — Yglesias or Cartoons Hate Her — is a **mood, not a priority**, and the reader settles it
visually in a heartbeat, so it is not Cockpit's to rank. The win is *across* types, not within them.

**What Cockpit does with curated input: route by type/source into a treatment, never suppress.** The
value Jon named — "wine offers summarized, canonical newsletters listed, personal emails highlighted"
— is triage-and-treat, not judge-and-rank. Each treatment is a rung in that hierarchy:

- **Personal email → highlighted.** Elevated by relationship, not by an AI relevance score.
- **Canonical / think-piece newsletter → listed.** Title and writer. A Slow Boring issue is one
  indivisible essay — there is nothing to sift *within* it, and the decision to read the writer was
  made at subscribe time.
- **Domain offer (wine, restaurant, product) → summarized** into a Find — the specialist-app
  candidate (§3).
- **Grab-bag / digest (Feed Me; occasionally a mailbag) → extracted.** This is the one place
  editorial-style sifting runs on curated input, and it runs *inside* the piece (pull the worthwhile
  items out), not across pieces.
- **Transactional / receipt mail → low, countable reference.** Shipping notices, receipts,
  reservations, account notices, and similar machine-delivered operational material stay present but
  are never elevated over personal or editorial mail. Login/verification codes are a distinguishable
  `ephemeral` sub-kind for a future explicit policy; the classification itself neither suppresses nor
  mutates Gmail.

**M5 S3 amendment (2026-09-18).** The fifth rung is evidence-driven: the S7 device pass found UPS
shipping, an Apple Store `do_not_reply` trade-in notice, a sign-in code, and a hotel confirmation
scattered across Personal and Newsletters because the four-rung taxonomy had no home for them. Jon
chose a treatment, not a Find. It inherits every §24 guardrail: deterministic retained-header/type
routing first; an explicit per-sender override wins; no Contacts scope, learned reputation store,
model-primary classification, suppression, or provider action. A clearly human one-to-one message is
personal even if its subject resembles a transactional notice.

**Override status (2026-09-18) — the correction mechanism is built; its UI is the last unbuilt piece.**
The per-sender override engine exists and is tested (`EmailSenderTreatmentOverride` +
`EmailTreatmentOperations.setSenderOverride`, M4 S5): an explicit correction wins over the deterministic
default, reclassifies all mail from that sender, survives recomposition, and is never learned or
auto-added. What is missing is the **affordance to invoke it** — nothing in the app calls
`setSenderOverride`, so a visible misplacement (e.g. an editorial-styled retail promo like Ministry of
Supply that carries no `sale`/`shop now` marker routes to `newsletter` instead of `offer`) is currently
*visible but not correctable on device*. Exposing the existing override in the Today row overflow menu
(and the reader) is a **small correction-affordance slice** (M5-adjacent / early M6); it is the intended
and only sanctioned fix for such misses — not classifier perfection, a model call, or a learned
reputation store, all still forbidden above. Known limit of per-sender granularity: an override forces
*all* of a sender's mail to one treatment, accepted here.

**M6 device-eval amendment (2026-09-22).** The correction control is **Move to section**, not Treat
sender as. It writes the existing locator-routing rule; the treatment-override table, classifier read,
and operations remain for compatibility, but the app no longer exposes treatment edits. Since
section changes can alter whether a newsletter is an offer or digest, extraction follows the resolved
role (`Offers` → offer schema; `Grab-bag` → digest schema) as well as existing offer/digest treatments.
This grants no Gmail disposition authority: policy candidates remain treatment-gated, and finance mail
continues to override locator routing, including mute.

**Confirmed-Find barrier amendment (2026-09-23).** For the explicit `offerWithFind` disposition policy,
the auto-Trash barrier is a Find Jon confirmed, never a model proposal. A handed-off Find also counts as
confirmed; pending and dismissed proposals do not satisfy the barrier. Confirmation may immediately
apply the already-enabled policy through its existing barrier and Undo log.

**Find referral extension (2026-09-24, M6 Gate 5 S-c1).** A `referred` Find also satisfies the
`offerWithFind` barrier because sending is a confirming act, and a receiver-judged `declined` Find keeps
that authority because the receiver's quality verdict does not revoke Jon's confirmation. Failed app
opens return the Find to `confirmed`; a dismissed or extraction-failed receiver verdict is likewise
re-sendable as `confirmed`.

**The AI boundary this sharpens (extends §22).** For curated input the model classifies, summarizes,
extracts, and highlights — it **never admits/declines or suppresses**. Organization changes order,
grouping, and summary; it never changes *membership* of curated mail. This is strictly more faithful to
Cockpit's own AI boundary ("AI may interpret, propose, summarize, classify… it does not get
source-deletion authority; model output does not silently become receiver-owned canonical state") than
the Edition editorial pass, which hands the model admit/decline over things Jon chose to receive. §22
demoted the "bouncer"; §24 removes even the "editor" for curated input, leaving the **organizer**.

**The spine re-centers.** V1's spine is **typed triage of curated input** — the inbox, organized by
treatment instead of by arrival order (Today; "orientation/attention," Product Law 1). Per-type
treatment (list / summarize / highlight / extract) is the core mechanism. This is what M4 (Gmail-Today)
is already walking toward; S4–S5 are the real product, not preamble to Edition.

**Edition is right-sized, not deleted.** The finite-package judgment stays the correct tool for the
genuinely barely-curated tail — aggregator streams, a raw RSS firehose, the "Technology stories" case
where Jon *does* want ruthless screening because he has *not* pre-curated it. It demotes from
centerpiece to a screening treatment for that tail. **Decided 2026-09-16: the tail renders as a section
*within* Today, and Edition is dropped as a top-level shell destination** — the shell becomes `Today /
Later / Library / Settings`. The shell change lands in its own slice; `AGENTS.md`'s "Current shell" is
amended when that slice ships, not before, so the doc keeps describing what is actually built.

**What survives from M2, and what demotes.**

- **Survives (the spine of the AI work):** type classification (kind, `isSubstantivePrimary` §18,
  subjects, summary), Find extraction, per-kind summary/preview. These *are* the treatments; they make
  triage valuable.
- **Demotes:** the editorial finite-package pass — cross-item admit/decline/section/rank/rationale over
  the whole day. It narrows to (a) the uncurated tail and (b) within-grab-bag extraction. It is no
  longer the everyday path.

**Consequence for §23 (latency).** The 60s-budget breach was dominated by the editorial pass (device
split, 2026-09-16: total 224.5s = type 71.1s + editorial 153.4s over 66 curated candidates). Under §24
that pass does not run over curated mail at all — so the breach largely dissolves for the common case
rather than needing the type-model swap or editorial trimming. §23's remaining relevance is the
uncurated tail; S6's parallelization stands and applies there.

**Finiteness comes from the input, not a cutoff.** Edition felt feed-like partly *because* of
`targetSize` ranking. For curated input, finiteness is intrinsic — the mail that arrived is already a
finite set. §14's `targetSize` applies only to the uncurated-tail screening treatment, not to the
curated inbox.

**Guardrails.**

- **Not "delete the AI."** Type classification and Find extraction are the surviving core; §24 removes
  a *misapplied selection layer*, not the interpretive work.
- **Not clickstream (holds §8, §22).** Treatments are driven by explicit type/source and explicit
  Stream disposition, never inferred behavior. §15's anti-forget guarantee stands in full; only the
  *promotion* effect dissolves for curated streams (this completes §21).
- **No grab-bag detector for V1.** Grab-bag streams are marked by hand (Feed Me → extract; the rest →
  list). One-and-a-half streams do not justify a classifier ("first use establishes a requirement");
  revisit only if buried-gem misses recur.
- **The model never hides a curated item.** Any treatment that would suppress or decline curated mail
  is out of bounds; that authority never leaves Jon.

**Dogfood amendment (2026-09-23, Jon) — read grab-bags whole; keep routine fetch off frontier.**
Breaking a digest such as Techmeme into small model-selected items made it harder to scan. Grab-bag
remains a deterministic section label, but its messages now appear as whole issues and receive no
automatic extraction call. Existing extracted details may remain stored for provenance but do not
drive the Today presentation. Offers retain a one-sentence summary and one Pending Find proposal,
using the on-device model only. A successful offer result is reused on later syncs; model failure
leaves the whole message readable. No automatic Gmail fetch invokes a frontier model or composes an
Edition. This revises the grab-bag extraction and frontier assumptions above, in the live Today and
V1 contracts, without changing the separate explicit Edition composition action. Existing enabled
Gmail disposition policies still apply after ingest through their committed-result barriers.

**Status.** The *decision* is resolved. Its downstream authoring is not, and must follow deliberately
(Documentation rule): the V1 sequence (`docs/V1-SCOPE-AND-SEQUENCING.md`) and milestones re-center on
typed triage; `docs/JUDGMENT-CONTRACT.md` §1 demotes the editorial finite-package pass to the uncurated
tail; `docs/IMPLEMENTATION-CONTRACT.md` §3 and the Edition/experience docs record the two-treatment
shape; §5, §14, and §22 are amended in remit (not deleted). None of that is done in this entry.

**Relates to:** §3 (Finds — the offer treatment), §5 (Edition remit narrowed), §14 (`targetSize` scope
narrowed to the tail), §15 (anti-forget stands; promotion dissolves — completes §21), §17/§22
(editorial pass demoted), §18 (substantive-primary still classifies), §19 (absorbed), §21 (absorbed),
§23 (latency dissolved for the curated path). Live docs: `docs/V1-SCOPE-AND-SEQUENCING.md`,
`docs/milestones/`, `docs/JUDGMENT-CONTRACT.md`, `docs/IMPLEMENTATION-CONTRACT.md`,
`docs/EDITION-EXPERIENCE.md`, `docs/CONTENT-STREAM-MODEL.md`.

**M5 S3b amendment (2026-09-18) — classification quality: the fallback, per-message routing, and two
transactional sub-kinds.** Lived use of the S4 surface (Jon, 2026-09-18) showed the Personal tier acting
as a **dumping ground**: order confirmations (Weck Jars, Apple Store), bills and a mobile-check-deposit
notice (AT&T via Bank of America bill-pay), a carrier update (UPS), and a health-appointment estimate
(MyUNCChart) all landed in Personal. The cause is structural, not a one-off miss, and the fix is three
deterministic refinements plus one taxonomy growth — all inside §24's guardrails (deterministic-first,
no learned reputation store, no model-primary classification, organize-not-suppress).

1. **The Personal fallback flips to the low rung.** Today the classifier, after the human-1:1 guard and
   the transactional check, routes any non-publication message to Personal — making the *top* relationship
   rung the catch-all for unclassified automated mail. Reverse it: an **automated-shaped, non-publication,
   otherwise-unclassified** message defaults to the **low transactional/reference rung, never Personal**.
   The `isClearlyHumanOneToOne` guard stays in front, so a genuine human one-to-one message (e.g. a small
   winery's owner emailing an order update) is still Personal. Misplacing a machine notice as reference is
   cheap; inflating Personal with machine mail defeats the tier.
2. **Treatment is decided per message; the per-sender override is a tiebreaker, not a hammer.** A sender
   sends different *kinds* of mail over time — Weck Jars sends an order confirmation today and a promotion
   next month — so the deterministic type/content signal decides each message (an order confirmation is
   transactional; a promotion is an offer), and the §24 per-sender override (the M4 S5 mechanism) resolves
   only the **genuinely ambiguous** residue. This corrects the earlier framing that a misplacement is fixed
   *only* by a per-sender override: the first fix is better per-message routing; the override is the escape
   hatch for what routing cannot disambiguate.
3. **Two transactional sub-kinds — `finance` and `shipment` — join `reference`/`ephemeral`. Sub-kinds, not
   tiers.** The transactional tier stays one visible rung (§24's small-vocabulary rule holds; no sixth
   tier). The sub-kind carries **handling posture**, not placement:
   - **`finance`** — bills, statements, invoices, payment/deposit notices. Consequential and record-like:
     **never** eligible for bulk or automatic Clear/Archive/Trash. Jon's reasoning is the justification — a
     pile of "delivered" notices is safe to sweep as a group; bills and deposits are not.
   - **`shipment`** — order confirmations, dispatch/tracking, delivery notices. Operational and **safe to
     clear once delivered**.
   - `reference` (generic) and `ephemeral` (login/verification codes) are unchanged.
   Detection stays deterministic: subject/type markers **plus sender shape** (carrier/commerce domains,
   `orders@`/`shipping@` subdomains) plus structured patterns (order/tracking numbers). Keywords alone are
   brittle and are never the sole signal.
4. **The sub-kinds' teeth land in S8, not now.** Classification (placement + sub-kind tagging) is a
   deepen-job slice (**S3b**); the *consequence* — the explicit disposition policy that refuses to
   bulk/auto-dispose `finance` and permits sweeping delivered `shipment` — lands with the Phase-4
   disposition policy (**S8**), behind Gate 3. Tagging never mutates Gmail; only S8's explicit, authorized
   policy acts, and it reads the sub-kind.

**Sequencing (M5).** This amendment + the `IMPLEMENTATION-CONTRACT.md` §3 shape (decision) → **S3b**
(classification quality: fallback flip, per-message detection, `finance`/`shipment` sub-kinds;
deterministic, no model) → **S4b** (expose the existing per-sender override in the Today row menu + reader,
inheriting per-message-first) → **S5** (tail) → the mutation job, where **S8** gives `finance` its
disposition safety. The reader original-HTML pane (§25) stays M6.

**Relates to:** §24 (extends the fifth-rung amendment and the override-status note above), §7 / ADR-0002
(finance disposition safety at S8), §18 (still deterministic, organize-not-judge).

---

## 25. The email Reader renders the original HTML in-app; reader-mode text is a non-starter — RESOLVED (build targeted M6)

Raised 2026-09-18 from the M5 reader spike device pass (PR #43). §20 resolved that the Reader renders
the substance Cockpit holds inline and left **"HTML-vs-plain rendering fidelity" explicitly undecided**.
The M5 body-legibility work (S2/S2b) chased that fidelity by *flattening* HTML to normalized text; the
spike then built a second option — a structured "reader-mode" re-render of the email in Cockpit's own
type (SwiftSoup → house components) — beside a WKWebView showing the sanitized **original**. Jon's device
pass settled it: **for HTML email the reader-mode re-render is a non-starter, and flattening to text is
"meh."** A designed email's value is partly its design; a plaintext or re-typeset version throws that
away. The original is what he wants to see.

**Decision (email branch of §20):** for `kind == .email`, the Reader renders the **held original HTML**
(`Artifact.rawSourceText`, already retained and device-local) in an **in-app WKWebView**, by default —
not normalized text, not a re-render. Reader-mode structured re-rendering is **dropped**, not deferred.
The non-email path (RSS/newsletter text) keeps §20's held-normalized-text render unchanged; this entry
resolves only the email fidelity question §20 left open.

**How this revises §20's "not a browser" boundary — a scoped, mitigated crossing.** §20 drew a hard line:
"No JavaScript, no navigation, no cookies, and no live fetch-and-scrape." Rendering the original in a
webview keeps most of that line and crosses one part of it deliberately:

- **Kept:** JavaScript **off** (`allowsContentJavaScript = false`); **navigation blocked** (only the
  initial `loadHTMLString`; user link taps cancelled — email links are untrusted); **no cookies/storage**
  (`WKWebsiteDataStore.nonPersistent()`); **no live fetch-and-scrape of the source page** — we render only
  HTML Cockpit already holds. It is still not a browser.
- **Crossed, on purpose:** the webview **loads remote subresources** (images/fonts) for fidelity, which
  §20's "no remote fetch" forbade. This is the accepted cost of showing the real design, and it is what
  makes tracking mitigation (below) matter. `teaser`/body-less pieces still fall to **Open Original**, and
  Open Original remains the honest fallback everywhere §20 named it.

**Interaction conclusions (from the spike; Today stays the base).** Today remains the full-width
orientation surface (§24; `TODAY-EXPERIENCE.md` §5.1). The email opens as a **large, near-full-iPad pane**
— as close to a Mac Mail detail view as the presentation allows — not a split-view sidebar and not a small
sheet: Jon wants to minimize scrolling, expanding, and timing. Conclusions to build to: open **directly
large** (no medium-detent expand step); a **zoom transition** (row expands into the pane) for a fast,
direct feel over a heavy slide-up; and **preload on tap** — a warm, reused WKWebView on a shared process
pool with `loadHTMLString` fired the instant the row is tapped, so content is rendering as the open
animation completes (the WebContent process spin-up, not the local HTML, is the latency to hide). These
supersede §5.1's "push" wording for the email reader; the architect updates that note when the slice lands.

**Tracking mitigation — layered, no server.** Jon accepts loading pixels but asked whether something
smarter exists. It does, and it needs no server (which the no-server law forbids anyway):

- **Now (cheap):** the non-persistent data store (no cross-email cookie correlation) + stripping obvious
  1×1 / hidden / zero-area tracking-pixel `<img>` before load (SwiftSoup), while keeping real imagery and
  `<style>`/`<head>` (full fidelity, not text extraction).
- **Smart upgrade (M6+):** `WKContentRuleList` — Safari's content-blocking engine, attachable to any app's
  WKWebView **in-process, with no separate App Extension target** — loaded with a community tracker list
  (**EasyPrivacy** or **DuckDuckGo Tracker Radar**), either bundled as prebuilt content-blocker JSON or
  converted from EasyList syntax via **AdGuard's open-source `SafariConverterLib`** (Swift). Compile once
  and cache via `WKContentRuleListStore`; refresh the snapshot as a later nicety. This upgrades "strip the
  dumb 1×1 beacon" to "block known tracker *domains*" while legit design images still load. DuckDuckGo's
  Apache-2.0 iOS app is the reference implementation. No server-side image proxying (Apple/Gmail-style) —
  it would violate the no-server law.

**Boundaries preserved.** Rendering held HTML is deterministic display, not judgment (AI boundary intact).
Custody is unchanged (§16 / ADR-0001 D6: `rawSourceText` and the render are device-local; nothing new
syncs). The S2b normalizer stays — it still serves the non-email path, classification, extraction, and
search — and the **S2b backfill floor-fix is independent** of this and can land anytime.

**Sequencing.** Build is **targeted for M6.** M5 remains Today-surface + Phase-4 dispositions; the reader
overhaul is not smuggled into it. The M5 reader spike (PR #43) is the evidence and is kept or discarded
once this is built for real. The `WKContentRuleList` tracker-blocking upgrade may be its own M6 slice or a
later refinement — not a blocker for the original-HTML pane.

**Not decided here:** final pane geometry and animation tuning (device pass); whether remote-content load
defaults on or behind a "Load Remote Content" control in the shipping version; and the exact M6 slice
split (pane vs. tracker-blocking).

**Relates to:** §20 (resolves its open email-fidelity question; scoped revision of its remote-fetch
boundary), §16 / ADR-0001 D6 (custody unchanged), §24 (Today stays the base surface), §11 (jon-platform
no-server law — rules out proxying). Live docs: `docs/TODAY-EXPERIENCE.md` §5.1, `docs/IPAD-FIRST-EXPERIENCE.md`
§7, `docs/milestones/` (M6, when authored).

**Amendment (2026-09-22, Jon, reader dogfooding) — links open outside Cockpit.** Blocking every link tap
made unsubscribe links and article links unusable. A **user-activated** tap on an `http`, `https`, or
`mailto` link now opens in the system browser/mail app; the web view itself still performs only the
initial `loadHTMLString` and never navigates, and every other scheme or navigation stays cancelled. The
webview is still not a browser. Slice: `docs/milestones/M6-reader-dogfood-slices.md` S-r3.

---

## 26. Narrow reply: plain text, in thread, to the sender — RESOLVED (2026-09-22, Jon)

**Evidence.** Dogfooding Today's reading queue, Jon triages personal mail in Cockpit and then has to
remember to go to his mail client to answer it. The triage loop is broken at exactly the messages that
matter most.

**Decision.** Cockpit may send a **plain-text reply to the sender, in the original Gmail thread**, from
the Reader, for Gmail pieces in the For you and Transactional roles. The body is written by Jon; no model
drafts or edits it. Recipient is `Reply-To` or `From`; threading uses `In-Reply-To`/`References` and the
Gmail `threadId`. Sending uses the already-granted `gmail.modify` scope. Sending is never retried
automatically. Cockpit keeps no drafts and no sent-mail record — Gmail is the record.

**Still out (the "broad reply/composition" exclusion stands).** Reply-all, CC/BCC, forwarding, new
compose, attachments, rich text, drafts, templates, signatures, send-later, AI-drafted replies, and
reply on newsletter roles. Any of these needs its own decision.

**Relates to:** ADR-0002 D7 (out-of-V1 list now points here), V1-SCOPE out-of-scope list, AGENTS.md Gmail
boundary. Slice: `docs/milestones/M6-reader-dogfood-slices.md` S-r5.

---

## 27. Gmail's Promotions tab: read new mail only, with no source list, into Offers — RESOLVED (2026-09-26, Jon)

**Evidence.** The offers Jon wants to sift for Finds arrive in Gmail's Promotions tab, which Cockpit
has never read. Every Gmail read is scoped to `category:primary` (ADR-0002 D2). The offer pipeline
behind the read already works: the Offers role, the on-device offer summary, its one proposed Find,
and the S-r6 barrier. Only the intake is missing. Jon keeps his promotional senders under tight
control upstream by unsubscribing, the traffic is modest, and he doesn't want to maintain a second
source list inside Cockpit.

**Decision.** Cockpit reads Gmail's Promotions tab next to Primary, **new mail only**.

- **Scope.** Inbox mail in `category:promotions` that was received after a fixed **Promotions epoch**:
  the moment of the first sync that knows about Promotions. The existing ~16k Promotions messages are
  not backfilled. Nothing older than the epoch ever enters, even when a later label change (Jon reads
  or archives an old promo in Gmail) puts it into the history feed. The epoch never moves once it is
  set.
- **No source list.** Every Promotions message after the epoch is read. Jon's unsubscribing is the
  curation. Cockpit adds no allowlist, blocklist, or opt-in step.
- **Placement.** A Promotions message with no explicit routing rule lands in **Offers**, not For you.
  Every existing routing input still wins over that default: a followed Stream, a List-ID or sender
  rule, a mute, and the transactional classification. A promo sender can be moved to Food or Wine, or
  muted, with the controls that exist today. Mute is the "stop showing me this sender" tool.
- **Same sync, same cursor.** Promotions rides the Primary `historyId` delta. The history feed is
  already account-wide, so the only change is membership: Primary ∪ Promotions-since-epoch. The added
  quota cost is one `messages.list` per sync plus one `messages.get` (20 units) per new promo. This
  amends ADR-0002 D2's "own budget and cadence" for Promotions only. Forward-only reading at this
  volume doesn't need its own cadence.
- **Disposition unchanged.** Nothing is automatic. Archive and Trash stay per-action, and an offer's
  Trash stays behind S-r6's confirmed-Find barrier. An auto-trash policy for promos would be a new
  explicit policy under §7 / ADR-0002 D7, not part of this entry.

**Still out.** Social, Updates, and Forums. Any Promotions backfill. A separate Promotions cadence or
budget. A promo sender list, allowlist, or opt-in.

**Re-open when** Promotions makes Offers noisy enough that Jon mutes senders faster than he
unsubscribes, or it measurably slows the delta sync. The fix then is a sender allowlist or its own
cadence, and not before.

**Relates to:** ADR-0002 D2 (amended), §7, §24 (Offers role), the M6 deferred ledger's "Promotions/Social
at scale" row (Promotions now scheduled; Social stays deferred). Slice:
`docs/milestones/M6-today-additions.md` S-t3.

---

## 28. Gmail read state: shown in Cockpit, and set to read when Jon opens a message — RESOLVED (2026-09-26, Jon)

**Evidence.** Jon wants to see at a glance which messages he has read, the standard mail-client
de-bold. §7 left read/unread as separate provider state, and Cockpit has never shown or set it. It
reads each message's labels and then discards `UNREAD`. Showing Gmail's state alone isn't enough.
Without write-back, anything Jon reads in Cockpit stays bold in both Gmail and Cockpit.

**Decision.**

- **Show it.** Cockpit mirrors Gmail's `UNREAD` label for each Gmail message and renders unread rows
  in bold in Today's sections and the reading queue. A ContentPiece is unread when any of its Gmail
  Artifacts is unread. The normal delta sync refreshes the mirror (a label change is already a
  history event that re-reads the message), so a message read in Mail.app de-bolds on the next sync.
- **Set it on open.** Opening a Gmail piece in Cockpit's Reader marks it read in Gmail with
  `messages.modify` removing `UNREAD` (5 units, under the `gmail.modify` scope Cockpit already has).
  The call is only made when the mirror says unread. It counts as an open when the Reader shows the
  piece, including when the queue auto-advances to it after a disposition, the way Mail behaves.
- **Reversible.** The Reader offers **Mark as Unread**, which re-adds `UNREAD`.
- **Still not attention state.** Clear, Dismiss, Archive, and Trash don't mark anything read, and
  marking read doesn't clear, dismiss, or remove anything from Today. Read state never feeds judgment,
  ranking, Personal Knowledge, disposition policy, or Today membership. Non-Gmail pieces (RSS) have no
  read state, and Cockpit doesn't invent one.
- **Failure is quiet.** The write is best-effort: on failure the row stays bold and the next open
  tries again. There's no retry queue and no error banner.

**Amends §7**, whose first paragraph now reads with this entry: Cockpit owns its own attention state.
Gmail read/unread is still provider state, which Cockpit now mirrors and sets when Jon opens a message.

**Relates to:** §7, ADR-0002 D1 (the message is the unit, so only the piece's own messages are marked,
never the whole thread) and D5 (a fourth, non-destructive label operation), `TODAY-EXPERIENCE.md` and
`EMAIL-INTELLIGENCE-MODEL.md` ("read/unread is not canonical attention state" still holds). Slice:
`docs/milestones/M6-today-additions.md` S-t2.

---

## 29. Daily links: a short list of places to visit each day, beside Today — RESOLVED (2026-09-26, Jon)

**Evidence.** Jon has a few places he means to visit every day, including at least two Apple News
channels. Apple News has no reader-side API: the Apple News API is publisher-only, and there's no
public access to followed channels, history, or article lists, or to News+ content. A channel's
share link (`https://apple.news/…`, from Share → Copy Link in News) does open that channel in the
News app. A link is the whole integration available.

**Decision.** Cockpit keeps a short, **Jon-authored, ordered list of Daily links**. It appears as a
narrow icon column on the trailing edge of Today's landing surface in regular width, and as a toolbar
menu in compact width.

- A Daily link is a title, a URL (`http`/`https`, which covers `apple.news`), an icon chosen from a
  small curated set of SF Symbols, an order, and a last-visited time. Jon manages the list in
  **Settings → Daily links**: add, edit, reorder, delete.
- Tapping a link opens it through the system: `apple.news` links go to News, web links go to Safari.
  The tap records a visit. The icon dims for the rest of the local calendar day and comes back the
  next day. That is the whole attention model: a daily checklist, not a feed.
- **Boundaries.** A Daily link is not a Stream, a ContentPiece, a Find, or a Later or Library item.
  Cockpit never fetches, scrapes, previews, or judges a link's destination, and visits never become
  Personal Knowledge or judgment input. There are no folders, tags, or import: it isn't a bookmark
  manager. If Jon wants a source's stories inside Cockpit, the answer is to follow its RSS feed as a
  Stream.

**Why a new table is justified (AGENTS.md persistence discipline).** It has user-authored identity,
an explicit order, a daily visited lifecycle, and one query (the ordered list with visited-today).
None of the existing nouns fits without bending it.

**Relates to:** §24 (Today stays orientation; this is orientation, not curation), the AGENTS.md AI
boundary. Slice: `docs/milestones/M6-today-additions.md` S-t4.

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
