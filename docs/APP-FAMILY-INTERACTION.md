# App-Family Interaction: Published Context and Handoff

**Status:** Working product/architecture decision  
**Date:** 2026-09-06

## Purpose

Cockpit belongs to a family of specialist applications such as Galavant and Yes Chef. The family should cooperate without collapsing their domain models into one shared database and without requiring Cockpit to poll or understand each specialist's canonical schema.

This document separates two different cross-app jobs that should remain distinct:

1. **Publication / awareness** — a specialist tells the app family what is currently relevant in its domain.
2. **Handoff / intent** — Cockpit asks a specialist to accept some incoming material for later domain-specific handling.

The governing principle is:

> Specialist applications publish small read-only projections of current context and accept incoming material through receiver-owned admission doors. Canonical specialist data remains private to the specialist.

This extends the product principle in `PRODUCT-MODEL.md` that specialist applications remain specialists.

---

## 1. Publication and handoff are different directions of travel

### Publication: "Here is what is currently going on"

Publication exists so Cockpit can understand current life context without interrogating another app's database.

Conceptually:

```text
Galavant ----\
              \
Yes Chef ------> Family Context ----> Cockpit
              /
Future App ---/
```

Examples:

- Galavant publishes an upcoming Burgundy trip and the dates/regions currently relevant to it.
- Yes Chef publishes an upcoming dinner menu and the date/occasion currently relevant to it.
- A future specialist might publish a current listening project, wine event, home project, or other bounded context.

Cockpit consumes these publications when doing Daily, Discover, relevance ranking, and other context-sensitive reasoning.

### Handoff: "Please accept this over there"

Handoff is a request to a specialist application.

Conceptually:

```text
Cockpit
   |
   | Add to Galavant / Add to Yes Chef
   v
receiver-owned admission door
   v
specialist incoming queue or review boundary
```

Handoff should not mean that the user must leave triage mode and immediately complete the specialist workflow.

A recipe sent to Yes Chef may simply enter a Yes Chef incoming queue. A place sent to Galavant may enter a consideration queue. The receiving app decides how and when that material is processed into canonical domain state.

### Product principle

> Publication provides awareness. Handoff expresses intent. Neither gives Cockpit ownership of specialist canonical data.

---

## 2. Cockpit should not poll specialist canonical databases

Cockpit should not learn Galavant's `Trip`, `TripIdea`, `Stop`, `Stay`, or reservation schema in order to determine whether a trip is relevant.

Likewise, Cockpit should not learn Yes Chef's menu, recipe, meal-plan, or workbench schema merely to discover that a dinner is coming up.

Instead, each producer publishes the smallest projection that is useful outside its own domain.

This creates an intentional anti-corruption layer:

```text
specialist canonical model
          |
          | derive
          v
published context projection
          |
          v
     app-family consumers
```

The publication is derived, replaceable, intentionally lossy, and read-only from the consumer's perspective.

A specialist may completely redesign its canonical schema while preserving the publication contract.

### Product principle

> Publish what the family needs to know, not the specialist database the family could theoretically inspect.

---

## 3. Published Contexts are current-life projections, not tasks

The family vocabulary should not assume that every published thing is an action or task.

A trip is not a task. A menu is not a task. A current cultural interest is not necessarily a task.

The provisional term is **Published Context**.

Examples:

### Galavant

A first useful trip publication might contain only enough information for Cockpit to understand relevance:

```text
Burgundy
May 8–14, 2027
status: planning
regions: Beaune, Côte de Nuits
```

Later, a real Cockpit requirement might justify selected additional context such as lodging locality or known dinner reservations. Those additions should be earned by product use rather than copied from Galavant's schema by default.

### Yes Chef

A first useful menu publication might contain:

```text
Dinner with Smiths
September 19
menu: lamb, corn, tomato salad
```

This may be enough for Cockpit to recognize that an incoming lamb recipe, wine offer, or entertaining article is unusually timely.

The publication does not need to tell Cockpit how Yes Chef stores dishes, recipe IDs, prep plans, or menu ordering.

---

## 4. Publications should be snapshots, not live remote queries

The desired behavior is producer-driven publication plus consumer-side reading of the latest available snapshot.

Conceptually:

```text
specialist canonical mutation
        |
        v
recompute relevant publication
        |
        v
publish latest snapshot
```

Cockpit later does:

```text
Daily / Discover / reasoning task
        |
        v
read latest family publications
        |
        v
reason against current context
```

