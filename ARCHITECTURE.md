# Cockpit Architecture

**Status:** Initial architecture  
**Date:** 2026-09-05

## 1. Purpose

Cockpit is a personal lifestyle and cultural-discovery application.

Its purpose is to help surface enjoyable, culturally interesting, timely, and personally relevant things across areas such as travel, food, wine, music, reading, events, and other interests.

Cockpit is explicitly **not** a work-management, productivity, task-management, or personal-KPI system.

The application should help its users notice and remember things worth experiencing without turning life into a queue of obligations.

This document defines how Cockpit software is built. Product vocabulary, canonical entities, ranking semantics, and the detailed core loop will be defined separately as the product architecture develops.

## 2. Relationship to jon-platform

Cockpit is a consumer of `jon-platform`.

`jon-platform` defines shared architectural conventions and contains proven domain-neutral packages used across Jon's applications.

Cockpit follows the platform rule:

> App domain belongs in the app. Shared infrastructure and proven cross-app abstractions belong in jon-platform.

Cockpit may generate evidence that a new shared abstraction is warranted. It must not move an abstraction into jon-platform merely because Cockpit could theoretically reuse it.

The normal progression is:

1. Implement the Cockpit requirement in Cockpit.
2. Notice a possible cross-app seam.
3. Record the evidence and extraction trigger in jon-platform's `SEAM-LEDGER.md`.
4. Continue app development.
5. Extract only when multiple real consumers prove the shared shape.

A jon-platform change made for Cockpit must also preserve or deliberately migrate existing consumers.

## 3. Baseline technology

Cockpit adopts the existing jon-platform house architecture.

### Application

- Swift 6.2+
- SwiftUI
- iOS/iPadOS as primary platforms
- macOS support where it naturally follows
- Swift Package Manager

### State and architecture

- Plain `@Observable` feature models
- Point-Free `Dependencies`
- Value-oriented domain models
- Functional core / imperative shell
- Thin SwiftUI views
- Explicit dependency clients around external APIs and framework boundaries
- Deterministic functions for important business and persistence logic

Cockpit does not introduce TCA or another application architecture without a specific requirement that the existing house architecture cannot satisfy.

## 4. Persistence

SQLiteData is Cockpit's canonical persistent store.

Cockpit follows jon-platform persistence rules:

- Local data is authoritative.
- Views observe database state rather than maintaining stale hand-loaded snapshots.
- Non-trivial database mutations live outside SwiftUI views.
- Complex transactions are expressed as deterministic functions operating on a database.
- Stable identity is preserved across edits.
- Schema design accounts for CloudKit constraints from the beginning.

Cockpit should not introduce a server-side database, app account system, or custom synchronization service unless a future product requirement demonstrably cannot be met by the local-first architecture.

## 5. Synchronization

Cockpit uses SQLiteData + CloudKit for personal-device synchronization where synchronization is required.

`CloudSyncKit` is the default shared implementation for manual synchronization enablement, CloudKit account-state handling, SyncEngine startup and shutdown, pending-change redrain behavior, share-extension synchronization coordination, and domain-neutral sync-health reduction.

Cockpit owns its CloudKit container configuration, SQLiteData schema, `makeSyncEngine` implementation, app-specific sync presentation/settings, and Cockpit-specific sharing semantics.

Cockpit must design its canonical ownership graph with CloudKit sharing constraints in mind rather than retrofit those constraints after the schema is established.

## 6. AI architecture

All model access goes through `LLMClientKit`.

Cockpit does not create a parallel Cockpit-specific transport layer for OpenAI, Anthropic, or Apple Foundation Models.

`LLMClientKit` owns domain-neutral mechanics including model requests/responses, provider routing, on-device access, frontier-provider access, API-key storage, streaming, tool transport, structured-output transport, and provider-specific wire formats.

Cockpit owns task selection, prompts, context construction, structured-output schemas, domain tools/actions, interpretation of responses, persistence decisions, capability requirements, and user-facing explanation of model behavior where needed.

### AI operating rule

> AI may propose. A deterministic application operation initiated or approved by the human performs the persistent write.

A model response is not canonical application state merely because it is plausible.

Cockpit should use deterministic computation where deterministic computation is sufficient. AI is particularly appropriate where interpretation, synthesis, classification, comparison, or fuzzy extraction provides meaningful value.

## 7. Semantic fidelity

Cockpit adopts jon-platform's semantic-fidelity doctrine as a core architectural rule.

Every significant representation boundary should be understood as lossless, intentionally lossy, lossless-or-loud, or review-dependent/best-effort.

This is especially important because Cockpit may eventually ingest heterogeneous material including web pages, newsletters, events, recommendations, travel information, music, food and wine material, and model-generated research.

Parsing successfully is not equivalent to preserving meaning correctly. Cockpit should prefer explicit uncertainty or human review to silently manufacturing semantic precision.

## 8. Web access and capture

`WebExtractorKit` is the default shared web-browsing and rendered-DOM infrastructure when Cockpit earns a concrete web-capture requirement.

Cockpit should not add the dependency merely because future web ingestion seems likely.

When adopted, `WebExtractorKit` may own persistent browsing, rendered DOM retrieval, effective-URL resolution, generic address/search behavior, and generic selection/capture infrastructure.

Cockpit owns source-specific extraction, source interpretation, domain schemas, extraction prompts, capture-field definitions where Cockpit-specific, normalization into Cockpit concepts, and Cockpit-specific browser composition/workflow.

## 9. External LLM handoff

