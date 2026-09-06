# Cockpit Capability Reality Map

**Status:** Working product/architecture decision  
**Date:** 2026-09-06

## Purpose

Cockpit should be future-ready without pretending that current mobile/agent harnesses can do things they cannot yet reliably do.

The product should therefore separate two kinds of future-proofing:

1. **Knowledge can be built ahead of future agents** because durable understanding compounds over time.
2. **Agency should not be designed ahead of proven harnesses** because execution, background runtime, source access, notification delivery, and app-to-app integration remain volatile and platform-dependent.

The governing principle is:

> **Be future-ready in what Cockpit knows; be conservative in what Cockpit claims it can do.**

Cockpit should commit near-term only to capabilities with a credible source, transport, execution boundary, and user experience using tools that can realistically be implemented now or with an explicit manual bridge.

This document identifies six near-term capabilities that meet that standard and parks more speculative agentic behaviors until their harnesses are real.

---

## 1. Capability reality tiers

When considering a new Cockpit behavior, classify it before designing architecture around it.

### Tier A — Works now

The app can perform the behavior with normal app runtime, known APIs, deterministic operations, or model calls initiated while Cockpit is active.

Examples:

- classify and summarize fetched email,
- extract structured information from a supplied source,
- reason against the Jon Brain,
- parse a known RSS/Atom feed,
- persist a captured item,
- hand material to another app through a receiver-owned admission door when available.

### Tier B — Works now with a manual bridge

The semantic workflow is real, but transport remains manual until a better platform integration appears.

Examples:

- `Jon Brain Handoff` copied/shared from ChatGPT into Cockpit,
- pasting a URL or selected text into Capture,
- sharing a podcast episode plus a short dictated description of what should be found.

The manual bridge is acceptable when the semantic contract is stable and the likely future automation merely replaces the transport.

### Tier C — Works as a user-initiated operation

Cockpit can do the work when the user explicitly invokes it, but should not imply reliable ambient/background behavior.

Examples:

- “Review this Galavant trip with Jon Brain,”
- “Find the report they were discussing and add it to Reading,”
- “Refresh my monitored feeds now,”
- “Filter this music feed against my Interests.”

### Tier D — Needs a specific harness/integration

The product idea is coherent, but reliable implementation depends on an external capability not yet proven.

Examples:

- continuous provider-specific ticket monitoring,
- immediate background alerts from arbitrary external sites,
- direct ChatGPT-to-Cockpit personal-knowledge writes without manual transport,
- ambient querying of specialist apps when they are not running unless a shared publication mechanism exists.

### Tier E — Future/agentic hypothesis

The product idea may become useful, but there is not yet enough execution reality to warrant a subsystem.

Examples:

- general autonomous web monitoring,
- broad proactive life management,
- inferred behavioral nudging without an explicit mandate,
- open-ended “agent” workflows whose source, runtime, authority, and completion semantics are undefined.

### Architectural rule

> No new subsystem should be justified primarily by a Tier D/E story when a Tier A/B/C consumer has not yet earned it.

---

## 2. Six near-term capabilities

The current realistic Cockpit product can be described through six capabilities.

1. **Daily** — intelligently triage what came in.
2. **Know** — build and synthesize durable Personal Knowledge.
3. **Advise** — reason against explicit supplied context using what Cockpit knows.
4. **Handoff** — send material into specialist-owned incoming queues.
5. **Curate** — intelligently filter bounded known sources.
6. **Capture & Enrich** — accept fuzzy low-friction capture and resolve it into useful material later in the workflow.

These do not require a general autonomous agent.

They do create the substrate a future agent would want: durable knowledge, explicit sources, faithful artifacts, semantic subjects, source/action policies, user intent, and safe deterministic mutation boundaries.

---

## 3. Daily — intelligent triage

### User problem

A significant amount of information arrives through email and similar sources. The user wants to know:

> What came into my world, what matters, and what can I safely ignore?

### Near-term capability

Cockpit can:

- fetch current Inbox material,
- classify and summarize,
- distinguish important/personal/consequential material from noise,
- extract structured meaning where useful,
- preserve source material where Cockpit assumes custody,
- apply Handling Policies,
- execute approved source actions such as archive/clear,
- surface especially important items before the user moves on with the day.

