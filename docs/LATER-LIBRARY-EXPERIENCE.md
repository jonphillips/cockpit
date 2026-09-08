# Cockpit Later and Library Experience

**Status:** Normative V1 product direction  
**Date:** 2026-09-08

Later and Library represent two different user intentions around the same underlying ContentPiece identity.

```text
ContentPiece
    ├── Later membership
    └── Library membership
```

They are not duplicate content stores.

---

## 1. Later

Later means:

> **I want this, but not now.**

### Laws

- admission is explicit;
- nothing enters automatically;
- nothing silently expires;
- Later is not a task queue;
- removing Later membership does not destroy the ContentPiece when another relationship/provenance still requires it.

### V1 behavior

- Save for Later from Edition/Reader;
- simple browse/open;
- remove from Later;
- Add to Library;
- local offline controls;
- perhaps simple date/source metadata.

Do not build cleanup intelligence before a real backlog exists.

### Deferred

- default sort sophistication;
- filters/facets;
- age/count cleanup thresholds;
- bulk cleanup;
- reminders/nudges;
- backlog analytics.

Cockpit should avoid turning Later into another guilt-producing inbox.

---

## 2. Library

Library means:

> **This ContentPiece is worth retaining as durable reference.**

**Library contains ContentPieces only.**

It does not contain canonical restaurants, wines, products, recipes, hotels, people, places, events, or other extracted domain things. Those are Finds destined for specialist apps or Pending Finds.

### V1 behavior

- explicit Add to Library;
- simple browse;
- search;
- useful metadata/provenance;
- summary/enrichment;
- Subjects where helpful;
- remove from Library;
- offline controls;
- durable custody for uploaded sole-source material;
- one explicit prospective Stream auto-Library policy after manual flow works.

### Retrieval posture

Start with ordinary text search, metadata, provenance, and lightweight Subjects.

Do not introduce embeddings/vector infrastructure merely because semantic retrieval sounds attractive. Add it when real Library corpus queries expose a meaningful gap.

Folders/collections and rich facets should also wait for demonstrated use.

---

## 3. Edition/Later/Library independence

A ContentPiece may move among relationships without changing identity.

Example:

```text
Andrew Harper report

Edition: yes
Library: yes (Stream policy)
Later: no
```

Jon saves it for a flight:

```text
Edition: resolved
Library: yes
Later: yes
Offline until Oct 8: yes on this iPad
```

After reading:

```text
Later: no
Library: yes
Offline: may expire according to explicit date
```

No copies or identity migration should be required.

---

## 4. Automatic Library admission

Edition and Library admission are independent.

A Stream may be configured prospectively to add qualifying future ContentPieces to Library even when Edition remains selective.

Example:

```text
Andrew Harper
Edition: selective
Library: all qualifying future reports/issues
```

V1 requirements:

- explicit policy;
- prospective only;
- no automatic historical backfill;
- manual Add to Library implemented/trusted first.

---

## 5. Library custody is source-sensitive

Library is a durable reference promise, not universal byte-level archival.

### Reliable upstream material

For Gmail-backed material with substantive content in Gmail, Cockpit may retain identity/provenance/summary and fetch the original on demand.

### Uploaded sole-source files

Cockpit must preserve payloads durably.

### Web/RSS text

Cockpit may retain normalized readable text when useful for durability/search/offline, without promising exact source presentation.

### Hosted media

Library does not imply downloading/storing complete YouTube video or podcast audio forever.

If an upstream source becomes unavailable, Cockpit reports degradation according to what it actually retained.

---

## 6. Offline availability

Offline state is independent of Later/Library membership.

### Automatic cache

Expendable; Cockpit may evict.

### Offline until [date]

Explicit temporary local promise, likely 30 days by default in V1.

The expiry must be visible/understandable. At expiry only the local redundant payload is removed.

### Keep Offline

Explicit indefinite local promise until Jon removes it.

Cockpit must not silently evict it.

This applies whether the ContentPiece is in Later, Library, or simply being prepared for near-term reading.

---

## 7. Finds do not enter Library

Suppose a travel newsletter produces a recommendation for travel shorts.

The newsletter issue may be a Library ContentPiece.

The shorts recommendation is a Find. It may be handed to a future specialist app or held as a Pending Find with sufficient descriptive/evidence context.

Do not solve the missing app by putting the product itself into Library or inventing a universal entity system.

---

## 8. Search and Subjects

Library should preserve enough semantic understanding to support useful browsing and search without turning Subjects into a universal entity graph.

Subjects may be lightweight derived enrichment attached to ContentPieces.

Do not build alias/merge/hierarchy machinery until actual retrieval failures require it.

---

## 9. Removal semantics

Removing from Later removes deferred-attention membership.

Removing from Library removes durable-reference membership.

Neither operation should automatically destroy underlying Artifact/provenance or Pending Find evidence still required by another product promise.

Physical payload cleanup should follow custody/lifecycle rules rather than be conflated with membership toggles.

---

## 10. V1 must prove

- Later feels like benign deferral rather than a second inbox;
- Library feels durably trustworthy without requiring universal payload duplication;
- same ContentPiece identity works across Edition/Later/Library;
- search is useful with simple metadata/text/Subjects;
- one Stream auto-Library policy works prospectively;
- offline temporary/indefinite guarantees are understandable and reliable.

The first substantial cleanup/facet/vector feature should come from actual use, not preemptive design.
