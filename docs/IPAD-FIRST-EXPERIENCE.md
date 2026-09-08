# Cockpit iPad-First Experience

**Status:** Working product/interaction decision  
**Date:** 2026-09-08

## Purpose

This document captures the iPad-first interaction model for Cockpit.

It reflects a material product constraint: Cockpit's canonical use is not a few-second phone check. It is often an extended morning session on an iPad with Magic Keyboard and trackpad, followed by lighter companion use on iPhone.

It should be read alongside:

- `docs/PRODUCT-MODEL.md`
- `docs/EMAIL-INTELLIGENCE-MODEL.md`
- `docs/PERSONAL-KNOWLEDGE-MODEL.md`
- `docs/TODAY-EXPERIENCE.md`
- `docs/CONTENT-EXPERIENCE.md`
- `docs/CONTENT-STREAM-MODEL.md`

The newer Content Stream model uses `Stream` for recurring content the user follows. `Source` remains correct for upstream/provider/provenance semantics.

---

## 1. Platform doctrine

> **Cockpit on iPad is the primary reading, judgment, and learning environment. Cockpit on iPhone is the companion for awareness, capture, lightweight triage, and fast action.**

The two platforms should share semantics, not feature symmetry.

The iPad should own the experiences that benefit from continuity, density, comparison, reading, keyboard/trackpad navigation, and contextual explanation.

The iPhone should own immediacy.

### Product principle

> **The iPhone is a companion, not a miniature iPad.**

---

## 2. Canonical use case: the morning desk

The defining session is roughly:

1. Sit down with iPad + Magic Keyboard.
2. Cockpit has reduced a large incoming world into a manageable Today briefing and Content edition.
3. Scan what needs attention.
4. Notice what especially deserves to register.
5. Move into Content and read selected material without losing position.
6. Compare where a domain warrants it.
7. Occasionally correct Cockpit or explain why something matters.
8. Keep, Clear, hand off, or simply let ordinary material age naturally.
9. Leave informed rather than feeling that a productivity queue was completed.

The session may last an hour.

Cockpit should also work for a five-minute check, but the extended reading/judgment session is the canonical design pressure.

### Product principle

> **Design for a satisfying reading session, not an inbox-clearing sprint.**

---

## 3. Platform asymmetry

### iPad owns

- full Today briefing,
- full Content edition,
- sustained reading,
- persistent master-detail inspection,
- contextual AI commentary,
- explicit learning/correction,
- deep Handled Quietly / skipped inspection,
- rich domain views such as Wine Market and Events,
- Interest Area / Stream management,
- deeper Personal Knowledge inspection,
- keyboard/trackpad accelerated workflows,
- side-by-side comparison where useful.

### iPhone owns

- quick situational awareness,
- Need Your Attention,
- the strongest few Finds,
- Capture,
- fast Keep / Not Interested / Clear,
- lightweight specialist Handoff,
- reading when convenient,
- sparse time-sensitive information.

Deep Stream Handling, broad skipped review, rich comparative views, and extensive Brain inspection should remain iPad-primary unless actual phone usage proves otherwise.

---

## 4. Primary shell: a persistent workspace

A conventional bottom-tab model should not be assumed for iPad.

A sidebar-oriented shell is the stronger hypothesis because it supports workspace continuity and keyboard/trackpad navigation.

Only two recurring product modes have clearly earned primary prominence so far:

```text
Today
Content
```

Secondary access should exist for:

- Interest Area / Following / Stream management,
- You / Personal Knowledge,
- Settings,
- retained/Kept material if it earns a separate destination,
- future capabilities such as Agents, Watches, Tasks, or other genuinely recurring modes once their execution harnesses and product value are real.

The exact UI label for Stream management remains open. `Following` may be friendlier than `Streams`; the domain noun remains Stream.

### Navigation principle

> **Top-level navigation is for recurring modes of use, not important internal concepts.**

The sidebar should deliberately leave room to grow rather than fill itself with every important subsystem.

---

## 5. Today workspace

Today is orientation and attention, not the entire Content experience.

A representative generous-width layout:

```text
┌─────────────┬───────────────────────────────┬──────────────────────────────┐
│ Sidebar     │ Today briefing                │ Selected detail / Reader     │
│             │                               │                              │
│ Today       │ calendar / context            │ Why this is here             │
│ Content     │ attention                     │ Cockpit's take               │
│             │ worth seeing                  │ original/source material     │
│             │ domain teasers                │ actions / commentary         │
│             │ handled quietly               │                              │
└─────────────┴───────────────────────────────┴──────────────────────────────┘
```

### Core invariant

> **Selecting something should normally replace the inspection surface without destroying the user's position in the briefing.**

Today should feel like a personalized editorial front page rather than a chronological feed.

Domain modules should appear dynamically when they have value rather than occupy permanent empty furniture.

---

## 6. Content workspace

Content is the leisurely newspaper.

At generous widths it should support:

- newspaper-like scanning,
- For You,
- Essentials,
- dynamic Interest Area sections,
- publisher/creator-aware identity and imagery,
- Seen state without forced clearing,
- persistent Reader/inspection,
- quick Keep / Clear / Tell You…,
- contextual Stream Handling.

A rough composition:

```text
┌─────────────┬────────────────────────────────────────────────────────────┐
│ Sidebar     │ CONTENT · Today's Edition                                 │
│             │                                                            │
│ Today       │ FOR YOU                                                    │
│ Content     │ strongest discoveries / selective hero imagery            │
│             │                                                            │
│             │ ESSENTIALS                                                 │
│             │ Opinion & Commentary                                       │
│             │ Arts & Culture                                             │
│             │ Food & Wine                                                │
│             │ Travel & Places                                            │
│             │ Technology & Making                                        │
│             │ Watch / Listen                                             │
└─────────────┴────────────────────────────────────────────────────────────┘
```

Interest Areas organize editorial intent and Stream management, but the edition remains free to place an Item where its meaning is most useful.

---

## 7. The Reader / inspection surface is first-class

The right-hand Reader should not merely be a web view bolted onto a list.

It should preserve provenance while adding useful Cockpit interpretation.

A common structure is:

1. **Why I showed you this**
2. **Cockpit's take**
3. **Original / source material**
4. relevant actions

The UI should make clear which assertions come from the original material and which are Cockpit interpretation.

### Reader modes

Different content shapes should produce different Reader behavior.

#### Important correspondence

- concise context,
- why it deserves attention,
- original message/thread material,
- upstream attention/source actions where permitted.

#### Full-text publication Stream

- brief orientation,
- then largely intact source material,
- clear Publisher/author identity,
- Stream Handling available contextually.

#### Link-list / digest Stream

- extracted candidates,
- why selected,
- lightweight access to screened-out links where useful,
- original issue provenance.

#### Mixed Stream

- short issue brief,
- mined Finds surfaced independently,
- original issue available for trust/context.

#### Rich domain view

- task-specific presentation such as Wine Market comparison or Events matching rather than forcing everything into article chrome.

Full-screen immersive reading should be available when desired, but should not be the default navigation transition for every Item.

---

## 8. Contextual commentary and learning

A promising iPad interaction is a lightweight commentary rail or composer tied to the selected material.

This should not become a generic chatbot sitting beside every screen.

The user should be able to say things like:

> PTA is one of my favorite directors. And I like keeping current with slightly pretentious film criticism.

or:

> Don't show every Paris bistro opening; I only care when something is genuinely distinctive.

Cockpit can interpret the explanation as:

- evidence for Personal Knowledge,
- a correction to existing knowledge,
- Stream Handling guidance,
- Interest Area guidance,
- temporary/current-context input,
- or some combination where warranted.

The user should not have to classify it manually.

### Product principle

> **The user explains meaning; Cockpit decides how that meaning should generalize.**

Governance should remain lightweight:

- explicit statements are strong evidence,
- Cockpit may briefly acknowledge its interpretation,
- Undo should be readily available,
- richer Personal Knowledge governance remains available secondarily,
- incidental reactions should not automatically become permanent isolated claims.

---

## 9. `Not Interested` and `Tell You…` are different

The product should not interrogate the user every time something is dismissed.

### Not Interested

Immediate filtering/ranking feedback.

Tap and move on.

No mandatory reason.

### Tell You…

Optional semantic correction or explanation.

Use it when there is something worth teaching.

### Product principle

> **Dismissal can be frictionless; explanation is valuable when volunteered.**

---

