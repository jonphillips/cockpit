# Cockpit Platform Adoption

**Status:** Normative living document  
**Date:** 2026-09-08

This document records Cockpit's relationship with `jon-platform`. It is not a Cockpit feature backlog and not a jon-platform backlog.

The governing rule is:

> **App domain belongs in the app. Shared infrastructure and proven cross-app abstractions belong in jon-platform.**

And:

> **First use establishes a requirement. Repeated use may establish an abstraction.**

---

## 1. Adoption matrix

| Platform capability | Cockpit disposition | Timing | Notes |
|---|---|---|---|
| House Swift architecture | ADOPT | Immediate | `@Observable`, Dependencies, functional core, thin views |
| SQLiteData conventions | ADOPT | Persistence bootstrap | Canonical local knowledge store |
| CloudKit architecture | ADOPT | Schema design | Respect ownership/FK constraints before schema hardens |
| `CloudSyncKit` | ADOPT | Persistence bootstrap | Cockpit owns container/configuration/schema/presentation |
| `LLMClientKit` | ADOPT | First model use | No Cockpit-specific provider transport |
| Semantic-fidelity doctrine | ADOPT | Immediate | Required at significant ingest/AI boundaries |
| Actionable-AI doctrine | ADOPT | First AI action | AI proposes/interprets; deterministic app operation writes/mutates |
| `WebExtractorKit` | DEFER | First concrete rendered-web/capture requirement | Feed autodiscovery alone does not justify a browser dependency |
| `LLMHandoffKit` full session/persistence model | DO NOT ADOPT CURRENT FORM | Only if a real external-LLM handoff requires reconsideration | Current semantics remain Galavant-shaped |
| Shared prompt/profile seam | WATCH | After real Cockpit PK use | Cockpit PK remains app-local first |
| Model-call provenance seam | WATCH | When existing metadata becomes insufficient | Do not invent parallel Cockpit framework |
| HTML boilerplate filtering seam | WATCH | If real web ingestion proves same need | Add evidence to platform seam ledger |
| Shared sync-health presentation | WATCH | Settings implementation | Reuse neutral reducer where appropriate; app owns UI semantics |
| New Cockpit-derived shared packages | REJECT FIRST USE | N/A | No ContentStreamKit, PersonalKnowledgeKit, FamilyContextKit, JonLibraryKit from one consumer |

---

## 2. Disposition meanings

### ADOPT

The capability is proven/domain-neutral enough that Cockpit should consume it instead of creating an alternative.

### DEFER

The capability is acceptable but the concrete Cockpit requirement has not fired. Do not add the dependency speculatively.

### WATCH

There is plausible cross-app evidence, but Cockpit should remain app-local until repeated real use clarifies the shared shape.

### DO NOT ADOPT CURRENT FORM

The available package/API carries semantics Cockpit should not inherit. A future concrete requirement may justify additive/neutralizing platform work.

### REJECT FIRST USE

Do not extract a new platform abstraction from Cockpit's first implementation merely because future reuse is imaginable.

---

## 3. Cockpit domain stays in Cockpit

The following are Cockpit product/domain semantics and should begin app-local:

- Interest Area;
- Stream and Stream Handling;
- Essential;
- Artifact / ContentPiece / Find distinctions;
- Edition/Later/Library semantics;
- custody promises and local offline policy;
- Personal Knowledge claims/provenance/correction;
- Gmail disposition policy semantics;
- relevance/ranking/editorial logic;
- Pending Finds;
- receiver-specific handoff composition;
- navigation/device composition;
- Cockpit prompts/structured-output schemas/actions.

The fact that another app could one day have a concept called “content,” “knowledge,” “handoff,” or “context” is not extraction evidence.

---

## 4. Platform work ownership

### Cockpit backlog

Owns work needed to make Cockpit a good product and to implement Cockpit-local boundaries.

### jon-platform backlog

Owns shared-package correctness, stale platform docs, platform defects, package/API drift, shared tests, and changes that are intrinsically platform concerns.

