# Cockpit Architecture

**Status:** Initial architecture  
**Date:** 2026-09-05

## 1. Purpose

Cockpit is a personal lifestyle and cultural-discovery application.

Its purpose is to help surface enjoyable, culturally interesting, timely, and personally relevant things across areas such as travel, food, wine, music, reading, events, and other interests.

Cockpit is explicitly **not** a work-management, productivity, task-management, or personal-KPI system.

The application should help its users notice and remember things worth experiencing without turning life into a queue of obligations.

This document defines how Cockpit software is built. Product vocabulary, canonical entities, ranking semantics, and the detailed core loop are developed in `docs/PRODUCT-MODEL.md`.

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

SQLiteData is Cockpit's canonical persistent knowledge store.

Cockpit follows jon-platform persistence rules:

- Local data is authoritative.
- Views observe database state rather than maintaining stale hand-loaded snapshots.
- Non-trivial database mutations live outside SwiftUI views.
- Complex transactions are expressed as deterministic functions operating on a database.
- Stable identity is preserved across edits.
- Schema design accounts for CloudKit constraints from the beginning.

The canonical knowledge store should contain relatively lightweight application truth: identities, provenance, extracted/normalized meaning, relationships, custody intent, Personal Model claims, and product state.

Potentially large preserved source bytes are a separate storage responsibility and must not be assumed to replicate through the ordinary SQLiteData synchronization path to every device.

Cockpit should not introduce a server-side database, app account system, or custom synchronization service unless a future product requirement demonstrably cannot be met by the local-first architecture.

## 5. Synchronization

Cockpit uses SQLiteData + CloudKit for personal-device synchronization where synchronization is required.

`CloudSyncKit` is the default shared implementation for manual synchronization enablement, CloudKit account-state handling, SyncEngine startup and shutdown, pending-change redrain behavior, share-extension synchronization coordination, and domain-neutral sync-health reduction.

Cockpit owns its CloudKit container configuration, SQLiteData schema, `makeSyncEngine` implementation, app-specific sync presentation/settings, and Cockpit-specific sharing semantics.

Cockpit must design its canonical ownership graph with CloudKit sharing constraints in mind rather than retrofit those constraints after the schema is established.

Artifact content has an independent cloud/local lifecycle described in Section 9. Cloud custody must not imply local availability on every device.

## 6. AI architecture

All model access goes through `LLMClientKit`.

Cockpit does not create a parallel Cockpit-specific transport layer for OpenAI, Anthropic, or Apple Foundation Models.

`LLMClientKit` owns domain-neutral mechanics including model requests/responses, provider routing, on-device access, frontier-provider access, API-key storage, streaming, tool transport, structured-output transport, and provider-specific wire formats.

Cockpit owns task selection, prompts, context construction, structured-output schemas, domain tools/actions, interpretation of responses, persistence decisions, capability requirements, and user-facing explanation of model behavior where needed.

### AI operating rule

> AI may propose. A deterministic application operation initiated or approved by the human performs the persistent write.

A model response is not canonical application state merely because it is plausible.

Cockpit should use deterministic computation where deterministic computation is sufficient. AI is particularly appropriate where interpretation, synthesis, classification, comparison, or fuzzy extraction provides meaningful value.

The Personal Model should be stored as structured, provenance-bearing application knowledge. LLM-readable prose/profile context should be generated as a task-specific projection rather than treated as canonical truth.

## 7. Semantic fidelity

Cockpit adopts jon-platform's semantic-fidelity doctrine as a core architectural rule.

Every significant representation boundary should be understood as lossless, intentionally lossy, lossless-or-loud, or review-dependent/best-effort.

This is especially important because Cockpit may eventually ingest heterogeneous material including web pages, newsletters, events, recommendations, travel information, music, food and wine material, and model-generated research.

Parsing successfully is not equivalent to preserving meaning correctly. Cockpit should prefer explicit uncertainty or human review to silently manufacturing semantic precision.

Artifact custody adds a specific fidelity promise:

> Once Cockpit tells the user they no longer need to care about the upstream source, Cockpit must own enough information to keep that promise.

A source pointer is not equivalent to preserved content.

## 8. Web access and capture

`WebExtractorKit` is the default shared web-browsing and rendered-DOM infrastructure when Cockpit earns a concrete web-capture requirement.

Cockpit should not add the dependency merely because future web ingestion seems likely.

When adopted, `WebExtractorKit` may own persistent browsing, rendered DOM retrieval, effective-URL resolution, generic address/search behavior, and generic selection/capture infrastructure.

Cockpit owns source-specific extraction, source interpretation, domain schemas, extraction prompts, capture-field definitions where Cockpit-specific, normalization into Cockpit concepts, and Cockpit-specific browser composition/workflow.

## 9. Artifact custody and availability

Cockpit distinguishes application knowledge from potentially large preserved source content.

A conceptual `ArtifactLibraryClient` should isolate the mechanics of assuming custody of original content, retrieving it, caching it, and guaranteeing per-device offline availability.

This is initially a Cockpit-local seam. Do not create a `JonLibraryKit`, standalone Jon Library product, or jon-platform package based on this first consumer.

### Independent dimensions

Artifact **custody** is synchronized product knowledge. Conceptually it distinguishes content Cockpit merely references from content Cockpit promises to preserve durably.

Artifact **availability** is device-local state. Conceptually it distinguishes content that is absent, expendably cached, or pinned on the current device.

These dimensions must not collapse into one `isSaved` or `isDownloaded` flag.

### Offline guarantee

> Keep on this device is a promise, not a hint.

Pinned content must live in app-controlled persistent local storage that Cockpit does not voluntarily purge. Expendable downloads may live in cache storage. Cockpit should be able to verify physical local availability rather than rely on an opaque cloud residency assumption.

