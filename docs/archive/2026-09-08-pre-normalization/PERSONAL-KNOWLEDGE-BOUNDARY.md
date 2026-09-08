# Shared Personal Knowledge: Ownership and Stewardship Boundary

**Status:** Working product/architecture decision  
**Date:** 2026-09-06

## Purpose

Cockpit needs a rich understanding of the user, but that knowledge should not be designed as private Cockpit-only state if other applications in the app family will eventually contribute to and consume it.

This document settles the ownership and durability boundary without yet settling the detailed Personal Model claim taxonomy, learning-signal rules, UI, or shared package API.

The governing principle is:

> Cockpit owns the primary user-facing experience of being known. The app family may ultimately own the knowledge.

---

## 1. Shared personal knowledge is not merely a Cockpit feature

The current Cockpit product model describes a Personal Model because Cockpit is the first application that needs broad cross-domain personal understanding.

That should not imply that the canonical knowledge must permanently live inside Cockpit's private database or be accessible only through Cockpit.

Examples of personal knowledge that may have value across the family include:

- important relationships,
- durable interests,
- meaningful preferences and aversions,
- relevant expertise/experience,
- household or person-specific constraints,
- stable circumstances that affect recommendations,
- cross-domain preferences whose usefulness extends beyond the app where they were first observed.

A cooking preference first learned in Yes Chef may eventually matter to Cockpit or Galavant. A travel preference learned in Galavant may eventually matter to Cockpit's discovery and newsletter interpretation.

The family should therefore preserve the possibility that personal knowledge becomes a shared substrate rather than three independent biographies.

---

## 2. Cockpit is the primary stewardship surface

Cockpit is uniquely cross-domain. Its product responsibility includes answering questions such as:

- What does the app family currently believe about me?
- Why does it believe that?
- Which beliefs are influencing this recommendation?
- Is this belief wrong, too broad, stale, or no longer useful?

Therefore Cockpit should provide the primary Jon-facing `You` / Personal Knowledge experience.

This means Cockpit is expected to own the main human-facing workflows for:

- inspection,
- explanation,
- correction,
- reinforcement,
- narrowing,
- retiring/forgetting a belief from active use.

This stewardship role is a product/UI responsibility. It must not be confused with exclusive storage ownership.

### Product principle

> Cockpit is the editorial home of shared personal knowledge, not necessarily its only writer or consumer.

---

## 3. Shared personal knowledge must be durable and cross-device

Personal knowledge is valuable precisely because it compounds over time. It cannot be treated as disposable device-local personalization state.

The architectural requirement is:

> Shared personal knowledge must be backed up/synchronized, durable across ordinary device replacement, and available to authorized family applications on all relevant devices.

A preference learned on an iPad should still be available to Yes Chef on an iPhone and to Galavant on another device without requiring Cockpit to be open or running on that device.

Therefore the long-term architecture must not require another app to invoke Cockpit at runtime merely to retrieve personal context.

The exact persistence mechanism is not decided here. A shared CloudKit-backed substrate is a likely direction because the family is already CloudKit-based and requires cross-device availability, but implementation should be validated against real multi-app participation before the schema is hardened.

---

## 4. Specialist applications may contribute and consume

The eventual family model is conceptually:

```text
                 Shared Personal Knowledge
                    ^       ^       ^
                    |       |       |
                contribute / consume
                    |       |       |
                Cockpit  Galavant  Yes Chef
                    |
                    v
             primary `You` UI
```

Specialist participation should remain narrow and semantically meaningful.

Examples:

- Yes Chef may contribute a durable cross-domain cooking preference after it has been meaningfully established.
- Galavant may contribute a durable travel preference that has usefulness outside one particular trip.
- Cockpit may contribute cross-domain inferences from mail, newsletters, discovery behavior, and other sources.
- Any app may consume a task-specific projection of relevant shared personal knowledge.

No app should need to ingest the entire personal knowledge graph simply because it can.

---

## 5. Specialist-local knowledge remains specialist-local by default

Not every learning should become family knowledge.

Examples that may remain Yes Chef-local:

- a preference about a particular cooking technique,
- recipe-specific workflow behavior,
- specialized prep-plan conventions.

Examples that may remain Galavant-local:

- a trip-specific pacing preference,
- a planning convention used only inside one itinerary,
- specialized map/route behavior.

Examples that remain Cockpit-local:

- Gmail Handling Policies,
- source-disposition automation,
- Cockpit-specific triage preferences.

The promotion question is:

> Does this learning describe the person/household in a way that is plausibly useful outside the domain where it was first observed?

If not, it stays local.

### Product principle

> Shared personal knowledge is promoted meaning, not a central dump of every application's behavioral exhaust.

---

## 6. Do not build a central surveillance event warehouse

The app family should not centralize every click, dismissal, save, recipe edit, itinerary move, or other interaction merely so a future model can mine the history.

Detailed interaction evidence belongs primarily to the application that understands its meaning.

A specialist may later contribute a higher-level personal claim with provenance back to its own evidence, rather than uploading its entire event stream into a shared family store.

This keeps the shared substrate interpretable and reduces accidental coupling between domain-specific interaction details and cross-domain personalization.

---

## 7. Shared Personal Knowledge is distinct from Published Context