### Harness reality

This is a real application workflow with concrete source APIs and deterministic mutation boundaries.

### Non-goal

Daily should not become a generalized task manager or pretend that all life activity can be represented as due dates and completion state.

---

## 4. Know — the Jon Brain

### User problem

The more the app family genuinely understands about Jon, Wendy, and their preferences/interests/facts, the better judgment it can provide now and the better positioned it becomes for future capabilities.

### Near-term capability

Cockpit maintains and synthesizes:

- **Facts** — useful durable factual knowledge,
- **Taste** — synthesized preferences, tradeoffs, aversions, and tendencies,
- **Interest** — subjects/entities with durable or evolving salience,
- provenance/evidence sufficient to explain why a conclusion exists,
- AI-generated Notices that identify patterns, changes, tensions, or potentially useful insights,
- a periodic/monthly review that surfaces only meaningful changes or ambiguities.

The Brain stores synthesized conclusions rather than conversational exhaust.

### Primary evidence

High-value evidence includes:

- explicit statements and corrections,
- `Jon Brain Handoff` material from rich conversations,
- explicit reactions such as “love this,” “wrong for us,” “more like this,”
- semantically meaningful commitments such as reservations, tickets, purchases, bids, bookings, saves, and specialist-domain outcomes,
- specialist-app learnings promoted only when they have cross-domain meaning.

Passive clicks, reads, dwell time, scroll depth, and unexplained non-engagement are weak evidence and should ordinarily not become durable Personal Knowledge.

### Harness reality

Cockpit can build this today using direct teaching, manual ChatGPT handoffs, AI synthesis, and a small number of high-semantic-value integrations.

Future ChatGPT/plugin/MCP/mobile integration should replace manual transport without changing the semantic contract.

### Product principle

> Knowledge can be built ahead of future agents because understanding compounds even when agency is still limited.

---

## 5. Advise — user-initiated reasoning against supplied context

### User problem

Much of the value of the Jon Brain does not require ambient agency. The user can deliberately ask an app to reason using its own domain context plus relevant Personal Knowledge.

Examples:

- “Review this Burgundy itinerary using what you know about us.”
- “Look at these three hotels through Jon Brain.”
- “Does this Yes Chef menu fit how we actually like to entertain?”
- “Which of these wines is most aligned with what we’ve learned about our preferences?”

### Near-term capability

A specialist app or Cockpit can assemble:

```text
explicit user request
+ supplied domain context
+ relevant Personal Knowledge projection
+ app-local preferences/context
        |
        v
     AI reasoning
```

The output is advisory unless a separately authorized deterministic operation follows.

### Harness reality

This is a Tier A/C capability: the user supplies the context or initiates the reasoning operation. It avoids unreliable background runtime and generalized agent machinery.

### Architectural consequence

Do not require a general `CurrentContext` subsystem merely to support advice. If a feature needs trip/calendar/menu context, assemble exactly the context that named consumer requires.

### Product principle

> No new context ontology without a named consumer and a demonstrated decision it improves.

---

## 6. Handoff — frictionless send-to-specialist queues

### User problem

Cockpit often operates in triage mode. Discovering something useful should not force the user to leave that mode and perform domain-specific work immediately.

Examples:

- recipe material -> Yes Chef incoming queue,
- restaurant/place -> Galavant consideration queue,
- future domain material -> receiver-owned pending/review boundary.

### Near-term capability

Cockpit sends:

- faithful source material,
- provenance,
- Cockpit interpretation/rationale,
- user intent.

The receiving specialist owns:

- incoming queue semantics,
- identity,
- exact POI/domain resolution,
- deduplication,
- validation,
- review/admission,
- canonical commit.

App Intents or equivalent receiver-owned doors are the likely implementation mechanism where available.

### Harness reality

This is a bounded, user-initiated operation and does not require an autonomous agent.

### Product principle

> Handoff means “put this somewhere useful for later specialist work,” not “interrupt triage and finish the specialist workflow now.”

---

## 7. Curate — bounded source intelligence

### User problem

Cockpit can provide significant value without scouring the entire internet if the user gives it a bounded source and a purpose.

