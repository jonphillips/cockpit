# Cockpit Content Experience

**Status:** Working product/interaction decision  
**Date:** 2026-09-08

## Purpose

This document captures the current design for Cockpit's **Content** experience: how Cockpit turns newsletters, RSS feeds, YouTube channels, publication streams, and other bounded content sources into a personalized daily newspaper that can be enjoyed, gradually cleared, and allowed to recede without becoming another backlog.

It extends:

- `docs/PRODUCT-MODEL.md`
- `docs/EMAIL-INTELLIGENCE-MODEL.md`
- `docs/IPAD-FIRST-EXPERIENCE.md`
- `docs/TODAY-EXPERIENCE.md`
- `docs/PERSONAL-KNOWLEDGE-MODEL.md`

This is a product and interaction model, not a pixel specification. Exact typography, card density, imagery, persistence windows, and source-management layout remain open to implementation and visual design.

---

## 1. Role of Content

Content is Cockpit's primary **reading, watching, browsing, discovery, and enrichment** environment.

It should feel like **Jon's newspaper**, not:

- an RSS reader,
- an email newsletter archive,
- a YouTube subscriptions inbox,
- a task list,
- a generic read-it-later service,
- or an infinite recommendation feed.

Its core question is:

> **I have some time. What is worth reading, watching, exploring, or considering?**

The strongest contrast is:

- **Today** asks what happened, what needs attention, and what especially deserves to register.
- **Content** asks what is worth consuming now or over the next several days.

A newsletter may arrive through Gmail but belong entirely in Content once Cockpit has ingested it. An NYT story may arrive through RSS. A YouTube video may arrive through a channel feed. The transport should remain visible as provenance but should not organize the main experience.

### Product principle

> **Sources organize ingestion. Content organizes meaning.**

And, consistently with Today:

> **Transport determines ingestion and source actions. Intent determines the product surface.**

---

## 2. Content is a newspaper, not a feed

Cockpit should perform substantial upstream reduction before presenting Content.

If thirty YouTube uploads arrive overnight, the product should not say:

```text
30 new videos
```

as though the user now owes the system thirty decisions.

Instead it may say:

```text
WATCH
3 worth a look
Screened from 30 new uploads
```

Likewise:

```text
FOOD & WINE
4 worth seeing
Screened from 18 incoming items
```

Raw arrivals are Cockpit's workload.

The user should interact with the **edition Cockpit produced**, not with every artifact that entered the system.

### Product law

> **Cockpit's backlog is not the user's backlog.**

This is central to the retired-life/lifestyle framing. Content should invite curiosity and pleasure, not manufacture obligations.

---

## 3. The daily edition

Content is organized around an **edition**.

The edition boundary is early morning. Each morning Cockpit assembles a fresh edition using:

```text
new material since the prior edition
        +
still-relevant carryovers
        +
Essential material not explicitly resolved
        ↓
TODAY'S CONTENT EDITION
```

The edition should feel coherent and finite enough to make progress through during a morning reading session.

However, a new edition does **not** mean everything from yesterday disappears.

### Core principle

> **The edition has a daily boundary. Individual stories do not all have a one-day lifespan.**

The right metaphor is that the newspaper **rolls forward** rather than resets.

### Edition law

> **Each morning Cockpit publishes a new edition. Freshness determines what enters; Handling determines how long material remains eligible; explicit user intent overrides aging.**

And:

> **An edition rolls forward; it does not simply reset.**

---

## 4. Different material deserves different hang time

Not all content has the same temporal shape.

Examples:

### Ephemeral daily news

A routine daily-news article may deserve only the current edition.

```text
Tuesday: surfaced
Wednesday: naturally gone unless Kept
```

### Opinion and commentary

A worthwhile essay may reasonably remain for several editions because its value is not exhausted by the day it arrived.

```text
Tuesday: New
Wednesday: Seen / still available
Thursday: still eligible if Cockpit believes it remains worth reading
```

### Weekly features

An NYT Food or Travel feature should not vanish merely because it arrived on a Tuesday.

