# Cockpit Today Experience

**Status:** Working product/interaction decision  
**Date:** 2026-09-08

## Purpose

This document captures the current design for Cockpit's **Today** surface after working through the real Gmail corpus, the iPad-first product decision, the distinction between attention/workflow material and leisurely Content, and the newer Content Stream / Interest Area model.

It extends:

- `docs/PRODUCT-MODEL.md`
- `docs/EMAIL-INTELLIGENCE-MODEL.md`
- `docs/IPAD-FIRST-EXPERIENCE.md`
- `docs/PERSONAL-KNOWLEDGE-MODEL.md`
- `docs/CONTENT-EXPERIENCE.md`
- `docs/CONTENT-STREAM-MODEL.md`

The design is intentionally detailed enough to guide product implementation, but it is not a pixel specification. Exact layout, card dimensions, typography, and iconography remain open to visual design.

---

## 1. Role of Today

Today is Cockpit's primary morning orientation surface.

Its job is not to reproduce Gmail, an RSS reader, a calendar app, or a task manager. Its job is to answer:

> **What needs my attention today, what especially deserves to register, and what can I safely ignore?**

Today should feel like a personal editorial front page assembled from multiple incoming channels and Content Streams, interpreted through Handling and Personal Knowledge.

The most important distinction is:

- **Today** is for orientation, attention, and the best current discoveries.
- **Content** is for leisurely browsing, reading, watching, enrichment, and revisiting material after the morning orientation moment.

A newsletter may arrive through Gmail but ultimately belong in Content. A wine offer may arrive through Gmail, disappear as an email, and emerge on Today as a derived Wine Market teaser. A strong Item from an RSS or YouTube Stream may deserve a Today teaser without making Today an RSS or video browser.

### Product principle

> **Transport determines ingestion and source actions. Intent determines the product surface.**

`Source` remains appropriate for upstream/provider/provenance semantics. Recurring Content inputs are **Streams**.

---

## 2. Canonical iPad use case

Today is designed first for an iPad used with Magic Keyboard and trackpad during an extended morning catch-up session.

An ordinary session may last an hour, but the product should also work on a quiet five-minute morning.

The flow is:

1. Open Cockpit on iPad.
2. Establish what kind of day this is.
3. See personal and consequential material that needs attention.
4. Notice a very small number of especially interesting discoveries.
5. See teaser intelligence from domains such as wine, events, cooking, retail, travel, or development.
6. Open selected material in a persistent detail/reader pane without losing the Today context.
7. Occasionally correct Cockpit or explain why something matters.
8. Move into Content when the posture changes from **catch up** to **read/browse/kill time**.

Today should support sustained use without feeling like a productivity ritual.

No streaks, completion scores, or Inbox Zero ceremony are needed.

---

## 3. Overall iPad composition

The current mental model is a deliberately sparse app shell plus a Today workspace.

Only two recurring modes have clearly earned primary prominence so far:

```text
Today
Content
```

Secondary access should exist for things such as:

- Interest Area / Following / Stream management,
- You / Personal Knowledge,
- Settings,
- future capabilities that eventually earn first-class status.

The exact user-facing name of Stream management remains open. The domain noun is `Stream`; `Following` may prove friendlier in UI.

The sidebar should deliberately leave room for future capabilities such as Agents, Watches, Tasks, or other genuinely recurring modes once their product value and execution harnesses are real.

### Navigation principle

> **Top-level navigation is for recurring modes of use, not important internal concepts.**

Personal Knowledge is foundational but does not require a permanent top-level `You` destination. Stream management is foundational to Content but does not require a permanent primary destination either.

### Today workspace

The Today workspace should support:

- an editorial overview,
- direct selection of modules/Finds,
- a persistent detail/reader area,
- optional full-screen reading when desired.

A rough structural model is:

```text
┌─────────────┬───────────────────────────────┬──────────────────────────────┐
│ Sidebar     │ Today briefing                │ Selected detail / reader     │
│             │                               │                              │
│ Today       │ date / context                │ Why this is here             │
│ Content     │ attention                     │ Cockpit's take               │
│             │ worth seeing                  │ original/source material     │
│             │ market/event teasers          │ actions / commentary         │
│             │ handled quietly               │                              │
└─────────────┴───────────────────────────────┴──────────────────────────────┘
```

