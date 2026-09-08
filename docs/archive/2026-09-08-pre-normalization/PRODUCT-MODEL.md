# Cockpit Product Model

**Status:** Working product model / decisions plus open questions  
**Date:** 2026-09-08

## Purpose

This document captures the product model emerging from Cockpit design discussions before implementation hardens it accidentally.

It is deliberately separate from `ARCHITECTURE.md`:

- `ARCHITECTURE.md` defines how Cockpit software is built.
- this document defines what Cockpit is trying to understand and what responsibilities it assumes for the user.

Names here are conceptual. They do not imply one database table, Swift type, screen, tab, or navigation destination per concept.

More specific current models live in:

- `docs/EMAIL-INTELLIGENCE-MODEL.md` — email/newsletter processing, Handling, Collapse/Extract/Brief/Screen/Mine/Match, progressive-cost enrichment, Finds, viewing chrome, and source actions.
- `docs/TODAY-EXPERIENCE.md` — morning orientation and attention.
- `docs/CONTENT-EXPERIENCE.md` — the rolling Content newspaper.
- `docs/CONTENT-STREAM-MODEL.md` — Interest Areas, Streams, Publishers/Creators, Transport, cadence, Handling, persistence, custody, and management.

### Terminology note

For recurring Content, the current noun is **Stream**.

Examples: `NYT Travel`, `Paris by Mouth`, `Matthew Yglesias`, a specific YouTube channel.

`Source` remains correct for upstream provider material, provenance/evidence, original source content, source disposition, and source actions.

This distinction matters because a Stream may arrive through email, RSS, YouTube, or another Transport, while the underlying provider Artifact still has independent custody/action semantics.

---

## 1. Product promise

Cockpit has an ordinary daily job before it has an ambitious discovery job:

> **Tell me what came into my world, what matters, and what I can safely ignore.**

Cockpit should provide an organized sense of incoming information such as email and followed Content Streams without turning life into work management.

The cultural-discovery system is a dividend of doing that job well, not a replacement for it.

### Product principle

> **Daily/Today is the floor; discovery is the dividend.**

A successful Tuesday morning may contain no remarkable discovery at all. Cockpit should still be valuable because it reduced a noisy incoming world to a trustworthy understanding of what deserves attention.

---

## 2. Cockpit is not an email client

Email is an important initial provider/channel, not Cockpit's product boundary.

Cockpit may:

- ingest mail from a provider,
- classify and summarize it,
- extract durable knowledge,
- preserve source content when warranted,
- prominently surface personal and otherwise important messages,
- propose source actions such as archive or mark-read,
- execute narrowly scoped approved source actions,
- support a constrained response workflow when that can be done without recreating a general mail client.

Cockpit should not recreate general mailbox navigation, arbitrary composition, folder management, spam management, a sent-mail browser, or a complete threading UI merely to claim email support.

The likely integration boundary is the mail service/provider rather than Apple Mail as a client. Apple does not provide a documented iOS API on which Cockpit can safely base exact-message deep-linking into Mail. Therefore `Open Original in Apple Mail` must not be required for Cockpit correctness.

### Product principle

> **Cockpit triages and highlights. Mail remains the action queue.**

The Gmail Inbox should remain the durable queue of messages that may still require the user's attention. Cockpit's job is to reduce noise, surface what matters, and make important personal/business messages hard to miss before the user enters Mail.

Cockpit should not manufacture parallel task state merely because an email may require action.

---

## 3. Today and Content are distinct modes

The current product now has a strong separation:

### Today

> **What happened, what needs my attention, and what especially deserves to register?**

Today owns orientation, personal/consequential attention, top discoveries, compact derived market/event/domain teasers, and inspectable quiet handling.

### Content

> **I have some time. What is worth reading, watching, exploring, or considering?**

Content is the rolling newspaper assembled from followed Streams across email publications, RSS/Atom, YouTube channels, and other bounded Transports.

### Product principle

> **Transport determines ingestion and source actions. Intent determines the product surface.**

A newsletter delivered through Gmail can be archived upstream after successful custody and still live naturally in Content.

A wine retailer message may disappear as email but contribute to a derived Wine Market view.

---

## 4. Daily email outcome

Cockpit's email end-state is not Inbox Zero.

The desired invariant is:

> **After Cockpit triage, anything remaining in Gmail Inbox is deliberately there because it may require Jon's attention, and Cockpit has highlighted the subset he especially should not miss.**

Cockpit is both subtractive and additive:

- **subtractive:** remove or recommend clearing messages that no longer deserve attention in Mail,
- **additive:** prominently surface personal, consequential, or otherwise high-value messages so they register mentally before the user returns to Mail.

The user may read or inspect such messages in Cockpit, but unresolved email remains represented by the upstream Inbox rather than by a Cockpit task system.

Cockpit should reason over the **current Inbox**, not merely messages that arrived since the last Today review. An older message that still remains in Inbox remains part of the current attention state.

### Important distinction

Importance and actionability are not the same thing.

