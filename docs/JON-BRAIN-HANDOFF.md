# Jon Brain Handoff

**Status:** Working product/architecture decision  
**Date:** 2026-09-06

## Purpose

Cockpit's Personal Knowledge system should be designed for the integration model we ultimately want, not constrained by today's weakest transport.

The long-term desired interaction is simple:

```text
rich conversational system
        |
        | "Jon Brain Handoff"
        v
semantic personal-knowledge payload
        |
        v
shared Personal Knowledge
```

Today, the transport may be manual copy/paste or Share Sheet text. In the future, it may be a ChatGPT plugin/app/MCP action, App Intent, agent tool, or another direct mobile-capable integration.

The durable contract should therefore be semantic rather than transport-specific.

### Product principle

> Design for the system we wish existed; use manual transport in the meantime. The transport can improve without changing the meaning of the handoff.

This document defines that manual semantic contract now so Cockpit can support a real workflow immediately while remaining poised for better desktop and mobile integration later.

---

## 1. A Jon Brain Handoff is not a conversation summary

The phrase **"Jon Brain Handoff"** means:

> Extract durable or currently useful personal knowledge from this conversation that may matter outside the conversation.

It does **not** mean:

- summarize everything discussed,
- preserve every factual detail,
- infer personality from incidental behavior,
- recreate the conversation in condensed form,
- dump every recommendation, destination, restaurant, recipe, or product mentioned,
- turn one-off situational choices into durable preferences.

The handoff should be conservative and intentionally sparse.

A good handoff contains only knowledge that is plausibly useful to Cockpit or another app-family consumer later.

---

## 2. Why conversational evidence is different

Rich conversation provides higher-quality personal evidence than passive behavioral tracking because the user can state, refine, qualify, contradict, and explain preferences in context.

For example, conversation can distinguish:

- "I like fruit in white wine" from "I want something lighter tonight."
- "We prefer countryside hotels" from "this airport-night hotel can be utilitarian."
- "Six nights in Burgundy feels like too much" from "Jon dislikes Burgundy."

Cockpit should not pretend passive interaction telemetry provides the same semantic fidelity.

### Personal Knowledge doctrine

> Durable Personal Knowledge should be grounded primarily in explicit statements, corrections, and intentional preference-bearing acts. Passive behavior may influence temporary relevance, but it should rarely become durable identity without confirmation.

A rich ChatGPT conversation is therefore a particularly valuable source of candidate Personal Knowledge because it contains semantic evidence Cockpit itself may never observe.

---

## 3. The manual protocol

The manual V1 protocol is plain text.

It uses three possible sections:

- **Remember** — strong enough to become durable Personal Knowledge.
- **Maybe** — useful but genuinely uncertain; should not silently become durable Personal Knowledge.
- **Temporary** — current context that may affect relevance now but should not become durable identity.

Empty sections are omitted.

Each bullet should:

- express one atomic idea,
- stand alone outside the source conversation,
- identify who it describes when relevant,
- preserve important scope and context,
- avoid fake numerical confidence,
- indicate evidence basis using one of:
  - `[explicit]`
  - `[strong inference]`
  - `[current context]`

Example:

```text
JON BRAIN HANDOFF

Remember
- [explicit] Jon prefers travel days that feel full but not rushed.
- [explicit] Jon and Wendy strongly value excellent dining when choosing travel lodging, especially when it reduces driving after dinner.
- [explicit] Wendy prefers white wines with some fruit and does not enjoy very austere styles.

Maybe
- [strong inference] Jon may increasingly prefer shorter tasting-menu experiences over very long Michelin tasting menus.

Temporary
- [current context] Jon and Wendy are currently traveling in the Dolomites.
```

---

## 4. Canonical ChatGPT instruction text

The following text is the canonical manual instruction Jon can place in ChatGPT personal instructions or reuse elsewhere.

