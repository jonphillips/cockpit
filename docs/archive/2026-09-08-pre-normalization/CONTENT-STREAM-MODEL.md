# Cockpit Content Stream Model

**Status:** Working product/domain decision  
**Date:** 2026-09-08

## Purpose

This document defines the current model for how Cockpit intentionally follows recurring Content inputs and organizes their management.

It extends:

- `docs/CONTENT-EXPERIENCE.md`
- `docs/EMAIL-INTELLIGENCE-MODEL.md`
- `docs/PERSONAL-KNOWLEDGE-MODEL.md`

The goal is to give the product and architecture a stable vocabulary before implementation accidentally hardens ambiguous uses of `Source`, `Publisher`, and `Subsource`.

The central model is:

```text
INTEREST AREA
      ↓
STREAM
      ↓
INCOMING ARTIFACTS
      ↓
INTERPRET / SCREEN / EXTRACT / ENRICH
      ↓
CONTENT ITEMS / FINDS
      ↓
CONTENT EDITION
```

with `Publisher / Creator`, `Transport`, and provenance attached to a Stream rather than treated as the user's primary hierarchy.

---

## 1. Vocabulary

### Interest Area

An **Interest Area** is the editorial reason Cockpit follows a set of recurring streams.

Examples:

- Opinion & Commentary
- Arts & Culture
- Food & Wine
- Travel & Places
- Technology & Making

Interest Areas are real user-visible objects, not merely tags.

They may carry lightweight descriptive/editorial guidance such as:

> Favor distinctive hotels, restaurants, destination intelligence, and strong place writing. De-emphasize generic service-travel churn.

Interest Areas should remain much lighter than Streams. They exist to provide a durable editorial lens and a natural management home, not to become a large ontology.

### Stream

A **Stream** is the recurring content flow Cockpit intentionally follows.

Examples:

- `NYT Travel`
- `NYT Food`
- `Matthew Yglesias`
- `Paris by Mouth`
- `Kitchen Projects`
- a specific YouTube channel
- an OpenAI release-notes feed

A Stream is the primary configurable content-ingestion object.

### Publisher / Creator

A **Publisher / Creator** identifies who produces a Stream.

Examples:

- The New York Times
- Paris by Mouth
- Matthew Yglesias / Slow Boring
- Point-Free
- an individual YouTube creator

Publisher/Creator is initially lightweight identity, branding, and grouping. It is not the primary behavioral hierarchy.

One publisher may produce many Streams:

```text
The New York Times
   ├── NYT Travel
   ├── NYT Food
   ├── NYT Movies
   └── NYT Technology
```

### Transport

**Transport** is how Cockpit receives the Stream.

Examples:

- RSS / Atom
- email
- YouTube channel feed
- provider API
- another explicit bounded integration later

Transport matters for ingestion, authentication, refresh, custody, and provider actions. It should rarely organize the Content experience.

### Source

`Source` remains a useful technical/provenance word, but it should no longer be the primary product noun for recurring Content management.

Use `source` for questions such as:

- What upstream artifact did this information come from?
- What is the authoritative original URL/material?
- What provider message must be archived?
- What evidence supports this interpretation?
- What source action is being proposed?

Do **not** use `Source` when the intended product meaning is “the recurring publication/feed/channel Cockpit follows.” That object is a **Stream**.

### Item / Find

A Stream produces incoming Artifacts that Cockpit may turn into Content Items, Finds, summaries, extracted Subjects, or other presentation-specific output.

The Stream is not itself the newspaper item.

---

## 2. Governing product principle

> **Interest Areas describe why Cockpit is consuming information. Streams describe what recurring flow Cockpit follows. Publishers describe who produced it. Transports describe how it arrived.**

The default user-facing management hierarchy should therefore be editorial rather than publisher-centric.

For example:

```text
TRAVEL & PLACES

Following
- NYT Travel
- Paris by Mouth
- Fathom
- selected YouTube travel channel
```

rather than forcing the user to begin with:

```text
New York Times
YouTube
Email
RSS
```

A secondary Publisher view may still be useful for inspection and maintenance.

---

## 3. Interest Areas are management objects

An Interest Area should initially own only a small amount of durable meaning.

Conceptually:

```text
InterestArea
- identity
- display name
- short description / editorial intent
- optional human-language Handling guidance
- display/order preferences where eventually earned
- active/hidden state if needed
```

