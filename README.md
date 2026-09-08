# Cockpit

Cockpit is a personal lifestyle and cultural-intelligence app for the Jon Universe.

Its job is to reduce incoming noise, surface what deserves attention, preserve worthwhile content, learn explicitly taught preferences and interests, and hand domain-specific discoveries to the specialist app that should own them.

Cockpit is explicitly **not** a productivity system, task manager, universal personal database, or generic email client.

## Current product shell

The current user-facing shell is normative:

```text
Today
Edition
Later
Library
Settings
```

- **Today** — what happened, what deserves attention, and what especially should register.
- **Edition** — a finite rolling personalized newspaper assembled from followed Streams, materialized once per day.
- **Later** — explicit deferred attention; nothing enters automatically and nothing silently expires.
- **Library** — durable retained **ContentPieces** for reference, retrieval, and enrichment.
- **Settings** — Following, Interest Areas, Personal Knowledge / You, integrations, and app settings.

`Following` is the friendly management label. `Stream` is the precise domain noun.

## Normative vocabulary

- **Interest Area** — why Cockpit follows recurring material.
- **Stream** — the recurring flow Cockpit intentionally follows.
- **Publisher / Creator** — who produces a Stream.
- **Transport** — how a Stream arrives, such as RSS/Atom, email, or YouTube.
- **Artifact** — concrete source material Cockpit received, fetched, or imported, with provenance and provider identity where applicable.
- **ContentPiece** — Cockpit's stable representation of a distinct piece of published or received material: article, newsletter issue, video, podcast episode, report, PDF, and similar authored content.
- **Find** — something valuable Cockpit identifies within or because of a ContentPiece. Finds are candidates for specialist Jon Universe apps, not Library contents.
- **Source** — upstream provider material, authoritative originals, provenance, and provider-side actions. Do not use `Source` as a synonym for Stream.
- **Personal Knowledge** — durable explicit understanding of Jon, currently organized coarsely as Fact, Taste, and Interest.
- **Current Context** — temporary situational information that may affect relevance but is not Personal Knowledge.

The ordinary UI should use the natural concrete noun — Article, Video, Newsletter, Report — rather than expose `ContentPiece` unnecessarily.

## Document authority

The live repository documentation describes the current system. Older design generations are preserved under `docs/archive/2026-09-08-pre-normalization/` for history and evidence only; **archive documents are never normative**.

When live documents appear to conflict, use this precedence:

1. `docs/DECISIONS.md` — ratified cross-cutting decisions and explicit deferrals.
2. `docs/IMPLEMENTATION-CONTRACT.md` — schema, state machines, invariants, and the definitions of load-bearing words.
3. `ARCHITECTURE.md` — software boundaries and architectural invariants.
4. `docs/PRODUCT-MODEL.md` — product responsibilities and vocabulary.
5. `docs/V1-SCOPE-AND-SEQUENCING.md` — what V1 actually builds and in what order.
6. Focused live documents in `docs/` — detailed behavior for their named area.
7. `PLATFORM-ADOPTION.md` — relationship to `jon-platform`.
8. Archive material — historical context only.

Where `docs/DECISIONS.md` states product intent and `docs/IMPLEMENTATION-CONTRACT.md` states a shape, they are answering different questions and do not conflict. If they do conflict, the ledger wins on intent and the contract wins on shape; correct whichever is wrong in the same change.

A later, more specific live document may refine an earlier broad statement, but it must not silently redefine a cross-cutting decision. If a real conflict is discovered, update the decision ledger and the affected documents together.

## Live document map

### Implementation

These three are the documents implementation agents work from. The essays below them are product reasoning, consulted by name when their area is being changed.

- [`docs/IMPLEMENTATION-CONTRACT.md`](docs/IMPLEMENTATION-CONTRACT.md) — the compact contract: schema, Edition state machine, invariants, and definitions of `Subjects`, `substantive primary material`, `qualifying`, and `judgment`. Read every session.
- [`docs/ADR-0001-PERSISTENCE-AND-EXECUTION.md`](docs/ADR-0001-PERSISTENCE-AND-EXECUTION.md) — Phase 0 ADR: execution model, ingest ownership, derived identity, CloudKit posture, Gmail authorization spike.
- [`docs/JUDGMENT-CONTRACT.md`](docs/JUDGMENT-CONTRACT.md) — how ContentPieces become an Edition: invocation, inputs, structured output, prompt, evaluation harness, cost budget.