A weekly feature may remain visible for much of the week or until the next meaningful installment supersedes it.

### Technical / instructional material

A useful development video, cooking technique, woodworking explanation, or other reference-like content may deserve several days of hang time even if not explicitly Kept.

### Event material

An event's relevance may persist according to event date and availability rather than publication date.

### Essentials

Essential sources are different again: their new substantive material should never silently disappear merely because it aged.

These distinctions should be driven primarily by source/subsource Handling and content shape, with AI available for semantic judgment where useful.

The system should not require the user to manually assign expiration dates to individual stories.

---

## 5. Essentials

Some writers or publications matter because of the user's relationship to the source itself, not just because each individual item happens to score highly against current interests.

Matthew Yglesias is the canonical example: if a source is one the user intends to follow comprehensively, Cockpit should not re-audition every post for relevance.

The current preferred term is **Essential**.

### Meaning

> **Essential means Cockpit should not quietly remove new substantive material from the active Content experience until the user explicitly deals with it.**

This is stronger than ordinary curation.

Examples of possible source Handling:

```text
MATTHEW YGLESIAS
Essential
Always show substantive new posts.
Do not auto-clear them.
Give enough orientation to decide whether to read now, later, or clear.
```

An Essential item may move through states such as:

```text
New
  ↓
Seen
  ↓
Clear OR Keep
```

but aging alone should not remove it.

### Personalization principle

> **Personalization should know when not to filter.**

Cockpit should distinguish between:

1. **Essential** — always surface substantive new material; explicit disposition required.
2. **Curated source** — follow the source but screen selectively.
3. **Discovery source** — the source itself is not important; surface only individual strong matches.

This distinction belongs primarily in Handling, not in a complicated user-visible taxonomy.

---

## 6. Presentation hierarchy

Content should be organized primarily by **editorial importance and subject**, not source.

A useful working hierarchy is:

```text
FOR YOU

ESSENTIALS

OPINION & COMMENTARY

ARTS & CULTURE

FOOD & WINE

TRAVEL & PLACES

TECHNOLOGY & MAKING

WATCH / LISTEN
```

These are editorial lanes, not fixed database facets.

Sections should appear only when they have worthwhile material. The exact set will evolve as actual usage shows which distinctions are useful.

### For You

`For You` contains the strongest cross-source judgments Cockpit made for the edition.

These are not necessarily the most important news stories. They are the things Cockpit believes are unusually likely to interest, delight, teach, or matter to the user.

A story may qualify because of:

- a strong Personal Knowledge match,
- unusual timeliness,
- a known current planning context,
- a subject or creator the user strongly cares about,
- an incidental nugget mined from a broader source,
- an unusually good opportunity.

`For You` should remain small enough that placement there means something.

### Essentials

`Essentials` provides predictable visibility for sources the user has explicitly or behaviorally established as must-see.

Unlike the rest of the newspaper, this area may benefit from some ordering stability and muscle memory.

### Subject sections

The remaining lanes organize meaning rather than source transport.

A Paris by Mouth restaurant opening, NYT Travel article, and YouTube hotel video may all belong under `Travel & Places`.

A Feed Me restaurant nugget, NYT Cooking article, and wine editorial may all appear under `Food & Wine`.

The database may know that a piece has multiple semantic memberships. The UI should usually choose one primary visual placement per edition rather than duplicate the same story everywhere.

---

## 7. Source identity remains visible

Although source does not organize Content, source identity matters for trust, taste, and provenance.

Content should be **source-savvy**.

A story should make it easy to see:

- publication or channel,
- author/creator where meaningful,
- source icon/logo/avatar when available,
- publication time,
- whether the source is email, RSS, YouTube, or another transport when deeper provenance is inspected,
- original source material or link.

The goal is a mixed-source newspaper that still feels grounded in recognizable publications and creators rather than AI-generated slurry.

### Visual language

The Content experience should likely combine:

- one or two hero stories where imagery genuinely adds pleasure,
- medium visual cards for material where image identity matters,
- many compact text-forward items,
- recognizable publication/channel marks.

