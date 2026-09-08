# Cockpit Content Experience

**Status:** Working product/interaction decision  
**Date:** 2026-09-08

## Purpose

This document captures the current design for Cockpit's **Content** experience: how Cockpit turns newsletters, RSS/Atom feeds, YouTube channels, publication feeds, and other bounded recurring inputs into a personalized daily newspaper that can be enjoyed, gradually cleared, and allowed to recede without becoming another backlog.

It extends:

- `docs/PRODUCT-MODEL.md`
- `docs/EMAIL-INTELLIGENCE-MODEL.md`
- `docs/IPAD-FIRST-EXPERIENCE.md`
- `docs/TODAY-EXPERIENCE.md`
- `docs/PERSONAL-KNOWLEDGE-MODEL.md`
- `docs/CONTENT-STREAM-MODEL.md`

The Stream model owns recurring-content vocabulary and management semantics. This document owns the reading/browsing experience produced from those Streams.

This is a product and interaction model, not a pixel specification. Exact typography, card density, imagery, persistence windows, and management layout remain open to implementation and visual design.

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

A newsletter may arrive through Gmail but belong entirely in Content once Cockpit has ingested it. An NYT story may arrive through RSS. A YouTube video may arrive through a channel feed. Transport should remain inspectable as provenance but should not organize the main experience.

### Product principles

> **Streams organize recurring ingestion intent. Content organizes meaning.**

> **Transport determines ingestion and source actions. Intent determines the product surface.**

`Source` remains correct language for upstream provider artifacts, provenance, original material, and provider mutations. The recurring thing the user follows is a **Stream**.

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

The user should interact with the **edition Cockpit produced**, not with every Artifact that entered the system.

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

A new edition does **not** mean everything from yesterday disappears.

### Core principle

> **The edition has a daily boundary. Individual stories do not all have a one-day lifespan.**

The newspaper **rolls forward** rather than resets.

### Edition law

> **Each morning Cockpit publishes a new edition. Freshness determines what enters; Handling determines how long material remains eligible; explicit user intent overrides aging.**

And:

> **An edition rolls forward; it does not simply reset.**

---

## 4. Different material deserves different hang time

Not all content has the same temporal shape.

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
Thursday: still eligible if worth carrying
```

### Weekly features

An NYT Food or Travel feature should not vanish merely because it arrived on a Tuesday.

A weekly feature may remain visible for much of the week or until the next meaningful installment supersedes it.

### Technical / instructional material

A useful development video, cooking technique, woodworking explanation, or other reference-like content may deserve several days of hang time even if not explicitly Kept.

### Event material

An event's relevance may persist according to event date and availability rather than publication date.

### Essentials

Material from an Essential Stream is different again: substantive primary material should never silently disappear merely because it aged.

These distinctions should be driven primarily by Stream Handling, cadence, content shape, and deterministic persistence defaults, with AI available for semantic judgment where useful.

The user should not manually assign expiration dates to ordinary stories.

---

## 5. Essentials

Some writers or publications matter because of the user's relationship to the **Stream itself**, not just because each individual Item happens to score highly against current interests.

Matthew Yglesias is the canonical example: if a Stream is one the user intends to follow comprehensively, Cockpit should not re-audition every post for relevance.

The preferred term is **Essential**.

### Meaning

> **Essential means Cockpit should not quietly remove substantive primary material from that Stream until the user explicitly deals with it.**

Example Stream Handling:

```text
MATTHEW YGLESIAS
Essential
Always show substantive new posts.
Do not auto-clear them.
Give enough orientation to decide whether to read now, later, or clear.
```

An Essential Item may move through:

```text
New
  ↓
Seen
  ↓
