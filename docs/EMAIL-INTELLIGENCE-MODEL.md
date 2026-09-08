# Cockpit Email Intelligence Model

**Status:** Normative V1 product/domain direction  
**Date:** 2026-09-08

Email is an important initial source/provider, not Cockpit's product boundary.

Cockpit should understand incoming Gmail well enough to reduce noise, surface consequential material, feed recurring editorial Streams, extract useful Finds, and apply narrowly authorized source dispositions without becoming a general email client.

---

## 1. Product boundary

Cockpit may:

- inspect the current Gmail Inbox;
- classify and summarize messages;
- identify personal/consequential material;
- recognize email-delivered recurring content;
- create ContentPieces from email-delivered publications;
- extract Finds;
- retain lightweight understanding/provenance;
- apply Leave / Archive / Trash according to explicit policy;
- expose bounded recent dispositions and Undo where possible.

Cockpit does not need V1 support for:

- arbitrary mailbox/folder navigation;
- generalized compose/reply;
- sent-mail browsing;
- generic threading UI;
- permanent Delete Forever;
- automatic unsubscribe;
- a universal Gmail rules engine.

---

## 2. Current Inbox is the attention set

Cockpit should reason over the current Inbox, not only newly arrived mail.

Inbox membership is the durable provider signal that a message/conversation still participates in Gmail attention.

Read/unread is not Cockpit's canonical attention state.

Cockpit attention and Gmail provider state remain separate models.

---

## 3. Three provider dispositions

After Cockpit has done its promised processing, the source email may be:

- **Leave in Inbox**
- **Archive**
- **Trash**

These are provider/source actions, not Stream Handling values and not Cockpit retention modes.

### Archive

Appropriate when the source remains valuable/reacquirable, especially recurring editorial material such as Yglesias or other newsletters.

### Trash

Appropriate for explicitly disposable operational/promotional material where long-term Gmail retention creates no value, such as routine Amazon shipping notices or low-value retail offers under an established policy.

V1 should use Gmail Trash rather than a permanent hard-delete operation.

### Leave

Conservative default when consequence/uncertainty means the source should remain in Inbox.

---

## 4. Explicit authority, not learned autonomy

Automatic Archive or Trash is allowed when backed by an **explicit user-established policy**.

AI may classify an incoming message to determine whether an authorized policy matches. It may later propose a policy based on observed repeated behavior, but that proposal must be explicitly accepted before Cockpit gains mutation authority.

Passive behavior does not silently create source-action policy.

For V1, keep policy mechanisms narrow:

- Stream-specific email disposition;
- a very small number of explicit non-Stream provider/category policies when useful.

Do not build a generalized rules language, visual rule builder, precedence engine, or learned policy system before real usage demands it.

---

## 5. Processing/disposition barrier

Cockpit must not Archive/Trash the upstream Artifact before any promised durable result has been successfully committed.

Conceptually:

```text
Gmail Artifact
→ inspect / classify / extract
→ persist any ContentPiece / Find / retained understanding
→ verify successful commit
→ apply authorized provider disposition
```

Examples:

### Yglesias newsletter

```text
Gmail message
→ ContentPiece
→ Edition / Essential Stream
→ retain Gmail identity + Cockpit understanding
→ Archive source
```

### Disposable retail offer with useful product Find

```text
Gmail message
→ extract Pending Find with evidence/provenance
→ persist Find
→ Trash source under explicit policy
```

### Amazon shipping notice

```text
Gmail message
→ perhaps summarize current status
→ no durable ContentPiece required
→ Trash under explicit policy
```

If processing fails before the barrier, source mail remains recoverable.

---

## 6. Editorial email belongs to Streams

A recurring editorial publication delivered through Gmail should be modeled as a Stream when the user follows it intentionally.

Stream Handling answers the editorial question:

> Why do I follow this and what should Cockpit do with it?

Email Source Disposition answers the provider question:

> What should happen to the Gmail message after safe processing?

These must remain independent.

Example:

