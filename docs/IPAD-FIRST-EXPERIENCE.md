# Cockpit iPad-First Experience

**Status:** Working product/interaction decision  
**Date:** 2026-09-07

## Purpose

Cockpit is deliberately **iPad first**.

The primary product context is not a quick phone glance. It is an extended morning session, typically with an iPad, Magic Keyboard, and trackpad, during which Jon spends substantial time catching up on email, news, newsletters, market information, travel ideas, cultural material, and other incoming information.

The iPhone is important, but it is a **companion** rather than a compressed copy of the iPad application.

The governing product decision is:

> **Cockpit on iPad is the primary reading, judgment, and learning environment. Cockpit on iPhone is the companion for awareness, capture, lightweight triage, and fast action.**

This changes the interaction model materially. The iPad experience should exploit persistence, simultaneous context, rich reading surfaces, keyboard/trackpad navigation, and domain-specific analysis rather than merely showing wider versions of iPhone cards.

This document extends:

- `docs/PRODUCT-MODEL.md`
- `docs/EMAIL-INTELLIGENCE-MODEL.md`
- `docs/PERSONAL-KNOWLEDGE-MODEL.md`
- `docs/CAPABILITY-REALITY-MAP.md`

It is a product/interaction model, not a final pixel specification.

---

## 1. Canonical use case: the morning desk

Cockpit should be designed around an ordinary but substantial session:

1. Jon sits down with the iPad and keyboard in the morning.
2. Cockpit has reduced a large incoming stream into a small number of things that need attention or are genuinely worth seeing.
3. Jon scans the briefing.
4. He reads selected material without losing his place in the briefing.
5. He compares choices where a domain warrants it.
6. He occasionally corrects Cockpit or explains why something matters.
7. He may keep something, hand it to a specialist app, or clear source email.
8. He leaves with an informed sense of what came into his world rather than a feeling that he completed a productivity ritual.

The experience should support an hour of use gracefully, but should not require an hour. A quiet day may take five minutes.

### Product principle

> **Design for a satisfying reading session, not an inbox-clearing sprint.**

No streaks, completion scores, gamified triage counts, or congratulatory Inbox Zero ceremony are needed.

---

## 2. Platform asymmetry is intentional

Cockpit should not pursue feature symmetry between iPad and iPhone merely for conceptual cleanliness.

### iPad owns

- the full Daily briefing,
- sustained reading,
- persistent master-detail inspection,
- contextual AI commentary,
- explicit learning/correction,
- deep `Skipped` inspection,
- rich domain views such as Wine Market or Events,
- source Handling review/editing,
- deeper Personal Knowledge inspection,
- keyboard/trackpad accelerated workflows,
- side-by-side comparison where it materially improves judgment.

### iPhone owns

- quick situational awareness,
- `Need Your Attention`,
- top Finds,
- Capture,
- fast Keep / Not Interested / Clear,
- lightweight specialist Handoff,
- reading when convenient,
- urgent/time-sensitive information when Cockpit has a legitimate reason to surface it.

The iPhone may expose reduced versions of richer iPad features, but should not contort itself to reproduce the full workspace.

### Product principle

> **The iPhone is a companion, not a miniature iPad.**

---

## 3. The iPad shell: persistent workspace

The canonical iPad interaction should be a persistent workspace rather than repeated push/pop navigation through full-screen cards.

A representative structure:

```text
+-------------------------+------------------------------------------+
| DAILY · Sep 7           |                                          |
|                         |  Selected material                       |
| NEED ATTENTION        6 |                                          |
|                         |  Why I showed you this                    |
| FOR YOU                 |                                          |
|   Travel              2 |  Cockpit's take                          |
|   Cooking             3 |                                          |
|   Wine Market         4 |  Original source / rich domain view      |
|   Reading             5 |                                          |
|   Development         1 |                                          |
|                         |                                          |
| HANDLED QUIETLY      46 |                                          |
+-------------------------+------------------------------------------+
```

The exact widths and navigation controls remain design questions, but the interaction invariant is important:

> **Selecting something should normally replace the inspection surface without destroying the user's position in the briefing.**

This makes scanning and reading fluid rather than modal.

---

## 4. Daily should feel editorial, not tabular

The Daily screen should not treat every source artifact or generated Find equally.

Cockpit should make an editorial judgment about what deserves prominence.

A day's composition might be:

```text
GOOD MORNING

6 things need your attention

TODAY'S BEST FINDS

Anne-Sophie Pic has a new Paris restaurant
Travel · Paris by Mouth

Xcode's headless MCP server matters for your app workflow
Development · iOS Code Review

A Legion release was buried in a comics-store blast
Culture · Ultimate Comics

WINE MARKET
4 worth seeing from 23 offers

COOKING
3 candidates

READING
5 strong matches

EVENTS
2 plausible hits
```

The layout may use cards, rows, modules, typography, or other visual hierarchy, but the principle is:

> **Daily is a personalized front page, not a chronological feed.**

Domains should appear dynamically when they have something worthwhile to contribute. Empty modules should ordinarily not consume space.

---

## 5. Three top-level Daily outcomes

Even with rich editorial composition, the user should be able to understand the whole morning through three concepts.

### Need Your Attention

Material where upstream attention state still matters:

- personal correspondence,
- consequential business mail,
- changed reservations,
- payment/subscription issues,
- tickets or deadlines,
- ambiguous material Cockpit is not willing to clear automatically.

These may remain relatively mail-like because the original communication itself matters.

### Worth Seeing / For You

Cockpit-generated value:

- Finds,
- market briefs,
- extracted restaurant/hotel ideas,
- recipe candidates,
- event matches,
- reading recommendations,
- development/platform changes,
- mixed-source nuggets.

The parent email may be secondary or invisible.

### Handled Quietly

Material Cockpit processed but did not elevate.

This should be compact in Daily and fully inspectable when desired.

### Product principle

> **Everything came in; Cockpit reduced it to attention, interest, or quiet handling.**

---

## 6. The Reader / Inspection surface

The right-hand iPad surface should be a first-class Cockpit Reader rather than merely a web view.

Its job is to preserve provenance while adding judgment.

A typical Find view should distinguish three layers clearly.

### Why I showed you this

Personalized rationale.

Example:

> New Paris dining from a major chef, with enough specificity and critical context to look like a plausible future trip consideration rather than generic travel news.

### Cockpit's take

A concise interpretation appropriate to the source and task.

Example:

> Anne-Sophie Pic has opened Utopic at Fondation Cartier, with a full restaurant following. Paris by Mouth describes the project in enough detail that it looks worth tracking for a future Paris trip.

### Original source

The actual publication/email/article material, faithfully rendered or opened in a web surface as appropriate.

### Product principle

> **AI interpretation should add a layer above the source, not erase the source.**

The interface must make it visually obvious which assertions come from the source and which are Cockpit's inference or synthesis.

---

## 7. Source shape determines the Reader mode

The Reader is one conceptual surface with multiple content modes.

### Full-text newsletter

Examples: Kitchen Projects, author essays.

Cockpit provides orientation and relevance guidance, then renders the newsletter largely intact.

The user subscribed partly because the writer is worth reading; Cockpit should not replace the writer with an unnecessary AI rewrite.

### Link-list / digest

Example: Best of Journalism.

The Reader should present extracted contained links as individual candidates:

```text
3 FOR YOU

Strong match
Anna Gàt on Phantom Thread
Reason: ...

Possible match
Why We Like Things — What Silicon Valley Gets Wrong About Taste
Reason: ...

17 SKIPPED
...
```

Full article enrichment should be selective and progressive-cost.

### Mixed newsletter

Example: Feed Me.

The Reader can show:

- short issue brief,
- primary story,
- separately mined Finds,
- lower-value sections available in original source.

An incidental restaurant mention may outrank the nominal headline story for Jon.

### Structured domain stream

Examples: wine offers, Ticketmaster events.

The right pane should become a domain-specific analysis view rather than pretending the source is prose to summarize.

---