Clear OR Keep
```

but aging alone should not remove it.

For mixed newsletters, Essential should protect the primary publication Artifact without necessarily making every incidental extracted Find immortal.

### Personalization principle

> **Personalization should know when not to filter.**

Cockpit should be able to represent at least these behavioral postures through Handling:

1. **Essential** — always surface substantive primary material; explicit disposition required.
2. **Permissive / curated** — follow the Stream and surface much of its substantive output.
3. **Selective** — screen meaningfully.
4. **Aggressive / discovery** — surface only unusually strong matches.

These are useful product concepts, not necessarily a prominent user-facing enum.

---

## 6. Presentation hierarchy

Content should be organized primarily by **editorial importance and Interest Area**, not Publisher or Transport.

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

The topical sections correspond naturally to Interest Areas, but the edition remains editorial rather than mechanically mirroring the management tree.

Sections should appear only when they have worthwhile material. The exact set will evolve as real use shows which distinctions matter.

### For You

`For You` contains the strongest cross-Stream judgments Cockpit made for the edition.

These are not necessarily the most important news stories. They are the things Cockpit believes are unusually likely to interest, delight, teach, or matter to the user.

A story may qualify because of:

- a strong Personal Knowledge match,
- unusual timeliness,
- current planning context,
- a subject or creator the user strongly cares about,
- an incidental nugget mined from a broader Stream,
- an unusually good opportunity.

`For You` should remain small enough that placement there means something.

### Essentials

`Essentials` provides predictable visibility for Streams the user has established as must-see.

Unlike the rest of the newspaper, this area may benefit from ordering stability and muscle memory.

### Interest Area sections

The remaining lanes organize meaning rather than Transport.

A Paris by Mouth restaurant opening, NYT Travel article, and YouTube hotel video may all belong under `Travel & Places`.

A Feed Me restaurant nugget, NYT Food article, and wine editorial may all appear under `Food & Wine`.

A Stream has one primary Interest Area for management, but an individual Item may be routed elsewhere when its meaning warrants it.

The system may know that a piece has multiple semantic memberships. The UI should usually choose one primary visual placement per edition rather than duplicate the same story everywhere.

### Product principle

> **Interest Areas organize editorial intent; the edition remains free to exercise editorial judgment.**

---

## 7. Publisher, creator, and provenance remain visible

Although Publisher does not organize Content, identity and provenance matter for trust, taste, and credibility.

Content should be **publisher-savvy and provenance-rich**.

A story should make it easy to see:

- Publisher or channel/creator,
- author where meaningful,
- recognizable icon/logo/avatar when available,
- publication time,
- original source material or link,
- deeper Transport/provenance detail when inspected.

The goal is a mixed-publication newspaper that feels grounded in recognizable voices and evidence rather than AI-generated slurry.

### Visual language

The Content experience should likely combine:

- one or two hero stories where imagery genuinely adds pleasure,
- medium visual cards for material where image identity matters,
- many compact text-forward items,
- recognizable publication/channel marks.

Travel, food, architecture, film, music, and place-oriented stories may benefit strongly from imagery.

Do not require every story to carry a giant generic image merely to make the page look busy.

---

## 8. The reading/clearing rhythm

A core emotional requirement is the **joy of gradually clearing the paper** without converting Content into a task-management system.

The edition should visibly settle as the user moves through it.

### New

An Item that has not yet been opened in Cockpit.

It carries normal visual prominence.

### Seen

Opening/tapping an Item should mark it **Seen**.

Seen does **not** mean Clear.

The Item remains in the edition but becomes visually subdued so the user can tell:

> **I already looked at this.**

The exact visual treatment remains open.

### Clear

Clear means:

> **I am done considering this Item in the active newspaper.**

It removes the Item from the active edition.

For ordinary Content this is not necessarily the same as mutating the original provider Artifact. Upstream source disposition follows Transport/provider policy and custody requirements.

For email-delivered Streams, Cockpit may already have archived the provider message after successful processing/custody.

### Keep

Keep means:

> **This deserves durable custody beyond the active edition. I want to be able to return to it later.**

Kept material exits ordinary newspaper aging and enters a retained collection.

The full design of `Kept`, `Reading`, or `Watch Later` has not yet been earned and should not prematurely become a universal knowledge-management system.

### Natural aging

The user does not have to explicitly Clear every ordinary Item.

Non-Essential material may naturally leave future editions according to Stream/item persistence policy.

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

It does not imply that the user reviewed all thirty upstream Artifacts; only the three surfaced candidates became part of the edition.

Essential material should not be swept away by broad section clearing unless the interaction makes that consequence explicit and deliberate.

---

## 10. End-of-edition posture

Content should permit a satisfying sense of being through the day's paper.

An end state may say:

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

Initial stance:

- the morning edition establishes the day's main reading surface,
- ordinary low-urgency arrivals do not constantly reshuffle it,
- new Essential material may enter when it arrives,
- unusually strong or time-sensitive discoveries may enter selectively,
- everything else can wait for the next edition.

Exact refresh policy remains an implementation/design question.

### Governing goal

> **A morning newspaper should not turn into an infinite feed by lunch.**

---

## 12. Old unresolved material

Over time, Essential or otherwise persistent material may linger.

This does not require a new conceptual category.

A future tool may offer an occasional review such as:

```text
5 Essentials have been hanging around for more than a week.
```

Cockpit might then produce richer summaries to help decide:

- Read,
- Keep,
- Clear.

For example:

> You opened this essay six days ago but never finished it. Its real argument is X; the part most likely to interest you is Y.

This is a useful future resolution tool, not a reason to complicate the core edition model now.

---

## 13. Content management model

The recurring-content model is defined in `docs/CONTENT-STREAM-MODEL.md`.

Its user-facing structure is:

```text
INTEREST AREA
      ↓
