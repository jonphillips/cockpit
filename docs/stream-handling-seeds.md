# Stream Handling seeds

**Status:** Evidence, extracted for use. Not an essay.
**Date:** 2026-09-11
**Provenance:** `docs/archive/2026-09-08-pre-normalization/EMAIL-INTELLIGENCE-MODEL.md` §11,
written 2026-09-07 from a real one-week Gmail corpus including archived mail.

These are Jon's own words about why he follows each source and what he wants done with it. They
were written as seed drafts — "not final settings and not a hard-coded sender switch statement" —
and are intended to be edited conversationally as he clarifies why he subscribes.

The normalization pass that produced the live `docs/EMAIL-INTELLIGENCE-MODEL.md` dropped all fifty.
That was a category error: they are data, not prose, and an essay was the wrong home. This file is
the right one until the schema can hold them.

`AGENTS.md` bars archived documents from resurrecting superseded product language or architecture.
It calls them historical evidence, which is precisely what corpus-derived data is. This file
carries the evidence forward and leaves the superseded architecture behind.

---

## Open contract question — where does this prose live?

**Raised for the architect before S3 writes Add Stream. Blocking for the Handling proposal step.**

`docs/IMPLEMENTATION-CONTRACT.md` §2 gives `Stream` a `handling` column, and `StreamHandling` is an
enum whose only case is `following`. `guidance` — the prose field — exists on `InterestArea`, not on
Stream.

So there is currently nowhere to put any of the text below. Meanwhile
`docs/JUDGMENT-CONTRACT.md` §4 passes "{stream name, handling, essential, interest area, guidance}"
into the prompt as though handling carried meaning, and `docs/V1-SCOPE-AND-SEQUENCING.md` §1 says
Add Stream proposes "concise Handling."

Fifty hand-written drafts are exactly the demonstrated requirement that AGENTS.md's persistence
discipline asks for before a column is added. The likely resolution is a prose column on Stream
alongside the enum — the enum stays a posture, the prose carries intent — but that is a contract
amendment, not an executor's call. **Do not invent a column to hold this. Escalate if it has not
been settled by the time you need it.**

---

## S3's five

Chosen for feed shape as much as content, so the parser meets real variety early. Done-criterion 2
asks for at least one feed that S1's synthetic cases do not resemble; several of these qualify.

| Stream | Why this one |
|---|---|
| Slow Boring | Substack; mixes long essays with roundup issues in one feed |
| Astral Codex Ten | Substack; very long posts, which exercises normalized-text size for real |
| Techmeme | Aggregator; high item volume and a shape unlike a newsletter |
| Point-Free | Technical publication with episode content — exercises `ContentKind` beyond `article` |
| Benedict Evans | Low-volume newsletter; the quiet case, which is easy to get wrong |

Jon's call, not the executor's — if he swaps one, the Handling text below travels with it.

---

## Publication sources

Transcribed verbatim. Written before contract §4 fixed Dismiss/Clear, so read the vocabulary before
pasting it anywhere user-facing; the intent is current, the wording may not be.

Several describe what judgment should *do* with an issue — brief the thesis, screen constituent
links, surface only strong matches. That is M2 behaviour. In M1 this text is inert data attached to
a Stream. Do not build any of it.

### Slow Boring / Matthew Yglesias

> **Treat Slow Boring as a writer I generally want available rather than a publication to filter aggressively. Brief the thesis enough that I can decide whether to read now, later, or skip. Elevate an issue when it strongly intersects with an existing Interest, but do not infer that skipping an issue means I no longer care about the writer/topic.**

### Astral Codex Ten

> **Brief substantive essays enough to decide whether to read and screen community/announcement-style posts much more aggressively. Do not treat every post from the same publication as equally valuable merely because the sender is high-signal.**

### Techmeme

> **Screen the technology stories for developments that materially intersect with my current interests—especially AI capabilities, developer tooling, Apple/mobile platforms, and changes that could affect the app family. Routine industry deal/news churn can stay suppressed. When a platform release could expand an actual harness, surface it with the concrete reason it matters.**

### Point-Free

> **Treat Point-Free as an architecture/tooling source relevant to patterns actually used in the app family. Surface library changes, techniques, or releases that could materially improve our current architecture. Do not surface every product update merely because we use Point-Free libraries. Explain the concrete seam or problem a new capability might affect.**

### Benedict Evans

> **Screen the newsletter for AI/platform/technology analysis that is unusually relevant to my current thinking. Preserve the high-level argument when it is useful, but avoid surfacing every industry link. If a contained item changes the practical capability landscape for my apps, elevate it separately.**

### Derek Thompson

> **Treat Derek Thompson as a high-signal writer on technology, economics, culture, and social change. Brief the central argument and tell me when an issue is unusually aligned with something I have been thinking about. Keep the full original available. Use my explicit reactions to refine which of his themes matter most, rather than learning from passive opens.**

### Noahpinion

> **Distinguish long-form essays from roundup issues. For essays, brief the thesis and relevance. For roundups, screen constituent links/topics and surface the parts most aligned with my technology/economics/culture interests. Do not force one processing style on both formats.**

### Cartoons Hate Her