`LLMHandoffKit` is **not currently an approved Cockpit dependency**.

The package currently contains Galavant-specific session/persistence semantics despite a nominally domain-neutral package boundary. Yes Chef has already evaluated the same package and deliberately adopted only the genuinely shared contract-marker helper rather than the Galavant-shaped session spine.

If Cockpit develops a genuine external-LLM handoff requirement, that requirement becomes additional evidence for reconsidering the package boundary.

Cockpit must not work around existing leakage by adopting Galavant vocabulary. Instead, jon-platform should evaluate an additive or coordinated neutralization while protecting Galavant and the narrower Yes Chef integration.

Until that requirement exists, no Cockpit-driven refactor is required.

## 10. Domain ownership

The following belong in Cockpit unless and until another real consumer proves otherwise:

- product vocabulary,
- canonical entities,
- database schema,
- source taxonomy,
- source adapters,
- relevance and ranking,
- taste and interest semantics,
- temporal relevance,
- recommendation policy,
- save/dismiss/archive semantics,
- cultural relationships,
- household semantics,
- Cockpit AI prompts,
- Cockpit structured-output schemas,
- Cockpit AI actions,
- feature models,
- application navigation,
- screen composition,
- iPhone/iPad product differences.

Cockpit must resist creating a generic platform abstraction merely because multiple Cockpit domains can technically be represented by it.

In particular, the fact that an article, restaurant, album, wine, event, hotel, and destination are all "things" does not prove that a universal shared `Item` abstraction is desirable.

Preserve meaningful distinctions until the product model demonstrates which distinctions should actually collapse.

## 11. External system boundaries

When Cockpit first integrates a new external framework or service, the integration should normally be wrapped immediately in an injectable client.

Potential future examples include calendar/event access, music-library access, newsletter/email ingestion, location/place services, event discovery, and external cultural databases.

These clients begin in Cockpit. A client moves to jon-platform only after another real application proves that its API and semantics are genuinely domain-neutral.

## 12. Platform extraction policy

> First use establishes a requirement. Repeated use may establish an abstraction.

When Cockpit discovers a possible platform abstraction:

1. Do not stop feature work merely to generalize it.
2. Search jon-platform's existing architecture and seam ledger.
3. Record new cross-app evidence in `SEAM-LEDGER.md`.
4. State an objective extraction trigger.
5. Keep the current implementation app-specific until the trigger occurs.
6. When extraction is justified, move rather than copy shared code.
7. Verify all existing consumers before removing old APIs.

## 13. Compatibility rule

Cockpit must never casually redefine jon-platform APIs around its own needs.

Any compatibility-sensitive jon-platform change must explicitly consider all known consumers: Galavant, Yes Chef, and Cockpit once it becomes a consumer.

Preferred migration order:

1. Add neutral/new capability.
2. Preserve existing behavior.
3. Migrate existing consumers.
4. Verify their builds/tests and important behavior.
5. Adopt from Cockpit.
6. Deprecate obsolete API.
7. Remove obsolete API only after all consumers have migrated.

Breaking coordinated migrations are allowed when materially superior, but must be deliberate and documented.

## 14. Device philosophy

Cockpit follows jon-platform's device-appropriate UI principle rather than forcing one identical composition across Apple devices.

Likely Cockpit usage will eventually distinguish richer browsing/exploration/curation/synthesis from lightweight awareness/capture/retrieval/in-the-moment use.

The exact iPad/iPhone split remains a Cockpit product-design decision rather than a platform rule. Do not prematurely encode it before the core loop is understood.

## 15. Testing

Cockpit should make deterministic core behavior cheap to test.

Particular emphasis should be placed on database operations, ranking/relevance calculations, normalization, semantic-fidelity boundaries, model-response decoding, AI proposal-to-commit boundaries, source adapters, migration behavior, and CloudKit-compatible identity behavior.

External dependencies should be injected so important behavior can be exercised without live network/model/framework calls.

## 16. Initial platform dependencies

| Capability | Decision |
|---|---|
| jon-platform architecture docs | Adopt |
| SQLiteData conventions | Adopt |
| CloudKit schema/sync laws | Adopt |
| `CloudSyncKit` | Adopt when persistence/sync bootstraps |
| `LLMClientKit` | Adopt |
| `WebExtractorKit` | Adopt when first concrete web workflow requires it |
| `LLMHandoffKit` | Do not adopt in current form |
| Semantic-fidelity doctrine | Adopt |
| Actionable-AI doctrine | Adopt |
| Shared chat UI | No assumption |
| New Cockpit-derived packages | None |

## 17. Open architecture questions

The infrastructure architecture is substantially settled. The major unresolved questions are product/domain questions:

- What is Cockpit's canonical model?
- What enters Cockpit?
- What is retained permanently versus surfaced ephemerally?
- What is the distinction between an interest, source, candidate, opportunity, saved object, and experience?
- Which concepts should span travel, food, wine, music, events, and reading?
- Which distinctions must remain domain-specific?
- What does "interesting now" mean?
- What evidence changes relevance?
- What is explicit user preference versus inferred preference?
- What role does time play?
- What household/shared semantics exist?
- What does AI know automatically?
- What does AI infer?
- What requires review?
- What should Cockpit do exceptionally well on iPad?
- What should remain immediately useful on iPhone?

These questions should drive the next phase of Cockpit design.

## 18. Architectural north star

Cockpit should contain rich product semantics over boring, proven infrastructure.

jon-platform supplies the boring infrastructure.

Cockpit supplies the opinion.
