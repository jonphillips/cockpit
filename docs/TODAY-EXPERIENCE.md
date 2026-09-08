# Cockpit Today Experience

**Status:** Normative V1 product direction  
**Date:** 2026-09-08

Today is Cockpit's orientation and attention surface.

It answers:

> **What happened, what deserves my attention, and what especially should register?**

Today is not a task dashboard and not a second email inbox.

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

---

## 6. Clear

For a Gmail-derived Today concern, `Clear` means:

> Cockpit no longer needs to hold this in attention, and the upstream source disposition may now be applied according to explicit policy.

Provider disposition is independently:

- Leave in Inbox;
- Archive;
- Trash.

`Clear` in Edition is a different operation and must be implementation-distinct.

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
