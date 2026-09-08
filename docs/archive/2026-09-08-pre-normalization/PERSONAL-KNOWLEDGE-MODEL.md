# Personal Knowledge Model: Know, Notice, and Synthesis

**Status:** Working product/architecture decision  
**Date:** 2026-09-06

## Purpose

Cockpit needs to know the user well enough to give better advice now and support increasingly capable agentic behavior later. That does **not** require a behavioral-surveillance warehouse or a transcript-like memory of everything Jon has ever said.

The Personal Knowledge system should instead maintain a small, durable, provenance-bearing, continuously synthesized understanding of Jon, Wendy, and relevant shared household context.

The governing principle is:

> Personal Knowledge stores conclusions, not conversational exhaust. Evidence supports, challenges, and refines those conclusions; AI periodically synthesizes across the evidence to notice patterns, changes, tensions, and useful insights.

This document defines the semantic/product model. `PERSONAL-KNOWLEDGE-BOUNDARY.md` defines ownership, durability, cross-device access, and likely future app-family extraction. `JON-BRAIN-HANDOFF.md` defines the manual/future conversational handoff contract.

---

## 1. The purpose of Personal Knowledge is better judgment

Personal Knowledge exists first to improve advice and reasoning.

Examples:

- Galavant can review a trip with awareness that Jon and Wendy prefer shorter city stays unless food/cultural density earns more time.
- Cockpit can recognize that a fifth four-hour tasting menu in six nights conflicts with an emerging preference for ambitious food with less ceremonial endurance.
- A future recommendation system can distinguish a defining interest such as Legion of Super-Heroes from a casual topic Jon happened to read about once.
- A future agent can combine a strong music interest with an explicitly approved Watch to decide that a ticket announcement deserves interruption.

The test for whether something belongs in durable Personal Knowledge is:

> Would knowing this materially improve advice or future judgment across contexts?

The system should not distort its knowledge model around whichever integrations or automations happen to exist today.

### Product principle

> Store personal meaning independently of today's available automations so future capabilities can make better use of the accumulated understanding without requiring it to be recollected.

---

## 2. `Know` is Facts plus Synthesized Understanding

The user-facing concept is **Know**.

Conceptually:

```text
Know
  |
  +-- Facts
  |
  +-- Synthesized Understanding
          |
          +-- Taste
          +-- Interest
```

This is a product/semantic model, not a ratified database enum hierarchy.

### Facts

Facts are relatively objective, durable things that are useful to reasoning.

Examples:

- Jon graduated from Harvard.
- Jon graduated from Harvard Business School.
- Jon lives in Chapel Hill.
- Wendy is Jon's spouse.
- RDU is the home airport.
- Jon is an experienced home cook.

Facts should generally be conservative, directly sourced where practical, and easy to correct.

### Taste

Taste describes how Jon, Wendy, or the household tend to prefer, choose, or trade things off.

Examples:

- Jon and Wendy generally prefer shorter city stays unless exceptional food/cultural density justifies more time.
- Jon strongly values ambitious dining but increasingly prefers less ceremonial, shorter high-end meals over marathon tasting menus.
- Wendy likes fruit in white wine but not heaviness or sweetness.
- Jon and Wendy tend to prefer characterful luxury over large corporate luxury.

Taste should preserve nuance and tradeoffs rather than collapse them into brittle scalar settings.

### Interest

Interest describes subjects/entities that have durable or currently meaningful salience.

Examples:

- Legion of Super-Heroes is a defining long-term interest for Jon.
- The 1975 is a strong music interest.
- Burgundy is a strong recurring interest.
- Mateo may be a high-salience restaurant relationship based on repeated reservations plus explicit enthusiasm.

Interest may evolve more dynamically than Taste. The system may eventually need a notion of salience and trajectory such as emerging, sustained, fading, or dormant, but exact cases are not ratified here.

### Product principle

> Taste answers "Would this fit me?" Interest answers "Should I care unusually much about this?" Facts answer "What is true about my life that helps interpret everything else?"