```text
Matthew Yglesias Stream
Interest Area: Opinion & Commentary
Handling: Essential; always surface substantive posts
Library: explicit/optional policy
Gmail disposition: Archive after safe processing
```

Clearing the email source in Today is not automatically the same as clearing the ContentPiece from Edition.

---

## 7. Non-editorial email need not become Streams

Operational/promotional mail such as Amazon shipping updates or generic retail offers does not need to be forced into the Stream model merely to support disposition.

A narrow explicit mail policy can say, conceptually:

```text
Amazon shipping notifications
→ Trash after processing
```

or:

```text
selected retailer offers
→ inspect for useful Finds
→ Trash after successful processing
```

Do not invent an `Amazon Shipping Stream` unless there is a separate editorial/product reason to follow it as recurring content.

---

## 8. Attention classes are product roles, not ontology

Useful coarse V1 roles may include:

- Personal / Consequential;
- Worth Seeing;
- recurring editorial Stream material;
- disposable operational/promotional material;
- other quiet low-value mail.

These roles help presentation/disposition but should not harden into a giant permanent email taxonomy.

The large collection of provider/handling examples from earlier design work is preserved in the documentation archive as scenario/test evidence, not as a mandate to build dozens of V1 policies.

---

## 9. Personal and consequential mail

Importance is not the same as actionability.

A personal message may deserve attention even when no reply is required. A bill/flight change may be consequential. Cockpit should fail conservatively when uncertain whether such source mail may leave Inbox.

Contacts may help identify likely personal correspondents but should not automatically define a canonical Personal set.

---

## 10. Threads and re-entry

Cockpit should not create a parallel permanent thread-resolution model.

If an archived thread receives a new reply and Gmail returns it to Inbox, it naturally becomes part of the current attention set again.

Prior Cockpit understanding may provide context; Inbox membership determines whether the conversation is currently unresolved upstream.

The exact Gmail message-versus-thread action semantics must be determined from the read-only integration spike and documented in a focused Gmail ADR before provider mutation is enabled.

---

## 11. Recent dispositions and Undo

Once Cockpit mutates Gmail, it should retain a bounded recent history sufficient to answer:

- what was dispositioned;
- Archive versus Trash;
- when;
- under which explicit policy;
- whether Undo/restore remains possible.

This safety surface is part of trustworthy external mutation, not a permanent forensic ledger.

---

## 12. Custody interaction

Gmail Archive is a legitimate authoritative repository for ordinary Gmail-backed source material.

Cockpit need not duplicate every newsletter forever merely because it enters Edition/Library. It should retain stable provider identity plus useful lightweight understanding and may fetch the substantive original on demand.

If Gmail/account access disappears, report degradation. Do not preemptively duplicate all Gmail payloads to insure against provider/account loss.

An email that only links to external subscriber-only material must be treated according to what substance Cockpit actually captured; Gmail presence alone does not magically preserve linked content.

---

## 13. Read-only integration first

Before enabling Archive/Trash, implement Gmail read-only Today and learn actual provider semantics:

- account boundary;
- message/thread IDs;
- current-Inbox query behavior;
- pagination/delta refresh;
- duplicate sender/address patterns;
- new-reply re-entry;
- failure/retry behavior;
- provider mutation/undo capabilities;
- relationship between Gmail Artifact and email-delivered ContentPiece.

Then write the concrete Gmail integration/disposition ADR from evidence.

Do not settle provider mechanics from abstract product prose.

---

## 14. V1 authority line

V1 may:

- analyze broadly;
- surface/suppress presentation according to relevance;
- Archive or Trash under explicit established authority;
- use deterministic application operations for provider mutation;
- preserve bounded recent disposition history.

V1 does not:

- silently learn destructive authority;
- permanently hard-delete mail;
- become a general mail client;
- build a generalized rules engine;
- auto-unsubscribe;
- broadly compose/reply on Jon's behalf.

This gives Cockpit enough authority to make Gmail materially cleaner while preserving a clear human authorization boundary.