Travel, food, architecture, film, music, and place-oriented stories may benefit strongly from imagery.

The app should not require every story to carry a giant generic image simply to make the page look busy.

---

## 8. The reading/clearing rhythm

A core emotional requirement is the **joy of gradually clearing the paper** without converting Content into a task-management system.

The Content edition should visibly settle as the user moves through it.

### New

An item that has not yet been opened in Cockpit.

It should carry normal visual prominence.

### Seen

Opening/tapping an item should mark it as **Seen**.

Seen does **not** mean Clear.

The item remains in the edition but should become visually subdued — for example, grayed or otherwise reduced in prominence — so the user can tell at a glance:

> **I already looked at this.**

The exact visual treatment is not yet specified.

### Clear

Clear means:

> **I am done considering this item in the active newspaper.**

It removes the item from the active edition.

For ordinary Content this is not necessarily the same as mutating the original provider. Source disposition follows the source's Handling policy and ingestion transport.

For email-delivered publications, Cockpit may already have archived the source email after successful custody/processing.

### Keep

Keep means:

> **This deserves durable custody beyond the active edition. I want to be able to return to it later.**

Kept material exits the ordinary aging rules of the newspaper and enters a retained collection.

The full design of `Kept`, `Reading`, or `Watch Later` has not yet been earned and should not be prematurely expanded into a universal knowledge-management system.

### Natural aging

The user does not have to explicitly Clear every ordinary item.

Non-Essential material may naturally leave future editions according to its persistence policy.

This is essential to preventing accumulation guilt.

### Product principle

> **Explicit clearing is available for satisfaction; natural aging prevents clearing from becoming an obligation.**

---

## 9. Clearing a section

Sections should support lightweight batch resolution where useful.

Example:

```text
WATCH
3 worth seeing
Screened from 30 uploads

[video]
[video]
[video]

Clear section
```

`Clear section` means the user does not want the remaining surfaced candidates carried forward in the active edition.

It should not imply that the user manually reviewed all thirty source artifacts; only the three surfaced candidates were ever promoted into the edition.

Essential material should not be swept away by broad section clearing unless the interaction makes that consequence explicit and deliberate.

---

## 10. End-of-edition posture

Content should permit a satisfying sense of being through the day's paper.

An end state may say something like:

```text
You're through today's edition.

4 things kept for later.
```

This should feel calm rather than celebratory.

No:

- streaks,
- completion scores,
- guilt-inducing unread counters,
- confetti,
- `37 of 37 complete` productivity theater.

The user should be able to leave with the feeling:

> **I know what was worth knowing today.**

---

## 11. Midday behavior

The early-morning edition is the canonical psychological boundary.

Content can still receive new material during the day, but Cockpit should avoid making the newspaper feel endlessly replenishing.

The initial product stance is:

- the morning edition establishes the day's main reading surface,
- ordinary low-urgency arrivals do not need to constantly reshuffle the page,
- Essential new material may enter when it arrives,
- unusually strong or time-sensitive discoveries may enter selectively,
- everything else can wait for the next edition.

Exact refresh policy remains an implementation/design question.

The governing goal is stability:

> **A morning newspaper should not turn into an infinite feed by lunch.**

---

## 12. Old unresolved material

Over time, some Essential or otherwise persistent material may linger.

This does not require a new conceptual category.

A future tool may offer an occasional review session such as:

```text
5 Essentials have been hanging around for more than a week.
```

Cockpit might then produce slightly richer summaries to help decide:

- Read,
- Keep,
- Clear.

For example:

> You opened this essay six days ago but never finished it. Its real argument is X; the part most likely to interest you is Y.

This is a useful future resolution tool, not a reason to complicate the core edition model now.

---

## 13. Content source model

The underlying source model is intentionally simple:

```text
SOURCE FAMILY
      ↓
SUBSOURCE / STREAM
      ↓
HANDLING
      ↓
INGEST / SCREEN / EXTRACT / ENRICH
      ↓
CONTENT EDITION
```