Examples:

### Travel & Places

> Surface distinctive hotels, restaurants, destination intelligence, openings, and unusually good place writing. Prefer material that could plausibly affect where we go or what we do over generic travel-service journalism.

### Food & Wine

> Surface genuinely useful cooking technique, strong recipe candidates, restaurant intelligence, and wine material with unusual relevance or value. Do not make volume itself look important.

### Technology & Making

> Surface developments that materially affect AI, Apple-platform development, the app family, tools, or hands-on making. Prefer actionable or conceptually important changes over routine industry churn.

These instructions should not become comprehensive preference profiles. Personal Knowledge remains the richer cross-domain understanding of the user.

### Interest Area law

> **An Interest Area provides an inherited editorial lens; it is not a replacement for Personal Knowledge or Stream-specific Handling.**

---

## 4. A Stream has one primary Interest Area

Every managed Stream should have one **primary Interest Area**.

That gives the user a natural place to find and manage it.

Examples:

```text
NYT Travel        -> Travel & Places
Kitchen Projects  -> Food & Wine
Matthew Yglesias  -> Opinion & Commentary
Point-Free        -> Technology & Making
```

This is a management/default-placement relationship, not a semantic prison.

A mixed Stream may produce Items that belong elsewhere.

Example:

```text
Feed Me
Primary Interest Area: Food & Wine

but an individual issue may yield:
- restaurant opening -> Food & Wine
- Poconos hotel -> Travel & Places
- Substack executive news -> News / Opinion & Commentary
```

The Item can be classified/routed according to its own meaning while the Stream remains managed under one stable primary Interest Area.

### Product law

> **A Stream has one primary editorial home; its Items may travel.**

---

## 5. Conceptual Stream model

A Stream currently needs to represent the following concerns.

### Identity

A stable Cockpit identity independent of display name, URL changes, or provider-specific identifiers.

### Name

Human-readable name such as:

- `NYT Travel`
- `Paris by Mouth`
- `Point-Free`
- `Matthew Yglesias`

### Publisher / Creator

Lightweight producer identity used for provenance, grouping, and visual branding.

### Transport + locator

Enough deterministic information to retrieve or recognize incoming material.

Examples:

- RSS/Atom feed URL
- YouTube channel ID
- email list/sender identity
- provider/API endpoint reference

Transport-specific credentials should remain transport/integration concerns rather than being embedded into editorial semantics.

### Primary Interest Area

The Stream's stable management/editorial home.

### Cadence

Observed or declared frequency such as:

- daily
- weekly
- irregular
- high-volume
- event-driven

Cadence is primarily system metadata, not routine user configuration.

It can help answer:

- Is silence normal?
- Is a burst expected?
- Should the previous issue remain until the next issue arrives?
- Is the Stream stale or broken?

Cockpit should normally infer cadence from observation or known metadata rather than make the user configure it.

### Content shape

A descriptive/inferred understanding of what the Stream usually emits.

Examples:

- full-text publication issue
- link digest
- mixed newsletter
- article feed
- video uploads
- structured event listings
- market offers

Content shape informs processing operations such as Brief, Screen, Mine, Extract, Match, or Collapse.

It should normally be inferred rather than exposed as a form field.

### Handling

Human-language editorial instruction answering:

> **Why do I follow this Stream, and what should Cockpit do with it?**

Examples:

**Matthew Yglesias**

> Essential. Always show substantive new posts. Give me enough orientation to decide whether to read. Never silently clear them.

**NYT Movies**

> Screen aggressively for serious criticism, filmmakers and films I care about, and unusually strong cultural pieces. Skip routine entertainment-industry churn.

**Point-Free**

> Be fairly permissive with substantive technical releases, especially anything relevant to architecture or libraries actually used in my apps.

**Paris by Mouth**

> Mine for restaurants, chefs, meaningful openings, and other Paris changes I might plausibly care about, even when they are buried inside a larger issue.

Handling is intentionally semantic. The product should not require the user to maintain a large matrix of topic toggles.

### Filtering posture

A Stream may conceptually behave as:

- **Essential** — substantive new primary material requires explicit user disposition
- **permissive** — surface much of the substantive output
- **selective** — screen meaningfully
- **aggressive/discovery** — surface only unusually strong matches

These postures are useful operational concepts but do not necessarily require a prominent enum in the UI. Human-language Handling is the primary product contract.

