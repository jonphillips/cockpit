# Cockpit Product Model

**Status:** Working product model / decisions plus open questions  
**Date:** 2026-09-05

## Purpose

This document captures the product model emerging from Cockpit design discussions before implementation hardens it accidentally.

It is deliberately separate from `ARCHITECTURE.md`:

- `ARCHITECTURE.md` defines how Cockpit software is built.
- this document defines what Cockpit is trying to understand and what responsibilities it assumes for the user.

Names here are conceptual. They do not imply one database table, Swift type, screen, tab, or navigation destination per concept.

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

### Important distinction

Importance and actionability are not the same thing.

A personal message can deserve prominent attention even if it requires no action. A transactional message may require action while being emotionally unimportant. Cockpit should optimize for **deserves attention**, not merely **requires action**.

### Conservative failure rule

When Cockpit is uncertain whether an email can safely leave the Inbox, the conservative default is to leave it there.

False negatives in clearing are more damaging than false positives in keeping.

## 4. Daily email experiences are class-specific

Cockpit should not force every incoming email through an identical one-message-at-a-time workflow.

Different classes of incoming mail can support different views and retention/disposition policies.

### Personal

Personal messages should be identified and surfaced prominently.

`Personal` should not automatically mean every address in Contacts. Contacts are useful evidence and onboarding input, but the personal set should be explicitly or gradually learned around real people and their identities.

A Person may have multiple email addresses. The durable concept is the Person, not the address string.

Cockpit may initially support explicit actions such as `Add to Personal` and later propose additions based on repeated evidence.

Personal email should be handled conservatively. Cockpit may summarize and highlight it, but should not casually clear it merely because a model believes no reply is needed.

### Market / retail reports

Promotional and market email is often more valuable as a batch report than as dozens of individual messages.

Examples include:

- wine-market offers,
- clothing offers,
- home-goods offers.

Cockpit may synthesize these into a report that highlights unusually relevant offers and preserves links back to the underlying source material.

The user should be able to clear the entire batch after reviewing the report.

### Newsletters

Newsletters should behave more like reading subscriptions than like ordinary Inbox traffic.

Each newsletter/source may eventually have its own policy, potentially including:

- show every new issue,
- summarize only,
- preserve original content or summary only,
- Cockpit retention duration,
- Gmail disposition after Cockpit processing.

The user should be able to see recent newsletter issues in Cockpit, open/read one in place, and then clear the related Gmail messages without making the newsletters disappear from Cockpit's own reading/history model.

This is a core example of Cockpit removing something from the action queue without removing it from the user's life.

### Business / transactional

Receipts, airline notices, bills, statements, reservations, deliveries, and similar messages can initially be grouped into a transactional triage experience.

They share one key characteristic: they are evidence of real-world transactions or obligations, but their eventual semantics differ.

Cockpit should initially make them easy to scan and selectively clear. Richer domain behavior can emerge later from real workflows rather than from one giant `Business` ontology.

Examples:

- receipt -> likely acknowledge / archive,
- flight schedule change -> potentially trip-relevant,
- statement -> often archival,
- bill -> may require action,
- reservation confirmation -> may reinforce known plans.

## 5. Clearing email

`Clear` is a Cockpit decision that the message no longer needs to remain in the Gmail Inbox for attention purposes.

It is not a task-completion concept.

Clearing has two independent consequences:

### Source disposition

What happens to the upstream Gmail message?

Examples:

- leave in Inbox,
- archive in Gmail,
- move to Trash.

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
- retail offer: Trash in Gmail + forget in Cockpit after report generation,
- receipt: archive in Gmail + retain extracted transaction metadata if useful,
- personal email: leave in Inbox + surface prominently in Cockpit.

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

## 6. Sources and artifacts

Cockpit must distinguish where information came from from what Cockpit actually received or captured.

### Source

A **Source** is an upstream origin or channel: Gmail, a newsletter publisher, a web page, RSS feed, event feed, music service, Instagram account, reservation/event platform, or another future integration.