The core question is:

> Given this known stream, what deserves my attention?

### Near-term capability

Cockpit can ingest a known feed/source and apply:

```text
Source
  +
source-specific purpose / handling instruction
  +
relevant Personal Knowledge when applicable
       |
       v
AI curation
```

This is deterministic ingestion plus model judgment over a bounded corpus.

### Example A — OpenAI capability feed

A source such as an OpenAI release-notes RSS/Atom feed could be tracked for one specific editorial purpose:

> Surface product/platform changes that materially expand what Cockpit or the Jon app family could realistically do, especially mobile integration, plugins/apps/MCP, app-to-app communication, background/agent capability, model/tool APIs, and Apple-platform relevance.

This filter is not primarily Personal Knowledge. It is a declared source-purpose/Handling instruction.

The output should distinguish:

- actual new harness capability,
- marketing/announcement noise,
- desktop-only capability with no mobile relevance,
- capability that exists in theory but lacks a usable integration path for Cockpit.

### Example B — music/news feed

A music/news feed can be filtered largely against Jon Brain Interests:

- strong artist interests,
- genre interests,
- emerging interests,
- known dislikes/low-salience areas where useful.

Cockpit should surface relevant items and may optionally provide an inspectable `Skipped` / `Others I filtered out` view.

The skipped view is valuable because it creates an explicit correction loop:

> “Why did you reject Fontaines D.C.? I definitely care about them.”

That user correction is strong Personal Knowledge evidence.

Silence about a skipped item is not evidence that the filter was correct forever.

### Harness reality

RSS/Atom and other bounded feeds are ordinary fetch/parse workflows. AI can classify and rank while the app is active or during whatever refresh opportunities the platform actually permits.

### Important limitation

Do not casually promise “continuous monitoring” on iOS.

Near-term semantics should be phrased in terms such as:

- refresh during Daily,
- refresh when Cockpit is opened,
- refresh during permitted background opportunities,
- refresh on explicit user request.

Reliable immediate alerts require a specific push/cloud/background harness and should be treated as a separate capability once proven.

### Product principle

> Bounded-source intelligence is real now; generalized ambient web monitoring is not required.

---

## 8. Capture & Enrich — fuzzy capture without stopping the moment

### User problem

The user often encounters something worth keeping while doing something else and does not want to stop to identify, research, categorize, and file it.

Example:

> Listening to a podcast about the Clippers and hearing mention of “the Wachtell report.”

The desired interaction is closer to:

> “Cockpit — read later: Wachtell report on the Clippers investigation.”

than:

> Find the correct URL, verify the document, download the PDF, classify it, and then save it.

### Near-term capability

Cockpit should support a low-friction capture object that may begin incomplete:

```text
raw human notion
"Wachtell Clippers report"
        |
        v
capture safely now
        |
        v
AI/web enrichment when execution is available
        |
        +-- resolve likely identity
        +-- find authoritative source
        +-- attach URL / metadata
        +-- retrieve/preserve source content where policy allows
        +-- classify destination/use
        |
        v
Reading / Cockpit artifact / specialist queue
```

The enrichment step must remain lossless-or-loud when exact identity matters. If Cockpit finds multiple plausible targets, it should preserve the ambiguity or ask at the consequential boundary rather than silently choosing the wrong document.

### Mobile entry doors

Likely capture doors include:

- Share Sheet,
- App Intent / Shortcut,
- Siri/voice invocation where practical,
- quick-capture control,
- paste,
- typed/dictated note.

The semantic operation is:

> **Capture this notion for later enrichment.**

The user should not be required to supply a fully formed URL.

### Podcast caveat

Sharing a podcast episode does not automatically imply that iOS gives Cockpit the exact transcript sentence or current playback-position transcript context.

Cockpit should use only the context actually supplied by the source/OS and a short user phrase when necessary.

Do not design around invisible transcript access that the platform does not provide.

### Harness reality

This is a Tier A/B/C workflow: capture is immediate and deterministic; enrichment can occur during active/user-initiated execution. Better future agents or background systems can automate the same semantic enrichment step later.

### Product principle

> Capture first; enrich later. Do not make the user finish the research task merely to remember that the research task exists.