### Edition persistence

How long surfaced material from this Stream normally remains eligible for the active Content edition.

This is distinct from storage retention.

Examples:

- daily news: short-lived
- opinion/commentary: several editions
- weekly feature: much of the week or until superseded
- technical/instructional content: several days
- event content: until relevance/event timing expires
- Essential: never silently age away

Exact durations should be deterministic defaults informed by cadence/content shape and overridden by explicit Handling where necessary.

### Artifact custody

Whether Cockpit preserves source material, a faithful representation, metadata/reference only, or some other retained form after ingestion.

This is independent of edition persistence.

### Upstream/source disposition

What happens to the provider artifact after successful processing, where such a mutation exists.

Most important for email:

- leave in Inbox
- archive after successful custody/processing
- Trash only under an explicitly configured disposable policy

This is independent of Content persistence and custody.

### Health

Operational status such as:

- healthy
- stale
- broken
- authorization required
- fetch/parsing failure
- intentionally quiet

Health belongs primarily in Stream management, not in the newspaper unless it materially affects trust.

### Follow state

At minimum:

- following
- paused
- stopped

A later implementation may need more operational state, but the product does not currently require a complex lifecycle enum.

---

## 6. Do not overload `retention policy`

The phrase `retention policy` is too ambiguous for the Stream model.

Cockpit must distinguish at least three concerns:

### Edition persistence

> How long should this surfaced material remain in the active newspaper?

### Artifact custody

> What source material does Cockpit preserve for later reading, evidence, or reprocessing?

### Upstream/source disposition

> What happens to the provider artifact after Cockpit has processed it?

Example:

```text
NYT Travel
Edition persistence: several editions / roughly weekly cadence
Artifact custody: metadata + authoritative article reference
Upstream disposition: none; RSS is read-only
```

versus:

```text
Kitchen Projects
Edition persistence: several days / until next issue
Artifact custody: preserve issue content
Upstream disposition: archive email after successful custody
```

### Architectural law

> **Edition persistence, artifact custody, and upstream disposition are separate decisions.**

---

## 7. Essential is a Stream-level posture with precise consequences

`Essential` belongs naturally on a Stream because it describes the user's relationship with that recurring flow.

Its core consequence is:

> **Substantive primary material from an Essential Stream may not silently age out of Content.**

For a simple one-post-per-artifact Stream such as Matthew Yglesias, this is straightforward.

For a mixed newsletter, `Essential` should not blindly make every extracted incidental Find immortal. The primary publication artifact is protected; extracted Items continue to follow their own meaning and persistence unless Handling says otherwise.

This avoids turning one Essential mixed publication into an unbounded collection of explicit-clear obligations.

---

## 8. Handling inheritance and precedence

The model should support useful defaults without making every Stream independently configured.

A conceptual decision stack is:

```text
Cockpit product defaults
        +
Interest Area guidance
        +
Stream Handling
        +
relevant Personal Knowledge
        +
Item-specific meaning/current context
        ↓
processing / ranking / placement / persistence
```

When instructions conflict, explicit narrower intent should win over broader defaults.

A practical precedence rule is:

1. explicit item-level user intent
2. explicit Stream Handling
3. explicit Interest Area guidance
4. relevant Personal Knowledge
5. product defaults / inferred behavior

Personal Knowledge is not simply “lower priority” in a mathematical sense; this ordering expresses user-authorized editorial instruction. A Stream rule such as `Always show Yglesias` intentionally constrains filtering even if a particular post looks weak against ordinary interest ranking.

### Product principle

> **Personal Knowledge tells Cockpit what the user is like. Interest Areas and Streams tell Cockpit what job the user hired this recurring content to do.**

---

## 9. Publisher / Creator should remain lightweight

Publisher/Creator should initially own only what has demonstrated value:

- stable identity
- display name
- icon/logo/avatar where available
- website/domain
- grouping of related Streams

It may later earn shared authentication, transport configuration, or publisher-wide defaults where real integrations make that useful.

Do not invent a large Publisher inheritance model merely because The New York Times happens to expose many feeds.

The user-facing behavioral unit remains the Stream.

---

## 10. Stream setup

V1 should support explicit, understandable Stream creation without requiring automatic discovery.

A useful flow is:

