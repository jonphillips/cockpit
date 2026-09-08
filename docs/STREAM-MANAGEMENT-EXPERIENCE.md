# Cockpit Stream Management Experience

**Status:** Working product/interaction decision  
**Date:** 2026-09-08

## Purpose

This document defines the current user experience for managing recurring Content Streams in Cockpit.

It extends:

- `docs/CONTENT-STREAM-MODEL.md`
- `docs/CONTENT-EXPERIENCE.md`
- `docs/LATER-LIBRARY-EXPERIENCE.md`
- `docs/IPAD-FIRST-EXPERIENCE.md`
- `docs/EMAIL-INTELLIGENCE-MODEL.md`

The goal is to keep Stream management powerful enough to express real editorial intent without turning Cockpit into an RSS administration tool, publisher directory, rules engine, or subscription-cleanup project.

The user-facing shell is currently:

```text
Today
Edition
Later
Library

Settings
```

`Following` lives under **Settings**, not as another primary destination.

---

## 1. Vocabulary

The domain model remains:

```text
INTEREST AREA
      ↓
STREAM
      ↓
INCOMING ARTIFACTS
      ↓
EDITION / LATER / LIBRARY OUTPUT
```

with `Publisher / Creator` and `Transport` attached to the Stream.

- **Interest Area** — why Cockpit consumes the recurring material.
- **Stream** — the recurring flow Cockpit intentionally follows.
- **Publisher / Creator** — who produces it.
- **Transport** — how it arrives.
- **Source** — reserved for upstream provider material, provenance, source actions, and authoritative originals.

In normal UI, **Following** is the friendly label for Stream management.

---

## 2. Navigation decision

Following does **not** earn a primary tab/sidebar destination.

It belongs under **Settings** and remains reachable contextually from an Item/Reader when the user wants to inspect or change how a Stream is handled.

### Product principle

> **Following is administration for Edition, not a recurring mode alongside Today, Edition, Later, and Library.**

A likely Settings structure is:

```text
SETTINGS

Following
Interest Areas
Personal Knowledge / You
Integrations
Other app settings
```

Exact Settings grouping remains open, but the navigation level is settled.

---

## 3. Following is organized Interest-Area-first

The management experience should begin with editorial purpose rather than Publisher or Transport.

Representative overview:

```text
FOLLOWING

Essentials                         6
Opinion & Commentary              12
Arts & Culture                     9
Food & Wine                       15
Travel & Places                   11
Technology & Making               8
```

The count represents followed Streams, not unread Items.

Tapping `Travel & Places` may show:

```text
TRAVEL & PLACES

Cockpit looks here for distinctive places, hotels,
restaurants and destination intelligence worth knowing.

FOLLOWING

NYT Travel
The New York Times · roughly weekly
Screen for unusually strong destination and hotel reporting.

Paris by Mouth
Email publication
Mine for restaurants, chefs and meaningful Paris changes.

Selected YouTube creator
YouTube
Only surface unusually strong matches.
```

The Interest Area is a management/editorial home, not a semantic prison for every Item emitted by the Stream.

---

## 4. One global Add Stream action

V1 should have **one global Add Stream operation**, not a separate `+ Add Stream` inside every Interest Area.

It can be exposed prominently at the top level of Settings/Following and may also deserve a global toolbar/sidebar action if the final shell makes that natural.

The interaction starts from the Stream the user wants to follow, then Cockpit proposes where it belongs.

Conceptually:

```text
ADD STREAM
        ↓
paste / enter something known
        ↓
Cockpit discovers/resolves recurring transport
        ↓
identify Publisher / Creator
        ↓
propose Interest Area
        ↓
propose Handling
        ↓
confirm Follow
```

### Product principle

> **There is one admission door; Interest Area is an outcome of setup, not a prerequisite for starting it.**

---

## 5. V1 includes feed autodiscovery

V1 should be more pleasant than requiring the user to hunt down raw RSS URLs.

The user should be able to paste a human-facing URL for something they already know they want to follow, including:

- publication home page,
- publication section page,
- author/column page,
- YouTube channel/handle,
- direct RSS/Atom URL,
- another supported recurring-content page.

Cockpit should attempt automatic feed/transport discovery and resolution.

This is **discovery of how to follow a known target**, not autonomous discovery of what the user ought to follow.

### Product law

> **V1 discovers the transport for known intent; it does not need to discover the user's intent.**

---

## 6. Resolution ladder

