# Cockpit Architecture

**Status:** Normative architecture  
**Date:** 2026-09-08

## 1. Purpose

Cockpit is a personal lifestyle and cultural-intelligence application. It helps Jon understand incoming information, notice worthwhile material, preserve content worth returning to, explicitly teach the system about his tastes/interests, and hand domain-specific discoveries to the specialist Jon Universe app that should own them.

Cockpit is explicitly not a productivity system, task manager, universal personal database, generic email client, or platform abstraction laboratory.

For product semantics see `docs/PRODUCT-MODEL.md`. For cross-cutting ratified decisions see `docs/DECISIONS.md`.

---

## 2. House architecture

Cockpit adopts the existing jon-platform house architecture:

- Swift 6.2+
- SwiftUI
- iPadOS/iOS primary
- plain `@Observable` feature models
- Point-Free `Dependencies`
- value-oriented domain models
- functional core / imperative shell
- thin SwiftUI views
- explicit dependency clients around external/framework boundaries
- deterministic database/business operations

Cockpit does not introduce TCA or another app architecture without a demonstrated requirement that the house architecture cannot satisfy.

---

## 3. Persistence and sync

SQLiteData is the canonical local knowledge store.

Cockpit follows jon-platform persistence laws:

- local data is authoritative;
- views observe database state;
- non-trivial mutations live outside views;
- transactions are deterministic and testable;
- stable identity survives edits;
- CloudKit constraints are considered before schema hardens.

Cloud synchronization uses SQLiteData + CloudKit and `CloudSyncKit` where synchronization is required. Cockpit owns its container/configuration, schema, `makeSyncEngine`, app-specific sync presentation, and product semantics.

Potentially large source payloads do not automatically belong in ordinary SQLiteData synchronization. Payload custody and per-device availability are separate responsibilities.

Do not introduce a custom server database, app account system, or synchronization service without a product requirement that cannot reasonably fit the local-first architecture.

---

## 4. Minimum content spine

The architecture distinguishes source evidence from user-facing published material.

### Artifact

An Artifact is concrete source material Cockpit received, fetched, or imported.

It may carry:

- provider/source identity;
- provenance;
- acquisition timestamp;
- authoritative/source locator;
- normalized source content when retained;
- payload reference where Cockpit owns bytes;
- relationship to a Stream where applicable.

Artifact is primarily about evidence, provenance, source actions, reprocessing, and custody.

### ContentPiece

A ContentPiece is Cockpit's stable representation of a distinct piece of published or received material: article, newsletter issue, video, podcast episode, report, PDF, and similar authored content.

Edition participation, Later membership, and Library membership operate on ContentPiece identity.

Artifact and ContentPiece identity must not collapse. Multiple Artifacts may support one ContentPiece; an Artifact may eventually yield multiple meaningful ContentPieces or Finds. Build multiplicity only when observed cases require it.

### Find

A Find is something valuable Cockpit identifies within or because of a ContentPiece. It may concern a restaurant, recipe, wine, product, hotel, event, book, or another domain thing.

A Find is not a Library ContentPiece merely because Cockpit discovered it through content. When a specialist Jon Universe app exists, that app owns canonical domain identity and admission. Cockpit may retain a lightweight Pending Find until an owner exists.

### Anti-universal-entity rule

Do not introduce a universal `Item`, `Thing`, or shared domain entity to unify ContentPieces with restaurants, products, wines, recipes, events, people, or other concepts.

---

## 5. Membership and lifecycle

ContentPiece identity is independent of Edition/Later/Library membership.

Conceptually:

```text
ContentPiece
    ├── Edition participation/state
    ├── Later membership
    └── Library membership
```

Removing one membership must not destroy a ContentPiece still required by another membership, provenance, history, or retained Find.

Edition must eventually support admission, Seen, Clear, natural aging/carryover, Essential protection, and resolution through Save for Later. Exact schema/state representation should be learned from the RSS vertical slice rather than fully designed in advance.

Later and Library are simpler durable memberships.

---

## 6. Deduplication and semantic fidelity

Deduplication should begin with strong deterministic evidence:

- provider stable identity;
- canonical URL;
- known publication identity;
- content fingerprint where clearly appropriate.