```text
choose/add a recurring stream
        ↓
Cockpit resolves publisher/creator + transport
        ↓
assign/propose primary Interest Area
        ↓
Cockpit proposes concise Handling
        ↓
optionally mark Essential
        ↓
Follow
```

The user should normally **not** have to configure:

- cadence
- content shape
- detailed persistence duration
- extraction strategy
- ranking weights
- transport mechanics

Cockpit should infer those or supply sensible defaults and expose corrections only when useful.

### NYT

The user may browse available NYT Streams with descriptive color, but management should still land them under Interest Areas:

```text
Travel & Places
  + NYT Travel

Food & Wine
  + NYT Food

Arts & Culture
  + NYT Movies
```

A secondary publisher view can answer:

> Which New York Times Streams am I following?

### YouTube

The Stream is the channel.

V1 should favor deliberate selection over importing an enormous historic subscriptions list.

### Email publications

A known newsletter can be explicitly admitted as a Stream and assigned to an Interest Area.

Automatic recognition such as:

> This looks like a recurring publication. Treat it as Content?

is valuable future source-discovery functionality, but it is **not required to establish the Stream model or V1 management UX**.

---

## 11. Stream discovery is a separate capability

Do not hide source-discovery complexity inside the Stream object.

Automatically proposing a new email Stream may require:

- recurring-message grouping
- publication/list recognition
- distinguishing editorial content from transactional/promotional mail
- resolving publication identity
- detecting duplicates with already-followed RSS/API Streams
- proposing an Interest Area
- proposing initial Handling
- remembering accepted/rejected proposals

That can be added progressively.

The V1 Stream model should work perfectly even if every Stream is explicitly added by the user.

### Product principle

> **Stream management and Stream discovery are separate problems. Do not make discovery magic a prerequisite for useful management.**

---

## 12. Pause, stop, move

### Pause

Temporarily stop ingesting/admitting new material from the Stream while preserving its identity, Handling, and existing retained Content.

### Stop following

Stop future ingestion/admission. Existing Kept material and durable derived knowledge should not be destroyed merely because the Stream is no longer followed.

### Move to another Interest Area

Change the Stream's primary management/editorial home for future behavior.

Historical provenance should remain truthful; moving a Stream does not rewrite where old Items came from.

The UI does not need a heavy migration ceremony.

---

## 13. Overlapping Streams and deduplication

The same underlying piece may enter through multiple Streams.

Examples:

- an NYT article appears in both `NYT Travel` and another NYT feed
- a linked article appears in a newsletter and a publication feed
- a future API and RSS integration both observe the same content

Cockpit should preserve all relevant provenance while avoiding duplicate user burden.

Conceptually:

```text
Stream A observation
       +
Stream B observation
       ↓
one underlying Content identity when confidently resolved
       ↓
one primary surfaced Item
```

Exact identity resolution can remain conservative. Uncertain matches should not be destructively merged.

### Product law

> **Multiple Streams may observe the same content; Cockpit should normally surface it once while preserving provenance.**

---

## 14. Stream health

Stream health should be visible when it matters but otherwise quiet.

A management view may show:

```text
NYT Travel          healthy · latest today
Paris by Mouth      healthy · weekly
Point-Free          healthy · irregular
Example Feed        fetch failed · 3 days
```

Cadence helps Cockpit distinguish `quiet` from `broken`.

Health problems should not pollute the Content edition unless they materially undermine expected coverage or require user action.

---

## 15. Management experience

The user should usually manage Streams **through Interest Areas**, because Interest Areas describe why the content matters.

A representative view:

```text
TRAVEL & PLACES

Following

NYT Travel
The New York Times · RSS
Features and destination reporting
Handling: screen for distinctive, relevant travel intelligence

Paris by Mouth
Paris by Mouth · Email
Handling: mine for restaurants, chefs and meaningful Paris changes

[ + Follow another stream ]
```

The primary screen need not prominently expose the word `Stream`; `Following` may be the friendlier UI label.

A secondary Publisher/Creator browser can support questions such as:

- show all NYT Streams
- show every YouTube channel I follow
- inspect publisher-wide connection/health

### What a Stream row/card likely needs

At most:

- Stream name
- Publisher/Creator identity
- primary Interest Area when outside that area's view
- Essential indicator where applicable
- concise Handling summary
- cadence/last activity as low-prominence metadata where useful
- health only when abnormal

Everything else belongs in detail or should remain inferred.

### Management principle