`APP-FAMILY-INTERACTION.md` defines Published Context as a current-life projection such as an upcoming trip or menu.

Published Context answers:

> What is happening now?

Shared Personal Knowledge answers:

> What has the family learned about the people over time?

These have different lifecycles.

### Published Context

- producer-owned,
- intentionally lossy,
- replaceable/expiring,
- current-state oriented,
- e.g. `Burgundy May 8–14`, `Dinner Saturday`.

### Shared Personal Knowledge

- durable,
- provenance-bearing,
- correctable,
- cross-domain where earned,
- e.g. `prefers characterful countryside hotels`, `strong interest in Burgundy`.

Cockpit may combine both when deciding what matters now:

```text
Shared Personal Knowledge
          +
Published Context
          +
Incoming Artifact / Subject
          |
          v
       Cockpit
          |
          v
   relevance / explanation
```

The two substrates may eventually share implementation infrastructure, but they should not be collapsed semantically.

---

## 8. Handling Policies are not Personal Knowledge

Operational instructions remain owned by the application whose behavior they control.

For example:

```text
Apple Store receipts -> extract metadata -> archive automatically
```

is a Cockpit Handling Policy, not a personal belief that Yes Chef or Galavant should consume.

Likewise a specialist application's operational settings do not become shared personal knowledge merely because they were learned from behavior.

This separation prevents changing a personal belief from unexpectedly changing source-action authority or specialist workflow behavior.

---

## 9. Shared knowledge must be directly consumable by family apps

A future Yes Chef or Galavant model call should not require this architecture:

```text
Yes Chef -> launch/query Cockpit -> ask Cockpit for profile -> continue
```

Instead the family should eventually support:

```text
Yes Chef task
    |
    v
relevant Personal Knowledge projection
    +
Yes Chef-local preferences/context
    |
    v
model reasoning
```

Cockpit should not need to be installed, awake, or running for another authorized family app to use the shared knowledge available on that device.

This is one of the strongest reasons not to bind the long-term canonical knowledge exclusively to Cockpit-private persistence.

---

## 10. Corrections should propagate to the shared knowledge

If a cross-domain shared belief is corrected in Cockpit, specialist consumers should eventually see the corrected state.

Likewise, if a specialist provides a legitimate correction to a shared belief, the family model should be capable of incorporating that correction rather than allowing each app's independent biography to drift.

The detailed conflict-resolution model is not settled here.

The requirement is simply:

> Once a belief is promoted to shared personal knowledge, its correction lifecycle is also shared.

Cockpit remains the preferred human-facing place to inspect and repair such knowledge because it can explain the cross-domain consequences.

---

## 11. PersonalKnowledgeKit is the likely extraction destination, not a current requirement

A shared package is likely to become appropriate relatively quickly once another real app must read or write the same personal-knowledge substrate.

The provisional likely destination is **`PersonalKnowledgeKit`** in `jon-platform`.

However, that name does not authorize speculative implementation today.

Cockpit is still the first consumer of the richer claim semantics. The immediate design requirement is therefore:

> Cockpit's Personal Model must be implemented behind boundaries that do not assume Cockpit will remain the only persistence owner or consumer forever.

A `PersonalKnowledgeKit` extraction should be triggered by a real second-app participation flow, for example:

- Yes Chef consumes a task-specific projection of shared personal knowledge,
- Galavant consumes a travel-relevant projection,
- Yes Chef or Galavant contributes a cross-domain claim that Cockpit then surfaces in `You`.

At that point the implementation has evidence for what is genuinely shared:

- claim/value representation,
- subject/person/household scope,
- provenance representation,
- synchronization/storage mechanics,
- correction semantics,
- projection/query API,
- conflict/version behavior.

Extract only that proven stable spine. Domain-specific learning evidence and specialist-local preference machinery remain in their applications.

### Platform principle

> Design Cockpit's first implementation for extractability; do not pre-build the extracted package.

---

## 12. The detailed Personal Model remains open

This document deliberately does not settle:

- exact claim taxonomy,
- confidence/strength representation,
- which user actions count as learning evidence,
- when repeated behavior becomes a durable belief,
- how contextual and temporal scope are represented,
- household/person subject structure,
- contradiction/history handling,
- Personal Knowledge UI organization,
- task-specific projection algorithms.

Those questions should continue to be designed from Cockpit's real product behavior.

The ownership decision above should constrain that work: whatever Cockpit builds should be capable of becoming shared family knowledge without making Cockpit itself a mandatory runtime dependency for the rest of the app family.

---

## Summary

- **Cockpit:** primary user-facing stewardship, explanation, correction, and cross-domain application of personal knowledge.
- **Shared Personal Knowledge:** durable, synchronized/backed-up, provenance-bearing knowledge that may be contributed to and consumed by multiple family applications.
- **Specialist apps:** keep domain-local learnings local by default; promote only cross-domain personal meaning when earned.
- **Published Context:** separate ephemeral/current-life substrate.
- **Handling Policies:** remain app-operational state, not shared personal beliefs.
- **`PersonalKnowledgeKit`:** likely future `jon-platform` extraction once a second real application participates; do not build speculatively.

> Cockpit owns the experience of knowing the user. The app family may ultimately own the knowledge.