A personal message can deserve prominent attention even if it requires no action. A transactional message may require action while being emotionally unimportant. Cockpit should optimize for **deserves attention**, not merely **requires action**.

### Conservative failure rule

When Cockpit is uncertain whether an email can safely leave the Inbox, the conservative default is to leave it there.

False negatives in clearing are more damaging than false positives in keeping.

---

## 5. Email experiences are class-specific

Cockpit should not force every incoming email through an identical one-message-at-a-time workflow.

Different classes of incoming mail can support different views and source-disposition policies.

The classes below remain useful as coarse attention/disposition groupings, but they are not a sufficient processing taxonomy. Content publications should additionally be understood as **Streams** with Stream Handling; see `docs/EMAIL-INTELLIGENCE-MODEL.md` and `docs/CONTENT-STREAM-MODEL.md`.

### Personal

Personal messages should be identified and surfaced prominently.

`Personal` should be a curated relationship set rather than a synonym for Contacts. Contacts are useful evidence and onboarding input, but inclusion in Contacts should not automatically confer Personal status.

The initial model should support explicit additions such as `Add to Personal`, with Contacts helping suggest likely candidates. Over time Cockpit may propose additional people based on repeated evidence, but the user remains in control of the curated set.

A Person may have multiple email addresses. The durable concept is the Person, not the address string.

Personal email should be handled conservatively. Cockpit may summarize and highlight it, but should not casually clear it merely because a model believes no reply is needed.

### Market / retail reports

Promotional and market email is often more valuable as a batch report than as dozens of individual messages.

Examples include:

- wine-market offers,
- clothing offers,
- home-goods offers.

Cockpit may synthesize these into a report that highlights unusually relevant offers and preserves links back to underlying source material.

The user should be able to clear the underlying batch after reviewing the report.

Archive is the default Gmail disposition for `Clear`. Marketplace/report behavior may expose a persistent `Trash cleared messages` policy for categories whose source mail is deliberately disposable. This setting belongs with the marketplace/report behavior rather than as friction on every individual clear action.

### Email-delivered Content Streams

Newsletters/publications should behave more like reading subscriptions than ordinary Inbox traffic.

A managed publication becomes a **Stream** with a primary Interest Area and Stream Handling such as:

- Essential / always surface substantive issues,
- brief the primary essay,
- mine mixed issues for relevant Finds,
- screen a link digest,
- preserve original content or a faithful representation,
- give feature material appropriate edition hang time.

Separately, its email Transport has upstream/source-disposition behavior such as:

- archive after successful custody/processing,
- leave in Inbox when uncertainty/consequence requires it,
- Trash only under explicit disposable policy.

Cockpit should become the primary reading context for email publications it manages. Once an issue has been successfully ingested according to custody policy, the user should expect to find and reread it in Cockpit rather than hunt through Gmail Archive.

Newsletter processing is not necessarily issue-level. A mixed Stream can contain a low-relevance main story plus one highly relevant restaurant, article, event, recipe, or cultural reference. Cockpit should be able to surface extracted Finds independently while preserving provenance and a path to the original Artifact.

### Business / transactional

Receipts, airline notices, bills, statements, reservations, deliveries, and similar messages can initially be grouped into a transactional triage experience.

They are evidence of real-world transactions or obligations, but their eventual semantics differ.

Cockpit should make them easy to scan and selectively clear. Understanding a transactional message does **not** imply that it can safely leave Inbox: Cockpit may summarize an airline change, bill, or statement while deliberately leaving the source message in Mail's action queue.

Over time, transactional providers/categories should acquire explicit **Handling Policies** describing both the Cockpit experience and desired source disposition.

Examples:

- Amazon shipping notices -> summarize, then clear,
- Amex statements -> show amount/date, leave in Inbox,
- airline itinerary changes -> explain what changed, leave until explicitly cleared,
- restaurant confirmations -> extract reservation context, then clear.

These policies should emerge from explicit preferences and repeated real behavior rather than from one giant `Business` ontology.

---

## 6. Clearing email

`Clear` is a Cockpit decision that the provider message no longer needs to remain in Gmail Inbox for attention purposes.

It is not a task-completion concept.

Archive is the default upstream action for `Clear`. Trash is an explicit learned/configured policy for deliberately disposable categories such as marketplace/promotional mail; it should not normally require a per-message choice.

Clearing has two independent consequences.

### Source disposition

What happens to the upstream Gmail message?

Examples:

- leave in Inbox,
- archive in Gmail,
- move to Trash when an explicit provider/category policy says the content is disposable.

The exact policy may be individual, provider-specific, Stream/Transport-specific, or category-specific.

### Cockpit disposition / custody

What happens to Cockpit's Artifact and derived knowledge?

Examples:

- forget source content,
- retain a summary,
- retain while context remains relevant,
- preserve the original,
- retain extracted Subjects/Signals while discarding ephemeral source bytes.

These dimensions must remain independent.

Examples:

- newsletter Stream: archive in Gmail + preserve/read in Cockpit,
- retail offer: archive by default, or Trash by configured marketplace policy + forget after report generation,
- receipt: archive in Gmail + retain extracted transaction metadata if useful,
- personal email: leave in Inbox + surface prominently in Cockpit.