> **The screen should answer what Cockpit follows and why, not expose the machinery that makes following possible.**

---

## 16. Contextual management remains important

Central management should not be the only way to change a Stream.

While consuming an Item, the user should be able to inspect:

```text
POINT-FREE
Technology & Making

How I handle this Stream
Be fairly permissive with substantive releases...

Change this...
```

or:

```text
NYT TRAVEL
Travel & Places

How I handle this Stream
Surface unusually good destination/hotel/place reporting...

Change this...
```

This lets corrections happen at the moment the user understands why the current behavior is wrong.

---

## 17. Relationship to Content presentation

Interest Areas are both management objects and natural editorial lanes, but management structure does not rigidly dictate the newspaper layout.

Content may still lead with:

```text
FOR YOU
ESSENTIALS
```

before topical Interest Areas.

A Stream's Item may be placed in a different section when the Item's meaning warrants it.

The Content experience remains editorially composed rather than a literal dump of each Interest Area's incoming queue.

### Product principle

> **Interest Areas organize editorial intent; the edition remains free to exercise editorial judgment.**

---

## 18. Relationship to email Handling

`Stream Handling` and upstream `source actions` are related but not synonyms.

For an email-delivered publication:

```text
Stream Handling
Why do I follow this publication?
What should Cockpit extract/surface?
How persistent should its content be?

Upstream source disposition
After successful ingestion/custody, should Gmail leave/archive/trash the provider message?
```

This distinction preserves the existing email doctrine:

> **Transport determines ingestion and source actions. Intent determines the product surface.**

`Source action`, `source disposition`, and `source material` remain correct language when discussing provider artifacts and provenance.

`Stream` is the correct language when discussing the recurring Content flow the user intentionally follows.

---

## 19. What not to model yet

Do not prematurely introduce:

- mandatory multi-Interest-Area membership for Streams
- giant publisher inheritance trees
- user-configured cadence for every Stream
- arbitrary per-item expiration forms
- universal topic-weight matrices
- automatic Stream discovery as a V1 dependency
- a general-purpose `Source` object that conflates publisher, transport, provenance, and recurring content intent

The conceptual model is intentionally richer than the first schema needs to be.

Do not translate every bullet in this document into a column before the first real Stream implementations demonstrate what must be persisted versus derived.

---

## 20. Design laws

1. **Interest Areas describe why Cockpit consumes recurring content.**
2. **Streams are the primary recurring Content unit the user follows and configures.**
3. **Publishers/Creators describe who produced a Stream; Transports describe how it arrived.**
4. **`Source` is reserved for upstream/provenance semantics, not used as the main recurring-content noun.**
5. **A Stream has one primary Interest Area; its Items may be routed elsewhere.**
6. **Interest Areas are real objects with lightweight inherited editorial guidance.**
7. **Stream Handling answers why this Stream is followed and how Cockpit should deal with it.**
8. **Personal Knowledge supplies broad personalization; Interest Areas and Streams supply editorial mandate.**
9. **Explicit narrower intent overrides broader inherited defaults.**
10. **Cadence and content shape are primarily inferred system metadata, not user homework.**
11. **Edition persistence, artifact custody, and upstream disposition are separate decisions.**
12. **Essential protects substantive primary material from silent aging.**
13. **Publisher/Creator remains lightweight until real consumers earn more abstraction.**
14. **Stream discovery is separate from Stream management.**
15. **Multiple Streams may observe the same content; Cockpit should normally surface it once while preserving provenance.**
16. **Management is primarily Interest-Area-first, with Publisher/Creator as a secondary lens.**
17. **The Content edition is editorial output, not a mirror of management structure.**
18. **Do not turn the conceptual model directly into an overbuilt schema.**

---

## 21. Open questions / validate in UI

The core model is considered sufficiently resolved to proceed.

The remaining questions are best tested in the actual Interest Area / Following management sketch:

- exact name of the secondary management destination (`Following`, `Streams`, or another label)
- how new Streams are discovered/browsed from within an Interest Area
- whether publisher browsing is a separate screen, inspector mode, or search/filter
- exact UI for editing human-language Handling
- how much cadence/health metadata belongs in a normal row
- whether an Interest Area needs explicit ordering/customization beyond its name and guidance in V1
- how pause/stop-following actions should treat currently surfaced but unkept edition Items

These do not require further ontology before visual/interaction design.