```text
When Jon says **“Jon Brain Handoff”**, extract personal knowledge from the current conversation that may be useful to Jon’s broader personal knowledge system and other apps.

This is **not a conversation summary**. Be conservative. Include only information that is likely to matter beyond the immediate conversation.

Output exactly:

**JON BRAIN HANDOFF**

Then include only the applicable sections below:

**Remember**
- Durable facts, preferences, aversions, interests, relationships, expertise, constraints, or recurring tendencies that are explicit or exceptionally well-supported.
- Prefer things Jon explicitly stated, clarified, or corrected.
- Use one standalone idea per bullet.
- Prefix each bullet with `[explicit]` or, only when unusually well-supported, `[strong inference]`.
- State who the belief describes when relevant: Jon, Wendy, Jon and Wendy, another person, etc.
- Preserve important scope. Do not turn a trip-specific or situational choice into a general preference.

**Maybe**
- Strong but genuinely uncertain interpretations that could be useful if Jon confirms them.
- Prefix each with `[strong inference]`.
- Do not include weak behavioral guesses.

**Temporary**
- Current interests, plans, circumstances, or situational preferences that are useful now but should not become durable identity.
- Prefix each with `[current context]`.
- Include a date/window when it materially defines the context.

Rules:
- Do not infer durable preferences merely from clicks, reads, questions, purchases, saves, or one-off choices.
- Do not treat non-engagement as negative preference evidence.
- Do not invent confidence scores.
- Do not repeat incidental facts just because they appeared in the conversation.
- Do not include sensitive personal information unless Jon explicitly made it relevant and it is clearly useful to the intended personal knowledge system.
- Favor 3–10 excellent bullets over exhaustive extraction.
- Preserve tensions and context rather than flattening them. For example, “likes fruit in wine but wants something lighter tonight” should not become “likes rich wine.”
- If nothing in the conversation deserves durable or temporary personal knowledge, output `No Jon Brain additions from this conversation.`
- Output only the handoff, with no explanation before or after it.
```

This instruction should be treated as the source of truth for the manual handoff format until explicitly revised.

---

## 5. Cockpit's manual receiving experience

Cockpit should make explicit teaching extremely easy.

A likely `You` affordance is conceptually:

> **Teach Jon Brain**  
> Paste or type anything you want the app family to know.

For a pasted Jon Brain Handoff, Cockpit should parse the sections and preserve provenance that the source was a conversational handoff.

Conceptually:

```text
source: ChatGPT handoff
basis: explicit | strong inference | current context
importedAt: ...
```

The exact storage schema remains part of the broader Personal Knowledge design and is not fixed here.

### Suggested admission semantics

- `Remember` + `[explicit]` — normally eligible for direct admission with lightweight Undo/correction.
- `Remember` + `[strong inference]` — retain inferred provenance; exact review policy remains open.
- `Maybe` — should remain a proposed belief until Jon confirms or promotes it.
- `Temporary` — should enter temporary/current relevance context, not durable identity.

The manual import should not force Jon to edit ontology fields, scopes, or internal schema.

AI may translate the handoff into structured Personal Knowledge; Cockpit owns the deterministic canonical mutation.

---

## 6. Manual transport is temporary; the contract is not

The desired evolution is:

### Today

```text
ChatGPT conversation
       |
       | "Jon Brain Handoff"
       v
plain-text handoff
       |
       | copy / paste / share
       v
Cockpit
```

### Future

```text
ChatGPT conversation
       |
       | "Jon Brain Handoff"
       v
direct Cockpit / Personal Knowledge action
       |
       v
shared Personal Knowledge
```

Possible future transports include:

- ChatGPT app/plugin integration,
- MCP or agent tool invocation,
- mobile Share Sheet improvements,
- App Intent or equivalent system action,
- direct Personal Knowledge service/API,
- other future conversational assistants.

The product should not depend on any particular one of these mechanisms.

### Architectural principle

> The semantic payload is the product contract; copy/paste, Share Sheet, plugin, MCP, App Intent, or agent invocation are replaceable transports.