---

## 3. Do not normalize the life out of the knowledge

The canonical semantic content should remain expressive and human-readable.

Prefer:

```text
Jon and Wendy have learned that more than roughly 36 hours in most cities is not appealing unless the food or cultural density justifies it.
```

rather than:

```text
preferredCityDurationHours = 36
foodOverride = true
```

Structure should surround the semantic proposition where computers actually need it, for example:

- who the knowledge describes,
- broad kind (`fact`, `taste`, `interest`),
- subject/entity where relevant,
- scope/context,
- provenance/basis,
- salience/strength where useful,
- temporal state/validity,
- supporting evidence references or summaries,
- correction/supersession state.

Exact schema and enum choices remain implementation decisions.

### Product principle

> Structured metadata should make semantic knowledge usable and correctable; it should not reduce nuanced personal understanding to a preferences spreadsheet.

---

## 4. Evidence is not the same thing as knowledge

The system should separate an emerging conclusion from the meaningful evidence supporting it.

Conceptually:

```text
meaningful evidence
       |
       v
   AI synthesis
       |
       v
personal conclusion
```

Example:

```text
CONCLUSION
Jon has a defining long-term interest in Legion of Super-Heroes.

SUPPORTING EVIDENCE
- explicit statements about longstanding obsession
- repeated collecting behavior
- multiple meaningful purchases/bids
```

The normal product experience should operate on the conclusion. Evidence exists so Cockpit can answer:

> Why do you believe this?

and so future synthesis can challenge, narrow, strengthen, or reinterpret the conclusion.

The system should not preserve every utterance or interaction as an independent durable belief.

### Product principle

> A statement or action may be evidence toward a larger understanding rather than a permanent memory in its own right.

---

## 5. AI should synthesize, not transcribe

The Personal Knowledge system is not a notebook of "random things Jon said."

The AI should periodically consolidate overlapping evidence into fewer, richer conclusions.

For example, several conversations and trip decisions may eventually support:

> Jon and Wendy prefer shorter city stays unless exceptional food/cultural density earns more time.

rather than preserving separate durable records such as:

- Jon said Munich felt long.
- Jon said six nights in Burgundy might be too much.
- Jon extended Paris.
- Jon complained about another city stay.

Similarly, several dining conversations may support:

> Jon's enthusiasm for ambitious dining remains high, but meal duration and ceremony increasingly behave like costs rather than virtues.

The AI is expected to process and synthesize. The knowledge base should become **more distilled as it learns more**, not simply larger.

### Product principle

> More evidence should normally produce better synthesis, not linear growth in memory records.

---

## 6. Evidence quality matters more than behavioral volume

Cockpit should not pretend that passive behavioral tracking is magical.

The strongest evidence sources are likely to be:

1. **Explicit declaration or correction**  
   "We do not want four-hour tasting menus anymore."  
   "Wendy likes some fruit in white wine."  
   "That is only true for this trip."

2. **Explicit reaction or preference-bearing action**  
   `Love this`, `More like this`, `Wrong for us`, deliberate handoff, intentional preservation, explicit comparison/choice.

3. **Semantically meaningful commitment systems**  
   Actual reservations, tickets, purchases, bids, bookings, specialist-app outcomes, collecting history, music/library history where the action itself has interpretable meaning.

4. **Repeated meaningful specialist behavior**  
   Repeated real choices in Yes Chef, Galavant, or another domain app where that app understands the semantics well enough to propose a broader conclusion.

Passive consumption evidence such as opens, clicks, scroll depth, dwell time, generic newsletter reading, and non-engagement should ordinarily be ignored for durable Personal Knowledge.

Reading an article does not imply endorsement. A newsletter open does not reliably imply interest. Non-engagement should not become negative taste evidence.

### Product principle

> Learn primarily from declaration, reaction, and meaningful commitment — not from surveillance of incidental consumption.

### Architectural constraint

> Do not persist telemetry merely because it might improve personalization later.