Correctness should not depend on another application being awake or launchable at query time.

This makes the system robust to ordinary iOS background-execution limits and to cross-device use.

### Product principle

> Push current context outward; read the latest snapshot when needed.

The implementation may eventually support change notifications, but instantaneous notification is an optimization rather than the semantic contract.

---

## 5. Cross-device awareness is a real requirement

The same-device case is not sufficient.

A common use case is:

```text
iPad:  plan Burgundy in Galavant
       |
       | sync/publication
       v
iPhone: open Cockpit the next morning
```

Cockpit should understand that Burgundy is current context even if Galavant has never been opened on that iPhone since the trip was edited.

Therefore an App Group alone is unlikely to be the complete publication substrate. Same-device shared storage may be useful, but the family model needs a synchronized cross-device representation.

The current implementation hypothesis is a **small shared app-family CloudKit context store** separate from each specialist's canonical database.

Conceptually:

```text
Galavant canonical CloudKit
          |
          | derived publication
          v
     Family Context Store
          ^
          | derived publication
          |
Yes Chef canonical CloudKit
```

Cockpit reads the Family Context Store. It does not gain general read access to Galavant or Yes Chef canonical storage merely because the same developer owns all three apps.

This is an implementation hypothesis, not yet a schema commitment.

---

## 6. App Intents are primarily doors and commands

App Intents/App Entities are a strong candidate for receiver-owned handoff operations and for bounded destination selection.

Examples:

- `Add to Yes Chef`
- `Consider in Galavant`
- select a Galavant trip when a destination must be chosen
- accept recipe material into a Yes Chef incoming queue

They should not automatically become the persistent pub/sub substrate for current family context.

The architectural distinction is:

- **Published Context Store:** persistent ambient awareness.
- **App Intent / receiver operation:** active request or command.

This also keeps handoff producer-agnostic: a receiver-owned App Intent may eventually be invoked by Cockpit, Shortcuts, another family app, or another system surface without exposing the receiver's internals.

---

## 7. Handoff should normally terminate in a specialist incoming queue

Cockpit is often operating in triage mode.

The interaction:

> Add this to Yes Chef

should usually mean:

> Yes Chef now has this material waiting for me when I am ready to cook/design the recipe.

It should not mean:

> Leave Cockpit now and decide ingredient sections, instruction structure, or other domain details.

Likewise:

> Add this to Galavant

may simply enqueue a place worth considering rather than forcing immediate POI resolution or trip scheduling.

Each specialist owns its queue semantics:

- what an incoming item contains,
- whether it is durable,
- how it is grouped,
- when it becomes canonical,
- what review/admission step is required,
- how duplicates are handled.

### YAGNI rule

> Do not design a universal family queue yet.

Yes Chef's queue and Galavant's queue may eventually expose a common seam, but that should be discovered after both are real rather than designed from Cockpit outward.

---

## 8. Specialists may publish queue summaries if Cockpit has a real use for them

A specialist's incoming queue is not automatically part of Cockpit's awareness model.

If a later product need emerges, a specialist may publish a small queue summary such as:

```text
Yes Chef
3 incoming items waiting for review
```

or:

```text
Galavant
2 places waiting for consideration
```

Cockpit should still not inspect or manage the specialist queue directly.

The specialist decides what queue state is appropriate to publish.

---

## 9. Published contexts should have bounded relevance and natural expiry

The Family Context Store should not become a second historical warehouse.

Published contexts represent what the producer says is currently useful to other apps.

A trip eventually ends. A menu service date passes. A short-lived planning context becomes irrelevant.

The producer should be responsible for replacing, retiring, or naturally expiring its publications as its canonical state changes.

A publication may need concepts such as:

- producer,
- publication kind,
- producer-owned opaque identity,
- updated timestamp,
- relevant date/window,
- schema/version marker,
- producer-defined payload.

Those fields are illustrative, not a ratified shared schema.

The key principle is:

> Current family context is a materialized projection, not an append-only family history.

Cockpit may retain its own derived knowledge where product semantics require history; the shared publication substrate need not provide it.

---

## 10. Specialist sovereignty still governs handoff

The Cross-App Handoff principles remain intact:

- the receiver owns canonical identity,
- the receiver owns deduplication,
- the receiver owns validation and admission,
- the receiver owns its queue/review workflow,
- Cockpit sends faithful source material, provenance, interpretation, and user intent,
- Cockpit does not write specialist canonical database records directly.

