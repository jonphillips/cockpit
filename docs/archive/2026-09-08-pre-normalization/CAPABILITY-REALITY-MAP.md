# Cockpit Capability Reality Map

**Status:** Working product/architecture decision  
**Date:** 2026-09-08

## Purpose

Cockpit should be future-ready without pretending that current mobile/agent harnesses can do things they cannot yet reliably do.

The product should separate two kinds of future-proofing:

1. **Knowledge can be built ahead of future agents** because durable understanding compounds over time.
2. **Agency should not be designed ahead of proven harnesses** because execution, background runtime, provider access, notification delivery, and app-to-app integration remain volatile and platform-dependent.

The governing principle is:

> **Be future-ready in what Cockpit knows; be conservative in what Cockpit claims it can do.**

Cockpit should commit near-term only to capabilities with a credible provider/source, transport, execution boundary, and user experience using tools that can realistically be implemented now or with an explicit manual bridge.

This document identifies six near-term capabilities that meet that standard and parks more speculative agentic behaviors until their harnesses are real.

### Terminology note

For recurring Content, the current product noun is **Stream**; see `docs/CONTENT-STREAM-MODEL.md`.

`Source` remains correct when discussing upstream provider material, provenance, evidence, source actions, or the external origin/access required by an agentic capability.

---

## 1. Capability reality tiers

When considering a new Cockpit behavior, classify it before designing architecture around it.

### Tier A — Works now

The app can perform the behavior with normal app runtime, known APIs, deterministic operations, or model calls initiated while Cockpit is active.

Examples:

- classify and summarize fetched email,
- extract structured information from supplied source material,
- reason against the Jon Brain,
- parse a known RSS/Atom Stream,
- persist a captured Item,
- hand material to another app through a receiver-owned admission door when available.

### Tier B — Works now with a manual bridge

The semantic workflow is real, but Transport remains manual until a better platform integration appears.

Examples:

- `Jon Brain Handoff` copied/shared from ChatGPT into Cockpit,
- pasting a URL or selected text into Capture,
- sharing a podcast episode plus a short dictated description of what should be found.

The manual bridge is acceptable when the semantic contract is stable and likely future automation merely replaces Transport.

### Tier C — Works as a user-initiated operation

Cockpit can do the work when the user explicitly invokes it, but should not imply reliable ambient/background behavior.

Examples:

- “Review this Galavant trip with Jon Brain,”
- “Find the report they were discussing and add it to Reading,”
- “Refresh my followed Streams now,”
- “Filter this music Stream against my Interests.”

### Tier D — Needs a specific harness/integration

The product idea is coherent, but reliable implementation depends on an external capability not yet proven.

Examples:

- continuous provider-specific ticket monitoring,
- immediate background alerts from arbitrary external sites,
- direct ChatGPT-to-Cockpit Personal Knowledge writes without manual Transport,
- ambient querying of specialist apps when they are not running unless a shared publication mechanism exists.

### Tier E — Future/agentic hypothesis

The product idea may become useful, but there is not yet enough execution reality to warrant a subsystem.

Examples:

- general autonomous web monitoring,
- broad proactive life management,
- inferred behavioral nudging without an explicit mandate,
- open-ended “agent” workflows whose source, runtime, authority, and completion semantics are undefined.

### Architectural rule

> **No new subsystem should be justified primarily by a Tier D/E story when a Tier A/B/C consumer has not yet earned it.**

---

## 2. Six near-term capabilities

The current realistic Cockpit product can be described through six capabilities.

1. **Daily / Today** — intelligently triage what came in.
2. **Know** — build and synthesize durable Personal Knowledge.
3. **Advise** — reason against explicit supplied context using what Cockpit knows.
4. **Handoff** — send material into specialist-owned incoming queues.
5. **Curate** — intelligently filter bounded known Streams.
6. **Capture & Enrich** — accept fuzzy low-friction capture and resolve it into useful material later in the workflow.