### Current cloud-storage hypothesis

CloudKit assets appear suitable for canonical preserved bytes because asset transfer can be separated from lightweight record fetching. A fetched CloudKit asset's staging file is temporary, so pinned content must be copied/moved into app-controlled persistent local storage.

This remains an implementation hypothesis, not a schema decision. Validate CloudKit asset behavior, SQLiteData integration, quotas, failure recovery, content hashing, and lifecycle requirements before hardening the storage design.

The likely boundary is conceptually:

```text
Cockpit domain
     |
     | preserve / retrieve / availability
     v
ArtifactLibraryClient
     |
     +-- CloudArtifactStore
     +-- LocalArtifactStore
            +-- expendable cache
            +-- persistent pinned content
```

Cockpit should use system viewers/frameworks for PDFs, media, and other content where possible. Artifact custody does not imply building a universal viewer.

## 10. Email and other source integrations

Cockpit should integrate with source services through app-local injectable clients before considering platform extraction.

Email is a source, not an instruction to build an email client.

The current product boundary is that Cockpit may ingest, understand, summarize, retain, preserve, and keep source-derived concerns salient. It may eventually propose or perform narrowly scoped provider actions such as archive or mark-read when those workflows are explicitly designed.

Cockpit must not depend on exact-message deep-linking into Apple Mail for correctness because Apple does not expose a documented iOS API that guarantees that behavior.

Provider folders/labels may be useful ingestion or transport controls, but they are not Cockpit's canonical triage/workflow state.

Source-action agency and constrained reply behavior remain open product decisions and must preserve the principle that Cockpit does not become a general email client.

## 11. External LLM handoff

`LLMHandoffKit` is **not currently an approved Cockpit dependency**.

The package currently contains Galavant-specific session/persistence semantics despite a nominally domain-neutral package boundary. Yes Chef has already evaluated the same package and deliberately adopted only the genuinely shared contract-marker helper rather than the Galavant-shaped session spine.

If Cockpit develops a genuine external-LLM handoff requirement, that requirement becomes additional evidence for reconsidering the package boundary.

Cockpit must not work around existing leakage by adopting Galavant vocabulary. Instead, jon-platform should evaluate an additive or coordinated neutralization while protecting Galavant and the narrower Yes Chef integration.

Until that requirement exists, no Cockpit-driven refactor is required.

## 12. Domain ownership

The following belong in Cockpit unless and until another real consumer proves otherwise:

- product vocabulary,
- canonical entities,
- database schema,
- source taxonomy,
- source adapters,
- artifact custody semantics,
- disposition semantics,
- Personal Model ontology,
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

## 13. External system boundaries

When Cockpit first integrates a new external framework or service, the integration should normally be wrapped immediately in an injectable client.

Potential future examples include calendar/event access, music-library access, newsletter/email ingestion, location/place services, event discovery, artifact storage, and external cultural databases.

These clients begin in Cockpit. A client moves to jon-platform only after another real application proves that its API and semantics are genuinely domain-neutral.

## 14. Platform extraction policy

> First use establishes a requirement. Repeated use may establish an abstraction.

When Cockpit discovers a possible platform abstraction:

1. Do not stop feature work merely to generalize it.
2. Search jon-platform's existing architecture and seam ledger.
3. Record new cross-app evidence in `SEAM-LEDGER.md`.
4. State an objective extraction trigger.
5. Keep the current implementation app-specific until the trigger occurs.
6. When extraction is justified, move rather than copy shared code.
7. Verify all existing consumers before removing old APIs.

## 15. Compatibility rule

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

## 16. Device philosophy

Cockpit follows jon-platform's device-appropriate UI principle rather than forcing one identical composition across Apple devices.

Likely Cockpit usage will eventually distinguish richer browsing/exploration/curation/synthesis from lightweight awareness/capture/retrieval/in-the-moment use.

Artifact availability is explicitly device-specific. A preserved Artifact may be pinned on an iPad while absent from an iPhone.

The exact iPad/iPhone product split remains a Cockpit design decision rather than a platform rule. Do not prematurely encode final navigation before the core loop is understood.

## 17. Testing

Cockpit should make deterministic core behavior cheap to test.

Particular emphasis should be placed on database operations, ranking/relevance calculations, normalization, semantic-fidelity boundaries, model-response decoding, AI proposal-to-commit boundaries, source adapters, migration behavior, CloudKit-compatible identity behavior, artifact custody transitions, local availability state, checksum/integrity verification, and source-action boundaries.

External dependencies should be injected so important behavior can be exercised without live network/model/framework calls.

## 18. Initial platform dependencies

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

## 19. Open architecture questions

The infrastructure architecture is substantially settled. Product/domain work is tracked in `docs/PRODUCT-MODEL.md`.

The highest-priority investigations are:

- Daily/Disposition: what does it mean to be finished with incoming material?
- Source actions: how much agency should Cockpit have over upstream systems?
- Cross-app handoff: how should Cockpit pass rich domain work to Yes Chef, Galavant, and future specialists?
- Personal Model: what kinds of structured claims can Cockpit know, with what provenance/confidence/scope?
- Artifact Library implementation: how should cloud custody, cache storage, pinned storage, integrity, quotas, and failure recovery be implemented without coupling bulk content to ordinary knowledge synchronization?
- What should Cockpit do exceptionally well on iPad versus iPhone?

Do not design a universal relevance/ranking algorithm until real incoming workflows establish what needs to be ranked.

## 20. Architectural north star

Cockpit should contain rich product semantics over boring, proven infrastructure.

jon-platform supplies the boring infrastructure.

Cockpit supplies the opinion.

For product semantics and the emerging Daily / You / Discover responsibilities, see `docs/PRODUCT-MODEL.md`.
