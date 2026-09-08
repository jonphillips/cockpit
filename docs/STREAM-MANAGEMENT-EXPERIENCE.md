# Cockpit Stream Management Experience

**Status:** Working product/interaction decision  
**Date:** 2026-09-08

## Purpose

This document defines the current user experience for managing recurring Content Streams in Cockpit.

It extends:

- `docs/CONTENT-STREAM-MODEL.md`
- `docs/CONTENT-EXPERIENCE.md`
- `docs/IPAD-FIRST-EXPERIENCE.md`
- `docs/EMAIL-INTELLIGENCE-MODEL.md`

The goal is to keep Stream management powerful enough to express real editorial intent without turning Cockpit into an RSS administration tool, a newsletter rules engine, or a content-discovery catalog.

The core product distinction is:

> **Content is the product. Stream management is administration for Content.**

And the V1 setup boundary is:

> **Resolve known intent; do not try to discover intent.**

The user tells Cockpit what recurring thing they want to follow. Cockpit should handle as much transport resolution and mechanical setup as it reasonably can.

---

## 1. User-facing vocabulary

The domain model remains:

```text
INTEREST AREA
      ↓
STREAM
      ↓
CONTENT
```

with `Publisher / Creator` and `Transport` attached to the Stream.

In normal UI, the word **Following** may be friendlier than exposing `Stream` everywhere.

Examples:

```text
TRAVEL & PLACES

Following
- NYT Travel
- Paris by Mouth
- Fathom
- selected YouTube channel
```

`Stream` remains the precise product/domain term. `Following` is a likely presentation label.

`Source` should remain reserved for upstream/provenance/provider-action semantics as defined in `docs/CONTENT-STREAM-MODEL.md`.

---

## 2. Navigation position

Stream management is not expected to be a primary everyday mode alongside `Today` and `Content`.

The recurring product modes are increasingly:

```text
Today
Content
Library
```

Stream management should remain secondary, likely reachable through one or more of:

- `Following`
- a management/settings group in the sidebar
- contextual Stream controls while reading Content
- an `Add Stream` action within an Interest Area

The exact sidebar placement remains a UI question.

### Navigation principle

> **Top-level navigation is for recurring modes of use; Following exists because the user occasionally needs to manage what feeds those modes.**

---

## 3. Primary management organization: Interest Area first

The management experience should begin with the user's editorial structure rather than transport or publisher.

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

The count represents followed Streams, not unread items.

Tapping an Interest Area shows the Streams contributing to it.

Example:

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

+ Add Stream
```

This should answer:

> **What have I asked Cockpit to pay attention to for this Interest Area, and why?**

---

## 4. What a normal Stream row shows

The normal management row/card should stay compact.

Likely visible information:

- Stream name
- Publisher / Creator identity and recognizable icon/avatar where available
- Essential indicator when applicable
- concise one-line Handling summary
- cadence or last activity only as low-prominence metadata when useful
- health only when abnormal

Do not routinely expose:

- raw RSS URLs
- YouTube channel IDs
- sender-pattern internals
- parsing strategy
- enrichment strategy
- deduplication state
- model/ranking parameters
- detailed persistence mechanics

### Health principle

> **Healthy should be quiet. Broken should be visible.**

A normal row should not become a dashboard of green status badges.

---

## 5. Stream detail

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

Change…

──────────────────────────────────

Following                   On
Last received               Sep 8
Typical cadence             Weekly-ish
Transport                   RSS

Pause
Stop Following
```

Not every inferred field needs to be visible in V1. The key requirement is that the user can understand what the Stream is, why Cockpit follows it, where it belongs, whether it is Essential, and whether ingestion is working.

---

## 6. The user owns three meaningful decisions

Most Stream complexity should remain inferred.

The user meaningfully owns:

1. **Why am I following this?**  
   Expressed through human-language Stream Handling.

2. **Where does it broadly belong?**  
   Expressed through one primary Interest Area.

3. **Is it Essential, or may Cockpit curate it?**  
   Essential has explicit behavioral consequences and deserves explicit UI.

The user should not ordinarily have to configure cadence, content shape, exact persistence duration, parsing mode, enrichment depth, or transport mechanics.

### Product principle

> **The user supplies editorial intent. Cockpit supplies mechanics and sensible defaults.**

---

## 7. Editing Handling

`Change…` should not open a rules form.

It should allow natural-language correction such as:

> Actually, I care a lot about interesting new hotels, even expensive ones. I almost never care about generic airline or points-and-miles stories.

Cockpit can then revise the durable Handling instruction and show the resulting plain-English interpretation.

Examples:

### Matthew Yglesias

```text
Essential.
Always surface substantive new posts.
Give me enough orientation to decide whether to read.
Never let an unresolved post silently age out.
```

### Point-Free

```text
Be fairly permissive with substantive technical releases,
especially architecture and libraries relevant to my apps.
```

### Paris by Mouth

```text
Mine for restaurants, chefs, meaningful openings and Paris
changes I might plausibly care about, even when buried inside
a larger issue.
```

### Handling principle

> **Settings should express intent, not expose the machinery used to satisfy it.**

---