## 10. Handled Quietly / Skipped is a trust surface

Skipped material should not become a forensic/debug screen or second Inbox.

It is a low-friction transparency surface answering:

> **What did Cockpit decide I did not need to see, and why?**

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

Selecting a row shows the underlying source/provenance and current rationale in the Reader.

A correction such as:

> This should not have been skipped — PTA is one of my favorite directors.

is especially high-value evidence because it reveals a mismatch between Cockpit's current understanding and the user's actual preference.

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
- original rationale/reviews,
- allocation status,
- perhaps later cellar relevance when a real integration exists.

The user should be able to compare several plausible offers without opening twenty retailer messages.

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
- why the originating Stream or publication thought it mattered,
- Cockpit's fit judgment,
- supporting critical references,
- `Add to Galavant`.

### Events

A view may include:

- performer/event,
- venue,
- date,
- location/distance,
- why matched,
- ticket/provider link.

### Development

Development intelligence should surface changes that materially affect what Cockpit or the app family can realistically do, with implementation implications made explicit.

A Stream may yield only the subset that materially changes the app-family harness.

---

## 12. Interest Area and Stream management on iPad

Stream management is important administration for Content, not a primary morning mode.

The user should normally manage Streams **through Interest Areas** because Interest Areas describe why Cockpit consumes them.

A representative view:

```text
TRAVEL & PLACES

Following

NYT Travel
The New York Times · RSS
Screen for distinctive, relevant travel intelligence

Paris by Mouth
Paris by Mouth · Email
Mine for restaurants, chefs and meaningful Paris changes

+ Follow another stream
```

The management experience should show only what the user needs to understand:

- Stream name,
- Publisher/Creator identity,
- Essential status where applicable,
- concise human-language Handling,
- cadence/last activity as quiet metadata where useful,
- abnormal health state.

Deeper detail may expose:

- Transport,
- provider/source disposition for email,
- custody behavior,
- pause/stop following,
- move to another Interest Area.

### Human-language Handling

Settings should read like editorial intent, for example:

```text
PARIS BY MOUTH
Travel & Places

HOW I HANDLE THIS STREAM
I mine this publication for restaurants, chefs, openings and food
experiences you might plausibly want to visit. I preserve why Paris
by Mouth thought the place mattered rather than reducing it to a name.

[ Change how I handle this… ]
```

### Product principle

> **Settings should express intent, not expose the machinery used to satisfy it.**

`Source` remains correct for original/provider material and source actions. `Stream` is the recurring Content object being followed.

---

## 13. Keyboard and trackpad are first-class input

A Magic Keyboard/trackpad user should be able to move rapidly through Today and Content without constantly reaching for the screen.

Exact shortcuts remain to be designed, but the interaction model should support:

- next/previous surfaced Item,
- next/previous section,
- open/select,
- Keep,
- Clear where applicable,
- Not Interested,
- Tell You…,
- open original,
- Stream Handling,
- specialist Handoff where a destination is obvious,
- focus commentary input,
- dismiss/return focus to briefing or edition.

Possible letter shortcuts can be explored (`J/K`, etc.) but should not be committed until they coexist cleanly with text input and system conventions.

Pointer interactions should provide:

- hover affordances where appropriate,
- contextual menus for secondary actions,
- precise selection in dense comparison views,
- predictable focus behavior.

### Product principle

> **Keyboard/trackpad fluency is core product ergonomics on iPad, not an advanced-user afterthought.**

---

## 14. Drag and drop is a promising specialist Handoff affordance

The semantic Handoff model already says:

> Put this into the specialist's incoming queue; do not perform the specialist workflow inside Cockpit.

On iPad, drag and drop may become a natural expression of this model.

Examples:

- restaurant Find -> Galavant,
- recipe candidate -> Yes Chef,
- article/report -> retained Reading destination,
- faithful source material dragged into another app window where the OS/app contract makes this reliable.

This should be evaluated after receiver-owned admission doors exist. Do not build generic drag infrastructure before there is a concrete consumer.

### Product principle

> **The iPad may make Handoff tactile, but specialist sovereignty remains unchanged.**

---

## 15. Multitasking and windows

Cockpit should behave well in iPad windowed/multitasking environments rather than assume full-screen use.

The workspace should adapt continuously to available width.

Broad behavior:

- generous widths: persistent briefing/edition + Reader + optional inspector/commentary rail,
- medium widths: briefing/edition + Reader; secondary inspector collapses,
- narrow/windowed widths: navigation/briefing can become sidebar or overlay while Reader remains primary,
- iPhone-sized widths: companion interaction model rather than forced preservation of desktop-style panes.

Do not encode the product model in fixed device-size assumptions.

---

## 16. Keep should remain modest initially

The iPad experience makes a Reading/Kept surface tempting, but Cockpit should not prematurely become a universal read-it-later product.

Initial semantics can remain simple:

- ephemeral edition Item,
- `Keep` when Jon wants durable custody,
- underlying source custody according to policy,
- later revisit from an appropriate retained-material surface.

The product can earn a richer Reading model from actual use.

---

## 17. Completion without productivity theater

Today and Content should provide different but related senses of settling.

Today may end with:

> You're caught up. Gmail still has 5 messages deliberately left in Inbox for your attention.

Content may end with:

> You're through today's edition. 4 things kept for later.

Avoid:

- completion percentages,
- streaks,
- confetti,
- productivity scores,
- giant unread counters,
- pressure to clear every category,
- artificial task state for interesting material.

### Product principle

> **The outcome is informed calm, not completed work.**

---

## 18. iPhone companion experience

The iPhone should preserve the semantic model while aggressively reducing interaction burden.

A likely iPhone experience emphasizes:

- Need Your Attention,
- today's best few Finds,
- Essentials,
- small summaries of domains with something worthwhile,
- Keep,
- Not Interested,
- quick Clear where safe,
- destination-specific Handoff,
- Capture.

The phone should excel when Jon is away from the iPad and encounters something in the world:

> Capture this.

> Keep this.

> Send this to Galavant.

> What did Cockpit say I really needed to see today?

---

## 19. The core interaction grammar

Despite sophisticated processing, the user's interaction grammar should remain small.

At the Item level:

```text
Cockpit surfaced something
        ↓
Why is it here?
        ↓
Inspect original if desired
        ↓
Keep / Clear / Handoff
        ↓
Wrong?
Not Interested / Tell You…
```

At the morning level:

```text
Everything came in
        ↓
Need my attention
Worth seeing
Handled quietly
        ↓
Content edition
        ↓
Read / watch / browse / keep / clear naturally
```

The sophistication belongs in processing, not in expanding the user's command vocabulary.

---

## 20. Design laws

1. **iPad is primary; iPhone is companion.**
2. **The canonical session is extended morning reading and judgment.**
3. **Today is orientation/attention; Content is the leisurely newspaper.**
4. **Persistent master-detail should minimize navigation churn.**
5. **The Reader preserves provenance while adding interpretation.**
6. **Contextual commentary is grounded in selected material, not a generic chatbot.**
7. **User explanations are high-value learning; dismissals can stay lightweight.**
8. **Handled Quietly is inspectable but not another Inbox.**
9. **Rich domain views are earned where structure adds value.**
10. **Interest Areas organize Stream management; Publisher/Creator and Transport remain secondary dimensions.**
11. **Stream Handling expresses editorial intent in human language.**
12. **`Source` remains reserved for upstream/provider/provenance semantics.**
13. **Keyboard/trackpad interaction is first-class.**
14. **Platform symmetry is not a requirement.**
15. **No productivity theater; the goal is informed calm.**
16. **Sophistication belongs in processing, not burden.**
17. **Top-level navigation is for recurring modes, not every important subsystem.**
18. **Leave room for future Agents/Watches/Tasks rather than inventing them before their harnesses exist.**

---

## 21. Next UI validation

The broad interaction model is sufficiently stable. The next useful work is visual/interaction validation rather than more ontology.

1. Sketch the Interest Area / Following management surface using real NYT, YouTube, and email Streams.
2. Draw one representative Content edition at a real iPad width.
3. Draw one Reader state for each of four shapes: important correspondence, full-text publication, link-list/mixed publication, and rich domain view.
4. Validate the sparse `Today` + `Content` primary navigation with secondary management access.
5. Test Seen, Clear, Keep, and persistent Reader behavior with keyboard/trackpad interaction.

The product should then move toward implementation slices and allow real use to resolve the remaining geometry and naming questions.