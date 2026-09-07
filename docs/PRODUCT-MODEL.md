# Cockpit Product Model

**Status:** Working product model / decisions plus open questions  
**Date:** 2026-09-06

## Purpose

This document captures the product model emerging from Cockpit design discussions before implementation hardens it accidentally.

It is deliberately separate from `ARCHITECTURE.md`:

- `ARCHITECTURE.md` defines how Cockpit software is built.
- this document defines what Cockpit is trying to understand and what responsibilities it assumes for the user.

Names here are conceptual. They do not imply one database table, Swift type, screen, tab, or navigation destination per concept.

The corpus-grounded refinement of email/newsletter processing lives in `docs/EMAIL-INTELLIGENCE-MODEL.md`. That document defines source-purpose Handling, message/section-level processing, the `Collapse / Extract / Brief / Screen / Mine / Match` primitives, progressive-cost enrichment, Finds, viewing chrome, the explicit learning loop, and initial source Handling drafts. Where the older class-level descriptions below are broad, the Email Intelligence Model should be treated as the more specific current design.

## 1. Product promise

Cockpit has an ordinary daily job before it has an ambitious discovery job:

> Tell me what came into my world, what matters, and what I can safely ignore.

Cockpit should provide an organized sense of incoming information such as email and newsletters without turning life into work management.

The cultural-discovery system is a dividend of doing that job well, not a replacement for it.

### Product principle

> Daily is the floor; discovery is the dividend.

A successful Tuesday morning may contain no remarkable discovery at all. Cockpit should still be valuable because it reduced a noisy stream to a trustworthy understanding of what deserves attention.

## 2. Cockpit is not an email client

Email is an important initial source, not Cockpit's product boundary.

Cockpit may eventually:

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

> Cockpit triages and highlights. Mail remains the action queue.

The Gmail Inbox should remain the durable queue of messages that may still require the user's attention. Cockpit's job is to reduce noise, surface what matters, and make important personal/business messages hard to miss before the user enters Mail.

Cockpit should not manufacture parallel task state merely because an email may require action.

## 3. Daily email outcome

Cockpit's email end-state is not Inbox Zero.

The desired invariant is:

> After Cockpit triage, anything remaining in Gmail Inbox is deliberately there because it may require Jon's attention, and Cockpit has highlighted the subset he especially should not miss.

Cockpit is both subtractive and additive:

- **subtractive:** remove or recommend clearing messages that no longer deserve attention in Mail,
- **additive:** prominently surface personal, consequential, or otherwise high-value messages so they register mentally before the user returns to Mail.

The user may read or inspect such messages in Cockpit, but unresolved email remains represented by the upstream Inbox rather than by a Cockpit task system.

Cockpit should reason over the **current Inbox**, not merely messages that arrived since the last Daily review. An older message that still remains in Inbox remains part of the current attention state and may still deserve prominent surfacing.

### Important distinction

Importance and actionability are not the same thing.

A personal message can deserve prominent attention even if it requires no action. A transactional message may require action while being emotionally unimportant. Cockpit should optimize for **deserves attention**, not merely **requires action**.

### Conservative failure rule

When Cockpit is uncertain whether an email can safely leave the Inbox, the conservative default is to leave it there.

False negatives in clearing are more damaging than false positives in keeping.

## 4. Daily email experiences are class-specific

Cockpit should not force every incoming email through an identical one-message-at-a-time workflow.

Different classes of incoming mail can support different views and retention/disposition policies.

The classes below remain useful as coarse attention/disposition groupings, but they are not a sufficient processing taxonomy. In particular, newsletters and promotional sources may be interpreted at message, section, or item level and may compose several processing operations under a source-specific Handling policy; see `docs/EMAIL-INTELLIGENCE-MODEL.md`.

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

Cockpit may synthesize these into a report that highlights unusually relevant offers and preserves links back to the underlying source material.

The user should be able to clear the entire batch after reviewing the report.

Archive is the default Gmail disposition for `Clear`. Marketplace/report widgets may expose a persistent `Trash cleared messages` policy for categories whose source mail is deliberately disposable. This setting belongs with the marketplace/report behavior rather than as friction on every individual clear action.

### Newsletters

Newsletters should behave more like reading subscriptions than like ordinary Inbox traffic.

Each newsletter/source may eventually have its own policy, potentially including:

- show every new issue,
- summarize only,
- preserve original content or summary only,
- Cockpit retention duration,
- Gmail disposition after Cockpit processing.

The user should be able to see recent newsletter issues in Cockpit, open/read one in place, and then clear the related Gmail messages without making the newsletters disappear from Cockpit's own reading/history model.

Cockpit should become the **primary reading history** for newsletters it manages. Once a newsletter issue has been successfully ingested according to its custody/retention policy, the user should expect to find and reread it in Cockpit rather than hunt through Gmail Archive.

This is a core example of Cockpit removing something from the action queue without removing it from the user's life.