Handoff is promotion into another domain, not migration out of Cockpit.

Cockpit may continue to retain the Subject, source evidence, relevance rationale, and watch relationship after a specialist accepts the material.

---

## 11. Exact real-world identity remains lazy

Published context and handoff should not force Cockpit to become a master POI reconciliation database.

Cockpit may maintain useful entity understanding sufficient to accumulate evidence around a likely same Subject, but exact provider identity should be resolved only when a downstream operation requires it.

For example:

- Cockpit may understand that `Terra Restaurant` and `Terra – The Magic Place` are related/same-establishment context without forcing Apple Maps resolution during Daily.
- A Galavant admission flow may later perform exact map-place resolution because precise place identity is part of Galavant's domain responsibility.

### Product principle

> Entity-resolution uncertainty must not turn Daily into data cleanup.

Human POI disambiguation is an exceptional fallback at a consequential edge, not routine Cockpit triage.

---

## 12. Do not build a universal family ontology

The shared context mechanism must not become an excuse to mint abstractions such as:

```text
UniversalItem
UniversalActivity
UniversalProject
UniversalTrip
UniversalMenu
```

The family layer transports deliberately small projections.

Galavant owns travel semantics. Yes Chef owns cooking/menu semantics. Cockpit owns awareness, relevance, and its own Subjects/Artifacts/Personal Model.

If multiple real publications later reveal a small stable common envelope, extract only that stable envelope.

Producer-specific payload semantics should remain producer-specific unless repeated evidence proves otherwise.

---

## 13. Platform extraction stance

This is one of the first Cockpit requirements that necessarily involves multiple real applications: Galavant and Yes Chef must publish before Cockpit can consume.

That makes a shared transport seam plausible earlier than many other Cockpit abstractions.

However, the correct next step is still **not** to invent a generic `FamilyContextKit` API in advance.

First implement one real Galavant publication and one real Yes Chef publication. Observe:

- what metadata is genuinely common,
- whether CloudKit sharing mechanics are identical,
- how producers replace/expire publications,
- how schema/version changes are handled,
- whether same-device App Group acceleration is useful,
- whether consumers need notifications or merely latest-state reads.

Only then decide what belongs in `jon-platform`.

The same rule applies to incoming queues: build specialist-owned queues first; extract queue infrastructure only if repeated implementation proves a stable shared shape.

---

## 14. Current family model

The working architecture is:

```text
                         READ / AWARENESS
                 +--------------------------+
                 |   Family Context Store   |
                 +--------------------------+
                    ^          ^          ^
                    |          |          |
                 publish    publish    publish
                    |          |          |
                Galavant    Yes Chef    future apps

                               |
                               v
                            Cockpit
                               |
                               | WRITE / INTENT
                               v
                      receiver-owned App Intents
                         /                 \
                        v                   v
                 Galavant queue       Yes Chef queue
                        |                   |
                        v                   v
                 Galavant admission   Yes Chef admission
                        |                   |
                        v                   v
                 canonical travel     canonical cooking
```

### Summary

- **Family publications:** "Here is what is currently relevant in my domain."
- **Cockpit consumption:** "Use that current context to understand what matters now."
- **Handoff:** "Please accept this incoming thing for later specialist handling."
- **Specialist queue:** "It is waiting here until the user is ready to work in this domain."
- **Canonical commit:** always owned by the specialist.

This allows Cockpit to become the family's ambient awareness layer without becoming the database, workflow engine, or UI for every specialist application.

---

## 15. Open implementation questions

These are deliberately not settled by this document:

1. Exact shared CloudKit container/schema design for Family Context.
2. Whether same-device App Group storage should supplement the cloud publication store.
3. How producers trigger publication recomputation without coupling every canonical write to network availability.
4. Whether Cockpit needs change notifications or only fresh reads at Daily/Discover boundaries.
5. The minimum first Galavant `PublishedTripContext` payload.
6. The minimum first Yes Chef `PublishedMenuContext` payload.
7. Whether publication identity needs a cross-device stable opaque producer ID beyond producer + kind + domain identity.
8. How family context behaves if one specialist app is uninstalled or stops publishing.
9. Exact App Intent contracts for specialist incoming queues.
10. Whether any queue or publication mechanics eventually earn extraction into `jon-platform`.

These questions should be answered from the first real Galavant and Yes Chef workflows rather than by designing a generalized family framework in prose.