Preserve all meaningful provenance. Prefer an occasional duplicate to an uncertain destructive merge.

Cockpit adopts jon-platform's semantic-fidelity doctrine. Every significant transformation should be understood as lossless, intentionally lossy, lossless-or-loud, or review-dependent/best-effort.

Parsing successfully is not equivalent to preserving meaning correctly. Prefer explicit uncertainty or review to fabricated precision.

---

## 7. Custody architecture

Cockpit separates four concerns:

1. **identity** — what the source/ContentPiece is;
2. **understanding** — lightweight durable metadata, provenance, summary/enrichment;
3. **reacquisition** — how substantive material can be fetched again;
4. **payload custody** — whether Cockpit itself must preserve substantive bytes/text.

Library membership does not universally imply full-payload archival.

Reliable upstream repositories may remain authoritative. Gmail Archive is a legitimate durable source for ordinary Gmail-backed material. Loss of provider/account access is a degradation state, not a reason to duplicate every source preemptively.

Uploaded sole-source material is different: when Cockpit accepts an uploaded file into Library and no reliable external original exists, Cockpit must preserve the payload.

External hosted media such as YouTube/podcast episodes does not imply permanent duplication of video/audio.

For web/RSS/text material, retain normalized readable substance when it materially improves durability, search, or offline use; do not make it a universal archival requirement when a reliable source remains authoritative.

A Cockpit-local `ArtifactLibraryClient`-style seam may isolate payload preservation/retrieval/availability mechanics if the implementation earns it. Do not extract `JonLibraryKit` from the first use.

CloudKit Assets remain an implementation hypothesis for Cockpit-owned payloads. Validate transfer behavior, quotas, hashing/integrity, failure recovery, lifecycle, and SQLiteData integration before hardening the storage design.

---

## 8. Device-local availability

Device availability is separate from custody and Library membership.

Conceptually distinguish:

- **automatic cache** — expendable;
- **Offline until [date]** — explicit temporary local promise with visible expiry;
- **Keep Offline** — explicit indefinite local promise.

Explicit offline material must live in app-controlled persistent storage and be verifiably available on the current device. `Keep Offline` may not be silently evicted by Cockpit. Temporary offline material may expire only according to the promise shown to the user.

Expiry removes only redundant local payload, not the ContentPiece, its memberships, provenance, or semantic understanding.

---

## 9. AI architecture

All model access goes through `LLMClientKit`.

`LLMClientKit` owns domain-neutral provider/model transport. Cockpit owns task selection, prompts, context construction, structured-output schemas, interpretation, domain actions, persistence decisions, and user-facing explanation.

### Operating rule

> **AI may propose, interpret, classify, summarize, reconcile, and extract. Deterministic application code performs canonical writes and external mutations under established user authority.**

Model output is not canonical application truth merely because it is plausible.

Use deterministic computation where sufficient. Use AI where fuzzy interpretation/synthesis creates real value.

---

## 10. Personal Knowledge architecture

Personal Knowledge is structured, provenance-bearing durable understanding derived from explicit human intent.

V1 supports coarse kinds:

- Fact
- Taste
- Interest

Durable knowledge may arise from direct teaching, correction, explicit explanation of why a ContentPiece matters, or confirmation of a Cockpit hypothesis.

Passive behavior may influence transient ranking or trigger a question, but may not silently become durable Personal Knowledge.

LLM synthesis may consolidate/deduplicate explicit knowledge while preserving semantic meaning and provenance. Materially new inference requires confirmation.

Current Context remains separate from Personal Knowledge. Knowledge does not grant agency.

Implement Personal Knowledge app-locally behind a movable seam. Do not create `PersonalKnowledgeKit` until a second real app proves the shared shape.

---

## 11. Email integration and source mutation

Email is a source/integration, not an instruction to build an email client.

Cockpit should initially integrate Gmail through an app-local injectable client. Read-only behavior is implemented before provider mutation.

Cockpit attention state is independent of Gmail read/unread.

Provider disposition is a separate deterministic concern:

- Leave in Inbox
- Archive
- Trash

Stream Handling is editorial intent; Gmail Source Disposition is upstream mutation policy.