STREAMS FOLLOWED FOR THAT AREA
      ↓
PROCESS / SCREEN / EXTRACT / ENRICH
      ↓
CONTENT EDITION
```

Examples:

```text
TRAVEL & PLACES
- NYT Travel
- Paris by Mouth
- Fathom
- selected YouTube travel channel
```

```text
FOOD & WINE
- NYT Food
- Kitchen Projects
- Feed Me
- Vinous
- selected cooking/wine channels
```

The primary management question is not:

> Which New York Times feeds do I administer?

It is:

> What should Cockpit be following for Travel & Places, Food & Wine, Arts & Culture, and the other Interest Areas I care about?

Publisher/Creator remains a useful secondary lens. For example, an NYT inspector can show all NYT Streams currently followed across different Interest Areas.

### Product principle

> **Publishers describe where information comes from. Interest Areas describe why Cockpit is consuming it. Why should usually win.**

---

## 14. Stream Handling for Content

Personal Knowledge answers broadly:

> **What does Cockpit know about the user?**

Interest Area guidance answers:

> **What editorial job should this area generally do?**

Stream Handling answers something narrower:

> **Why do I follow this Stream, and how should Cockpit deal with it?**

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

The user should not maintain detailed topic-filter forms.

### Product principle

> **Jon Brain supplies broad personalization. Interest Areas and Stream Handling supply recurring editorial intent.**

---

## 15. Handling inheritance

A useful conceptual decision stack is:

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

Explicit narrower user intent should win when there is conflict.

For example:

```text
Technology & Making:
Favor changes that materially affect AI, Apple development, or making.

Point-Free:
Be unusually permissive with substantive releases.
```

Or:

```text
Food & Wine:
Favor useful technique and distinctive food/wine intelligence.

NYT Food:
Give strong feature pieces more hang time because the Stream is weekly-ish.
```

This decision stack should not become a visible rules engine.

---

## 16. Stream management is secondary administration

Stream management is important but is not itself a primary recurring mode of use.

The primary app may remain almost comically sparse:

```text
Today
Content
```

with secondary access to:

- Interest Areas / Following / Stream management,
- You / Personal Knowledge,
- Settings,
- future capabilities that eventually earn first-class status.

The exact user-facing label for the management surface remains open. `Following` may be friendlier than `Streams`; the domain noun remains Stream.

### Navigation principle

> **Top-level navigation is for recurring modes of use, not important internal concepts.**

A standalone management surface should answer:

> **What is Cockpit following for each Interest Area, and what does Cockpit think each Stream is for?**

A representative Interest Area view:

```text
TRAVEL & PLACES