Given a human-facing URL, Cockpit should attempt a bounded resolution ladder.

### 1. Direct RSS / Atom

If the URL is already a feed:

- validate it,
- derive title/Publisher where possible,
- propose the Stream.

### 2. Generic website feed autodiscovery

For an ordinary webpage:

- inspect standard RSS/Atom autodiscovery metadata,
- inspect obvious linked feeds,
- if one clear feed exists, propose it,
- if several plausible feeds exist, show the small set rather than silently guessing.

This generic autodiscovery is part of V1.

### 3. Narrow provider-specific resolution

Known providers may justify deterministic adapters.

Examples:

- YouTube human-facing channel/handle -> stable channel identity -> official uploads feed,
- reliable NYT section/collection mappings where available.

Provider adapters should remain narrow and testable.

### 4. Fallback

If Cockpit cannot resolve the recurring transport:

> I couldn't find a recurring feed automatically. Paste its RSS/Atom URL instead.

Failure should be explicit and recoverable.

---

## 7. What V1 autodiscovery does not mean

The decision to include feed autodiscovery does **not** imply V1 must provide:

- a browsable catalog of all NYT feeds,
- search/recommendation across all YouTube channels,
- import/cleanup of hundreds of historical YouTube subscriptions,
- automatic recommendations for new publications across the web,
- ongoing unsolicited discovery of Streams the user might like.

Those are separate future capabilities.

### Boundary

> **Resolve “follow this thing” intelligently; defer “what else should I follow?”**

---

## 8. Confirming a discovered Stream

After resolution, setup should emphasize editorial intent rather than transport machinery.

Example:

```text
FOUND
NYT Travel
The New York Times

Interest Area
Travel & Places                    >

Cockpit proposes:
Screen for distinctive destination, hotel, restaurant and
place reporting. Give major features several editions of hang time.

Essential                          Off

[ Follow ]
```

The raw feed URL can exist in deeper technical detail but should not dominate normal setup.

---

## 9. Stream rows stay compact

A normal Following row should show only information that helps the user understand what Cockpit follows and why.

Likely visible:

- Stream name,
- Publisher / Creator,
- Essential indicator where applicable,
- concise Handling summary,
- cadence/last activity only as quiet metadata where useful,
- health only when abnormal.

Do not routinely expose:

- raw RSS URLs,
- channel IDs,
- sender-pattern internals,
- parser/enrichment strategy,
- deduplication state,
- model/ranking parameters,
- detailed persistence mechanics.

### Health principle

> **Healthy should be quiet. Broken should be visible.**

---

## 10. Stream detail

Tapping a Stream should expose the small number of decisions the user meaningfully owns.

Representative structure:

```text
NYT TRAVEL
The New York Times

Interest Area
Travel & Places                    >

Essential
Off

HOW COCKPIT HANDLES THIS

Find unusually good destination, hotel and restaurant
reporting. Let major features remain for several editions.
Skip routine service journalism unless it intersects strongly
with something I care about.

[ Change… ]

LIBRARY
Automatic admission               Off

──────────────────────────────────
Following                         On
Last received                     Sep 8
Typical cadence                   Weekly-ish
Transport                         RSS

Pause
Stop Following
```

Not every inferred field needs to be visible in V1.

---

## 11. The user owns a small number of meaningful decisions

The user meaningfully owns:

1. **Why am I following this?** — Stream Handling.
2. **Where does it broadly belong?** — primary Interest Area.
3. **Is it Essential, or may Cockpit curate it?**
4. **Should every new item be admitted automatically to Library?** — only where that stronger durable-corpus posture makes sense.

The user should not ordinarily configure cadence, content shape, parser, ranking weights, exact expiry duration, or enrichment depth.

### Product principle

> **The user supplies editorial/custody intent. Cockpit supplies mechanics and sensible defaults.**

---

## 12. Editing Handling: propose before committing

`Change…` should accept natural-language correction rather than open a rules form.

Example input:

> Actually, I care a lot about interesting new hotels, even expensive ones. I almost never care about generic airline or points-and-miles stories.

Cockpit should then generate a **proposed rewritten durable policy** and show it before saving.

Example:

```text
PROPOSED HANDLING

Surface distinctive destination, hotel and restaurant reporting,
including luxury hotels when the property itself is interesting.
Aggressively skip points-and-miles, airline-hack and generic
service-travel stories unless they intersect with a specific current need.

[ Cancel ]   [ Save Changes ]
```

The user sees the canonical interpretation before it becomes persistent policy.

