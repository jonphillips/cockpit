# Cockpit iPad-First Experience

**Status:** Normative device direction, intentionally not pixel-complete  
**Date:** 2026-09-08

Cockpit is iPad-first for rich reading, browsing, curation, teaching, and management. iPhone remains important but should not force the app into one identical composition across devices.

---

## 1. Shared product model

Both device families share the same conceptual destinations:

```text
Today
Edition
Later
Library
Settings
```

Following lives under Settings.

The product model is shared; navigation/composition may be device-appropriate.

---

## 2. iPad strengths

The iPad should be the best place for:

- deliberate morning Today review;
- Edition browsing and reading;
- richer Reader context/provenance;
- Later/Library browsing;
- Personal Knowledge inspection/teaching;
- Jon Brain bulk import/review;
- Following/Interest Area management;
- Pending Find review/handoff;
- side-by-side or contextual detail where SwiftUI naturally supports it.

The goal is a calm, information-rich lifestyle/cultural cockpit, not a desktop productivity console.

---

## 3. iPhone strengths

The iPhone should be useful for:

- awareness of Today;
- lightweight Edition reading;
- quick Save for Later / Add to Library;
- offline access while traveling;
- correcting/teaching Cockpit in context;
- simple Find/handoff actions;
- checking a Pending Find or Library ContentPiece in the moment.

V1 does not require visual/interaction parity with iPad.

---

## 4. Sidebar/navigation

On iPad, a sidebar is a natural home for the five primary destinations with Settings revealing Following, Interest Areas, Personal Knowledge / You, and integrations.

Do not add Following as a sixth peer merely because it has substantial management UI.

On iPhone, an appropriate compact navigation treatment may be chosen without changing product semantics.

---

## 5. Edition on iPad

Edition should exploit width for editorial clarity rather than dashboard density.

Potential use of columns, richer cards, contextual reader detail, or section navigation should be tested against the core product law: finite, calm, and worth spending time with.

Do not encode a permanent hero-card/section geometry before real ContentPieces reveal what density feels right.

---

## 6. Today on iPad

Today should feel like orientation, not operations.

The surface may show Worth Seeing, personal/consequential attention, and compact quiet-handling transparency without becoming a grid of KPIs, counts, or work queues.

Provider plumbing and detailed Gmail status should stay secondary unless something is abnormal.

---

## 7. Reader and contextual actions

Reader should make ContentPiece substance primary and keep product actions accessible:

- Clear;
- Save for Later;
- Add to Library;
- Offline until / Keep Offline;
- Tell/Teach Cockpit;
- Find/handoff where relevant;
- Stream Handling context;
- Open Original when useful.

Do not make the Reader a debug surface for transports, model scores, custody modes, or deduplication.

---

## 8. Offline is especially important on mobile devices

An explicit offline promise must be inspectable and trustworthy on the current device.

The user should never have to guess whether a ContentPiece that was explicitly downloaded for a flight is still physically local.

Temporary offline state should show its expiry. Keep Offline should remain until explicitly released.

---

## 9. iPhone polish is not an architecture gate

The initial vertical slices should prove the product and persistence model on the richest natural surface without blocking on perfect iPhone composition.

Once the loops are useful, refine iPhone around actual in-the-moment behavior rather than shrinking the iPad UI mechanically.

---

## 10. Build-and-learn questions

- final iPad sidebar/grouping details;
- whether Reader benefits from split-view context;
- Edition card density/section navigation;
- Today visual hierarchy;
- exact iPhone destination navigation;
- which management tasks should be absent/simplified on iPhone;
- bulk offline/travel preparation affordances.

These should be answered with real content and daily use.