The exact number of visible columns may adapt with window size. The governing behavior is persistence: selecting something should not routinely destroy the user's place in Today.

---

## 4. Top-of-day context

The top of Today should establish lightweight situational context rather than immediately dropping the user into message triage.

Likely ingredients include:

- `Today` / date,
- local weather when useful,
- today's calendar context,
- perhaps a compact representation of time-sensitive obligations.

The calendar is valuable because it helps answer:

> **What kind of day am I having?**

Calendar context can also improve relevance decisions. Travel information may matter more on a travel day; restaurant material may become timely around a dinner reservation; a fully open morning may invite a richer Content transition.

### Reminders caution

Cockpit should not casually mirror Apple Reminders as a permanent dashboard box merely because the data exists.

A better future abstraction may be something like **Time-sensitive today**, which can derive from:

- calendar,
- reminders,
- reservations,
- email-extracted deadlines,
- membership/account expiration,
- other explicit obligations.

This remains an open design question. Today must not drift into a generic life task manager.

---

## 5. Need Your Attention

The attention area is the conservative, workflow-oriented part of Today.

It should prominently surface material that may still deserve human attention, including:

- personal correspondence,
- business/transactional material,
- changed reservations,
- account/payment problems,
- tickets or confirmations with consequential changes,
- provider messages Cockpit is not confident it can safely clear.

### Personal

A Personal module may summarize current relevant correspondence by person or thread rather than list raw Gmail messages.

Example:

```text
PERSONAL
Jack
Mom
Hotel reply from a named person
```

Personal material should be handled conservatively and should not be silently cleared merely because an AI predicts that no response is required.

### Business / consequential

A Business/Consequential module may summarize facts and actions such as:

```text
BUSINESS
Point-Free payment method needs updating
Reservation changed
Membership expires soon
```

The user should understand the real-world consequence without Cockpit manufacturing a parallel task-completion state.

`Clear` still means the upstream provider message no longer needs Inbox attention. It does not mean the real-world obligation was completed.

---

## 6. Worth Seeing Today

Today needs a first-class editorial area for discoveries that are neither personal mail nor one of the named domain widgets.

This is the place for:

> **The most interesting things that entered Jon's world today.**

The motivating example is a Paris by Mouth newsletter containing, deep within the issue, news that Anne-Sophie Pic had opened Utopic at Fondation Cartier and would open a full restaurant shortly afterward.

That discovery should not have to fit awkwardly into `Personal`, `Business`, `Wine Market`, `Retail Market`, or `Events` merely to be visible.

Example:

```text
WORTH SEEING TODAY

Anne-Sophie Pic has a new Paris restaurant
Paris by Mouth · strong travel/food match

Xcode headless MCP materially changes app-development workflows

iOS Code Review · strong development match
```

The area should contain very few Items. It represents Cockpit's strongest editorial judgment, not another queue.

### Product principle

> **Today must have permission to surface a great discovery even when it does not fit a named module.**

---

## 7. Derived intelligence modules

Today may also show domain-specific intelligence modules generated by processing many upstream Artifacts and/or Streams.

Examples include:

- Wine Market,
- Retail Market,
- Events,
- Cooking,
- Travel,
- Reading,
- Development,
- other domains that earn meaningful current output.

These modules should usually be **compact teasers**, not full analytical workspaces.

Their purpose is:

> **Give Jon one or two concrete reasons to care enough to open the richer view.**

### Teaser pattern

A good module should combine:

1. **Compression** — evidence that Cockpit did work.
2. **One or two actual Finds** — something specific enough to be tempting.
3. **Editorial labels/reasons** — why those Finds are interesting.
4. **A path to the full view.**

Example:

```text
WINE MARKET
3 worth seeing · 21 ignored

BEST FIT
2024 Santenay 1er Cru
Strong producer, appealing vintage, unusually sane price.

ALLOCATION
Ferren fall release opens Sep 15
A producer already worth paying attention to.

See all 3 →
```

Retail:

```text
RETAIL MARKET
2 worth seeing · 18 ignored

ACTUALLY RELEVANT
Proper Cloth
A lightweight piece that plausibly fits how Jon dresses.

POSSIBLE BUY
Grenson
One sale pair that avoids the chunky/fashion-forward problem.

See all →
```