### Read/unread is not disposition

Gmail read/unread state is not Cockpit's canonical attention state.

Reading a message in Cockpit may mark it read upstream, but `read` must not imply `cleared`. A personal message can be read and still deliberately remain in Inbox. Conversely, a marketplace batch can be understood and cleared without requiring the user to open every underlying message individually.

For email attention, Inbox membership is the meaningful durable state; read/unread is primarily presentation and provider-state plumbing.

### Threads re-enter naturally

Cockpit should not maintain a parallel thread-resolution system.

If a conversation is handled and archived in Mail, then a later reply that causes the conversation to re-enter Inbox naturally makes it part of Cockpit's current attention set again. Cockpit may retain prior understanding for context, but upstream Inbox remains authoritative for whether the email conversation is currently unresolved.

### Recent Clears

Cockpit should retain a modest recent history of clearing decisions so mistakes are understandable and recoverable without creating a permanent forensic ledger.

A `Recent Clears` experience should make it possible, for an appropriate bounded period, to see what Cockpit cleared, when, under which Handling policy, and to restore/reconsider source messages where the provider still permits it.

This becomes especially important as Trash policies and learned automation are introduced.

### Learned clearing policies

Cockpit may eventually propose narrow automation based on repeated explicit user behavior, for example:

> You have cleared every Apple Store receipt for six months. Automatically clear future Apple Store receipts?

Such automation should be:

- provider/category-specific,
- explicitly approved,
- understandable,
- reversible where possible,
- conservative around personal or consequential mail.

Do not jump directly from model classification to autonomous clearing.

---

## 7. Content edition semantics

Content is not an accumulating unread queue.

The edition boundary is early morning.

Each new edition combines:

```text
new worthwhile material
+
still-relevant carryovers
+
Essential material not explicitly resolved
```

Individual Items have different lifespans:

- daily news may age quickly,
- opinion/features can hang around several editions,
- weekly Food/Travel features deserve longer persistence,
- events persist according to event timing,
- Essential Stream material requires explicit disposition.

Opening means **Seen**, not Clear. Seen Items remain but become visually quieter.

`Keep` grants durable custody beyond ordinary edition aging.

### Product laws

> **The edition has a daily boundary; individual stories do not all have a one-day lifespan.**

> **Cockpit's backlog is not the user's backlog.**

---

## 8. Interest Areas and Streams

Recurring Content is managed primarily through **Interest Areas** rather than Publisher silos.

Examples:

```text
TRAVEL & PLACES
- NYT Travel
- Paris by Mouth
- Fathom
- selected YouTube channel
```

```text
FOOD & WINE
- NYT Food
- Kitchen Projects
- Feed Me
- Vinous
```

A Stream has one primary Interest Area for management/default editorial intent, but its individual Items may be routed elsewhere according to meaning.

Publisher/Creator and Transport remain important secondary dimensions.

### Product principle

> **Interest Areas describe why Cockpit consumes recurring content. Streams describe what recurring flow it follows. Publishers describe who produced it. Transports describe how it arrived.**

---

## 9. Morning cadence

Today is primarily a deliberate morning review, not a replacement notification stream.

The morning review should establish situational awareness, reduce the Inbox, and surface the handful of messages/developments the user especially should not miss.

The Content edition is also established in the early morning and should remain psychologically stable rather than continuously replenish like an infinite feed.

Cockpit may surface selected information during the day when it is clearly important, Essential, or time-sensitive, but intraday surfacing should be sparse.

### Product bias

> **Morning review by default; selective interruption by exception.**

---

## 10. Onboarding is not steady state

Cockpit's long-term semantics should not be distorted to accommodate historically messy provider state.

A first-time user may have years of accumulated Inbox mail that does not represent thousands of current obligations, and may have hundreds of stale YouTube subscriptions or newsletter senders that do not deserve admission as managed Streams.

Bootstrap/cleanup should therefore be an explicit onboarding concern.

For Content, V1 should favor deliberate Stream admission over pretending that importing every historical subscription equals understanding what the user actually wants Cockpit to curate.

---

## 11. Current product laws

1. **Cockpit tells the user what came into their world, what matters, and what can safely be ignored.**
2. **Today is orientation/attention; Content is reading/browsing/enrichment.**
3. **Cockpit is not an email client; Gmail Inbox remains the email attention queue.**
4. **Importance is not the same as actionability.**
5. **Uncertainty around consequential email fails conservatively by leaving more in Inbox.**
6. **Transport determines ingestion and source actions; intent determines product surface.**
7. **Source disposition and Cockpit custody are independent.**
8. **Stream is the recurring Content noun; source remains the upstream/provenance/action noun.**
9. **Interest Areas organize why Streams are followed.**
10. **The Content edition rolls forward; it does not create an accumulating unread backlog.**
11. **Essential Stream material cannot silently age away.**
12. **No productivity theater; Cockpit exists to make life richer and calmer, not to turn it into work.**