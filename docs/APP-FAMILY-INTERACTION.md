# Cockpit App-Family Interaction

**Status:** Normative cross-app boundary  
**Date:** 2026-09-08

Cockpit participates in the Jon Universe without becoming its universal database or workflow hub.

The family model has two deliberately different directions:

```text
specialist app → small Current Context projection → Cockpit

Cockpit Find → receiver-owned admission boundary → specialist app
```

Do not collapse these into a universal family queue or entity graph.

---

## 1. Specialist apps publish current context

A specialist app may publish a small read-only projection of state that helps Cockpit judge relevance.

Examples:

- Galavant: active/upcoming trip, destination, timing, perhaps small trip-intent summary;
- Yes Chef: near-term cooking/meal context if a concrete Cockpit use eventually appears.

The projection should be intentionally smaller than the specialist app's canonical database.

Cockpit consumes awareness; it does not acquire ownership of the specialist domain.

---

## 2. Current Context is not Personal Knowledge

A current trip to Paris may make Paris restaurant/news content highly relevant.

That does not mean Cockpit should create durable Personal Knowledge saying Jon is permanently focused on Paris.

Current Context is temporary, refreshable, and may disappear naturally when the specialist context changes.

A durable Interest/Taste requires separate explicit teaching/confirmation.

---

## 3. Finds travel outward

A Find is something Cockpit identifies within/because of a ContentPiece that belongs conceptually to another domain.

Examples:

```text
restaurant Find → Galavant
recipe Find     → Yes Chef
product Find    → Pending until a suitable owner exists
```

Cockpit should pass:

- faithful descriptive material;
- provenance/source context;
- relevant evidence/excerpt;
- Cockpit interpretation/why it mattered;
- user intent to consider/admit;
- lightweight hints that help the receiver.

The receiver owns:

- canonical domain identity;
- deduplication;
- validation;
- canonical persistence;
- acceptance/rejection;
- domain-specific enrichment.

---

## 4. No universal ontology

Cockpit must not create a family-wide `Thing` so a restaurant, recipe, bottle of wine, product, article, and event can all fit one abstraction.

The point of specialist apps is that their domain semantics differ.

A restaurant described in Cockpit remains descriptive/evidence until Galavant admits/resolves it into Galavant's own canonical model.

---

## 5. Pending Finds bridge missing apps

When no suitable receiver exists, Cockpit may retain a lightweight Pending Find.

Examples may include:

- pantry products;
- wine recommendations;
- travel clothing;
- gear;
- books/products in a domain that has not yet earned a specialist app.

Pending Finds preserve enough information to remain useful and later hand off cleanly. They do not justify building Shopping/Consumption/Cellar/Product schemas in Cockpit.

The accumulated shape of orphan Finds is legitimate evidence for what app the Jon Universe should build next.

---

## 6. Handoff is an admission request, not shared ownership

A handoff should conceptually mean:

> Cockpit believes this material is relevant to your domain and Jon wants you to consider it.

It must not mean:

> Cockpit has already decided the receiver's canonical object identity/state.

The receiver may:

- accept;
- reject;
- merge with an existing object;
- ask for clarification/review;
- normalize/reinterpret fields according to its domain.

---

## 7. First handoff implementation

V1 should implement exactly one real receiver end-to-end, chosen by whichever current app exposes the cleanest admission boundary at implementation time.

Do not create a generalized handoff framework first.

After the first receiver, inspect what data was actually useful. A second receiver is the earliest credible evidence for shared family handoff infrastructure.

---

## 8. Personal Knowledge sharing

Cockpit is the primary stewardship surface for Personal Knowledge in V1.

Long term, other apps may benefit from task-specific projections or shared physical ownership.

Do not prebuild `PersonalKnowledgeKit` or a family-wide PK store. Implement Cockpit's real requirement locally behind a movable seam and extract only after a second consumer proves shared semantics.

---

## 9. Infrastructure that deliberately waits

Do not build in V1 merely for conceptual completeness:

- Family Context Store;
- shared family queue;
- universal envelope;
- family entity graph;
- generic notification bus;
- App Group acceleration;
- shared `FamilyContextKit`;
- generalized `HandoffKit`;
- two-way cross-app canonical synchronization.

Use the smallest concrete projection/handoff that proves the real consumer relationship.

---

## 10. Cross-app principle

> **Share context, not ownership. Hand off candidates, not canonical truth. Extract infrastructure only after repeated real consumers prove it.**
