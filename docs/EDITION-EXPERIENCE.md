# Cockpit Edition Experience

**Status:** Normative V1 product direction  
**Date:** 2026-09-08

Edition is Cockpit's finite rolling personalized newspaper.

It answers:

> **I have some time. What is worth reading, watching, exploring, or considering?**

Edition is the user-facing destination name. `Content` remains a broader subsystem/domain word, not a competing navigation label.

Edition is a materialized entity composed once per day, not a live query. Shape and state machine: `docs/IMPLEMENTATION-CONTRACT.md` §3. How an Edition gets composed: `docs/JUDGMENT-CONTRACT.md`.

---

## 1. Edition is not an infinite feed

Cockpit should not reward endless scrolling or create an accumulating unread backlog.

A morning edition conceptually combines:

```text
new worthwhile ContentPieces
+
still-relevant carryovers
+
Essential material not explicitly resolved
```

The daily boundary refreshes the editorial package; it does not imply every ContentPiece has a one-day lifespan.

Different material deserves different persistence according to meaning, cadence, and Stream Handling.

---

## 2. Morning stability

Edition should feel psychologically stable rather than continuously replenish like social media.

The default bias is:

> **Morning edition by default; sparse intraday admission by exception.**

Important, Essential, or time-sensitive material may arrive during the day when justified. V1 should not optimize for constant freshness at the expense of finiteness.

---

## 3. ContentPiece state in Edition

Opening a ContentPiece means **Seen**, not resolved.

Seen should make content quieter without implying the user has dealt with it.

**`Dismiss`** means the ContentPiece no longer needs to remain in the active Edition attention set. Edition uses `Dismiss`; Today's Gmail attention action uses `Clear`. They were previously both called Clear, which forced four documents to warn that the two must be implementation-distinct. Different words, different operations, no warning needed.

`Save for Later` records explicit deferred attention and resolves the immediate Edition relationship.

`Add to Library` records durable retained reference and is independent of Later/Edition state. It never changes Edition entry state.

The states and legal transitions are settled in `docs/IMPLEMENTATION-CONTRACT.md` §3. The durations — carryover budget, backlog threshold, target size — are tuned from use.

---

## 4. Essential Streams

Essential is a Stream-level posture.

Its core product promise is:

> **Substantive primary material from an Essential Stream cannot silently age out of Edition.**

Matthew Yglesias is the canonical example: if Jon wants to be a completist, Cockpit may visually quiet a Seen post but may not quietly forget it merely because several editions passed.

For mixed Streams, Essential protects substantive primary publication material rather than making every incidental extracted Find immortal. What counts as substantive primary material is defined in `docs/IMPLEMENTATION-CONTRACT.md` §1 and returned by the judgment pass with a correctable reason.

### The relief valve

Essential as stated collides with Product Law 3. A Stream that publishes faster than Jon reads produces an unresolved set that grows without bound — inside the surface that is supposed to feel finite and calm. Left alone, Edition acquires the permanent guilt column that Later was carefully designed to avoid.

So: an unresolved Essential entry carried more than 14 times moves to a distinct **Essential backlog** group. It is reachable and visible, it still requires explicit disposition, and it is not part of the daily package or the size target.

Nothing silently ages away, and the daily Edition stays finite. Both halves of the promise survive. The threshold is a starting number and is tuned from use.

---

## 5. Sections and ranking

Edition may use sections such as Essentials, For You, or Interest Area lanes when they help comprehension.

V1 should avoid treating a section taxonomy as core ontology. The important behavior is that Cockpit produces a finite comprehensible editorial package, not that every ContentPiece occupies a permanent category.

Ranking/judgment may consider:

- explicit Stream Handling;
- Essential posture;
- Interest Area guidance;
- relevant Personal Knowledge;
- Current Context;
- recency/timing;
- ContentPiece meaning;
- cadence/persistence defaults.

Explicit narrower user intent should constrain broader inferred relevance.

---

## 6. Reader actions

A V1 Reader should make the important product actions obvious without turning into a toolbar of system internals.

Core actions:

- Seen happens naturally through reading/opening;
- Dismiss;
- Save for Later;
- Add to Library;
- Offline until [date];
- Keep Offline;
- explicit teaching such as “why this matters” / Tell Cockpit;
- contextual Stream Handling access;
- Find/handoff actions when a meaningful Find exists;
- Open Original when useful/possible.

Provider/transport plumbing should remain secondary.

---

## 7. Provenance and explanation

Cockpit should preserve meaningful source context and be able to explain why a ContentPiece was surfaced when that explanation is useful.

This is why `EditionEntry.rationale` exists: an explanation cannot be reconstructed from state flags after the fact, so the reason is written at composition time and stored. It is addressed to Jon, states product logic rather than model internals, and is correctable from the same interaction.

Examples:

- from the Matthew Yglesias Stream, marked Essential;
- surfaced because it strongly matches an explicitly taught Burgundy Interest;
- arrived through Gmail but belongs in Edition as an email-delivered Stream.

Explanations should reveal relevant product logic, not expose model-scoring internals.

---

## 8. Edition versus Today

Today answers:

> What happened and what deserves attention?

Edition answers:

> What is worth spending time with?

The same upstream Artifact may influence both, but product intent determines the surface.

An email-delivered newsletter may be archived upstream after processing and live naturally in Edition. A consequential personal email may remain in Today/Gmail attention without becoming Edition content.

---

## 9. Edition versus Library

Edition admission is selective/temporal. Library admission is durable/reference-oriented.

They are independent.

A Stream may eventually be configured to:

- feed Edition selectively;
- add all qualifying future ContentPieces to Library prospectively.

Automatic Library admission does not imply automatic historical backfill.

---

## 10. V1 must prove

- finite Edition feels materially calmer than an infinite feed;
- several real Streams can contribute useful material;
- Essential prevents silent loss without making Edition oppressive;
- Seen and Dismiss feel meaningfully distinct;
- Later and Library actions map cleanly to the same ContentPiece;
- Personal Knowledge can change relevance/explanation;
- Reader/provenance feels trustworthy.

---

## 11. Build-and-learn questions

Do not decide abstractly:

- exact Seen visual treatment;
- exact carryover budget and Essential backlog threshold — the numbers, not the states;
- exact edition size, starting from 20;
- section ordering;
- card density/hero treatment;
- midday admission volume;
- dedicated Essential cleanup/review UI;
- final Reader geometry at different iPad/iPhone widths.

Use daily behavior after the RSS and email-delivered Stream slices to answer these.