## 8. Contextual Stream management

The standalone Following surface should not be the only place to change a Stream.

While reading an Item, the user should be able to reach lightweight contextual controls such as:

```text
POINT-FREE
Technology & Making

How I handle this Stream
Be fairly permissive with substantive releases…

Change…
```

This is important because the best moment to correct Handling is often the moment Cockpit makes a judgment the user disagrees with.

Contextual access should remain secondary to reading actions such as Keep, Clear, Tell Cockpit, Handoff, or Open Original.

---

## 9. V1 Add Stream philosophy

V1 should not require Cockpit to maintain a browsable catalog of all NYT feeds, all YouTube channels, or every possible publication on the internet.

That sounds simple in a mockup but hides a materially different product capability: content-source discovery.

Instead, V1 should assume:

> **The user already knows the publication, section, writer, creator, or channel they want to follow.**

The Add Stream interaction should then make the mechanical setup as easy as possible.

### Product law

> **Resolve known intent; do not try to discover intent.**

---

## 10. Add Stream by human-facing URL

The preferred V1 input is not necessarily a raw RSS URL.

The user should be able to paste a URL for the thing they already know they want to follow:

- an RSS/Atom feed URL
- a publication website
- a publication section page
- an author/column page
- a YouTube channel page
- another supported bounded recurring-content URL

Cockpit then attempts deterministic resolution.

Conceptually:

```text
Paste URL for something I want to follow
        ↓
recognize / inspect URL
        ↓
resolve a recurring Stream when possible
        ↓
validate transport
        ↓
identify Publisher / Creator
        ↓
propose Interest Area
        ↓
propose Handling
        ↓
confirm Follow
```

This is significantly better than requiring the user to understand feed plumbing while remaining far smaller than a discovery catalog.

---

## 11. Resolution ladder

Given a pasted URL, Cockpit should attempt a bounded resolution ladder.

### 1. Direct RSS / Atom

If the URL already resolves to RSS/Atom:

- validate the feed
- identify title/publisher where possible
- create/propose the Stream

### 2. Generic web feed autodiscovery

For an ordinary webpage, Cockpit may inspect standard feed-discovery metadata and obvious linked RSS/Atom alternatives.

If one clear feed exists, propose it.

If several plausible feeds exist, show the small set for user selection rather than guessing silently.

### 3. Small provider-specific resolvers

Known providers may justify narrow adapters where resolution is deterministic and valuable.

Examples:

- YouTube channel URL/handle -> stable channel identity -> official uploads feed
- known NYT section/collection page -> corresponding validated NYT feed where a reliable mapping exists

A provider adapter should resolve a user-supplied known target. It should not silently grow into a publisher-wide browsing/catalog subsystem.

### 4. Explicit fallback

If Cockpit cannot resolve the human-facing URL:

> I couldn't find a recurring feed automatically. Paste its RSS/Atom URL instead.

Failure should be clear and recoverable rather than disguised as model magic.

---

## 12. YouTube V1

For YouTube, the user should not need to know or construct an Atom feed URL.

A human-facing channel URL or handle should be sufficient input when Cockpit can deterministically resolve it.

Conceptually:

```text
Paste YouTube channel URL
        ↓
resolve channel identity
        ↓
validate official uploads feed
        ↓
Stream
```

The product should not require importing the user's entire historical YouTube subscriptions list.

Likewise, V1 does not need:

- recommendations among all YouTube subscriptions
- automatic classification of hundreds of old subscriptions
- global YouTube channel discovery

Those are future discovery features, not prerequisites for following a known creator.

---

## 13. NYT and similar publishers in V1

A publisher such as The New York Times may expose many useful recurring feeds, but Cockpit does not need a comprehensive publisher catalog in V1.

If the user already knows they want `NYT Travel`, they should be able to paste the human-facing NYT Travel page or the feed URL.

Cockpit may use a small provider-specific mapping when reliable, then validate the resulting feed.

What V1 should not promise:

> Show me every NYT stream I might like.

or:

> Browse the full NYT feed hierarchy inside Cockpit.

Those require catalog/discovery functionality that is separable from Stream management.

### Publisher principle

> **A publisher adapter may resolve a known destination without becoming a publisher browser.**

---

## 14. Confirming a resolved Stream

Once Cockpit resolves the recurring flow, confirmation should focus on editorial intent rather than transport details.

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

Change…

Essential                          Off

Follow
```

The raw resolved feed URL can remain available in deeper technical detail if needed, but it should not dominate setup.

---

## 15. Publisher/Creator browsing is secondary and future-facing

Publisher grouping remains useful for occasional questions such as:

- Which NYT Streams am I following?
- Which YouTube creators am I following?
- Is a publisher-wide connection broken?

A secondary publisher view may eventually show:

```text
THE NEW YORK TIMES