Examples:

### New York Times

```text
New York Times
   ├── Movies
   ├── Food
   ├── Travel
   ├── Technology
   ├── Opinion / Culture
   └── selected writers
```

### YouTube

```text
YouTube
   ├── Point-Free
   ├── cooking creator
   ├── film channel
   ├── woodworking creator
   └── other deliberately selected channels
```

The V1 goal should not be to import every YouTube subscription accumulated over many years. The Content source list should represent deliberately useful streams Cockpit is expected to curate.

### Email publications

```text
Email publications
   ├── Slow Boring
   ├── Feed Me
   ├── Kitchen Projects
   ├── Paris by Mouth
   └── Best of Journalism
```

Once these are recognized as managed Content sources, Gmail is simply their delivery transport.

---

## 14. Handling for Content

Personal Knowledge answers broadly:

> **What does Cockpit know about the user?**

Content Handling answers something narrower:

> **Why do I follow this source, and how should Cockpit deal with it?**

That distinction should keep source management lightweight.

Examples:

```text
MATTHEW YGLESIAS
Essential.
Always show substantive new posts.
Give enough orientation to decide whether to read.
Do not auto-clear.
```

```text
NYT MOVIES
Screen aggressively.
Surface serious film criticism, directors and films I care about,
and unusually strong cultural pieces.
Skip routine entertainment-industry churn.
```

```text
POINT-FREE
Be fairly permissive with substantive technical releases,
especially material relevant to architecture or libraries I actually use.
```

```text
FEED ME
Brief the main issue and mine it for incidental restaurants,
media, food, travel, or cultural nuggets I would otherwise miss.
```

```text
BEST OF JOURNALISM
Treat as a link collection.
Screen the linked pieces against what you know about me
rather than asking me to browse the whole list.
```

The user should not have to maintain detailed topic filter forms.

### Product principle

> **Jon Brain supplies most personalization. Handling supplies source-specific intent.**

---

## 15. Handling inheritance

The internal model may benefit from a simple inheritance structure:

```text
general Cockpit judgment
        +
source-family default
        +
specific stream instruction
        +
Personal Knowledge
        ↓
processing / ranking / persistence decision
```

For example:

```text
YouTube default:
Screen uploads against my interests.

Point-Free override:
Be unusually permissive with substantive releases.
```

Or:

```text
NYT default:
Surface unusually relevant journalism rather than comprehensive coverage.

NYT Food override:
Give strong technique/features more hang time because the section is weekly.
```

This is an implementation model, not necessarily a UI users need to see directly.

---

## 16. Source management experience

Sources are important infrastructure but are not themselves a primary recurring mode of use.

The primary navigation may remain almost comically sparse:

```text
Today
Content
```

with secondary access to:

- Sources,
- You / Personal Knowledge,
- Settings,
- future capabilities that eventually earn first-class status.

### Navigation principle

> **Top-level navigation is for recurring modes of use, not important internal concepts.**

`Sources` is administration for Content.

A standalone Sources surface should answer:

> **What am I following, and what does Cockpit currently think it should do with each source?**

Likely groupings may include:

```text
PUBLICATIONS & FEEDS

YOUTUBE

EMAIL PUBLICATIONS
```

Each source row can show:

- source name,
- source identity/icon,
- Essential status where applicable,
- concise human-language Handling summary,
- health/status if ingestion is failing,
- `Change how I handle this…`,
- stop following / remove.

The user should not routinely need this screen during the morning reading session.

---

## 17. Source setup should be light

Adding a source should not become taxonomy configuration.

### NYT example

Cockpit may present available streams with some descriptive color:

```text
NEW YORK TIMES

✓ Movies — reviews, essays, filmmaker coverage
✓ Food — cooking, restaurants, food culture
✓ Travel — destinations, hotels, travel reporting
○ Sports
○ Style
...

Cockpit will filter selected streams using what it knows about you.
```

### YouTube example

The natural subsource is the channel.

Cockpit should allow the user to deliberately add a manageable set of channels rather than mechanically importing an enormous historic subscription list.