These do not require a general autonomous agent.

They do create substrate a future agent would want: durable knowledge, explicit Streams and provider provenance, faithful Artifacts, semantic Subjects, Handling/source-action policies, user intent, and safe deterministic mutation boundaries.

---

## 3. Today — intelligent triage

### User problem

A significant amount of information arrives through email and other channels. The user wants to know:

> **What came into my world, what matters, and what can I safely ignore?**

### Near-term capability

Cockpit can:

- fetch current Inbox/provider material,
- classify and summarize,
- distinguish important/personal/consequential material from noise,
- extract structured meaning where useful,
- preserve source material where Cockpit assumes custody,
- apply Handling Policies,
- execute approved source actions such as archive/Clear,
- surface especially important Items before the user moves on with the day.

### Harness reality

This is a real application workflow with concrete provider APIs and deterministic mutation boundaries.

### Non-goal

Today should not become a generalized task manager or pretend that all life activity can be represented as due dates and completion state.

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

Future ChatGPT/plugin/MCP/mobile integration should replace manual Transport without changing the semantic contract.

### Product principle

> **Knowledge can be built ahead of future agents because understanding compounds even when agency is still limited.**

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
        ↓
AI reasoning
```

The output is advisory unless a separately authorized deterministic operation follows.

### Harness reality

This is a Tier A/C capability: the user supplies the context or initiates the reasoning operation. It avoids unreliable background runtime and generalized agent machinery.

### Architectural consequence

Do not require a general `CurrentContext` subsystem merely to support advice. If a feature needs trip/calendar/menu context, assemble exactly the context that named consumer requires.

### Product principle

> **No new context ontology without a named consumer and a demonstrated decision it improves.**

---

## 6. Handoff — frictionless send-to-specialist queues

### User problem

Cockpit often operates in triage/reading mode. Discovering something useful should not force the user to leave that mode and perform domain-specific work immediately.

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

> **Handoff means “put this somewhere useful for later specialist work,” not “interrupt triage and finish the specialist workflow now.”**

---

## 7. Curate — bounded Stream intelligence

### User problem

Cockpit can provide significant value without scouring the entire internet if the user deliberately follows a bounded Stream and gives Cockpit an editorial purpose.

The core question is:

> **Given this known Stream, what deserves my attention?**

### Near-term capability

Cockpit can ingest a known Stream and apply:

```text
Stream
  +
Interest Area guidance
  +
Stream Handling
  +
relevant Personal Knowledge when applicable
       ↓
AI curation / extraction / ranking
```

This is deterministic ingestion plus model judgment over a bounded corpus.

The recurring-content model is defined in `docs/CONTENT-STREAM-MODEL.md`.

### Example A — OpenAI capability Stream

An OpenAI release-notes RSS/Atom Stream could be followed under `Technology & Making` with a specific Handling instruction:

> Surface product/platform changes that materially expand what Cockpit or the Jon app family could realistically do, especially mobile integration, plugins/apps/MCP, app-to-app communication, background/agent capability, model/tool APIs, and Apple-platform relevance.

This filter is not primarily Personal Knowledge. It is declared Stream purpose/Handling.

The output should distinguish:

- actual new harness capability,
- marketing/announcement noise,
- desktop-only capability with no mobile relevance,
- capability that exists in theory but lacks a usable integration path for Cockpit.

### Example B — music/news Stream

A music/news Stream can be filtered largely against Jon Brain Interests:

- strong artist interests,
- genre interests,
- emerging interests,
- known dislikes/low-salience areas where useful.

Cockpit should surface relevant Items and may provide an inspectable `Skipped` / `Handled Quietly` view.

The skipped view creates an explicit correction loop:

> “Why did you reject Fontaines D.C.? I definitely care about them.”

That correction is strong Personal Knowledge evidence.

Silence about a skipped Item is not evidence that the filter was correct forever.

### Harness reality

RSS/Atom, email publications, YouTube channel feeds, and other bounded integrations are ordinary fetch/parse workflows when a concrete Transport exists. AI can classify and rank while the app is active or during refresh opportunities the platform actually permits.

### Important limitation

Do not casually promise “continuous monitoring” on iOS.

Near-term semantics should be phrased in terms such as:

- refresh during the morning edition build,
- refresh when Cockpit is opened,
- refresh during permitted background opportunities,
- refresh on explicit user request.

Reliable immediate alerts require a specific push/cloud/background harness and should be treated as a separate capability once proven.

### Product principle

> **Bounded-Stream intelligence is real now; generalized ambient web monitoring is not required.**

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
        ↓
capture safely now
        ↓
AI/web enrichment when execution is available
        ├── resolve likely identity
        ├── find authoritative source
        ├── attach URL / metadata
        ├── retrieve/preserve source content where policy allows
        └── classify destination/use
        ↓
retained Cockpit material / specialist queue
```