Automatic Archive/Trash requires an explicit user-established policy. AI may classify a message to apply that authorized policy; it may not silently acquire destructive authority from observed behavior.

Before Archive/Trash, Cockpit must durably commit any ContentPiece, Find, or other result it promises to retain. This processing/disposition barrier is a hard correctness boundary.

V1 does not require permanent Delete Forever, generalized reply/composition, automatic unsubscribe, learned deletion, or a generic rules engine.

The concrete Gmail integration ADR must be written **after** the read-only spike establishes real message/thread/account/retry/undo semantics and **before** mutation is enabled.

---

## 12. Streams and transports

Stream is an editorial/domain concept. Transport is delivery mechanics.

A Stream may arrive through RSS/Atom, email, YouTube, or another bounded integration.

V1 starts from known user intent and includes RSS/Atom autodiscovery from a human-facing URL. `WebExtractorKit` should be adopted only when a concrete rendered-web/capture workflow requires it; ordinary feed discovery should not automatically pull in a browser stack.

Source health belongs to management and should be quiet when healthy, visible when abnormal.

---

## 13. App-family boundaries

Cockpit may consume small read-only Current Context projections from specialist apps.

Handoff is the opposite direction: Cockpit sends faithful material, provenance, interpretation, and user intent to a receiver-owned admission boundary.

The receiving app owns canonical domain identity, deduplication, validation, and persistence.

Do not build a universal family entity graph, shared queue, or generic handoff framework before multiple real receivers prove a common seam.

---

## 14. jon-platform relationship

Cockpit consumes proven domain-neutral platform infrastructure and keeps product/domain semantics app-local.

Adopt:

- jon-platform architecture conventions;
- SQLiteData patterns;
- CloudKit/CloudSyncKit;
- Point-Free Dependencies;
- `LLMClientKit`;
- semantic-fidelity doctrine;
- actionable-AI doctrine.

Defer `WebExtractorKit` until earned.

Do not adopt current `LLMHandoffKit` session/persistence semantics; they remain Galavant-shaped.

> **First use establishes a requirement. Repeated use may establish an abstraction.**

A Cockpit-driven platform change must identify and preserve/migrate existing Galavant and Yes Chef consumers.

---

## 15. External boundaries and dependency clients

Wrap new external frameworks/services behind injectable app-local clients when they first become concrete requirements.

Likely examples include:

- Gmail;
- feed fetching;
- artifact/payload storage;
- provider-specific content APIs;
- future calendar/music/place/event integrations.

A client moves to jon-platform only after another real application proves its semantics are domain-neutral.

---

## 16. Device philosophy

Cockpit is iPad-first for rich reading, browsing, curation, teaching, and management. iPhone should be useful for awareness, lightweight reading/capture, and in-the-moment access without forcing visual/navigation parity.

The five-destination product model is shared; composition may be device-appropriate.

Do not make iPhone polish a blocker for proving V1 product loops.

---

## 17. Testing priorities

Make deterministic core behavior cheap to test, especially:

- database lifecycle and identity;
- Artifact/ContentPiece deduplication/provenance;
- Edition state transitions and Essential behavior;
- Later/Library invariants;
- custody/local-availability transitions;
- semantic-fidelity boundaries;
- model response decoding;
- Personal Knowledge reconciliation/supersession;
- Gmail disposition barriers/retries/undo;
- cross-app handoff boundaries;
- CloudKit-compatible migrations/identity.

External dependencies should be injectable so important behavior can be tested without live services/models.

---

## 18. Architecture gates

Cockpit should be implemented through complete vertical slices with deliberate architecture reviews between them. The normative sequence is in `docs/V1-SCOPE-AND-SEQUENCING.md`.

Do not build the entire conceptual schema up front. At each gate ask whether implementation evidence invalidated assumptions underneath the next slice.

When evidence requires changing a ratified decision, amend `docs/DECISIONS.md` and affected docs deliberately rather than allowing code/document drift.

---

## 19. North star

> **Cockpit contains rich product semantics over boring, proven infrastructure.**

`jon-platform` supplies the boring infrastructure. Cockpit supplies the opinion.