### Email publication example

Cockpit may infer from Gmail behavior:

> This looks like a recurring publication. Treat it as Content?

Then propose a Handling instruction rather than ask the user to configure a large form.

### Product principle

> **Source setup should express intent, not expose ingestion machinery.**

---

## 18. Contextual source management

Most source management should be available where the source is already being consumed.

While reading a Point-Free item:

```text
How I handle Point-Free
Be fairly permissive with substantive releases.

Change this…
```

While reading an NYT Movies piece:

```text
How I handle NYT Movies
Screen aggressively for serious criticism and strong known-interest matches.

Change this…
```

While reading an email newsletter:

```text
How I handle Kitchen Projects
Mine substantive technique.
Archive source email after successful ingestion.

Change this…
```

This should reduce dependence on a centralized Sources control panel.

---

## 19. Content processing model

The Content experience inherits the progressive-cost intelligence model already established for email.

A useful general pipeline is:

```text
bounded source material arrives
        ↓
deterministic extraction / metadata
        ↓
cheap local or batched relevance judgment
        ↓
obvious rejects stay out of the edition
        ↓
promising / ambiguous candidates
        ↓
selective enrichment where necessary
        ↓
small number of surfaced Content items
```

### Product principle

> **Spend intelligence in proportion to demonstrated relevance.**

Not every NYT headline needs a full fetch.

Not every YouTube upload needs transcript-level understanding.

Not every newsletter link needs enrichment.

The edition is the output of this funnel.

---

## 20. Relationship to Today

Today and Content deliberately overlap at the very top of the value hierarchy.

A strong discovery may appear on Today as a teaser because it deserves to register during morning orientation.

The richer material belongs in Content for reading/browsing.

Examples:

```text
Paris by Mouth email
      ↓
Cockpit mines Anne-Sophie Pic restaurant news
      ↓
TODAY
Worth Seeing teaser
      ↓
CONTENT
Travel & Places story / retained source context
```

```text
24 wine retailer emails
      ↓
Cockpit derives Wine Market intelligence
      ↓
TODAY
1–2 tempting Wine Market teasers
      ↓
CONTENT
full curated Wine Market view
```

```text
30 YouTube uploads
      ↓
Cockpit screens down to 3
      ↓
TODAY
possibly the single strongest one if especially notable
      ↓
CONTENT
Watch section with 3 candidates
```

### Product principle

> **Today tells me what deserves to register. Content lets me spend time with what is worth consuming.**

---

## 21. iPad interaction model

Content is designed first for iPad with Magic Keyboard and trackpad.

The page should support:

- newspaper-like scanning,
- source-aware visual hierarchy,
- keyboard navigation through sections/items,
- persistent detail/reader behavior where useful,
- optional immersive full-screen reading,
- quick Keep / Clear / Tell You… / source Handling actions,
- easy transition among sections without losing position.

A likely high-level composition is:

```text
┌───────────────┬───────────────────────────────────────────────┐
│ Sidebar       │ CONTENT · Today's Edition                    │
│               │                                               │
│ Today         │ FOR YOU                                       │
│ Content       │ hero / strongest discoveries                  │
│               │                                               │
│               │ ESSENTIALS                                    │
│               │ Opinion & Commentary                          │
│               │ Food & Wine                                   │
│               │ Travel & Places                               │
│               │ Watch                                         │
│               │ ...                                           │
└───────────────┴───────────────────────────────────────────────┘
```

At generous widths, selecting an item may open a persistent Reader or inspection zone without losing the edition. Exact layout remains open.

---

## 22. iPhone companion

The iPhone version of Content should not attempt to recreate the full iPad newspaper.

Likely emphasis:

- Essentials,
- strongest For You items,
- compact section browsing,
- quick Keep,
- quick Clear,
- reading/watch handoff when convenient.

Deep source management, broad retrospective browsing, and rich comparative market views can remain iPad-primary unless real usage proves otherwise.

---

## 23. What Content must not become

Cockpit should actively resist several failure modes.

