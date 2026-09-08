# Cockpit Content Stream Model

**Status:** Normative product/domain decision  
**Date:** 2026-09-08

## 1. Core vocabulary

### Interest Area

An **Interest Area** is the editorial reason Cockpit follows recurring material.

Examples:

- Opinion & Commentary
- Arts & Culture
- Food & Wine
- Travel & Places
- Technology & Making

Interest Areas are user-visible management objects with lightweight editorial guidance. They are not a large ontology or a replacement for Personal Knowledge.

### Stream

A **Stream** is the recurring content flow Cockpit intentionally follows.

Examples:

- NYT Travel
- Matthew Yglesias
- Paris by Mouth
- Kitchen Projects
- a selected YouTube channel

A Stream is the primary configurable recurring-content object.

### Publisher / Creator

Identifies who produces the Stream. This is initially lightweight identity/branding/grouping, not the primary behavioral hierarchy.

### Transport

How Cockpit receives the Stream: RSS/Atom, email, YouTube/feed/API, or another bounded integration.

Transport determines ingestion, authentication, source actions, and operational mechanics. It should rarely organize the Edition experience.

### Source

Use `Source` for upstream provider material, provenance, authoritative originals, and provider-side actions. Do not use it as the recurring-publication noun; that noun is `Stream`.

---

## 2. Governing principle

> **Interest Areas describe why Cockpit consumes recurring content. Streams describe what recurring flow Cockpit follows. Publishers describe who produced it. Transports describe how it arrived.**

Following is organized Interest-Area-first rather than transport-first or publisher-first.

---

## 3. One primary Interest Area

Every Stream has one primary Interest Area for management/editorial intent.

That relationship provides a stable home, not a semantic prison. Individual ContentPieces or Finds may be relevant to other Interest Areas according to their meaning.

Example:

```text
Feed Me
Primary Interest Area: Food & Wine

one issue may yield:
- restaurant Find → Food & Wine / Galavant candidate
- hotel Find → Travel & Places / Galavant candidate
- publication link → another ContentPiece
```

---

## 4. Stream intent and configuration

A Stream needs only the concerns that have demonstrated product value.

### Stable identity

Cockpit-owned identity independent of display-name or locator changes.

### Name

Human-readable Stream name.

### Publisher / Creator

Lightweight producer identity.

### Transport + locator

Enough deterministic information to retrieve/recognize recurring material.

### Primary Interest Area

Stable editorial/management home.

### Handling

Human-language editorial instruction answering:

> **Why do I follow this Stream, and what should Cockpit do with it?**

Examples:

**Matthew Yglesias**

> Essential. Always surface substantive new posts. Give me enough orientation to decide whether to read. Never let unresolved primary posts silently age away.

**NYT Movies**

> Screen aggressively for serious criticism, filmmakers and films I care about, and unusually strong cultural pieces. Skip routine entertainment churn.

**Paris by Mouth**

> Mine for restaurants, chefs, meaningful openings, and Paris changes I might plausibly care about even when buried inside a mixed issue.

Handling should remain semantic rather than expose ranking weights, parser modes, or a large toggle matrix.

### Essential

Essential is a Stream-level posture. Its binding consequence is:

> **Substantive primary material cannot silently age away from Edition.**

Unresolved Essential material that outlives the daily package moves to a visible Essential backlog rather than either aging out or bloating Edition. See `docs/EDITION-EXPERIENCE.md` §4.

Essential is not an Interest Area and should not leak into the hierarchy as though it were one. A derived “Essentials” filter/group is fine.

### Cadence and content shape

Cadence/content shape may be inferred operational metadata useful for health, persistence defaults, and processing. They should normally not be user-configured.

### Health

Healthy should be quiet. Abnormal states such as stale, broken, authorization required, or repeated parse/fetch failure should be visible in Following.

### Follow state

At minimum:

- following;
- paused;
- stopped.

Do not create a complex lifecycle enum before real needs appear.

---

## 5. Handling precedence

