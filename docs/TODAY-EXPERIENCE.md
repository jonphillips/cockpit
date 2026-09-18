# Cockpit Today Experience

**Status:** Normative V1 product direction  
**Date:** 2026-09-08

Today is Cockpit's orientation and attention surface.

It answers:

> **What happened, what deserves my attention, and what especially should register?**

Today is not a task dashboard and not a second email inbox.

Today's substance depends on Gmail, which lands in Phase 3. Until then Today should carry the day's Edition summary and Essential backlog status rather than sit empty — the shell is being lived in from Phase 1 and a dead primary destination teaches the wrong thing about the app.

---

## 1. Morning orientation

Today is primarily a deliberate morning review.

Its job is to establish situational awareness, reduce noisy incoming material to a trustworthy understanding, and make consequential/personal things hard to miss.

The product bias is:

> **Morning review by default; sparse interruption by exception.**

Today may show a small number of meaningful intraday updates when timing truly matters, but it should not become a replacement notification stream.

---

## 2. Today versus Edition

Today:

> What happened / what deserves attention?

Edition:

> What is worth spending time reading/watching/exploring?

The same upstream Artifact may contribute to either or both, but intent determines product surface.

An email-delivered newsletter may be processed into a Stream/ContentPiece and live primarily in Edition. A personal message may remain a Today/Gmail attention concern without becoming Edition material.

---

## 3. Gmail Inbox remains the upstream attention queue

Cockpit reasons over the **current Gmail Inbox**, not only mail that arrived since the last review.

Anything remaining in Inbox may still deserve attention. Cockpit does not manufacture parallel task state merely because a message may require action.

Read/unread is provider presentation state, not Cockpit's canonical attention state.

A read message can still deserve attention. A batch can be understood without opening every underlying message.

---

## 4. Attention is broader than actionability

Cockpit should optimize for **deserves attention**, not merely **requires action**.

Examples:

- personal note: important, perhaps no action;
- flight change: consequential and actionable;
- routine Amazon shipping update: operational, probably disposable;
- valuable newsletter: intellectually worthwhile but better handled as Stream/Edition material.

When uncertain about personal/consequential email disposition, fail conservatively by leaving the source in Inbox.

---

## 5. V1 Today structure

Today may include a small set of product roles rather than a giant taxonomy.

### Worth Seeing

The few incoming things Cockpit thinks especially deserve to register.

### Personal / Consequential

Messages where relationship, consequence, timing, or obligation makes quiet handling inappropriate.

### Quiet handling / processed awareness

Compact transparency about lower-value incoming material Cockpit understood without demanding equal visual weight.

V1 should avoid turning these roles into dozens of permanent categories.

> **Drift note (2026-09-18).** The role names above ("Worth Seeing" / "Personal-Consequential" /
> "Quiet handling") predate `DECISIONS.md` §24, which replaced the relevance taxonomy with the
> type/relationship **treatment hierarchy** (personal / newsletter / offer / grab-bag, + the
> transactional rung added in M5 S3). M4 S7 built that hierarchy; this section was not reconciled at
> M4 S9. The §24 reflection into this section is **M5 S3's** job (it carries the §24 amendment), not
> S1's. §5.1 below describes how that hierarchy is *composed* into a surface; read the two together
> until S3 rewrites §5's role names.

---

## 5.1 Orientation-surface composition (M5 S1 design note)

**Status:** M5 S1 design note, 2026-09-18. Settles the *composition* S4 builds; final visual styling
stays Jon's device pass (`AGENTS.md`). The approved first-pass mockup is
[`docs/mockups/today-orientation-surface.html`](mockups/today-orientation-surface.html).

The failure §24 indicts is the **flat inbox** — every message the same visual weight, sorted by
accident of arrival. Today's answer is a composed **morning brief**, not a scrolling list. Product
Law 1 ("Today is orientation/attention") is honoured only if the surface first tells Jon *how the
morning is shaped* — how much sits where, what is new and enticing, what is personal — before he
opens anything.

### The composition has five jobs