### Not an unread counter machine

Do not expose giant accumulating counts such as:

```text
1,283 unread articles
```

The whole point of Cockpit is that most incoming material never becomes the user's burden.

### Not an infinite algorithmic feed

Content should have an edition boundary and a sense of completion.

### Not a source taxonomy browser by default

Browsing by source may exist, but it is a secondary lens.

### Not a preference-database editor

Jon Brain and Handling should absorb natural-language guidance without asking the user to maintain fine-grained topic forms.

### Not a read-it-later warehouse

Keep is necessary. A giant universal archive is not yet justified.

### Not a task manager

Seen, Clear, and Keep support reading rhythm. They should not turn every article into a task with due dates, completion percentages, or guilt.

---

## 24. Design laws

1. **Content is a personalized newspaper, not an inbox or feed reader.**
2. **Sources organize ingestion; Content organizes meaning.**
3. **Cockpit's backlog is not the user's backlog.**
4. **The edition has a daily boundary; individual stories have different lifespans.**
5. **An edition rolls forward rather than resetting.**
6. **Essentials require explicit user disposition and never silently age away.**
7. **Personalization must know when not to filter.**
8. **Opening means Seen, not Clear.**
9. **Seen material becomes visually quieter but remains available.**
10. **Clear removes something from the active newspaper; Keep grants durable custody.**
11. **Natural aging is a feature, not data loss, for non-Essential material.**
12. **Subject/editorial meaning drives presentation; source remains visible as provenance.**
13. **Sections are dynamic editorial lanes, not rigid ontology.**
14. **One item should normally have one primary visual placement per edition.**
15. **Source Handling explains why the source is followed and how aggressively Cockpit should filter it.**
16. **Personal Knowledge supplies most personalization; source-specific configuration should remain light.**
17. **Source management is secondary administration, not the main Content experience.**
18. **Source setup should express intent rather than expose machinery.**
19. **The morning edition should remain psychologically stable rather than become an infinite feed by lunch.**
20. **Completion should feel like finishing a newspaper, not achieving Inbox Zero.**

---

## 25. Open questions / validate in UI

The product model is considered sufficiently resolved to proceed. The following should remain explicit validation questions rather than block further design.

### Exact visual treatment of Seen

We know Seen should be subdued while remaining in place. Exact typography, opacity, icons, and section-collapse behavior remain open.

### Persistence defaults

The model is settled, but exact values are not.

Need implementation evidence for defaults such as:

- daily-news lifespan,
- commentary lifespan,
- weekly-feature lifespan,
- technical/instructional lifespan,
- event-driven lifespan.

These should be editable via Handling where necessary but should not become routine user configuration.

### Midday admission

Need to test how much new material can enter an already-established edition without undermining the sense of a finite newspaper.

### Kept experience

Keep must exist, but the eventual shape of the retained collection remains deliberately underdesigned.

### Duplicate semantic membership

Current recommendation: allow multiple semantic classifications internally but only one primary visual appearance in an edition. Validate whether cross-section references are ever useful enough to break this rule.

### Essential review tool

The concept of occasional aging review is promising but should wait until unresolved Essential content becomes a real behavior rather than a hypothetical feature.

---

## 26. Recommended next design work

Content itself is now coherent enough that further abstract discussion is likely to produce diminishing returns.

The next useful design work should focus on adjacent surfaces and concrete interaction slices:

1. **Resolve the top-level iPad shell/navigation** around the now-strong `Today` + `Content` distinction.
2. **Design one representative Content edition at a real iPad width**, including For You, Essentials, two or three topical sections, Seen state, and Clear/Keep behavior.
3. **Design Sources management as a secondary surface**, including NYT stream selection, YouTube channel selection, and email-publication handling.
4. **Design one full Reader interaction** from Content, including provenance, Cockpit commentary, Keep, Clear, Tell You…, and source Handling.
5. **Define the first concrete V1 source slice** so implementation can test the edition model against real incoming material rather than mocks.

At that point, remaining questions should be resolved by building and using the product rather than extending the ontology.