A Source is not necessarily durable content under Cockpit's control.

### Artifact

An **Artifact** is a particular piece of source material Cockpit encountered or captured: an email message, newsletter issue, article, PDF, attachment, web snapshot, social post, event listing, or other incoming unit.

An Artifact can exist at different levels of custody. Cockpit may know that an Artifact existed without promising to preserve its original bytes forever.

### Product principle

> The ontology serves the inbox. The inbox should never feel like data entry for the ontology.

Most incoming Artifacts should be understandable and disposable without becoming rich permanent domain objects.

## 7. Attention is not custody

Cockpit understanding content and Cockpit preserving content are separate decisions.

Conceptually, an Artifact may be:

- **observed** — Cockpit saw enough to classify or summarize it; source content need not survive indefinitely,
- **retained** — Cockpit keeps enough source material while it supports a still-relevant concern or understanding,
- **preserved** — Cockpit assumes durable custody of meaningful source content even if upstream access later disappears.

These terms are provisional. The important decision is the distinction, not the enum spelling.

A paid recipe newsletter illustrates why custody matters. If Cockpit tells the user it has preserved a recipe, cancellation of the upstream subscription must not silently turn the preserved recipe into a dead URL.

### Semantic-fidelity rule

> Once Cockpit tells the user they no longer need to care about the upstream source, Cockpit must own enough information to keep that promise.

A pointer is not a preserved artifact.

## 8. Knowledge and content are different storage responsibilities

Cockpit's canonical knowledge store should remain relatively lightweight. Potentially large original content has a separate lifecycle.

Conceptually:

```text
Cockpit knowledge
  Artifact identity
  provenance
  extracted/normalized meaning
  custody intent
  relationships
        |
        v
Artifact content
  original HTML
  PDF
  image
  attachment
  audio/video
  other potentially-large bytes
```

The existence of an Artifact in Cockpit must not imply that all of its content downloads to every device.

## 9. Cloud custody and local availability are independent

Artifact storage has at least two independent dimensions.

### Custody

A synchronized fact about Cockpit's responsibility for the content, conceptually:

- `referenced` — Cockpit knows the source/provenance but does not promise durable possession,
- `preserved` — Cockpit owns a durable canonical copy.

### Device availability

A device-local fact, conceptually:

- `absent` — content is not physically present on this device,
- `cached` — content is present but may be discarded and redownloaded,
- `pinned` — Cockpit promises not to voluntarily evict this content from this device.

The exact implementation names remain open.

A preserved Artifact can therefore be absent on an iPhone, cached on a Mac, and pinned on an iPad simultaneously.

### Product principle

> Keep on this device is a promise, not a hint.

Cockpit should be able to verify its own offline-readiness claims from app-controlled local storage rather than merely infer them from an opaque cloud-download state.

## 10. Artifact Library boundary

The need for explicit custody and device availability establishes a real subsystem boundary, but not a new product or shared package.

For now:

- **Product:** Artifact custody is part of Cockpit.
- **Architecture:** Cockpit should isolate an Artifact Library subsystem/client.
- **jon-platform:** do not create `JonLibraryKit` or another shared package from this first consumer.

The likely conceptual responsibility is:

```text
Cockpit domain
     |
     | preserve / retrieve / availability
     v
ArtifactLibraryClient
     |
     +-- cloud content storage
     +-- disposable device cache
     +-- persistent per-device pinned storage
```

The current storage hypothesis is CloudKit assets for canonical preserved bytes, app cache storage for expendable downloads, and app-controlled persistent storage for pinned offline content. Exact CloudKit/SQLiteData integration should be validated during implementation rather than embedded in the product model.

Cockpit should use system viewers such as Quick Look and media frameworks where appropriate rather than become a universal document/media viewer.

## 11. Signals, subjects, and opportunities

Incoming material may produce knowledge beyond the Artifact itself.

### Signal

