# Cockpit Product Model

**Status:** Normative product model  
**Date:** 2026-09-08

## 1. Product promise

Cockpit's ordinary job is:

> **Tell me what came into my world, what matters, what I can safely ignore, and what is worth returning to.**

Its broader dividend is cultural discovery: helping Jon notice worthwhile ideas, places, recipes, products, wines, books, events, and other opportunities without turning life into task management.

Cockpit is explicitly not a productivity system, KPI system, universal knowledge database, generic email client, or replacement for the specialist Jon Universe apps.

---

## 2. Product shell

The current shell is:

```text
Today
Edition
Later
Library
Settings
```

### Today

> **What happened, what deserves my attention, and what especially should register?**

Today owns morning orientation, personal/consequential email attention, a small Worth Seeing set, compact derived awareness, and inspectable quiet handling.

### Edition

> **I have some time. What is worth reading, watching, exploring, or considering?**

Edition is a finite rolling personalized newspaper assembled from followed Streams.

### Later

> **I want this, but not now.**

Later is explicit deferred attention. Nothing enters automatically and nothing silently expires.

### Library

> **This ContentPiece is worth retaining as durable reference.**

Library contains ContentPieces only. It is not a database of restaurants, wines, products, recipes, people, places, or other extracted domain things.

### Settings

Settings owns Following, Interest Areas, Personal Knowledge / You, integrations, and ordinary app configuration.

`Following` is administration for Edition, not another primary mode.

---

## 3. Core content vocabulary

### Artifact

Concrete source material Cockpit received, fetched, or imported, with provenance/provider identity where applicable.

Examples: Gmail message, RSS entry, imported PDF, fetched page representation.

### ContentPiece

Cockpit's stable representation of a distinct piece of published/received material.

Examples: article, newsletter issue, post, video, podcast episode, report, PDF.

The ordinary UI should call it by its natural type rather than say `ContentPiece`.

### Find

Something valuable Cockpit identifies within or because of a ContentPiece.

Examples: restaurant, recipe, wine, pantry item, travel shorts, hotel, event, book.

A Find is not automatically Library material. When a specialist app exists, Cockpit should hand it off. When no app exists, Cockpit may keep a lightweight Pending Find until the Jon Universe earns the right domain owner.

### Product boundary

> **Cockpit retains the material Jon consumed or may want to consume. Cockpit notices valuable things within it. Specialist apps own those things.**

---

## 4. Edition semantics

Edition is not an accumulating unread queue.

A morning edition combines:

```text
new worthwhile material
+
still-relevant carryover
+
Essential material not explicitly resolved
```

Opening means **Seen**, not Clear. Seen content may become visually quieter but remains eligible until resolved or naturally aged according to policy.

Substantive primary material from an Essential Stream cannot silently age away.

Save for Later resolves the immediate Edition attention relationship while adding explicit Later membership. Add to Library may occur independently of Edition and Later.

Exact aging windows, section ordering, card density, and intraday admission should be learned from use rather than treated as settled ontology.

---

## 5. Interest Areas and Streams

An **Interest Area** describes why Cockpit follows recurring material.

A **Stream** is the recurring flow itself.

Examples:

```text
Travel & Places
- NYT Travel
- Paris by Mouth
- selected YouTube channel
```

```text
Food & Wine
- NYT Food
- Kitchen Projects
- Vinous
```

A Stream has one primary Interest Area for management/editorial intent. Individual ContentPieces and Finds may be relevant elsewhere.

Publisher/Creator identifies who produced the Stream. Transport identifies how it arrives. Source refers to the upstream provider material/provenance/action surface.

### Handling

Stream Handling answers:

> **Why do I follow this Stream, and what should Cockpit do with it?**

Handling is semantic/human-language editorial intent, not a giant matrix of ranking toggles.

### Essential

Essential is a Stream-level posture with a precise consequence: substantive primary material requires explicit disposition and cannot silently age out.

### Add Stream

There is one global Add Stream operation. The user starts from something they already know they want to follow. Cockpit resolves transport, proposes Publisher/Creator, Interest Area, Handling, and Essential posture, then confirms Follow.

V1 includes RSS/Atom autodiscovery from human-facing URLs. It does not need autonomous discovery of what the user should follow.

---

## 6. Today and email

Cockpit is not an email client.

The Gmail Inbox remains the upstream queue for email that still requires or deserves attention. Cockpit's job is to reduce noise, surface what matters, and safely apply explicitly authorized source dispositions.

Cockpit reasons over the **current Inbox**, not only newly arrived messages since the last review.

Importance and actionability are different. A personal message may deserve attention even when no reply is required; an operational message may require action while carrying little emotional importance.

When uncertain about consequential mail, Cockpit fails conservatively by leaving it in Inbox.

### Clear and source disposition

`Clear` is a Cockpit attention action. The provider-side result is independently one of:

- Leave in Inbox
- Archive
- Trash

Archive is appropriate for valuable source material such as Yglesias. Trash is appropriate for explicitly disposable categories such as Amazon shipping notices or routine retail offers when an authorized policy exists.

Read/unread is provider presentation state, not Cockpit's canonical attention state.