The enrichment step must remain lossless-or-loud when exact identity matters. If Cockpit finds multiple plausible targets, preserve ambiguity or ask at the consequential boundary rather than silently choosing the wrong document.

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

Use only the context actually supplied by the provider/OS plus a short user phrase when necessary.

### Harness reality

This is a Tier A/B/C workflow: capture is immediate and deterministic; enrichment can occur during active/user-initiated execution. Better future agents/background systems can automate the same semantic enrichment step later.

### Product principle

> **Capture first; enrich later. Do not make the user finish the research task merely to remember that the research task exists.**

---

## 9. What remains deliberately parked

The following should not yet become first-class subsystems simply because they sound like future-agent features.

### Watch

A future Watch is an explicit standing monitoring mandate such as:

> Tell me if this specific condition becomes true.

It requires a credible execution/source/notification harness.

Interest alone does not grant monitoring authority.

### Nudge

A future Nudge is explicit requested behavioral help.

Do not infer standing behavioral mandates from passive data or ordinary Interests.

### Broad Current Context

Do not create a universal context ontology ahead of named consumers. Assemble exactly the context needed for a concrete decision.

### Autonomous discovery

Do not assume a general agent constantly scans the open web and discovers what the user should care about.

Bounded Streams and explicit Capture already provide substantial value with honest harnesses.

---

## 10. Product/architecture laws

1. **Be future-ready in what Cockpit knows; conservative in what Cockpit claims it can do.**
2. **Knowledge can be designed ahead of agents because knowledge is durable; agent substrate should wait for real harnesses.**
3. **No new subsystem should be justified mainly by a speculative Tier D/E consumer.**
4. **Today, Know, Advise, Handoff, Curate, and Capture & Enrich are credible near-term capabilities.**
5. **Curate operates over bounded known Streams, not an imaginary omniscient web agent.**
6. **Stream is the recurring Content noun; source remains the provider/provenance/action noun.**
7. **No new context ontology without a named consumer and demonstrated decision it improves.**
8. **AI can interpret/reason/propose; canonical and external mutations go through deterministic app operations under current intent or approved policy.**
9. **Manual Transport bridges are acceptable when the semantic contract is durable.**
10. **Do not promise background continuity without a concrete scheduler/push/runtime harness.**

---

## 11. Implementation posture

The next implementation architecture should be tested against concrete V1 slices rather than generalized agent stories.

Good proving slices include:

- one real Gmail Today loop,
- one real Content Interest Area with one or two Streams,
- one Personal Knowledge storage/synthesis loop,
- one fuzzy Capture & Enrich flow,
- one receiver-owned specialist Handoff.

A Stream implementation should be narrow enough to expose the actual ingestion/refresh/persistence seams without prematurely requiring a universal `ContentStreamKit` in `jon-platform`.

First use in Cockpit is evidence, not proof of a platform abstraction.