### Product law

> **Handling edits are conversational input followed by an explicit proposed-policy review.**

This is preferable to either a large settings form or invisible immediate mutation.

---

## 13. Essential

Essential deserves explicit UI because it has a strong behavioral consequence.

> **Substantive primary material from an Essential Stream may not silently age out of Edition.**

For mixed publications, Essential protects the primary publication artifact; it does not necessarily make every extracted incidental Find immortal.

---

## 14. Automatic Library admission

A Stream may independently have an explicit Library policy.

Example:

```text
ANDREW HARPER

Edition Handling:
Surface especially relevant new issues/material.

Library:
Automatically catalog every new issue.
```

This is stronger than ordinary Stream custody and independent of Edition selection.

Rules:

- explicit user-approved policy,
- prospective only,
- **no automatic backfill**,
- stopping/changing the policy does not delete already admitted Library Items,
- payload/download behavior remains governed by Library/storage rules in `docs/LATER-LIBRARY-EXPERIENCE.md`.

### Product principle

> **A Stream may feed Edition selectively and Library comprehensively.**

---

## 15. Contextual management

Following under Settings is the centralized management surface, but Stream Handling should remain reachable contextually while reading an Item.

Example:

```text
POINT-FREE
Technology & Making

How Cockpit handles this Stream
Be fairly permissive with substantive releases…

Change…
```

The best moment to correct a policy is often when the current output demonstrates that the policy is wrong.

Contextual Stream controls should remain secondary to primary Reader actions such as Save for Later, Clear, Tell Cockpit, Handoff, and Open Original.

---

## 16. Publisher / Creator remains secondary

Publisher grouping is useful for occasional inspection:

```text
THE NEW YORK TIMES

Following
Travel        -> Travel & Places
Food          -> Food & Wine
Movies        -> Arts & Culture
Technology    -> Technology & Making
```

But Publisher is not the primary management hierarchy and V1 does not require a complete publisher catalog browser.

---

## 17. Pause, stop, and move

### Pause

Temporarily stop new material while preserving Stream identity, Handling, Interest Area, and existing Later/Library material.

### Stop Following

Stop future recurring ingestion/admission.

Existing:

- Later memberships,
- Library memberships,
- durable Personal Knowledge,
- truthful provenance

remain intact.

### Move Interest Area

Change the Stream's primary future management/editorial home without rewriting historical provenance.

---

## 18. What V1 must not become

Do not turn Following into:

- a primary navigation destination,
- a giant RSS directory,
- a comprehensive publisher browser,
- a YouTube subscriptions cleanup project,
- a taxonomy editor,
- a rules matrix,
- a feed-health dashboard,
- a user-maintained frequency database.

Autodiscovery is deliberately bounded to making **known Stream admission** pleasant.

---

## 19. Design laws

1. **Following lives under Settings, not in primary navigation.**
2. **Interest Areas remain the primary management hierarchy once a Stream is admitted.**
3. **There is one global Add Stream operation.**
4. **V1 includes generic RSS/Atom feed autodiscovery from human-facing URLs.**
5. **Provider-specific resolvers may supplement generic autodiscovery where deterministic.**
6. **V1 discovers how to follow known intent; it need not discover what the user should follow.**
7. **The user owns Interest Area, Handling, Essential posture, and optional automatic Library admission.**
8. **Healthy operation is quiet; abnormal health is visible.**
9. **Handling is edited in natural language, then shown as a proposed rewritten canonical policy before commit.**
10. **Essential prevents silent aging of substantive primary material.**
11. **Automatic Library admission is explicit, prospective, and never silently backfilled.**
12. **Publisher/Creator remains a secondary lens.**
13. **Stopping a Stream does not destroy Later/Library material or durable knowledge.**
14. **Following should answer what Cockpit follows and why, not expose ingestion machinery.**

---

## 20. Open questions / validate in implementation

The remaining questions are now implementation/design details rather than ontology:

- exact placement of the global Add Stream control within Settings/sidebar chrome,
- how many autodiscovered feed candidates to show before the UI becomes noisy,
- whether V1 needs NYT-specific resolution beyond generic feed discovery,
- whether YouTube channel resolution can be done entirely without user API/account setup,
- how Stream health and retries are surfaced when autodiscovery initially succeeds but later fetches fail,
- exact Stream detail presentation for automatic Library admission and per-device offline policy,
- exact Settings hierarchy for `Following` versus `Interest Areas`.