Following
Travel        -> Travel & Places
Food          -> Food & Wine
Movies        -> Arts & Culture
Technology    -> Technology & Making
```

But **browsing all available Streams from that publisher** should remain a separate future feature until a real provider/catalog integration earns it.

---

## 16. Stream discovery is explicitly deferred

V1 Stream setup is user-initiated resolution, not autonomous discovery.

Future features may include:

- scan recent email for likely recurring publications
- suggest converting a recurring newsletter into a managed Stream
- inspect a large YouTube subscription list and recommend a smaller deliberate set
- recommend additional NYT feeds based on an Interest Area
- discover publications that could improve an Interest Area

Each of these requires materially more than the Stream model itself: catalogs, provider/account integration, identity resolution, recommendation logic, deduplication, proposal suppression, and trust UX.

They should not be smuggled into V1 behind phrases such as `Browse streams` or `Cockpit notices…`.

### Product principle

> **Stream discovery is a future capability. V1 only needs excellent admission of a Stream the user already wants.**

---

## 17. Pause, stop, and move

### Pause

Temporarily stop new material while preserving Stream identity, Handling, Interest Area, and existing retained content.

### Stop Following

Stop future ingestion/admission. Existing Library/Kept material and durable derived knowledge remain intact.

### Move

Change the primary Interest Area for future management/editorial behavior.

Moving a Stream does not rewrite historical provenance or force old Items into a new conceptual history.

---

## 18. Relationship to Library

Library is not part of Stream management, but one boundary matters:

> **Stopping a Stream does not delete material the user explicitly Kept.**

Library represents user-chosen durable material. Stream state controls future recurring ingestion.

Likewise, technical artifact custody for a Stream does not automatically make every retained artifact a Library item.

### Product principle

> **Cockpit custody is not Library; Library reflects explicit user Keep intent.**

---

## 19. What V1 must not become

Do not turn Stream management into:

- a giant RSS directory
- a publisher catalog browser
- a YouTube subscriptions cleanup project
- an email newsletter auto-discovery engine
- a feed-health dashboard
- a taxonomy editor
- a rules engine
- a user-maintained frequency database
- a publisher/subsource hierarchy the user must understand

The user should mostly see a concise answer to:

> **What am I following here, and why?**

---

## 20. Design laws

1. **Interest Areas are the primary management hierarchy.**
2. **Streams are the recurring content flows Cockpit intentionally follows.**
3. **`Following` is a likely friendly UI label for Stream management.**
4. **The user owns editorial intent; Cockpit owns most mechanics.**
5. **The key user decisions are Interest Area, Handling, and Essential posture.**
6. **Healthy operation should be quiet; abnormal health should be visible.**
7. **Stream Handling is edited in human language, not a rules matrix.**
8. **Contextual Stream management is as important as centralized management.**
9. **V1 resolves Streams the user already knows they want.**
10. **A human-facing URL is the preferred setup input when Cockpit can resolve it.**
11. **Resolution should proceed from direct feed, to generic autodiscovery, to narrow provider-specific adapters, to explicit fallback.**
12. **Provider adapters resolve known targets; they do not imply publisher-wide discovery catalogs.**
13. **Stream discovery is separate future functionality.**
14. **Stopping a Stream does not destroy Library items or durable knowledge derived from it.**
15. **The management experience should answer what Cockpit follows and why, not expose ingestion machinery.**

---

## 21. Open questions / validate in UI and implementation

The model is now sufficiently resolved that remaining questions should be answered through sketches and the first concrete integrations rather than additional ontology.

### Naming and navigation

- Is the management destination actually labeled `Following`, or does that word work better only as the section label inside Interest Areas?
- Does Following deserve a secondary sidebar entry, or should it live under Content/Settings plus contextual access?
- Should Essentials be a management group as well as a Content presentation section?

### Interest Area management

- Does the Following overview show only Interest Areas and counts, or also one-line summaries of what each area is for?
- Can Interest Areas be reordered/hidden in V1, or is that unnecessary until usage earns it?
- Is adding a Stream always initiated from an Interest Area, or can there be a global `Add Stream` that proposes one?

### Add Stream resolution

- How much generic website feed autodiscovery is worth implementing in the first slice versus accepting direct feed URLs plus a few provider adapters?
- Which provider-specific resolvers earn V1 support first: YouTube, NYT, or neither until generic RSS works?
- If a page exposes multiple valid feeds, what is the cleanest confirmation UI?
- How much identity/branding enrichment should happen before Follow versus asynchronously afterward?

### Handling

- Should `Change…` immediately rewrite the durable Handling statement after AI interpretation, with Undo, or show a proposed rewrite for confirmation?
- Does Essential remain a separate explicit toggle, or can natural-language Handling such as `never let me miss this` set it only after explicit confirmation?

### Health and cadence

- What exactly constitutes `broken` versus merely `quiet` for an irregular Stream?
- Is last-received/cadence visible only in Stream detail unless something is wrong?

### Stop / pause semantics

- When a Stream is paused or stopped, should currently surfaced but unkept Items remain in the current edition until normal resolution/aging, or clear immediately?
- Should Stop Following offer a one-time option to remove currently active edition Items without touching Library?

### First implementation slice

The strongest candidates for validating the model are:

1. generic RSS/Atom feed URL -> Stream
2. YouTube channel URL -> Stream
3. one email publication -> Stream

The first slice should prove resolution, Interest Area assignment, Handling, edition admission, and health before adding discovery catalogs.