---

## 9. Three operating modes plus Know

The six capabilities can be understood through three user-facing operating modes, with Personal Knowledge beneath them.

### Triage

Something came to Cockpit.

> What matters? What can safely leave my attention?

Primary capability: **Daily**.

### Capture

Jon encountered something elsewhere.

> Don’t make me deal with it now. Understand enough to put it somewhere useful.

Primary capabilities: **Capture & Enrich**, **Handoff**.

### Curate

A known stream is coming in.

> Reduce it intelligently according to my interests or the purpose I declared.

Primary capability: **Curate**.

### Know

Underlying all three:

> Understand Jon/Wendy increasingly well so judgment improves.

Primary capability: **Jon Brain**.

### Advise

`Advise` cuts across all modes: when the user explicitly asks for judgment, combine the supplied domain context with relevant Personal Knowledge and perform a high-quality model call.

---

## 10. What Personal Knowledge can and cannot authorize

Personal Knowledge can improve relevance, ranking, explanation, filtering, and advice.

It may also justify a **suggestion** that the user create a future standing mandate.

Examples:

- strong The 1975 Interest -> suggest “Want me to watch tour announcements?”
- repeated Mateo reservations -> suggest “Want Mateo wine dinners treated as high-priority?”

But Personal Knowledge alone does not grant authority to create alerts, notifications, background monitoring, purchases, reservations, or other autonomous actions.

### Product principle

> Knowledge can suggest agency; knowledge does not grant agency.

---

## 11. Parking lot: Watch

`Watch` remains a compelling product primitive but is not yet part of the committed near-term core unless a specific implementation harness exists.

A Watch would mean:

> Monitor a bounded external condition and surface a meaningful change under an explicit user mandate.

Examples:

- The 1975 announce tour dates,
- Mateo announces a wine dinner,
- a new Legion series/collection is announced,
- a desired ticket/availability condition becomes true.

The semantic contract is understandable, but reliable implementation requires answers to:

- which sources,
- who performs polling/refresh,
- how often,
- where execution occurs while Cockpit is not open,
- whether push/server infrastructure exists,
- how changes are deduplicated,
- what counts as meaningful,
- how notifications are delivered,
- what happens when source access fails.

Until those harness questions are answered, retain Watch as a product hypothesis rather than building a generic agent subsystem.

---

## 12. Parking lot: Nudge

`Nudge` also remains plausible but should require explicit behavioral authority from Jon.

Example:

> “Do a better job of reminding me to actually read NYT Food.”

This differs from source discovery: the user already has access and is asking Cockpit to help change behavior.

A future Nudge needs clear answers to:

- what desired behavior was explicitly requested,
- what evidence indicates the behavior did/did not happen,
- how often intervention is appropriate,
- how to avoid becoming nagware,
- how the user pauses/cancels the mandate.

### Product principle

> Cockpit should never infer a behavioral improvement goal merely from observing behavior; the mandate must be explicit.

Do not build generalized behavior-coaching machinery until a real Nudge use case earns it.

---

## 13. Current Context is derived input, not yet a subsystem

The family may eventually have rich ambient current context from calendars, reservations, trips, menus, tickets, and specialist publications.

However, Cockpit should not create a general `CurrentContext` ontology merely because such context could someday be useful.

Instead:

- name a concrete consumer,
- identify the decision the context improves,
- fetch/assemble the smallest necessary context for that operation,
- extract shared publication or context infrastructure only when repeated real consumers prove the seam.

Examples:

- Galavant trip review can consume the current trip directly.
- Daily could later consume a small Galavant trip publication if that demonstrably improves relevance.
- a calendar-aware feature can query the specific calendar window it needs rather than requiring a canonical context graph first.

### Product principle

> Context is earned by consumers; it is not a speculative knowledge warehouse.

---

## 14. Family Context publication remains a documented seam, not an implementation mandate

`APP-FAMILY-INTERACTION.md` describes how specialist apps may publish small current-domain projections to the family.

That architecture remains useful, but implementation should wait for a concrete consumer.

Do not build the Family Context Store simply because the design is elegant.

A first publication should be driven by a feature such as:

> Cockpit Daily materially improves when it knows a specific Galavant trip is current.

Only then decide the minimum publication payload and transport.

---

## 15. Harness-first design rules

The following rules should guide future capability discussions.

### Rule 1 — Name the source

If Cockpit is expected to know that something changed, identify where that information comes from.

### Rule 2 — Name the execution environment

If Cockpit is expected to notice something while the app is not open, identify what process actually runs and where.

### Rule 3 — Name the authority

If Cockpit is expected to take an action, identify whether it is intrinsic, instance-approved, batch-approved, policy-authorized, or prohibited.

### Rule 4 — Name the failure mode

If the source disappears, background execution fails, or the model is uncertain, define the safe result.

### Rule 5 — Do not confuse model intelligence with harness capability

A stronger model can interpret better. It cannot create network access, background runtime, notification delivery, provider permissions, or app-to-app transport that the system does not provide.

### Rule 6 — Prefer semantic contracts whose transport can improve later

Examples:

- `Jon Brain Handoff`,
- capture-and-enrich,
- receiver-owned handoff,
- bounded source curation.

Manual or user-initiated transport can serve V1 while better plugins/MCP/App Intents/agents later automate the same semantic operation.

### Rule 7 — Build durable knowledge ahead of volatile execution machinery

Personal Knowledge should survive and improve future capabilities even if today’s integrations are primitive.

---

## 16. What not to build yet

Do not build, absent a concrete named consumer/harness:

- a universal agent framework,
- a general `CurrentContextStore`,
- a general autonomous Watch engine,
- a generalized Nudge/behavior-change engine,
- a universal family queue,
- a universal family ontology,
- broad clickstream/engagement telemetry for hypothetical personalization,
- generalized continuous internet monitoring,
- a cloud scheduler merely because future agent features might need one,
- a shared publication package before two real producer/consumer flows prove its stable shape.

These may become correct later. They are not earned merely by being plausible.

---

## 17. Near-term product reality map

| Capability | Reality now | Primary input | AI role | Deterministic/app role |
| --- | --- | --- | --- | --- |
| **Daily** | Works now | Inbox/source artifacts | classify, summarize, extract, prioritize | custody, persistence, source mutation, recovery |
| **Know** | Works now / manual ChatGPT bridge | explicit teaching, handoffs, meaningful evidence | synthesize, notice, consolidate, explain | durable storage, provenance, correction state |
| **Advise** | User-initiated now | explicit domain context + Jon Brain | reason, compare, critique | assemble context, persist only explicit operations |
| **Handoff** | User-initiated now as receiver doors exist | source material + intent | interpret/rationale | receiver admission, queue, canonical commit |
| **Curate** | Works now for bounded feeds | RSS/Atom/known streams + purpose/Interests | filter, rank, explain | fetch, parse, retain rejects/source state |
| **Capture & Enrich** | Works now with manual/share/voice bridge | fuzzy notion + available source context | resolve identity, research, classify | immediate capture, custody, destination/queue commit |
| **Watch** | Future unless harness named | explicit standing condition | judge meaningful change | scheduler/source polling/push/notifications |
| **Nudge** | Future unless harness named | explicit behavioral mandate | contextualize intervention | schedule/delivery/state tracking |

---

## 18. Summary

Cockpit does not need general agency to become valuable.

A credible near-term product is:

1. **Daily** — intelligent triage.
2. **Know** — build the Jon Brain.
3. **Advise** — user-initiated reasoning with relevant Personal Knowledge.
4. **Handoff** — frictionless send-to-specialist queues.
5. **Curate** — bounded source intelligence with inspectable filtering.
6. **Capture & Enrich** — low-friction fuzzy capture resolved into useful material.

These capabilities map naturally to:

```text
TRIAGE   -> what came in and matters?
CAPTURE  -> I encountered something; don't make me deal with it now.
CURATE   -> reduce known streams intelligently.
KNOW     -> understand me increasingly well.
ADVISE   -> apply that understanding to a question I am asking now.
```

Future Watch/Nudge/agent capabilities should be added only when the execution harness is specific and credible.

> **Design the knowledge and semantic contracts for the future we want. Implement only the agency the current harness can honestly support.**