Detailed domain evidence should remain in the app that understands it unless there is a real reason to preserve a compact provenance reference or promoted conclusion in shared Personal Knowledge.

---

## 7. High-semantic-value systems may provide useful evidence

Some external systems carry more meaning than generic browsing telemetry because their actions represent commitments.

Potential examples include:

- restaurant reservation systems such as OpenTable or Resy,
- ticketing systems,
- purchasing/collecting systems such as eBay,
- music listening/library history when repeated over meaningful time,
- calendar attendance/planning,
- Galavant trip outcomes,
- Yes Chef cooking/menu outcomes,
- explicit favorites/saves where the source semantics make the action meaningful.

Availability of a direct integration is not assumed. Evidence might eventually arrive through APIs, email extraction, calendar, App Intents, exports, provider plugins, or another mechanism.

The ontology should not be shaped around today's available connectors.

### Product principle

> Integrations provide evidence; they do not define the Personal Knowledge ontology.

---

## 8. Temporary relevance is not durable identity

Recent behavior can affect what seems timely without becoming a conclusion about who Jon is.

Example:

> Jon has been reading about Burgundy heavily this week.

That may justify a temporary relevance boost. It should not automatically create:

> Burgundy is a defining interest.

Conceptually:

```text
short-lived relevance signals
        !=
durable Personal Knowledge
```

Temporary relevance should decay naturally unless stronger evidence earns promotion into durable understanding.

This lets Cockpit adapt to what is salient now without converting every burst of attention into permanent personality.

---

## 9. Personal Knowledge does not grant agent authority

Knowing that something matters is different from being authorized to act on it.

Example:

```text
KNOW
The 1975 is a strong music interest for Jon.
```

is separate from:

```text
WATCH
Notify Jon promptly when new The 1975 tour dates or ticket sales appear.
```

Likewise:

```text
KNOW
Mateo is a high-salience restaurant for Jon.
```

is separate from:

```text
WATCH
Surface Mateo wine-dinner announcements immediately.
```

And:

```text
KNOW
NYT Food is an important publication for Jon.
```

is separate from:

```text
NUDGE
Help Jon actually read NYT Food regularly.
```

Personal Knowledge may justify **suggesting** a Watch or Nudge. It does not itself create that mandate.

### Product principle

> Understanding can suggest agency; only explicit intent or approved policy grants agency.

---

## 10. Current Context remains separate from Personal Knowledge

Current Context answers:

> What is happening now?

Examples:

- Burgundy trip in May,
- Mateo reservation Friday,
- The 1975 concert in June,
- Yes Chef dinner menu Saturday,
- upcoming calendar events.

These are not durable personality claims.

Cockpit combines current context with Personal Knowledge and incoming information:

```text
Personal Knowledge
       +
Current / Published Context
       +
Incoming World
       |
       v
   AI reasoning
       |
       v
What matters now?
```

Calendar, reservations, specialist-app publications, and similar sources may therefore be extremely valuable without becoming Personal Knowledge themselves.

---

## 11. `You` is an analyst, not a memory editor

Cockpit's `You` experience should have three jobs:

1. **Describe me**  
   What does the app family currently understand about Jon/Wendy?

2. **Notice me**  
   What patterns, changes, tensions, exceptions, or potentially useful insights are emerging?

3. **Let me correct you**  
   Is the understanding right, wrong, too broad, contextual, stale, or changing?

The user should not manage Personal Knowledge day to day.

The normal `You` surface should show understandable synthesized projections, not database rows.

For example:

### Travel

> Jon and Wendy tend to favor characterful luxury, beautiful countryside, exceptional food, and relatively unhurried days. They generally prefer shorter city stays unless a city offers unusually deep food or cultural rewards.

### Food & Wine

> Jon values ambitious dining but is increasingly resistant to marathon tasting-menu ceremony. Wendy prefers white wines with fruit but not excess weight or sweetness.

### Music & Culture

> The 1975 is a major current music interest. Legion of Super-Heroes is a defining long-term interest and collecting area.