## 8. Contextual commentary: the iPad learning loop

The iPad should make it easy to react to the currently selected material without leaving it.

This is not a general-purpose chatbot bolted onto the app.

It is **contextual commentary grounded in the selected Artifact/Find/source**.

A lightweight commentary rail, inspector composer, or bottom input area should allow text or dictation such as:

> PTA is one of my favorite directors, and I like keeping current with slightly pretentious film criticism.

or:

> I don't care about high-altitude cooking.

or:

> I like this hotel idea because the location would let us walk to serious restaurants rather than drive after dinner.

Cockpit can interpret that response as:

- immediate filtering guidance,
- evidence for an existing Claim,
- a new Fact/Taste/Interest candidate,
- evidence toward a richer synthesized conclusion,
- source-specific Handling correction.

The user should not have to classify the response manually.

### Product principle

> **The user explains meaning; Cockpit decides how that meaning should generalize.**

### Governance

The interaction should remain lightweight:

- explicit user statements are strong evidence,
- Cockpit may acknowledge how it interpreted them,
- Undo should be readily available,
- richer Personal Knowledge governance remains available in `You`,
- a random reaction should not automatically become a permanent isolated claim when it is better treated as supporting evidence.

---

## 9. `Not interested` and `Tell You` are different

The product should not interrogate the user every time something is dismissed.

### Not interested

Immediate ranking/filtering feedback.

Tap and move on.

No mandatory reason.

### Tell You

Optional semantic correction or explanation.

Use it when the user believes there is something worth teaching:

> I never care about safari travel.

> PTA is one of my favorite directors.

> This particular kind of recipe is interesting because it solves entertaining prep, not because I love the ingredient.

### Product principle

> **Dismissal can be frictionless; explanation is valuable when volunteered.**

---

## 10. `Handled Quietly` / Skipped is a trust surface

Skipped material should not be a forensic/debug screen or a second Inbox.

It is a low-friction transparency surface that answers:

> What did Cockpit decide I did not need to see, and why?

On iPad, the larger workspace can make this useful without making it prominent.

Representative layout:

```text
HANDLED QUIETLY · 46

All | Reading | Travel | Cooking | Offers | Events

Phantom Thread essay
Film interest seemed weak

Safari lodge opening
Conflicts with known travel preference

Lemon icebox pie
Doesn't match current cooking priorities

Generic luggage sale
No relevant product
```

Selecting a row shows the underlying source and current rationale in the Reader.

A correction such as:

> This should not have been skipped — PTA is one of my favorite directors.

is especially high-value evidence because it exposes a mismatch between Cockpit's current understanding and the user's actual preference.

### Product principle

> **Model disagreement is a learning opportunity, not merely an error state.**

Silence about skipped material is not durable negative evidence.

---

## 11. Rich domain views belong on iPad

The iPad should exploit screen real estate where a domain has meaningful structure.

These are not universal object tables. They are task-specific presentations.

### Wine Market

A market view may show:

- wine/bottling,
- vintage,
- merchant,
- price,
- why Cockpit thinks it matters,
- source rationale/reviews,
- allocation status,
- perhaps later external enrichment such as cellar relevance when a real integration exists.

The user should be able to compare several plausible offers without opening 20 retailer messages.

### Cooking

Possible groupings include:

- Weeknight,
- Entertaining,
- Technique,
- especially promising recipe candidates.

Actions may include `Read` and receiver-owned `Add to Yes Chef` Handoff.

### Travel

A Find may expose:

- place/hotel/restaurant,
- location,
- source rationale,
- critical references,
- why it fits current Taste/Interest,
- `Add to Galavant` or destination-specific consideration Handoff.

Cockpit should not turn this into a shadow travel database.

### Events

A comparison view may include:

- performer/event,
- venue,
- date,
- location/distance where useful,
- why matched,
- ticket/source link.

### Development / capability intelligence

A source may yield only the subset that materially changes what the app family can do.

The view should make the implementation implication explicit rather than merely summarize technical news.

---

## 12. Source Handling as an editable editorial instruction