Newsletter processing itself is not necessarily issue-level. A mixed source can contain a low-relevance main story plus one highly relevant restaurant, article, event, recipe, or cultural reference. Cockpit should therefore be able to surface extracted Finds independently of the parent issue while preserving source provenance and a path back to the original.

### Business / transactional

Receipts, airline notices, bills, statements, reservations, deliveries, and similar messages can initially be grouped into a transactional triage experience.

They share one key characteristic: they are evidence of real-world transactions or obligations, but their eventual semantics differ.

Cockpit should make them easy to scan and selectively clear. Understanding a transactional message does **not** imply that it can safely leave Inbox: Cockpit may summarize an airline change, bill, or statement while deliberately leaving the source message in Mail's action queue.

Over time, transactional sources/categories should acquire explicit **handling policies** describing both the Cockpit experience and the desired source disposition. A policy is richer than `Archive` versus `Keep`.

Examples:

- Amazon shipping notices -> summarize, then clear,
- Amex statements -> show amount/date, leave in Inbox,
- airline itinerary changes -> explain what changed, leave until explicitly cleared,
- restaurant confirmations -> extract reservation context, then clear.

These policies should emerge from explicit user preferences and repeated real behavior rather than from one giant `Business` ontology.

## 5. Clearing email

`Clear` is a Cockpit decision that the message no longer needs to remain in the Gmail Inbox for attention purposes.

It is not a task-completion concept.

Archive is the default upstream action for `Clear`. Trash is an explicit learned or configured policy for deliberately disposable categories such as marketplace/promotional mail; it should not normally require a per-message choice.

Clearing has two independent consequences:

### Source disposition

What happens to the upstream Gmail message?

Examples:

- leave in Inbox,
- archive in Gmail,
- move to Trash when an explicit source/category policy says the content is disposable.

The exact policy may be individual, source-specific, or category-specific.

### Cockpit disposition

What happens to Cockpit's own Artifact and derived knowledge?

Examples:

- forget source content,
- retain a summary,
- retain while context remains relevant,
- preserve the original,
- retain extracted Subjects/Signals while discarding ephemeral source bytes.

These dimensions must remain independent.

Examples:

- newsletter: archive in Gmail + preserve/read in Cockpit,
- retail offer: archive by default, or Trash by configured marketplace policy + forget in Cockpit after report generation,
- receipt: archive in Gmail + retain extracted transaction metadata if useful,
- personal email: leave in Inbox + surface prominently in Cockpit.

### Read/unread is not disposition

Gmail read/unread state is not Cockpit's canonical attention state.

Reading a message in Cockpit may mark it read upstream, but `read` must not imply `cleared`. A personal message can be read and still deliberately remain in Inbox. Conversely, a marketplace batch can be understood and cleared without requiring the user to open every underlying message individually.

For email attention, Inbox membership is the meaningful durable state; read/unread is primarily presentation and source-state plumbing.

### Threads re-enter naturally

Cockpit should not maintain a parallel thread-resolution system.

If a conversation is handled and archived in Mail, then a later reply that causes the conversation to re-enter Inbox naturally makes it part of Cockpit's current attention set again. Cockpit may retain prior understanding for context, but the upstream Inbox remains authoritative for whether the email conversation is currently unresolved.

### Recent Clears

Cockpit should retain a modest recent history of clearing decisions so mistakes are understandable and recoverable without creating a permanent forensic ledger.

A `Recent Clears` experience should make it possible, for an appropriate bounded period, to see what Cockpit cleared, when, under which handling policy, and to restore/reconsider source messages where the provider still permits it.

This becomes especially important as Trash policies and learned automation are introduced.

### Learned clearing policies

Cockpit may eventually propose narrow automation based on repeated explicit user behavior, for example:

> You have cleared every Apple Store receipt for six months. Automatically clear future Apple Store receipts?

Such automation should be:

- source/category-specific,
- explicitly approved,
- understandable,
- reversible where possible,
- conservative around personal or consequential mail.

Do not jump directly from model classification to autonomous clearing.

## 6. Daily cadence

Daily is primarily a deliberate morning review, not a replacement notification stream.

The morning review should establish situational awareness, reduce the Inbox, and surface the handful of messages or developments the user especially should not miss.

Cockpit may also surface selected information during the day when it is clearly important or time-sensitive, but intraday surfacing should be intentionally sparse. The product should not recreate notification overload under a new brand.

The current product bias is therefore:

> Morning review by default; selective interruption by exception.

## 7. Onboarding is not steady state

Cockpit's long-term Daily semantics should not be distorted to accommodate a historically messy Inbox.

The steady-state model is that current Inbox membership represents the current email action/attention queue. A first-time user may instead have years of accumulated Inbox messages that do not carry that meaning.

Cockpit should therefore treat initial Inbox cleanup/bootstrap as an explicit onboarding concern rather than interpreting a large historical Inbox as thousands of current obligations.