When Cockpit discovers a platform issue, keep one authoritative issue/PR in jon-platform and reference it from Cockpit if blocking.

Do not maintain two drifting descriptions of the same shared work.

---

## 5. Consumer compatibility

Compatibility-sensitive jon-platform changes must consider known consumers:

- Galavant;
- Yes Chef;
- Cockpit once using the changed capability.

Preferred migration order:

1. add neutral/new capability;
2. preserve existing behavior;
3. add tests;
4. migrate existing consumers deliberately;
5. verify builds/tests/important behavior;
6. adopt in Cockpit;
7. deprecate/remove old API only after migration.

A coordinated breaking migration is allowed only when preserving compatibility is materially worse and the consumer migration plan is explicit.

---

## 6. Current seams to watch

### Personal Knowledge / prompt context

Cockpit will generate task-specific model context from structured explicit Personal Knowledge and Current Context.

**Disposition:** WATCH.

Trigger for shared abstraction: a second real app needs materially the same durable PK semantics or projection behavior and comparison shows a genuinely neutral seam.

Do not create `PersonalKnowledgeKit` from Cockpit alone.

### Current Context sharing

Specialist apps may eventually publish small context projections consumed by Cockpit.

**Disposition:** WATCH / app-local concrete integration first.

Trigger: at least two real producer/consumer relationships reveal repeated neutral mechanics.

Do not create `FamilyContextKit` first.

### Artifact/payload storage

Cockpit may need a local seam for uploaded payload custody and explicit offline availability.

**Disposition:** app-local.

Trigger for sharing: another real app demonstrates the same mechanical storage/availability contract independent of Cockpit semantics.

Do not create `JonLibraryKit` first.

### External handoff

Current `LLMHandoffKit` has Galavant-shaped session/persistence semantics. Yes Chef already consumes only the neutral portion it actually shares.

Cockpit's V1 Jon Brain workflow is copy/paste natural-language teaching and does **not** establish a requirement for `LLMHandoffKit`.

Cockpit's first specialist-app Find handoff should also be implemented directly against the receiver-owned admission boundary, not through a generalized package.

Reconsider shared handoff infrastructure only after multiple real receivers expose common mechanics.

### Web extraction

Generic RSS/Atom autodiscovery should be implemented with the lightest deterministic mechanics required.

Adopt `WebExtractorKit` only when Cockpit needs rendered DOM/persistent browsing/capture behavior that the package actually owns.

---

## 7. Platform-change workflow

When Cockpit appears to need a jon-platform change:

1. confirm the requirement cannot reasonably remain app-local;
2. inspect the relevant jon-platform package/docs/ADR/seam ledger;
3. identify existing consumers;
4. add Cockpit evidence to the platform seam ledger if the abstraction is not proven;
5. if the extraction trigger has not fired, implement locally;
6. if the trigger has fired, define the neutral requirement from all real consumers;
7. prefer additive implementation/migration;
8. add/update platform tests;
9. verify consumers;
10. adopt in Cockpit;
11. remove obsolete APIs only after migration.

---

## 8. Anti-patterns

Do not:

- change jon-platform just to make a Cockpit call site prettier;
- add Cockpit domain vocabulary to a shared package;
- copy shared package code into Cockpit;
- create a Cockpit-specific duplicate of an existing neutral client;
- generalize a first-use Cockpit abstraction;
- let a package name convince Cockpit to adopt domain leakage;
- merge breaking platform changes without consumer verification;
- let platform cleanup disappear into Cockpit's feature backlog;
- let a real Cockpit blocker disappear into a generic platform wishlist.

---

## 9. Current blockers

There are currently **no jon-platform blockers to beginning Cockpit V1**.

Cockpit should begin with the vertical sequence in `docs/V1-SCOPE-AND-SEQUENCING.md` using existing proven platform capabilities.

No new shared package is required before the first RSS → Edition → Later/Library slice.