Following

NYT Travel
The New York Times · RSS
Handling: screen for distinctive, relevant travel intelligence

Paris by Mouth
Paris by Mouth · Email
Handling: mine for restaurants, chefs and meaningful Paris changes

+ Follow another stream
```

A normal row/card should need little more than:

- Stream name,
- Publisher/Creator identity,
- Essential indicator where applicable,
- concise Handling summary,
- cadence/last activity as quiet metadata where useful,
- health only when abnormal.

The user should not routinely need this surface during the morning reading session.

---

## 17. Stream setup should be light

Adding a Stream should not become taxonomy configuration.

A useful flow is:

```text
choose/add recurring stream
        ↓
resolve Publisher/Creator + Transport
        ↓
assign/propose primary Interest Area
        ↓
Cockpit proposes concise Handling
        ↓
optionally mark Essential
        ↓
Follow
```

The user should normally not configure cadence, content shape, persistence duration, extraction strategy, or ranking weights.

### NYT example

Cockpit may show available NYT Streams with descriptive color:

```text
NEW YORK TIMES

Travel — destinations, hotels, travel reporting
Food — cooking, restaurants, food culture
Movies — reviews, essays, filmmaker coverage
Technology — technology reporting
...
```

but adding one should assign it into an Interest Area such as `Travel & Places` or `Arts & Culture`.

### YouTube example

The Stream is the channel.

Cockpit should let the user deliberately select a manageable set rather than mechanically importing an enormous historic subscription list.

### Email publication example

A known newsletter can be explicitly followed as a Stream and assigned to an Interest Area.

Automatic discovery such as:

> This looks like a recurring publication. Treat it as Content?

is valuable later, but it hides meaningful source-discovery functionality and is not a V1 prerequisite.

### Product principle

> **Stream setup should express editorial intent, not expose ingestion machinery.**

---

## 18. Contextual Stream management

Most Stream management should also be available where the Stream is being consumed.

While reading a Point-Free Item:

```text
POINT-FREE
Technology & Making

How I handle this Stream
Be fairly permissive with substantive releases.

Change this…
```

While reading an NYT Movies Item:

```text
NYT MOVIES
Arts & Culture

How I handle this Stream
Screen aggressively for serious criticism and strong known-interest matches.

Change this…
```

For email-delivered Streams, transport/source-disposition details can remain available in deeper inspection without conflating them with Stream editorial intent.

---

## 19. Content processing model

The Content experience inherits the progressive-cost intelligence model established for email.

A useful general pipeline is:

```text
bounded Stream material arrives
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
small number of surfaced Content Items
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
Paris by Mouth Stream
      ↓
Cockpit mines Anne-Sophie Pic restaurant news
      ↓
TODAY
Worth Seeing teaser
      ↓
CONTENT
Travel & Places Item / retained source context
```

```text
24 wine retailer messages/feeds
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
30 YouTube uploads across followed Streams
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
- Publisher/Creator-aware visual hierarchy,
- keyboard navigation through sections/Items,
- persistent detail/reader behavior where useful,
- optional immersive full-screen reading,
- quick Keep / Clear / Tell You… / Stream Handling actions,
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

At generous widths, selecting an Item may open a persistent Reader or inspection zone without losing the edition. Exact layout remains open.

---

## 22. iPhone companion

The iPhone version of Content should not attempt to recreate the full iPad newspaper.

Likely emphasis:

- Essentials,
- strongest For You Items,
- compact section browsing,
- quick Keep,
- quick Clear,
- convenient reading/watch handoff.

Deep Stream management, broad retrospective browsing, and rich comparative market views can remain iPad-primary unless real usage proves otherwise.

---

## 23. What Content must not become

### Not an unread counter machine

Do not expose giant accumulating counts such as:

```text
1,283 unread articles
```

The whole point of Cockpit is that most incoming material never becomes the user's burden.

### Not an infinite algorithmic feed