Events:

```text
EVENTS
2 plausible hits

STRONG MATCH
[artist/event]
Nearby, good date, strong known-interest fit.

WILDCARD
[film/performance]
Not an obvious favorite, but Cockpit thinks it is worth a look.

See all →
```

### Useful teaser labels

Potential labels include:

- Best fit
- Best value
- Strong match
- Unusual
- New allocation
- Wildcard
- Worth knowing about
- Probably your thing

These are domain/editorial language, not a universal enum requirement.

### Interaction

- Clicking a teaser Find should open that specific Find directly in the detail pane.
- Clicking the module title or `See all` should open the richer domain view, likely in Content or a dedicated derived view.

---

## 8. Dynamic composition

Today should not reserve permanent empty furniture for every possible domain.

One morning may contain:

```text
Wine Market
Reading
Cooking
Travel
```

Another may contain:

```text
Events
Development
Restaurants
Music
```

If a domain has nothing worth saying, it should usually disappear rather than show an empty module.

Some modules may eventually earn persistent placement through observed utility, but the default should remain editorial and adaptive.

### Product principle

> **Today is composed around value delivered today, not around a fixed taxonomy of life domains.**

---

## 9. Handled Quietly

Today should expose a small, low-prominence trust door for material Cockpit processed and chose not to surface.

Example:

```text
47 handled quietly ›
```

or:

```text
47 handled quietly
18 promotions · 12 weak reading matches · 9 routine notices · 8 other
```

This is not a queue the user is expected to review.

It exists because Cockpit must be inspectable. It supports moments such as:

> “Wait, why did you skip that Phantom Thread piece?”

The skipped/quiet view can reveal lightweight reasoning and provide explicit correction opportunities.

Silence about skipped material is not learning evidence.

Explicit disagreement is.

---

## 10. Persistent detail / reader behavior

On iPad, the preferred default is persistent master-detail behavior rather than replacing the entire Today surface whenever something is selected.

Example:

```text
┌────────────────────────────┬──────────────────────────────────┐
│ TODAY                      │ Anne-Sophie Pic                  │
│                            │                                  │
│ Personal                   │ WHY I SHOWED THIS                │
│ Business                   │ ...                              │
│                            │                                  │
│ Worth Seeing               │ COCKPIT'S TAKE                   │
│  > Anne-Sophie Pic         │ ...                              │
│  Phantom Thread            │                                  │
│                            │ ORIGINAL                         │
│ Wine Market                │ Paris by Mouth source material   │
│ Events                     │                                  │
│                            │ Add to Galavant · Keep           │
│ Handled quietly            │ Not for me · Tell You…           │
└────────────────────────────┴──────────────────────────────────┘
```

The detail pane may contain:

- Why this is here,
- Cockpit's take,
- original/source material,
- Keep,
- Clear where upstream attention semantics apply,
- specialist Handoff,
- Not interested,
- Tell You…,
- Stream Handling access for recurring Content,
- provider/source-action detail where relevant.

Full-screen reading should remain available as an optional immersive mode, especially for long-form material, but should not be the default navigation model.

---

## 11. `Tell You…` and contextual learning

The Brain should be prominent in Cockpit's behavior rather than necessarily in top-level navigation.

Today is one of the main places where contextual learning occurs.

Examples:

- “PTA is one of my favorite directors.”
- “I don't care about high-altitude cooking.”
- “This restaurant matters because I follow the chef.”
- “Don't show every Paris bistro opening; I only care if something is genuinely distinctive.”

`Tell You…` should allow natural-language text or dictation without asking the user to classify the input as Fact, Taste, Interest, Stream Handling, or temporary guidance.

Cockpit decides how the evidence should be used and distilled, while preserving provenance and allowing correction.

---

## 12. Keyboard and trackpad

Because the canonical platform is iPad + Magic Keyboard + trackpad, Today should be navigable fluently without constant touch interaction.

The product should eventually support shortcuts for actions such as:

- move through modules/Finds,
- open selected Find,
- return focus to Today,
- Keep,
- Not interested,
- Tell You…,
- Clear where appropriate,
- specialist Handoff where a sensible shortcut exists,
- toggle/enter immersive reading.