On iPad, source Handling should feel like editing an instruction to a trusted editor, not configuring a rules engine.

Example:

```text
PARIS BY MOUTH

HOW I HANDLE THIS

I mine this newsletter for restaurants, chefs, openings and food
experiences you might plausibly want to visit. I preserve why Paris
by Mouth cares about them, including useful critical context,
neighborhood and price.

I generally ignore broad Paris promotion and items without a
specific reason to care.

[ Change how I handle this... ]
```

The user can edit conversationally:

> Don't surface every bistro opening just because we like Paris. I mostly want things that sound genuinely distinctive.

Cockpit should synthesize a revised Handling instruction and make the change understandable.

Domain-specific widgets may expose a few meaningful controls, but the prose policy remains primary.

### Product principle

> **Settings should express intent, not expose the machinery used to satisfy it.**

---

## 13. Keyboard and trackpad are first-class input

A Magic Keyboard/trackpad user should be able to move rapidly through Daily without reaching for the screen constantly.

Exact shortcuts remain to be designed, but the interaction model should support:

- next/previous surfaced item,
- next/previous section,
- open/select,
- Keep,
- Clear where applicable,
- Not Interested,
- Tell You,
- open original,
- source Handling,
- specialist Handoff where a destination is obvious,
- focus commentary input,
- dismiss/return focus to briefing.

Possible letter shortcuts can be explored (`J/K`, etc.), but should not be committed until they coexist cleanly with text input and system conventions.

Pointer interactions should provide:

- hover affordances where appropriate,
- contextual menus for secondary actions,
- precise selection in dense comparison views,
- predictable focus behavior.

### Product principle

> **Keyboard/trackpad fluency is core product ergonomics on iPad, not an advanced-user afterthought.**

---

## 14. Drag and drop is a promising specialist handoff affordance

The semantic Handoff model already says:

> Put this into the specialist's incoming queue; do not perform the specialist workflow inside Cockpit.

On iPad, drag and drop may become a particularly natural expression of this model.

Examples:

- restaurant Find -> Galavant,
- recipe candidate -> Yes Chef,
- article/report -> retained Reading destination,
- source material dragged into another app window where the OS/app contract makes this reliable.

This should be evaluated after receiver-owned admission doors exist. Do not build generic drag infrastructure before there is a concrete consumer.

### Product principle

> **The iPad may make handoff tactile, but specialist sovereignty remains unchanged.**

---

## 15. Multitasking and windows

Cockpit should behave well in iPad windowed/multitasking environments rather than assume full-screen use.

The workspace should adapt continuously to available width.

Broad behavior:

- generous widths: persistent briefing + Reader + optional inspector/commentary rail,
- medium widths: briefing + Reader, secondary inspector collapses,
- narrow/windowed widths: navigation/briefing can become a sidebar or overlay while Reader remains primary,
- iPhone-sized widths: companion interaction model rather than forced preservation of desktop-style panes.

Do not encode the product model in fixed device size assumptions.

---

## 16. Navigation hypothesis

A conventional bottom-tab model should not be assumed for iPad.

A sidebar-oriented shell is a stronger initial hypothesis because it supports persistent workspace navigation and keyboard/trackpad interaction.

Potential top-level destinations include:

- **Today** — the current Daily briefing,
- **Reading / Kept** — retained material worth returning to,
- **You** — Personal Knowledge stewardship and Notices,
- **Sources** — source/Handling management,
- **Recent** — potentially recent Clears/history if a real product need earns it.

`Capture` may be better represented as a global action/command than a navigation destination.

These names and counts are not yet decisions. The important point is that iPad navigation should optimize for workspace continuity rather than mobile tab symmetry.

---

## 17. Reading / Keep should remain modest initially

The iPad experience makes a Reading surface tempting, but the system should not prematurely become a universal read-it-later product.

Initial semantics can remain simple:

- ephemeral Daily Find,
- `Keep` when Jon wants the material retained,
- source custody according to policy,
- later revisit from an appropriate retained-material surface.

The product can earn a richer Reading model from actual use.

---

## 18. Morning completion without productivity theater