---

## 7. Mobile is a first-class requirement

Jon spends substantial time using ChatGPT and the app family on iPad and iPhone.

The long-term handoff design should therefore not assume:

- desktop-only workflows,
- exported archives,
- filesystem manipulation,
- command-line tooling,
- manually downloaded JSON,
- a Mac being awake.

The target interaction should become as close as possible to:

```text
Jon: "Jon Brain Handoff."

ChatGPT: [extracts candidate knowledge]

[Add to Jon Brain]
```

One deliberate action should be sufficient to transmit the semantic handoff when platform integration eventually permits it.

Manual text exists to bridge the present gap, not to define the final UX.

---

## 8. Do not bulk-mine conversation history by default

A future integration with richer ChatGPT history or memory access should not automatically turn all historical conversations into Personal Knowledge.

The same conservative doctrine applies even when transport becomes powerful.

Prefer:

- deliberate handoff from a conversation,
- explicit import of a memory/profile summary,
- narrowly reviewed candidate extraction,
- user-triggered retrospective analysis.

Avoid:

- silently ingesting every historical conversation,
- creating durable claims from incidental discussion,
- treating model-generated summaries as authoritative without provenance,
- converting chat history into a behavioral surveillance warehouse.

Better integration should reduce friction, not lower the evidence standard.

---

## 9. Relationship to shared Personal Knowledge

The Jon Brain Handoff is a producer-neutral contribution mechanism into the app family's emerging Personal Knowledge model.

ChatGPT is only one possible producer.

Other future producers might include:

- Cockpit's own explicit teaching UI,
- Galavant when a travel-specific learning earns cross-domain meaning,
- Yes Chef when a cooking preference earns cross-domain meaning,
- another conversational assistant,
- a future family application.

Cockpit remains the primary Jon-facing stewardship surface for inspection, correction, and understanding.

The underlying durable knowledge should remain capable of becoming app-family shared infrastructure, as documented in `PERSONAL-KNOWLEDGE-BOUNDARY.md`.

A future `PersonalKnowledgeKit` may eventually own common ingestion/provenance/projection mechanics once a second real app participates. This document does not require that package now.

---

## 10. Settled decisions

1. `Jon Brain Handoff` is a semantic Personal Knowledge extraction command, not a conversation summary.
2. Manual text is the V1 transport.
3. The canonical text format uses `Remember`, `Maybe`, and `Temporary` sections.
4. The extraction standard is conservative; explicit semantic evidence outranks passive behavioral inference.
5. Cockpit should provide an easy `Teach Jon Brain`-style entry point.
6. The system is designed for eventual direct conversational integration rather than optimized around copy/paste limitations.
7. Mobile is a first-class target for the future direct handoff.
8. Better integration must reduce friction without lowering Personal Knowledge evidence standards.
9. The semantic contract should survive future plugin/MCP/agent/App Intent transport changes.
10. Do not build a bespoke ChatGPT-only canonical knowledge model; ChatGPT contributes into the broader shared Personal Knowledge system.

---

## 11. Open questions

These remain intentionally unresolved:

1. Exact Cockpit import UI and whether manual paste should auto-detect the handoff format.
2. Whether `[strong inference]` under `Remember` should require explicit confirmation in V1.
3. How `Temporary` context is stored and naturally expires.
4. Whether handoffs should carry source conversation metadata when a future direct integration can provide it.
5. How corrections propagate back to a conversational source, if ever.
6. Exact structured API/tool payload when direct integration becomes possible.
7. Whether a future ChatGPT action writes directly into shared Personal Knowledge infrastructure or through a Cockpit-owned service endpoint.
8. When the second app-family participant is sufficient to extract ingestion/provenance mechanics into `PersonalKnowledgeKit`.

These should be decided from working Cockpit ingestion plus the actual integration capabilities available at implementation time rather than predicted from today's ChatGPT transport limitations.