These summaries are projections from structured knowledge. They are replaceable/regenerable; the underlying knowledge and provenance are canonical.

---

## 12. Notices are AI-generated hypotheses, not canonical truth

The AI should be allowed to reason across Facts, Taste, Interests, meaningful evidence, and current context to produce **Notices**.

A Notice is something like:

- "You seem increasingly willing to sacrifice hotel grandeur for walkability to excellent restaurants."
- "Your enthusiasm for ambitious dining has not diminished, but your tolerance for ceremony and meal duration has."
- "Burgundy appears to be more than a wine interest; it repeatedly drives travel, restaurants, collecting, and reading."
- "You say you prefer relaxed travel days, yet your first-pass itineraries repeatedly become overstuffed. You may enjoy planning maximalistically even though you prefer traveling more selectively."

A Notice is valuable precisely because Jon may not have stated it this way.

However:

> A Notice is a hypothesis until evidence or Jon's clarification earns promotion into durable Personal Knowledge.

The AI may notice without being allowed to silently rewrite canonical understanding.

This gives the system intellectual curiosity without overconfidence.

---

## 13. Contradiction and tension are information

Two beliefs or behaviors that appear inconsistent should not be immediately reconciled by deleting one or inventing a compromise.

Examples:

- Jon and Wendy generally prefer short city stays, yet repeatedly extend Paris.
- Wendy likes fruit in white wine, while recent choices reject very large fruity whites.
- Jon strongly values ambitious dining, while increasingly complaining about four-hour tasting menus.
- Jon values exceptional hotels, yet often prioritizes walkability to restaurants over resort isolation.

These may reveal scope, exceptions, evolution, or tradeoffs.

### Product principle

> Contradiction is information. Preserve the tension until context explains it.

The AI should surface tensions selectively and invite clarification rather than silently choosing which belief wins.

A clarification may produce a richer conclusion, for example:

> Jon values ambitious dining but increasingly prefers concentrated excellence over ceremonial duration.

---

## 14. Monthly Review is the primary governance rhythm

Jon should not be asked to curate the Brain continuously.

A monthly review is a good default human-control surface because it allows quiet learning while keeping the model visible and correctable.

The review should be a **distilled delta**, not an inventory audit.

Useful categories include:

### New

A conclusion that appears newly useful or durable.

### Strengthened

An existing understanding now has materially stronger evidence.

### Changing

Evidence suggests an established preference or interest may be evolving.

### Tension worth clarifying

Two beliefs, patterns, or contexts appear meaningfully inconsistent or more nuanced than the current synthesis captures.

### Possibly stale

An older belief may no longer deserve the same weight.

### Notice

An interesting pattern the AI sees but does not yet think should become durable knowledge.

The monthly review should focus on the few things that became meaningfully better, weaker, stranger, or more interesting — not dozens of unchanged beliefs.

Typical actions should be lightweight:

- `Looks right`
- `Clarify`
- `Only in this context`
- `That's changed`
- `Forget / stop using this`

The user should also be able to ask why the system believes something and inspect the meaningful supporting provenance when desired.

---

## 15. Explicitly confirmed knowledge outranks later weak inference

The system should not casually overwrite a direct statement or correction with weaker behavioral evidence.

Conceptually:

```text
explicit statement / confirmed correction
                >
strong semantically meaningful inference
                >
weak or ambiguous behavioral evidence
```

This is not a numeric-confidence hierarchy. It is an epistemic/provenance distinction.

If strong later evidence conflicts with an explicit belief, the right response may be a Notice or monthly-review tension:

> "You previously told me X, but recent meaningful choices look different. Has this changed, or is the recent behavior contextual?"

---

## 16. Teaching should be easier than behavioral inference

The highest-quality Personal Knowledge often comes from conversation or direct teaching because the user can express degree, rationale, exceptions, and context.

Cockpit should make this extremely easy through an always-accessible natural-language teaching door, provisionally:

> **What should the Jon Brain know?**

Jon should be able to type or dictate ordinary statements such as:

- "Wendy likes some fruit in white wine, but neither of us wants syrupy wine."
- "When we travel, minimizing driving after a serious dinner matters a lot."
- "I am getting much less interested in giant tasting menus."

AI may convert these into structured Personal Knowledge while preserving subject, scope, provenance, and nuance.

Directly initiated teaching should not require an onerous review workflow. A lightweight `Remembered · Undo` pattern is preferable unless the input is materially ambiguous.

`JON-BRAIN-HANDOFF.md` defines the parallel conversational-system handoff for ChatGPT and future integrations.

---

## 17. Design for the conversational integration we want

Rich conversations can provide better Personal Knowledge evidence than Cockpit's own behavioral observation because conversation contains reasons, corrections, tradeoffs, and explicit context.

The family architecture should therefore assume that future ChatGPT/plugin/MCP/agent integrations will improve.

Today the manual `Jon Brain Handoff` text protocol can transport synthesized knowledge into Cockpit.

Later the transport may become a direct plugin, MCP tool, App Intent, agent action, or another mobile-friendly mechanism.

The semantics should remain the same:

```text
conversation
     |
     v
high-quality candidate personal knowledge
     |
     v
shared Personal Knowledge
```

The system should not bulk-mine all conversation history merely because future APIs make that possible. Deliberate semantic handoff is preferred over exhaustive transcript ingestion.

---

## 18. App-family participation follows the shared-knowledge boundary

`PERSONAL-KNOWLEDGE-BOUNDARY.md` establishes that Cockpit is the primary Jon-facing stewardship surface while durable Personal Knowledge may ultimately be app-family-owned.

The likely future direction is:

```text
Shared Personal Knowledge
       ^       ^       ^
       |       |       |
    Cockpit  Galavant  Yes Chef
       |
       v
   primary `You`
```

Specialist apps may contribute conclusions when they have semantically meaningful domain evidence and may consume task-specific projections of shared knowledge.

They should not dump raw interaction histories into the shared substrate.

`PersonalKnowledgeKit` remains the likely future `jon-platform` extraction once a second real application participates. This document intentionally defines semantics before package mechanics.

---

## 19. What remains open

This document settles the product model more than the storage schema.

Still open:

- exact SQLiteData/CloudKit schema,
- exact claim record representation,
- exact representation of evidence/provenance references,
- salience/strength cases,
- interest trajectory cases,
- temporal validity mechanics,
- subject/person/household identity representation,
- consolidation/supersession mechanics,
- how often background synthesis runs,
- exact monthly-review UX,
- exact `You` navigation and editing surfaces,
- which initial external systems are technically available as high-semantic evidence sources,
- first Galavant/Yes Chef cross-app Personal Knowledge participation.

These should be derived from implementation slices and real examples rather than invented as a complete ontology now.

---

## Summary

- **Know** = Facts + Synthesized Understanding.
- **Synthesized Understanding** currently means Taste + Interest.
- **Evidence** supports conclusions but is not itself the normal user-facing knowledge base.
- **AI synthesizes** overlapping evidence into fewer, richer conclusions.
- **Passive behavioral telemetry is weak** and should ordinarily not become durable knowledge.
- **Declaration, reaction, and meaningful commitment** are the preferred evidence sources.
- **Temporary relevance** can adapt ranking without becoming identity.
- **Personal Knowledge does not grant agency**; Watch and Nudge remain separate mandates.
- **Current Context** is separate from durable Personal Knowledge.
- **`You` is an analyst**, responsible for Describe / Notice / Correct.
- **Notices are hypotheses**, not automatic canonical truth.
- **Contradictions are information** and should be surfaced for contextual clarification rather than silently flattened.
- **Monthly Review** is the preferred low-friction governance rhythm.
- **The knowledge base should become more distilled, not merely larger, as evidence accumulates.**

> The Jon Brain should know enough to give better advice, notice things Jon has not quite articulated himself, and prepare the app family for better future agency — without becoming a transcript archive or behavioral-surveillance system.
