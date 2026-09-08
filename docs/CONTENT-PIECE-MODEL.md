# Cockpit ContentPiece, Find, Custody, and Offline Model

**Status:** Normative domain decision  
**Date:** 2026-09-08

This document defines the smallest current content spine. It intentionally refuses a universal ontology.

---

## 1. Artifact

An **Artifact** is concrete source material Cockpit received, fetched, imported, or otherwise encountered.

Examples:

- a Gmail message;
- an RSS/Atom entry;
- newsletter content;
- an imported PDF;
- a fetched readable web representation;
- provider metadata for a video or other publication.

Artifacts are principally concerned with:

- provenance;
- provider/source identity;
- authoritative source locators;
- source-side actions;
- custody/reacquisition;
- reprocessing/evidence.

Artifact identity is not the same as the published-content identity shown to the user.

---

## 2. ContentPiece

A **ContentPiece** is Cockpit's stable representation of a distinct piece of published or received material.

Examples:

- article;
- newsletter issue;
- blog/Substack post;
- YouTube video;
- podcast episode;
- report;
- PDF;
- another discrete authored/published work.

`ContentPiece` is an architectural/domain term. UI should normally use the natural concrete noun.

A restaurant discussed in an article is not a ContentPiece merely because Cockpit learned about it through content.

---

## 3. Artifact and ContentPiece are distinct

Cockpit must support the conceptual possibility that:

```text
Artifact A ─┐
            ├── ContentPiece X
Artifact B ─┘
```

or:

```text
Artifact
  ├── ContentPiece / primary publication
  └── Find(s)
```

V1 should not prebuild a generic relationship framework before actual cases require it.

Strong deterministic identity should unify obvious duplicates while preserving all provenance. Uncertain identity should remain uncertain rather than be destructively merged.

In practice this is achieved by *derivation* rather than by merging: `ContentPiece.id` is a UUIDv5 over a canonical identity string, so the same item arriving through two Streams — or ingested independently on two devices — lands on one row without any merge operation. See `docs/ADR-0001-PERSISTENCE-AND-EXECUTION.md` D3. Merging remains reserved for genuinely uncertain cases, where the conservative posture above still applies.

---

## 4. Edition, Later, and Library memberships

Do not create separate Edition/Later/Library copies of content.

Conceptually:

```text
ContentPiece
    ├── Edition participation/state
    ├── Later membership
    └── Library membership
```

Edition is temporal/attention-oriented. Later and Library are durable memberships with different intent.

ContentPiece identity must survive movement among these relationships.

---

## 5. Library boundary

**Library contains ContentPieces only.**

Examples of valid Library contents:

- Burgundy travel article;
- Andrew Harper report;
- newsletter issue;
- useful video;
- PDF reference document.

Examples of things that should not become Library entries merely because Cockpit discovers them:

- Forestis as a hotel;
- a restaurant;
- bottle of wine;
- recipe;
- travel shorts;
- pantry product;
- person;
- destination.

This is a deliberate architectural boundary against a universal personal database.

---

## 6. Find

A **Find** is something valuable Cockpit identifies within, because of, or while interpreting a ContentPiece.

Examples:

- restaurant recommendation;
- recipe candidate;
- wine recommendation;
- product recommendation;
- hotel;
- event;
- book;
- another domain-specific opportunity.

A Find may carry a broad inferred kind to aid explanation/routing. That does not create a canonical cross-domain ontology.

### Specialist ownership

When a suitable Jon Universe app exists:

```text
Cockpit Find
→ receiver-owned admission boundary
→ receiver decides identity/validation/deduplication/canonical persistence
```

Cockpit supplies faithful source material/provenance, interpretation, and user intent. It does not dictate the receiver's model.

### Pending Finds

A Find may remain Pending when:

1. no suitable receiver exists; or
2. a receiver exists but the user has not chosen handoff/disposition.

A Pending Find should retain enough information to stay useful later:

- useful name/description;
- broad kind;
- originating ContentPiece/provenance;
- relevant source evidence/excerpt when needed;
- why Cockpit thought it mattered;
- source URL/locator;
- lightweight structured hints useful for future admission;
- proposed destination when known.

These are descriptive/evidence hints, not Cockpit-owned canonical Restaurant/Product/Wine/etc. schema.

A product Find might safely retain brand, mentioned price, category hint, source URL, and recommendation rationale without creating a product catalog.

### Weak by design

Do not add rich domain editors, catalogs, inventory, normalized product identity, wine schemas, restaurant databases, domain-specific collections, or universal entity relationships to Pending Finds.

Repeated demand for that richness is evidence for a future specialist app.

### Lifecycle

The minimal conceptual lifecycle is:

```text
Pending → Handed Off
Pending → Dismissed
```