A useful conceptual decision stack is:

```text
product defaults
+
Interest Area guidance
+
Stream Handling / Essential
+
relevant explicit Personal Knowledge
+
Current Context / ContentPiece meaning
↓
judgment / placement / persistence
```

Explicit narrower user intent should constrain broader inferred relevance.

A Stream rule like “Always show substantive Yglesias posts” intentionally overrides ordinary curation even if a particular post appears weak against generic interest ranking.

Personal Knowledge tells Cockpit what Jon is like. Interest Areas/Streams tell Cockpit what job recurring material was hired to do.

---

## 6. Edition persistence, custody, and source disposition are separate

Do not use a vague `retention policy` to collapse three decisions.

### Edition persistence

How long should a surfaced ContentPiece remain eligible for the active Edition?

### Custody

What substantive source material/understanding does Cockpit preserve or rely on?

### Upstream source disposition

What happens to the provider Artifact after processing?

For email this may be Leave, Archive, or Trash under an explicit authorized policy.

These dimensions are independent.

Example:

```text
Matthew Yglesias
Handling: Essential
Edition persistence: explicit resolution required for substantive posts
Custody: Gmail-backed + Cockpit understanding
Gmail disposition: Archive after safe processing
```

---

## 7. Automatic Library admission

A Stream may eventually carry an explicit prospective policy to add qualifying future ContentPieces to Library automatically.

A future ContentPiece **qualifies** when it is substantive primary material from the Stream carrying the policy. Nothing else — this is deliberately not a rules language. Both terms are defined in `docs/IMPLEMENTATION-CONTRACT.md` §1.

This is independent of Edition admission.

Example:

```text
Andrew Harper
Edition: selective
Library: add all qualifying future reports/issues
```

V1 should implement explicit Add to Library first, then prove one automatic Stream policy.

No silent historical backfill in V1.

---

## 8. Add Stream philosophy

V1 starts from **known user intent**.

The user identifies something they already want to follow. Cockpit handles transport discovery/mechanics.

One global Add Stream flow:

```text
paste / enter known target
→ discover/resolve recurring transport
→ identify Publisher / Creator
→ propose Interest Area
→ propose concise Handling
→ optionally mark Essential
→ Follow
```

### Feed autodiscovery is V1

For a human-facing URL, Cockpit should attempt:

1. direct RSS/Atom validation;
2. standard website RSS/Atom autodiscovery;
3. obvious linked-feed inspection;
4. narrow deterministic provider resolver where justified;
5. explicit fallback asking for a feed URL when unresolved.

This is discovery of **how to follow a known target**, not discovery of what Jon should follow.

---

## 9. Discovery that waits

Do not require for V1:

- autonomous recommendations for new publications;
- publisher-wide catalogs;
- search across all YouTube channels;
- historical subscription import/cleanup;
- automatic mailbox-wide newsletter discovery;
- generic “sources you may like” machinery.

Those are separate product capabilities.

---

## 10. Pause, stop, and move

### Pause

Temporarily stop future ingestion/admission while preserving Stream identity, Handling, and existing retained ContentPieces.

### Stop Following

Stop future ingestion/admission. Existing Later/Library ContentPieces and durable Finds/knowledge survive according to their own lifecycle.

### Move Interest Area

Change the Stream's management/editorial home prospectively. Historical provenance remains truthful.

---

## 11. Deduplication across Streams

The same underlying ContentPiece may arrive through multiple Streams or Transports.

Use strong deterministic identity when available and preserve all provenance. Do not build a probabilistic universal reconciliation engine in V1.

---

## 12. V1 must prove

- a known human-facing URL can become a working Stream without requiring raw feed expertise;
- Interest-Area-first Following feels natural;
- Handling/Essential are understandable and materially affect Edition behavior;
- Stream health can be inspected without becoming a monitoring dashboard;
- email-delivered Streams cleanly separate Stream intent from Gmail source disposition;
- one explicit auto-Library policy works prospectively after manual Library behavior is trustworthy.