1. **Count.** Every treatment tier carries a live count in its header, so the shape of the morning
   reads at a glance (e.g. "2 personal, 5 newsletters, 2 offers, a grab-bag, 6 transactional; the
   Tail screened 12 of 148"). Counts are orientation, not a badge to clear.
2. **Promote.** A band above the tiers surfaces the few **enticing new arrivals** — a new issue from
   a followed writer (Yglesias, Noahpinion), the Feed Me grab-bag, a surfaced offer report. Promotion
   is deterministic from *newness + treatment*, never a per-item relevance score (it stays on §24's
   organize side): it answers "what just landed that you'll actually want," not "what did a model
   rank."
3. **Highlight.** Personal mail is rendered elevated — a larger card, a warm edge, sender + preview —
   because it *is* personal (relationship), not because it scored high. This is the top of the
   hierarchy.
4. **Enter.** Each tier offers a per-category entry point ("Open all", "See all N") so a tier is a
   door, not just a pile. The brief is scannable; the depth is one tap away.
5. **Rank across types, never within.** The tier order is a fixed, deterministic cross-type hierarchy;
   **within** a tier, order is arrival-based (newest-first on the email's own date, per M4 S7's
   device pass) — choosing between two newsletters is a *mood, not a priority* (§24).

### Tier order (deterministic, top to bottom)

1. **Fresh this morning** — the promote band (enticing new arrivals).
2. **Personal** — highlighted.
3. **Newsletters** — listed (title + writer).
4. **Offers** — summarized, each becoming a Pending Find. **Rolls up at volume:** N offers of a kind
   (five wine offers) collapse into one compact aggregate with drill-in, never one large capsule each
   (Jon, 2026-09-18). Deeper grouping — rolling grouped offers into a single grouped Find — is a later
   Finds concern (Phase 6), not the surface.
5. **Grab-bag** — extracted (the flagged digest decomposed into its worthwhile items, inside the
   piece).
6. **Transactional** — the low rung (M5 S3's fifth treatment): reference, not attention; present and
   countable, never suppressed, never elevated. **Ephemeral sub-case:** login/verification codes are
   actioned-immediately and stale by the morning — S3 classifies them distinctly and S8's explicit
   disposition policy is where auto-Trash lands (never a silent classification-driven delete).
7. **From the Tail** — the uncurated-screening section (the demoted Edition): aggregator streams Jon
   has *not* curated, ruthlessly screened. Because that composition is minutes long (§23), the tail
   entry shows **honest recompose progress** and always resolves to a definite state — never a bare
   indefinite spinner (M5 S5).

### What this note does not settle

Final typography, spacing, colour, and exact card geometry — those are Jon's device pass, and the
mockup pins *arrangement*, not pixels. No new persistence or judgment call: the surface composes tags
and summaries S5(M4)/S7/S8 + S3 already produce (M5 S4 is view-layer only). The §24 organize/select
line is not reopened — nothing here selects, declines, or suppresses curated mail.

---

## 6. Clear

For a Gmail-derived Today concern, `Clear` means:

> Cockpit no longer needs to hold this in attention, and the upstream source disposition may now be applied according to explicit policy.

Provider disposition is independently:

- Leave in Inbox;
- Archive;
- Trash.

Edition's equivalent action is called `Dismiss`. Different words for different operations, so no shared command and no ambiguity.

Examples:

- Yglesias source email → Archive after safe processing;
- Amazon shipping notice under explicit policy → Trash;
- consequential personal/business mail → often Leave until explicitly resolved.

---

## 7. Safe mutation barrier

Today must never mutate Gmail before Cockpit has safely committed anything it promises to retain.

Conceptually:

```text
read/analyze Artifact
→ create/persist promised ContentPiece / Find / derived result
→ verify commit succeeded
→ apply authorized Leave/Archive/Trash disposition
```

If processing fails, source mail remains recoverable.

---

## 8. Recent dispositions

Once Cockpit can Archive/Trash, the user needs a modest bounded safety surface.

Recent dispositions should make it possible to understand:

- what was cleared;
- when;
- whether it was Archived or Trashed;
- which explicit policy applied;
- whether Undo is still available.

This is not a permanent audit-log product.

---

## 9. Threads re-enter naturally

If a previously handled conversation receives a new reply and Gmail returns it to Inbox, Cockpit evaluates it again.

Clear is not a permanent Cockpit thread-resolution flag.

Prior understanding may assist interpretation, but upstream Inbox membership remains authoritative for current email attention.

---

## 10. Personal relationship model

Personal should be a curated relationship concept rather than “everyone in Contacts.”

Contacts may provide onboarding evidence/suggestions. Durable Personal status should remain explicit/understandable.

Cockpit should be particularly conservative around personal mail and should not infer autonomous clearing authority from apparent lack of reply.

Do not overbuild a universal Person graph in V1 solely for email classification.

---

## 11. Current Context

Today may use Current Context from other Jon Universe apps when it materially improves relevance.

Example: an active Galavant trip may make a travel disruption or nearby cultural event unusually important.

This context is temporary and separate from Personal Knowledge.

---

## 12. V1 limits

Today V1 does not require:

- replacing Gmail navigation;
- generalized reply/composition;
- a task system;
- a giant business/transaction ontology;
- automatic unsubscribe;
- silent learned source deletion;
- permanent Delete Forever;
- constant notification behavior.

The V1 proof is that a morning review makes the incoming world feel calmer and more intelligible while preserving trust around consequential material.