Do not build a complex workflow state machine until use proves one is needed.

A Pending Find may survive removal of the originating ContentPiece from Library. Preserve enough provenance/evidence for the retained Find to remain intelligible.

---

## 7. Custody is promise-based

Cockpit distinguishes:

### Identity

Can Cockpit identify the ContentPiece/source again?

Examples: canonical URL, Gmail message/thread ID, RSS GUID, YouTube ID, file hash.

### Understanding

Does Cockpit retain lightweight semantic knowledge that makes browsing/scanning immediate?

Examples:

- title;
- creator/publisher;
- date;
- provenance;
- summary;
- Subjects;
- why surfaced / relevant interpretation.

### Reacquisition

Can Cockpit reliably retrieve the substantive original again from a provider/source?

### Payload custody

Does Cockpit itself own enough substantive bytes/text to survive upstream loss?

These concerns must not be collapsed.

---

## 8. Source-sensitive custody policy

### Gmail-backed material

Gmail Archive may remain the authoritative repository for ordinary material that exists substantively in the email.

Cockpit should retain stable provider identity plus its own lightweight understanding. It does not need to duplicate every archived newsletter forever.

If Gmail/account access disappears, Cockpit reports degradation. It does not preemptively insure against that scenario by copying all mail.

An email that merely links to subscriber-only external content is different; custody must reflect the substance Cockpit actually has access to rather than assume email completeness.

### Uploaded sole-source material

If the user uploads a PDF/document and Cockpit accepts it into Library without a reliable external original, Cockpit must preserve the payload durably.

A summary/pointer is not sufficient.

### Textual material

Cockpit stores `normalizedText` for **every** ContentPiece with textual substance, at ingest, unconditionally, and indexes it.

The earlier conditional — retain it "when it materially improves durability, search, or offline use" — was always satisfied for anything Library could hold, since Library search is a V1 requirement. A long article is roughly 30KB. The condition bought nothing and licensed inconsistent implementation.

Cockpit still does not promise Internet-Archive-style preservation of exact HTML, layout, or assets unless a product requirement explicitly needs that fidelity. Text is not a payload; the promise-based custody model below governs payloads.

### Hosted media

Adding a YouTube video or podcast episode to Library does not imply storing the media payload forever.

Provider identity, metadata, provenance, transcript where legitimately available/useful, and Cockpit understanding may be sufficient.

---

## 9. Local availability is separate

A ContentPiece can be durably retrievable without being locally available on a particular device.

Likewise a cached local copy does not imply durable custody.

Conceptually:

### Automatic cache

Cockpit may fetch/cache recent or opened material for performance. This is expendable and should never be represented as a user guarantee.

### Offline until [date]

An explicit temporary promise. V1 may start with a 30-day default.

The UI must expose the expiry clearly enough that automatic removal is expected rather than mysterious.

At expiry Cockpit removes only the redundant device-local payload. Membership, metadata, provenance, summaries, and upstream access remain.

### Keep Offline

An explicit indefinite promise on the current device.

Cockpit must not silently evict this material. It remains until the user releases the promise or an unavoidable platform/storage failure is reported explicitly.

### Implementation law

> **Explicit offline availability is a promise, not a cache hint.**

Pinned/offline material must live in app-controlled persistent local storage that Cockpit can verify rather than relying on opaque cloud residency.

---

## 10. Pending Find evidence and custody

A Pending Find does not require preserving the entire originating ContentPiece forever.

It does require enough durable evidence/provenance to answer:

- what was found;
- where it came from;
- why it mattered;
- what information a future receiver would need to evaluate/admit it.

This targeted evidence obligation prevents an orphan Find from becoming a meaningless note while preserving the Library boundary.

---

## 11. Persistence guidance for V1

Before adding schema, preserve these invariants:

- Artifact identity != ContentPiece identity;
- ContentPiece identity != Edition/Later/Library membership;
- Find identity exists only when independent lifecycle/handoff needs it;
- provider/source action state != Cockpit attention state;
- Library membership != payload custody;
- custody != device availability;
- automatic cache != explicit offline promise.

Do not design full many-to-many relationship machinery, universal Item types, universal Subject graphs, or provider-independent archival modes before real source implementations demand them.

---

## 12. Questions delegated to implementation evidence

- Which Artifact↔ContentPiece multiplicities actually occur in RSS/Gmail V1?
- Which canonicalization/fingerprinting rules are required?
- Which web/RSS source classes deserve durable normalized text?
- What exact CloudKit/file design best satisfies uploaded-payload custody?
- What storage accounting/cleanup UX is needed once real offline use exists?
- How often Pending Finds outlive their source and what minimum evidence proves sufficient?

These are build-and-learn questions, not reasons to expand the ontology now.