Content should have an edition boundary and a sense of completion.

### Not a Publisher/Stream browser by default

Browsing by Publisher or Stream may exist, but it is a secondary lens. The newspaper is organized around editorial value and meaning.

### Not a preference-database editor

Personal Knowledge, Interest Area guidance, and Stream Handling should absorb natural-language guidance without asking the user to maintain fine-grained topic forms.

### Not a read-it-later warehouse

Keep is necessary. A giant universal archive is not yet justified.

### Not a task manager

Seen, Clear, and Keep support reading rhythm. They should not turn every article into a task with due dates, completion percentages, or guilt.

---

## 24. Design laws

1. **Content is a personalized newspaper, not an inbox or feed reader.**
2. **Streams organize recurring ingestion intent; Content organizes meaning.**
3. **Interest Areas describe why Cockpit follows Streams.**
4. **Publisher/Creator describes who produced material; Transport describes how it arrived.**
5. **`Source` remains reserved for upstream/provenance semantics rather than the recurring-content management noun.**
6. **Cockpit's backlog is not the user's backlog.**
7. **The edition has a daily boundary; individual stories have different lifespans.**
8. **An edition rolls forward rather than resetting.**
9. **Essentials require explicit user disposition and never silently age away.**
10. **Personalization must know when not to filter.**
11. **Opening means Seen, not Clear.**
12. **Seen material becomes visually quieter but remains available.**
13. **Clear removes something from the active newspaper; Keep grants durable custody.**
14. **Natural aging is a feature, not data loss, for non-Essential material.**
15. **Editorial meaning and Interest Areas drive presentation; Publisher/provenance remains visible.**
16. **Sections are dynamic editorial lanes, not rigid ontology.**
17. **One Item should normally have one primary visual placement per edition.**
18. **A Stream has one primary Interest Area, but its Items may be routed elsewhere.**
19. **Stream Handling explains why the Stream is followed and how Cockpit should deal with it.**
20. **Personal Knowledge supplies broad personalization; Stream-specific configuration should remain light.**
21. **Stream management is secondary administration, not the main Content experience.**
22. **Stream setup should express intent rather than expose machinery.**
23. **The morning edition should remain psychologically stable rather than become an infinite feed by lunch.**
24. **Completion should feel like finishing a newspaper, not achieving Inbox Zero.**

---

## 25. Open questions / validate in UI

The product model is sufficiently resolved to proceed. These should remain validation questions rather than block design.

### Exact visual treatment of Seen

We know Seen should be subdued while remaining in place. Exact typography, opacity, icons, and collapse behavior remain open.

### Persistence defaults

The model is settled; exact values are not.

Need implementation evidence for daily-news, commentary, weekly-feature, technical/instructional, and event-driven defaults.

### Midday admission

Need to test how much new material can enter an established edition without undermining the finite-newspaper feeling.

### Kept experience

Keep must exist, but the retained collection remains deliberately underdesigned.

### Duplicate semantic membership

Current recommendation: allow multiple classifications internally but only one primary visual appearance in an edition.

### Essential review tool

Occasional aging review is promising but should wait until unresolved Essential material becomes real behavior.

### Management label

The domain noun is `Stream`. The best user-facing label for the secondary management surface may be `Following`, `Streams`, or something else and should be resolved in UI work.

---

## 26. Recommended next design work

Further abstract Content discussion is now likely to produce diminishing returns.

Next useful work:

1. Design the Interest Area / Following management screen using real NYT, YouTube, and email Streams.
2. Design one representative Content edition at a real iPad width, including For You, Essentials, topical areas, Seen state, and Clear/Keep.
3. Design one full Reader interaction including provenance, Cockpit commentary, Keep, Clear, Tell You…, and Stream Handling.
4. Resolve the top-level iPad shell around the strong `Today` + `Content` distinction while keeping management secondary.
5. Define the first concrete V1 Stream slice so implementation tests the model against real incoming material rather than mocks.

At that point, remaining questions should be resolved by building and using the product rather than extending the ontology.