Cockpit should provide a sense of settled awareness without turning the morning into a task-completion ritual.

An appropriate end state might say:

> You're caught up. Gmail still has 5 messages deliberately left in Inbox for your attention.

The briefing remains available for reading and reconsideration.

Avoid:

- completion percentages,
- streaks,
- confetti,
- productivity scores,
- pressure to clear every category,
- artificial task state for interesting material.

### Product principle

> **The outcome is informed calm, not completed work.**

---

## 19. iPhone companion experience

The iPhone should preserve the semantic model while aggressively reducing the interaction burden.

A likely iPhone Daily includes:

- Need Your Attention,
- Today's best few Finds,
- small summaries of domains with something worthwhile,
- Keep,
- Not Interested,
- quick Clear where safe,
- destination-specific Handoff,
- Capture.

Deep source-policy editing, broad Skipped review, large comparison tables, and extensive Personal Knowledge inspection can remain iPad-primary unless real phone usage proves otherwise.

The phone should excel when Jon is away from the iPad and encounters something in the world:

> Capture this.

> Keep this.

> Send this to Galavant.

> What did Cockpit say I really needed to see today?

---

## 20. The core interaction grammar

Despite sophisticated processing, the user's interaction grammar should remain small.

At the item level:

```text
Cockpit surfaced something
        |
        v
Why is it here?
        |
        v
Inspect source if desired
        |
        v
Keep / Clear / Handoff
        |
        v
Wrong or incomplete?
Not Interested / Tell You
```

At the Daily level:

```text
Everything came in
        |
        +-> Need my attention
        |
        +-> Worth seeing
        |
        +-> Handled quietly
```

The machinery may be sophisticated. The experience should not feel sophisticated in the burdensome sense.

---

## 21. North-star behavior

A representative north-star interaction is:

> A meaningful fact is buried deep inside a source Jon trusts. Cockpit knows it intersects strongly with his interests, extracts it without making him read the entire source, preserves the source's rationale, gives it appropriate prominence in the morning briefing, and lets Jon either act on it or explain why it matters so future judgment improves.

The Anne-Sophie Pic / Paris by Mouth example demonstrates the desired effect well: Cockpit should routinely catch exactly the kind of specific, high-value detail a human subscriber can easily miss while skimming a long newsletter.

This is much more ambitious and useful than:

> AI summarizes my inbox.

---

## 22. Design laws

1. **iPad is the primary Cockpit experience; iPhone is a companion.**
2. **The canonical session is an extended morning reading/judgment session.**
3. **Daily is a personalized editorial front page, not a chronological feed.**
4. **Persistent master-detail context should minimize navigation churn.**
5. **The Reader preserves provenance while adding Cockpit interpretation.**
6. **Contextual commentary is grounded in the selected material, not a generic chatbot.**
7. **User explanations are high-value learning evidence; dismissals may remain lightweight.**
8. **Handled Quietly is inspectable for trust but should not become another inbox.**
9. **Rich domain views are allowed when the domain earns them; do not force universal presentation.**
10. **Handling should be edited as human intent, not administered as a rules taxonomy.**
11. **Keyboard/trackpad fluency is first-class iPad ergonomics.**
12. **Do not demand feature symmetry between iPad and iPhone.**
13. **No productivity theater: the goal is informed calm.**
14. **The sophistication belongs in the processing, not in user burden.**

---

## 23. Next design work

This document intentionally stops short of committing final navigation or pixels.

The next useful design work is concrete:

1. Jon independently sketches the experience from his own instincts.
2. Compare that sketch against the principles above rather than treating this document as a wireframe mandate.
3. Resolve the iPad shell/navigation model.
4. Design the canonical `Today` screen at one representative width.
5. Design four representative Reader modes:
   - important correspondence,
   - full-text newsletter,
   - link-list newsletter,
   - rich domain view.
6. Design the commentary/learning interaction.
7. Design `Handled Quietly` and source Handling editing.
8. Only then translate the experience into implementation slices.

The product should continue to resist abstraction that is not earned by a named interaction.