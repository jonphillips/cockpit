# Cockpit Platform Adoption

**Status:** Living document  
**Date:** 2026-09-05

## Purpose

This document records Cockpit's relationship with `jon-platform`.

It is not a Cockpit feature backlog and not a jon-platform backlog.

Its purpose is to answer:

- Which platform capabilities does Cockpit use?
- Which capabilities has Cockpit deliberately not adopted?
- Which possible shared abstractions is Cockpit providing new evidence for?
- Which Cockpit work is blocked by a jon-platform decision?
- Which jon-platform changes require consumer-compatibility verification?

This document prevents architectural decisions from disappearing into chat history or being rediscovered by future agents.

## Adoption matrix

| Platform capability | Cockpit disposition | Timing | Notes |
|---|---|---|---|
| House Swift architecture | ADOPT | Immediate | `@Observable`, Dependencies, functional core, thin views |
| SQLiteData | ADOPT | Persistence bootstrap | Canonical local store |
| CloudKit architecture | ADOPT | Schema design | Design ownership/FK graph before schema hardens |
| `CloudSyncKit` | ADOPT | Persistence bootstrap | App owns configuration and `makeSyncEngine` |
| `LLMClientKit` | ADOPT | First model use | No Cockpit-specific provider transport |
| `WebExtractorKit` | DEFER | First concrete web workflow | Do not add speculatively |
| `LLMHandoffKit` | BLOCKED | Only if external handoff becomes a Cockpit requirement | Current session spine remains Galavant-shaped; Yes Chef intentionally consumes only the neutral marker helper |
| Semantic-fidelity doctrine | ADOPT | Immediate | Required for significant ingest/AI boundaries |
| Actionable-AI doctrine | ADOPT | First AI action | AI proposes; human-approved deterministic code writes |
| Shared chat presentation | WATCH | Unknown | Cockpit has not established that chat is a core UI |
| Prompt/profile seam | WATCH | Profile design | Cockpit may provide extraction-trigger evidence |
| Model provenance seam | WATCH | AI architecture matures | Do not create an independent Cockpit provenance framework |
| HTML boilerplate filtering seam | WATCH | Web ingestion | Cockpit may become additional consumer |
| Shared sync-health presentation | WATCH | Settings implementation | Reuse reducer; do not assume UI/model convergence |

## Disposition definitions

### ADOPT

The platform capability is sufficiently proven and appropriate for Cockpit. Cockpit should consume it rather than create an alternative.

### DEFER

The capability is acceptable but Cockpit has not yet earned the requirement. Do not introduce the dependency merely because future use seems likely.

### WATCH

There is evidence of a possible cross-app abstraction, but not enough evidence to design or extract it now. Relevant Cockpit implementation should remain app-specific while evidence is added to jon-platform's seam ledger.

### BLOCKED

Cockpit should not consume the capability in its current form. A real Cockpit requirement may trigger jon-platform work. Blocked does not mean "fix immediately."

### REJECT

Cockpit has deliberately chosen not to follow a platform capability or proposal. A rejection should include rationale.

# Work ownership

## Cockpit backlog

Cockpit's backlog owns work necessary to make Cockpit a good product: canonical domain model, product vocabulary, core loop, relevance/ranking, source model, ingestion, temporal semantics, household semantics, Cockpit AI behavior, Cockpit prompts/schemas, Cockpit UI, and iPhone/iPad behavior.

Cockpit issues should not contain generic jon-platform cleanup unless Cockpit is genuinely blocked by it.

## jon-platform backlog

jon-platform owns work intrinsic to the health or correctness of the shared platform: package defects, stale architecture documentation, package/API documentation drift, tracked build products, broken ADR references, shared test gaps, and generic package correctness.

A Cockpit audit may discover these issues, but they remain jon-platform work.

## Cross-repository dependency

When Cockpit requires a jon-platform change, create one authoritative jon-platform issue/PR and reference it from Cockpit.

Cockpit representation:

> BLOCKED BY: jon-platform #NN — neutral external-LLM handoff boundary

jon-platform representation:

> Existing consumer: Galavant  
> Existing partial consumer: Yes Chef  
> Proposed consumer: Cockpit  
> Cockpit dependency: cockpit #NN

Do not maintain two independent descriptions of the same platform work.

# Consumer compatibility policy

Every compatibility-sensitive jon-platform change must identify its known consumers.

Current consumer set:

- Galavant
- Yes Chef
- Cockpit, once adopted

The PR description should contain:

## Consumer impact

### Galavant

- Current usage:
- API/compile impact:
- Behavioral impact:
- Migration required:
- Verification performed:

### Yes Chef

- Current usage:
- API/compile impact:
- Behavioral impact:
- Migration required:
- Verification performed:

### Cockpit

- Current/proposed usage:
- Capability unlocked:
- Migration required:
- Verification performed:

A consumer that does not use the changed package should be explicitly marked `Not affected`.

# Migration strategies

## 1. Additive — preferred

1. Add new API/capability.
2. Preserve existing API and behavior.
3. Add tests.
4. Migrate consumers independently.
5. Deprecate old API if appropriate.
6. Remove only after all consumers have migrated.

This is the normal strategy for Cockpit-driven platform evolution.