Exact key assignments remain open. Keyboard/trackpad efficiency is a core interaction requirement rather than an afterthought.

---

## 13. Relationship to Content

Today should not become the permanent home of everything Cockpit discovers.

A useful lifecycle is:

```text
incoming provider material / Stream Artifacts
       ↓
processing / interpretation
       ↓
Today teaser or attention item when currently important
       ↓
Content for ongoing reading/browsing/consumption
```

### Newsletter Stream

```text
Kitchen Projects email arrives
       ↓
ingest + process according to Stream Handling
       ↓
archive Gmail according to upstream source-disposition policy
       ↓
Today: perhaps one useful technique / issue teaser
       ↓
Content: issue remains available to read
```

### Wine

```text
23 merchant messages
       ↓
collapse into market intelligence
       ↓
provider email cleared according to Handling/policy
       ↓
Today: 1–2 tempting Wine Market teasers
       ↓
Content/market view: full curated set
```

### Events

```text
Ticketing / venue Streams or messages
       ↓
parse + match
       ↓
Today: 1–2 strong/wildcard events
       ↓
Content/events view: richer browseable set
```

### Product principle

> **Today tells me what happened and what deserves to register. Content is where I decide what I feel like consuming.**

---

## 14. End-of-review posture

Today should settle rather than celebrate completion.

If the user has handled the important current material, a calm end state may say:

```text
You're caught up.

5 Gmail messages remain deliberately in Inbox for your attention.
```

The day's briefing should remain readable afterward.

No confetti, streaks, scores, or `17/17 complete` behavior.

---

## 15. iPhone companion adaptation

The iPhone should not attempt to recreate the full Today workspace.

Its Today experience should emphasize:

- Need Your Attention,
- the very best Worth Seeing Items,
- compact market/event teasers,
- Capture,
- quick Keep / Not Interested / Clear,
- lightweight Handoff,
- optional reading when convenient.

Deep skipped review, rich market comparison, Stream Handling editing, sustained contextual commentary, and complex browsing can remain primarily iPad experiences.

Platform asymmetry is intentional.

---

## 16. Open questions

The following remain deliberately unresolved and should not block moving on.

### Naming

`Today` currently feels slightly stronger than `Daily` because it names a destination rather than a process, but the final label remains open.

### Top context composition

Need to determine the exact balance among:

- date,
- weather,
- calendar,
- reminders/time-sensitive context.

Calendar feels strongly justified. A direct Reminders mirror remains questionable.

### Fixed versus dynamic module placement

Dynamic editorial composition is the default. Usage may prove that specific modules such as Wine Market deserve more persistent placement.

### Detail-pane geometry

Need visual prototyping across common iPad widths and window states to determine when the Reader appears as a trailing pane, wider replacement region, sheet, or optional full-screen view.

### Attention grouping names

`Personal` and `Business` are useful current labels, but exact naming and whether Business should become `Consequential`, `Needs Attention`, or another concept remain open.

### `Handled Quietly` wording

The concept is settled; the final user-facing phrase is not.

### Stream management destination label

Stream is the domain term, but the secondary UI destination may be better named `Following` or something else. This should be resolved in the management sketch rather than by ontology.

---

## 17. V1 acceptance test

A successful ordinary Monday morning should feel roughly like this:

1. Today immediately establishes date/day context and the shape of the day.
2. Personal and consequential material is obvious and hard to miss.
3. Cockpit surfaces perhaps one to three especially interesting discoveries that would otherwise have been buried.
4. Market/event/domain modules provide concrete teaser Finds rather than generic counts.
5. The user can understand that substantial upstream/Stream volume was compressed without reviewing it.
6. Selecting something preserves the Today context while opening a rich explanation/source view.
7. The user can correct Cockpit at the moment a judgment is wrong.
8. Quietly handled material remains inspectable without becoming another obligation.
9. When the user wants to linger, browse, read, or kill time, the natural next move is Content.
10. The session ends with informed calm rather than a productivity score.

### North-star interaction

> **Cockpit should make it normal for an important or delightful thing buried deep in a noisy incoming Stream to become obvious at exactly the moment Jon is catching up on his world.**