### Product and architecture

- [`ARCHITECTURE.md`](ARCHITECTURE.md) — application architecture, persistence, AI boundaries, custody, platform rules.
- [`PLATFORM-ADOPTION.md`](PLATFORM-ADOPTION.md) — what Cockpit adopts from `jon-platform`, defers, or must keep app-local.
- [`docs/DECISIONS.md`](docs/DECISIONS.md) — current decision ledger: resolved, deliberately deferred, build-and-learn.
- [`docs/PRODUCT-MODEL.md`](docs/PRODUCT-MODEL.md) — coherent current product model and product laws.
- [`docs/V1-SCOPE-AND-SEQUENCING.md`](docs/V1-SCOPE-AND-SEQUENCING.md) — V1 cutline, vertical slices, and architecture gates.

### Content and retention

- [`docs/CONTENT-PIECE-MODEL.md`](docs/CONTENT-PIECE-MODEL.md) — Artifact, ContentPiece, Find, custody, provenance, deduplication, offline guarantees.
- [`docs/EDITION-EXPERIENCE.md`](docs/EDITION-EXPERIENCE.md) — the rolling finite newspaper.
- [`docs/LATER-LIBRARY-EXPERIENCE.md`](docs/LATER-LIBRARY-EXPERIENCE.md) — deferred attention versus durable retained content.

### Following

- [`docs/CONTENT-STREAM-MODEL.md`](docs/CONTENT-STREAM-MODEL.md) — Interest Areas, Streams, Handling, Essential, transport, health, source disposition.
- [`docs/STREAM-MANAGEMENT-EXPERIENCE.md`](docs/STREAM-MANAGEMENT-EXPERIENCE.md) — Following UI and Add Stream resolution.

### Today and email

- [`docs/TODAY-EXPERIENCE.md`](docs/TODAY-EXPERIENCE.md) — morning orientation and attention.
- [`docs/EMAIL-INTELLIGENCE-MODEL.md`](docs/EMAIL-INTELLIGENCE-MODEL.md) — Gmail intelligence, source disposition, explicit authority, and V1 limits.

### Personal Knowledge and app family

- [`docs/PERSONAL-KNOWLEDGE-MODEL.md`](docs/PERSONAL-KNOWLEDGE-MODEL.md) — explicit durable knowledge, synthesis, provenance, correction.
- [`docs/PERSONAL-KNOWLEDGE-BOUNDARY.md`](docs/PERSONAL-KNOWLEDGE-BOUNDARY.md) — Current Context, agency, and cross-app ownership boundaries.
- [`docs/JON-BRAIN-HANDOFF.md`](docs/JON-BRAIN-HANDOFF.md) — V1 manual bulk teaching from ChatGPT or another AI system.
- [`docs/APP-FAMILY-INTERACTION.md`](docs/APP-FAMILY-INTERACTION.md) — current context projections and Find handoff to specialist apps.

### Experience and implementation reality

- [`docs/IPAD-FIRST-EXPERIENCE.md`](docs/IPAD-FIRST-EXPERIENCE.md) — device philosophy and shell composition.
- [`docs/CAPABILITY-REALITY-MAP.md`](docs/CAPABILITY-REALITY-MAP.md) — what is real in V1, what is only a concept, and what waits for evidence.

`docs/CONTENT-EXPERIENCE.md` remains only as a compatibility pointer to `EDITION-EXPERIENCE.md`; `Edition` is the current user-facing noun.

## Implementation posture

Cockpit should be built as complete vertical slices, not as a speculative framework. The first major slice is:

```text
known URL
→ RSS/Atom autodiscovery
→ Stream
→ Artifact
→ ContentPiece
→ Personal Knowledge (incl. Jon Brain import)
→ judgment
→ Edition
→ Reader
→ Later / Library / Pending Finds
→ offline availability
```

Personal Knowledge and Find extraction are inside the first slice, not after it. Judgment built against no preferences is judgment that has to be rebuilt, and Finds are what distinguish Cockpit from a feed reader — the orphan-Find population should start accumulating from day one.

Then stop and review the architecture before adding Gmail. See `docs/V1-SCOPE-AND-SEQUENCING.md`.

## North star

> **Cockpit retains the material Jon consumed or may want to consume. It notices valuable things within that material. Specialist Jon Universe apps own those things.**

And throughout:

> **Rich product semantics over boring, proven infrastructure.**