> **Treat Cartoons Hate Her as a conversational/cultural writer I may want to skim regardless of topic. Give me a concise orientation and call out when an essay overlaps strongly with my interests in culture, media, technology, or social behavior. Do not over-filter the publication into disconnected article nuggets; writer voice is part of why I subscribe.**

### I Might Be Wrong / Jeff Maurer

> **Brief the core argument/joke premise and make the full issue easy to read. Surface an issue more strongly when it intersects with topics I clearly follow. Do not reduce the source to political topic tags; the writer's perspective and style are part of the subscription value.**

### Singal-Minded

> **Brief the main claim and why it may matter to me, keeping the original available. Treat media/journalism methodology and institutional-behavior stories as potentially higher signal than generic partisan controversy. Let explicit reactions, not reading time, refine the source policy.**

### iOS Code Review

> **Surface developments that materially affect how I can build, test, architect, or operate my apps—especially agent/AI tooling, Xcode capabilities, Foundation Models, SwiftUI architecture, background execution, App Intents, and meaningful platform changes. Separate "interesting developer news" from an actual change in what the Cockpit/Galavant/Yes Chef harness can do. Ignore routine beta churn unless it changes a real implementation decision.**

### The Free Press

> **Process by message shape. For a single long-form feature, brief the thesis. For multi-item front-page/digest sends, screen constituent stories and surface only strong matches. Treat subscription marketing as disposable. Preserve enough source context that I can distinguish a genuinely interesting argument from generic outrage bait.**

### The Dispatch / Jonah Goldberg / related newsletters

> **Separate author essays, focused newsletters, and subscription promotion. Brief real editorial pieces according to writer/topic relevance; aggressively suppress generic membership marketing. The fact that multiple newsletters share a publisher should not force them into one Handling policy.**

### Best of Journalism

> **Screen all recommended links cheaply against my Interests and Taste. Do not fetch and summarize every article. Use titles, authors/publications, metadata, and the Brain first; enrich only strong or ambiguous candidates. Surface a small number of strong matches plus worthwhile maybes, with a short explanation of why each might be for me. Keep rejected titles inspectable so I can correct missed interests. When I explain why a hit matters, treat that explanation as strong learning evidence rather than relying on click behavior.**

### The New York Times — The Morning

> **Do not summarize a summary by default. Scan the contained items for something unusually aligned with my Interests or current concerns and tease only those hits. If nothing is specifically for me, say little or nothing. Preserve a path to the full issue. The goal is "anything here especially for Jon?" rather than another compressed news digest.**

### Washington Post / general news digests

> **Treat broad daily digests primarily as hit-detection streams. Surface a contained story only when it strongly matches an Interest or deserves attention for another explicit reason. Do not reproduce the publisher's own prioritization as if it were personalization. More focused newsletters can be briefed according to their own purpose.**

### NextDraft

> **Treat NextDraft as a curated link digest. Brief the day's organizing theme only if useful, then screen individual stories for unusually strong matches. Do not expand every clever headline into a full summary. Keep promising links available and let the rest disappear unless I inspect skipped items.**

### Puck daily digests

> **Treat Puck's multi-story digests as item-level material. Mine the issue for entertainment, media, sports-business, technology, or cultural stories that strongly match me rather than assuming the headline story is the relevant one. For a strong hit, preserve enough context to decide whether to open the underlying reporting. Do not summarize unrelated Puck verticals merely because they share one email.**

### Feed Me

> **Give me a short orientation to the issue, then separately hunt for highly specific restaurant, food, media, business, and culture references that match my interests. A side mention can be more valuable than the headline story. Ignore routine fashion/beauty/lifestyle material unless something unusually intersects with my Taste or Interests. Preserve the author's specific observation or rationale around a surfaced nugget; that context is often why the mention is useful.**

### On the House

> **Mine restaurant/hospitality intelligence for openings, chef moves, notable operators, and specific New York dining developments I might plausibly care about. Surface concrete places/changes with the source's judgment; suppress generic industry chatter unless it intersects with another Interest.**

### What's Alan Watching? / Alan Sepinwall

> **Treat this as television criticism rather than generic entertainment news. Surface essays/recaps when they concern shows I watch or broader TV-industry/critical themes I care about. Keep other issues available but low priority. If I reveal a strong showrunner/director/show interest, use that explicitly rather than inferring from every recap click.**

---

## Deliberately left in the archive

The other twenty-nine drafts cover categories M1 cannot act on, and lifting them here would be
pre-building for slices that do not exist:

- **Food and cooking publications** (§11.5–11.11) — NYT Cooking, Milk Street, Bon Appétit and the
  individual recipe writers. Feed-backed and genuinely wanted, but their drafts are mostly about
  Find extraction, which is M2 at the earliest.
- **Wine and winery allocations** (§11.1–11.4) — family policies that assume a synthesized market
  brief across many senders. No Cockpit concept holds that yet.
- **Travel, hotels, venues, ticketing** (§11.12–11.16, §11.38–11.42) — Find-shaped and
  handoff-shaped.
- **Retail, transactional, account and billing mail** (§11.43–11.50) — not editorial material at
  all. `docs/EMAIL-INTELLIGENCE-MODEL.md` §7 and §9 explain why these never become Streams.

They stay in the archive until the slice that needs them arrives. Whoever writes that slice should
extract them the same way rather than pointing an executor at a superseded document.