A new reply that returns a conversation to Inbox naturally causes Cockpit to evaluate it again.

---

## 7. Later and Library

### Later

Later is a promise of deferred attention, not archival custody and not a guilt queue.

- explicit admission only;
- no silent expiry;
- simple browse/open/remove;
- Add to Library when durable retention becomes appropriate.

### Library

Library is Cockpit's durable corpus of ContentPieces.

It may receive explicit additions and, for an explicitly configured Stream, prospective automatic additions independent of Edition selection.

Automatic Library admission is never an excuse for silent historical backfill in V1.

Library should begin with useful metadata, provenance, semantic understanding, ordinary text search, and Subjects when helpful. More elaborate retrieval must be earned by corpus evidence.

---

## 8. Custody and offline

Library membership does not universally mean Cockpit stores a permanent byte-for-byte copy of the original.

Reliable upstream repositories may remain authoritative; Cockpit can retain identity, provenance, summary/enrichment, and a reliable reacquisition path.

Uploaded sole-source material creates a stronger promise: Cockpit must preserve the payload.

Loss of a normally reliable upstream source is a degradation state Cockpit can report; it does not justify preemptively duplicating all Gmail/provider material.

### Local availability

Offline state is independent of Edition/Later/Library.

- automatic cache may be evicted;
- **Offline until [date]** is an explicit temporary promise with visible expiry;
- **Keep Offline** is an indefinite promise until the user releases it.

This is intentionally designed to avoid opaque iCloud-style residency behavior.

---

## 9. Personal Knowledge

Personal Knowledge is durable explicit understanding of Jon.

V1 coarse categories are:

- Fact
- Taste
- Interest

Durable knowledge enters through direct teaching, correction, explicit explanation of why a ContentPiece matters, or confirmation of a question Cockpit asks.

Passive clickstream behavior does not silently become Personal Knowledge.

Cockpit may notice a pattern and ask, but the user must confirm before a materially new claim becomes durable.

The LLM may summarize, deduplicate, consolidate, and roll up explicit knowledge without turning Personal Knowledge into a daily maintenance chore. It must preserve meaning/provenance and may not invent materially broader claims.

Current Context is separate. Knowledge does not grant action authority.

### Jon Brain

V1 includes natural-language bulk teaching. Jon may invoke a standing `Jon Brain` convention in ChatGPT, copy synthesized `[Fact]`, `[Taste]`, and `[Interest]` bullets, and paste them into Cockpit.

Cockpit semantically reconciles the import against existing Personal Knowledge, auto-handles clerical duplicates/consolidation, and surfaces meaningful additions/refinements/contradictions for review.

No direct ChatGPT account/memory integration is required in V1.

---

## 10. Finds and the Jon Universe

Finds are outbound domain opportunities, not an excuse to enlarge Library.

Examples:

```text
restaurant Find → Galavant
recipe Find     → Yes Chef
product Find    → Pending until a suitable owner exists
```

The receiving specialist app owns canonical identity, deduplication, validation, and persistence.

Pending Finds should preserve enough faithful descriptive/provenance/evidence information to remain useful without developing domain-rich schemas inside Cockpit.

A growing population of orphan Finds may reveal the need for a future Shopping, Consumption, Cellar, Gear, or other app. Cockpit should let that shape emerge from evidence rather than invent it in advance.

---

## 11. Current Context and app-family awareness

Specialist apps may publish small current-context projections that help Cockpit judge relevance, such as active/upcoming travel context.

This context is not automatically Personal Knowledge and does not create family-wide canonical domain ownership.

Cockpit may use it to notice that a restaurant opening matters now without claiming ownership of the restaurant.

---

## 12. Product laws

1. **Cockpit tells Jon what came into his world, what matters, what can safely be ignored, and what is worth returning to.**
2. **Today is orientation/attention; Edition is reading/browsing/enrichment.**
3. **Edition is finite and rolling, not an infinite feed or unread backlog.**
4. **Later is explicit deferred attention and never silently expires.**
5. **Library contains ContentPieces, not universal domain things.**
6. **Finds belong with specialist apps when an owner exists.**
7. **Pending Finds are a holding queue, not a knowledge base.**
8. **Interest Areas describe why; Streams describe what recurring flow; Publisher/Creator describes who; Transport describes how.**
9. **Essential prevents substantive primary Stream material from silently aging away.**
10. **Stream Handling and provider Source Disposition are separate.**
11. **Cockpit attention state and Gmail provider state are separate.**
12. **Personal Knowledge comes from explicit intent, not clickstream inference.**
13. **Knowledge does not grant agency.**
14. **Reliable upstream custody, Cockpit-owned payload custody, and device-local offline availability are separate.**
15. **No productivity theater and no universal ontology.**

---

## 13. What should wait

Exact Edition aging, Later cleanup, Library retrieval sophistication, autonomous source discovery, monthly Personal Knowledge review, learned email policy proposals, generalized handoff infrastructure, trip-aware offline preparation, and future specialist-app taxonomy should all wait for implementation/use evidence.

See `docs/DECISIONS.md` and `docs/V1-SCOPE-AND-SEQUENCING.md` for the authoritative deferral list and implementation order.