## 2. Deprecate and migrate

1. Introduce replacement.
2. Mark old API deprecated.
3. Migrate Galavant.
4. Migrate Yes Chef where applicable.
5. Migrate Cockpit.
6. Verify all consumers.
7. Remove obsolete API in a later platform change.

## 3. Coordinated breaking migration

Use only when preserving the old API creates greater risk or complexity than a coordinated change.

Requirements:

- explicit rationale,
- identified consumer PRs,
- consumer verification,
- coordinated merge/order plan,
- no period in which an unknowingly broken consumer is treated as healthy.

# Compatibility verification target

The desired long-term invariant is:

> A jon-platform change is not considered fully green merely because jon-platform's package tests pass; known consumers must remain compatible.

The ideal CI gate eventually verifies Galavant, Yes Chef, and Cockpit against the proposed jon-platform revision.

Until that automation exists, compatibility-sensitive PRs require explicit consumer verification.

# Cockpit-generated platform evidence

## Prompt/profile layering

Existing applications already have related concepts for standing user preference/context injected into model prompts. Cockpit is likely to need a rich personal preference/interest context.

**Current disposition:** WATCH.

### Trigger

When Cockpit has implemented a real profile/context mechanism and its layering semantics can be compared with the existing consumers.

### Do not do yet

Do not invent a generalized profile object based on what Cockpit is expected to need. Cockpit's actual model should provide the evidence.

## Model-call provenance

Existing apps have growing need to understand model tier, context, budget, effort, and degradation. Cockpit may create substantial model traffic.

**Current disposition:** WATCH.

### Trigger

When the already-recorded provenance design has proven itself in an existing consumer or Cockpit develops a concrete requirement that cannot be handled by existing response metadata.

### Do not do yet

Do not create `CockpitModelProvenance` as a parallel architecture.

## HTML boilerplate filtering

Multiple apps have evidence for deterministic removal of link-heavy/non-content blocks before extraction. Cockpit may become another web-ingestion consumer.

**Current disposition:** WATCH.

### Trigger

Cockpit implements web ingestion and demonstrates the same filtering requirement, or an existing consumer requires shared tuning first.

## External LLM handoff

`LLMHandoffKit` currently contains a Galavant-shaped session/persistence model. Yes Chef already performed a convergence review and adopted only `HandoffContractMarker`, leaving its SQLiteData `AIHandoff` session model and `Learning` return model app-specific because those semantics genuinely differ.

**Current disposition:** BLOCKED for Cockpit full-package adoption.

### Trigger

Cockpit develops a concrete external ChatGPT/Claude handoff workflow.

At that point Cockpit supplies another real consumer from which to determine whether a broader neutral spine exists beyond the already-shared marker helper.

### Required platform questions

- What belongs in a domain-neutral session?
- Should payloads be opaque to the package?
- How are app-specific candidate/entity relationships represented?
- How is the handoff marker namespaced?
- How is contract/version negotiation represented?
- How is storage namespaced or delegated?
- How are UUID/time dependencies injected?
- How is Galavant compatibility preserved?
- Which Yes Chef behavior is genuinely shared versus merely conceptually similar?

Do not answer these questions speculatively before Cockpit has a use case.

# Platform-change workflow

When Cockpit appears to need a jon-platform change:

1. Confirm that Cockpit cannot reasonably implement the requirement app-side.
2. Search jon-platform docs, packages, ADRs, and seam ledger.
3. Identify existing consumers of the affected package/API.
4. Add Cockpit evidence to `SEAM-LEDGER.md` if the abstraction is not yet proven.
5. If the extraction trigger has not fired, implement in Cockpit.
6. If the trigger has fired, write the platform decision/ADR where architecturally significant.
7. Prefer additive implementation.
8. Add or update platform tests.
9. Verify existing consumers.
10. Adopt the platform change in Cockpit.
11. Remove/deprecate old APIs only after consumer migration.

# Anti-patterns

Do not:

- change jon-platform merely to make a Cockpit call site prettier,
- add Cockpit domain vocabulary to a shared package,
- copy shared package code into Cockpit,
- create a Cockpit variant of an existing shared client,
- generalize a first-use Cockpit abstraction,
- merge a breaking platform API and discover consumer failures later,
- make Cockpit depend on undocumented platform behavior,
- allow platform TODOs to disappear into Cockpit's feature backlog,
- allow Cockpit blockers to disappear into a generic jon-platform cleanup list.

# Current blockers

There are currently **no jon-platform blockers to beginning Cockpit**.

Cockpit can proceed with product/domain architecture using the existing platform.

`LLMHandoffKit` is blocked for full Cockpit adoption, but external LLM handoff is not currently an established Cockpit requirement and therefore does not block application development.

# Next review

Revisit this document when one of the following occurs:

- Cockpit canonical domain/schema is approved.
- Cockpit implements its first AI context/profile.
- Cockpit implements its first web-ingestion workflow.
- Cockpit develops an external LLM handoff requirement.
- Cockpit identifies a platform API that must change rather than merely be consumed.
- A jon-platform package introduces a breaking/deprecated API relevant to Cockpit.

The purpose of each review is not to seek abstractions. It is to ask whether new evidence has changed any disposition in the adoption matrix.