A **Signal** is evidence or meaning extracted from source material: a restaurant opened, an artist released an album, a hotel was recommended, Michelin changed a rating, or a person asked the user for something.

`Signal` is currently internal vocabulary and may prove too broad. It should not be forced into the UI.

### Subject

A **Subject** is a durable real-world or cultural thing that Cockpit can understand across time: a restaurant, album, wine, hotel, place, person, book, event series, and so on.

`Subject` is a conceptual category, not approval for one universal database `Item` with many optional fields. Domain distinctions should remain meaningful.

### Opportunity

An **Opportunity** is the relationship between something potentially interesting and the user's current life context: a Burgundy restaurant becomes relevant to a planned Burgundy trip; an artist of interest announces a nearby concert; a wine of interest appears on tonight's restaurant list.

### Product principle

> A Subject can be interesting for years. An Opportunity is interesting now.

Opportunity should not become Cockpit's center of gravity. It is an output of a broader system that first handles mundane incoming information well.

## 12. Subject Watching / source fan-out

Cockpit should track Subjects rather than force the user to manage feeds individually.

Example:

> Watch this restaurant for events and interesting changes.

The watched relationship belongs between the user and the Subject. Cockpit may then discover and use several imperfect Sources for that Subject, for example:

```text
Restaurant Subject
  official website
  newsletter
  Instagram
  OpenTable / Resy / Tock
  press mentions
```

No single source should become the product contract when multiple sources can contribute evidence.

This is particularly important for hostile or incomplete platforms such as social networks, where official APIs may be narrow and scraping may be brittle.

The open question is how Cockpit discovers, ranks, monitors, and explains source coverage for a watched Subject without turning the user into a feed administrator.

## 13. Awareness without task management

Some incoming information matters because it should register mentally, not because Cockpit needs to create a task.

Personal email is the clearest example.

Cockpit should prominently surface important personal or consequential messages in Daily so the user does not lose them in morning noise. However, for email, the durable unresolved state remains the upstream Inbox.

Cockpit should not translate ordinary life into due dates, priorities, completion percentages, KPI dashboards, or project-management machinery.

The product goal is situational awareness:

> These are the things you especially should not miss before you move on with your day.

If an email remains unresolved, Mail can remain responsible for the actual action queue.

## 14. The Personal Model — "You"

Cockpit should maintain an explicit, inspectable, correctable model of what it believes about the user.

The canonical model should not be a single prose biography or opaque LLM prompt. Prose profiles may be generated as task-specific projections from structured knowledge.

Potential claim families include:

- identity/circumstance,
- interest,
- preference,
- aversion,
- constraint,
- relationship,
- intention,
- current context,
- experience,
- possession,
- expertise.

The taxonomy is not yet approved.

A personal-model claim should be capable of carrying provenance, confidence, scope/context, temporal validity, and correction state where appropriate.

Cockpit should eventually be able to answer:

> Why do you believe this about me?

and allow the user to reinforce, correct, narrow, or forget a belief.

### Product principle

> Structured personal knowledge is canonical; LLM-readable prose is a projection.

This model should learn from explicit statements and from meaningful interaction evidence while avoiding false precision from isolated behavior.

## 15. The emerging loop

The current product hypothesis is:

```text
incoming sources
      |
      v
   Artifacts
      |
   understand
      |
      +----> Daily experiences / source disposition
      |
      +----> Signals ----> Subjects
                           |
                           +---- current context ----+
                           |                         |
                           +---- Personal Model -----+
                                                     v
                                                Opportunity

User choices / corrections / experiences
                 |
                 +----------> Personal Model
```

This is intentionally not a screen map.

## 16. Specialist applications remain specialists

Cockpit should not become mediocre versions of Yes Chef, Galavant, a wine cellar application, a music application, and every other domain tool.

Current hypothesis:

> Cockpit discovers, connects, remembers why something matters, and hands rich domain work to the application that actually owns that domain.

A recipe discovered in a newsletter may remain linked to its preserved source Artifact in Cockpit while a deliberate handoff creates the canonical recipe in Yes Chef.

A Burgundy restaurant discovered by Cockpit may become a Galavant idea rather than forcing Cockpit to reproduce Galavant's trip-planning model.

The exact cross-app handoff contract is unresolved and should be designed from real workflows.

## 17. AI role

AI is appropriate for interpretation, summarization, fuzzy extraction, classification, comparison, and proposing personal-model updates.

AI output is not canonical merely because it sounds plausible.

Cockpit should preserve the architectural rule:

> AI proposes; deterministic application code owns canonical mutation.

Examples include proposed dispositions, extracted Subjects, inferred personal-model claims, and proposed source actions. The exact amount of review can vary by reversibility and consequence.

## 18. Current product responsibilities

It is useful to think of Cockpit as having three responsibilities, without assuming three tabs or screens:

### Daily

What came in? What deserves attention? What can safely leave the Inbox? What especially should not be missed?

### You

What does Cockpit believe about the user, why, and how can those beliefs be corrected?

### Discover

Given Subjects, evidence, current context, and the Personal Model, what is unusually relevant or enjoyable now?

These are responsibilities, not navigation decisions.

## 19. Open design investigations

### A. Daily / Disposition

The basic email boundary is now established: Mail remains the action queue; Cockpit reduces noise and highlights what matters.

Remaining questions include:

- How should `Personal` be bootstrapped and learned?
- What classes of incoming mail deserve purpose-built Daily experiences versus generic triage?
- How should the user distinguish `Clear -> Archive` from `Clear -> Trash` without adding friction?
- Which Gmail/Cockpit policies should live per sender, per newsletter, per category, or globally?
- How long must Cockpit retain enough source material to undo or audit a classification/clearing judgment?
- How should messages arriving after the morning Daily session be surfaced?
- Should `mark read` be independent from clearing, and which system owns read/unread semantics?
- How should threads/conversations behave when earlier messages were cleared but a new reply arrives?
- What should happen when Cockpit was wrong?

Do not assume Gmail folders or labels are Cockpit's canonical workflow state.

### B. Source actions and agency

Define the progression from observation to mutation of upstream systems.

Potential ladder:

1. read,
2. classify/summarize,
3. propose a source action,
4. execute an explicitly approved source action,
5. learn narrowly scoped automatic source actions when safe and reversible.

Examples include archive, Trash, mark-read, unsubscribe, and constrained reply behavior for email.

### C. Subject Watching / source fan-out

Define what `Watch this Subject` means, how Cockpit finds available sources, what confidence/reliability it assigns them, how often it checks them, and how it represents degraded coverage when sources become unavailable.

The user should express interest in the Subject rather than maintain individual feeds.

### D. Cross-app handoff

Define how Cockpit sends a discovered rich domain object to Yes Chef, Galavant, or future specialist applications while retaining provenance and the reason it mattered.

This should be based on concrete workflows before changing `LLMHandoffKit` or creating a new shared abstraction.

### E. Personal Model ontology

Define claim families, evidence/provenance, confidence, temporal scope, contradictions, explicit versus inferred beliefs, corrections, relationships, and task-specific projection into LLM context.

This should be designed for inspectability rather than merely prompt quality.

## 20. Deliberately deferred

Do not yet design:

- a universal relevance score,
- a giant cross-domain `Item`,
- a Jon Library standalone application,
- a `JonLibraryKit` platform package,
- a complete email client,
- a universal viewer,
- final tab/navigation structure,
- a generalized prompt/profile platform abstraction,
- broad autonomous source mutation.

We need real Cockpit workflows before these abstractions can be justified.

## 21. Product north star

Cockpit should quietly reduce information burden while building a useful, user-owned understanding of what matters.

The mundane and ambitious sides are the same system:

> Understand what enters the user's world, make what deserves attention hard to miss, remove what can safely recede, assume only the custody that is warranted, and use that understanding to surface better possibilities over time.
