# Cockpit Email Intelligence Model

**Status:** Working product/architecture decision grounded in real inbox corpus  
**Date:** 2026-09-07

## Purpose

This document captures the email-intelligence model earned from reviewing a real one-week Gmail corpus, including archived mail, rather than inventing a newsletter taxonomy from first principles.

It extends `docs/PRODUCT-MODEL.md` and `docs/CAPABILITY-REALITY-MAP.md`.

The core product promise remains:

> **Tell me what came into my world, what matters, and what I can safely ignore.**

The corpus makes one refinement especially clear:

> **Cockpit should turn email into a personalized briefing, not a better inbox.**

Email is a source and attention queue. The valuable Cockpit objects are often not emails at all. They may be:

- an important correspondence thread,
- a market brief synthesized from many offers,
- a recipe worth considering,
- a restaurant opening buried in a newsletter,
- a concert matched against an Interest,
- a development-platform change relevant to the app family,
- an article worth reading,
- a concrete fact/action extracted from transactional mail,
- or nothing, because Cockpit correctly determined that the material was safe to ignore.

This document defines how Cockpit should reason about that transformation without making Jon maintain a giant taxonomy or preference database.

---

## 1. Corpus-driven conclusions

A representative week of Gmail contained hundreds of message records across two receiving addresses, including:

- direct personal/business correspondence,
- transactional confirmations and notices,
- wine retailer offers and winery allocations,
- clothing and other retail promotions,
- full-text cooking newsletters,
- link-heavy reading digests,
- author-driven essays,
- mixed newsletters containing many unrelated nuggets,
- travel and restaurant intelligence,
- event listings,
- film/music/comics/cultural streams,
- developer and AI newsletters,
- woodworking commerce and instructional material,
- duplicate or near-duplicate campaigns delivered to multiple addresses.

The corpus strongly rejects several tempting simplifications.

### 1.1 Inbox membership is not relevance

Archived sources included highly useful material. Inbox membership is upstream workflow state: whether a Gmail message still represents unresolved attention.

It must not be used as a proxy for whether the source or its content is valuable to Cockpit.

> **Inbox state answers “does Mail still need my attention?” It does not answer “is this material relevant to my life?”**

### 1.2 Gmail category is not product semantics

`Promotions`, `Updates`, and similar provider categories are useful plumbing hints but weak product concepts.

A promotional email may contain:

- a wine worth buying,
- a Legion of Super-Heroes release,
- a comedian Jon wants to see,
- a restaurant event worth attending,
- or nothing at all.

An `Updates` email may be a long essay Jon always wants available, a link digest that needs aggressive screening, or a transactional notice with a real deadline.

### 1.3 Sender is not the processing policy

A single publisher can send materially different kinds of mail.

Examples from the corpus:

- a cooking publisher may send both editorial recipe content and pure merchandise,
- a wine publication may combine editorial regional analysis, event promotion, and a list of recently published reports,
- a mixed cultural newsletter may contain a primary story plus several unrelated restaurant/media/style references.

Therefore:

> **Do not encode `sender -> newsletterType -> behavior` as the product model.**

A source has a Handling policy, but message and section shape still matter.

### 1.4 The email is often not the atomic intelligence unit

Many emails are containers.

A mixed issue can be modeled conceptually as:

```text
ISSUE
├── primary essay
├── restaurant mention          <- strong personal hit
├── media-business item
├── fashion item                <- likely skip
└── external article link       <- maybe
```

A wine publication might be:

```text
ISSUE
├── regional editorial report
├── tasting event
├── unrelated collector event
├── recently published Riesling report  <- possible strong hit
└── other recent articles
```

Cockpit must be able to interpret and rank at message, section, and item level.

### 1.5 Duplicate provider messages should not become duplicate intelligence

The corpus contains exact and near-exact campaigns sent to multiple user addresses.

Conceptually:

```text
Provider messages: 2
       ↓
Semantic incoming artifact: 1
       ↓
Cockpit interpretation: 1
```

Cockpit may still retain both provider message identifiers underneath because source disposition may need to act on both.

### 1.6 “What I skipped” is a product surface, not merely debugging

A filtered source should sometimes be able to say:

> **3 for you · 17 skipped**

The skipped view need not be prominent or routinely reviewed. Its value is trust and correction.

If Jon notices a meaningful false negative, that becomes an unusually valuable learning moment:

> “Why did you skip Fontaines D.C.? I definitely care about them.”

or:

> “That Phantom Thread piece matters because Paul Thomas Anderson is one of my favorite directors and I like keeping up with serious film criticism.”

The user supplies the missing reason; the Brain can decide how to generalize it.

Silence about skipped material is not durable evidence that the filter was correct.

---

## 2. Product model: source purpose + material shape + Personal Knowledge

Cockpit should answer one human question per managed source:

> **For this source, what do you want Cockpit to do for you?**

That is a Handling Policy.

Processing emerges from three inputs:

```text
USER / SOURCE PURPOSE
        +
MESSAGE OR SECTION SHAPE
        +
RELEVANT PERSONAL KNOWLEDGE
        ↓
HANDLING STRATEGY
        ↓
BRIEF / FIND / ACTION / SKIP
```

### 2.1 Source purpose

Source purpose is the durable semantic instruction.

Examples:

- find wines genuinely worth considering,
- find weeknight recipes and entertaining ideas,
- mine travel newsletters for specific hotels/restaurants/experiences,
- tell me what a writer is arguing so I can decide whether to read,
- screen a large article list against my Interests,
- surface platform changes that materially expand what my apps can do,
- match local events against artists/comedians/cultural interests.

### 2.2 Material shape

Material shape should ordinarily be inferred rather than configured by Jon.

Common shapes include:

- full original text,
- mostly links/titles,
- structured product offer,
- structured event list,
- mixed editorial plus links,
- digest/summary of other reporting,
- transactional notice,
- personal conversation.

Material shape determines processing mechanics and cost. It is not necessarily a user-facing taxonomy.

### 2.3 Relevant Personal Knowledge

Jon Brain can contribute:

- durable Interests,
- Taste and aversions,
- useful Facts,
- strong explicit corrections,
- contextual distinctions already supported by knowledge.

Examples:

- “African safari is not a travel interest” can suppress safari material across travel sources,
- preference against oxidized Jura styles can affect wine-offer ranking,
- a strong Paul Thomas Anderson Interest can elevate a sparse Phantom Thread link,
- strong Legion of Super-Heroes Interest can turn one line in a generic comics promotion into a major hit.

Personal Knowledge should improve judgment; it should not become a thousand-line source-specific rules file.

---

## 3. Six core processing primitives

The real corpus suggests that a small set of reusable operations can handle most source behavior.

These are conceptual operations, not necessarily Swift protocols, database enums, model endpoints, or visible controls.

## 3.1 Collapse

**Job:** turn many related incoming messages into one useful briefing.

Best examples:

- wine retailer offers,
- clothing retailer campaigns,
- repeated venue/event promotions,
- possibly other high-volume commercial streams.

Instead of:

> 21 wine emails

Cockpit should aim for:

> **Wine Market — 4 worth seeing from 21 offers**

Collapse should preserve provenance back to the specific underlying offer(s) for price, rationale, purchase link, and source disposition.

## 3.2 Extract

**Job:** identify specific useful entities/ideas already described richly in the source.

Examples:

- restaurants from Paris by Mouth,
- recipes from NYT Cooking,
- hotels and experiences from a travel newsletter,
- specific wines from a merchant catalog,
- useful product candidates from clothing or equipment newsletters.

The output is not merely a summary. It is a set of candidate Finds carrying source rationale.

Example:

```text
Eskal — Paris 8th
Why it surfaced:
- former Astrance chef
- five-course menu at €89
- outside critics describe strong sauce work
- credible Michelin trajectory

Source: Paris by Mouth
```

Do not strip away the source's reason for caring merely to create a sterile entity record.

## 3.3 Brief

**Job:** orient Jon to a source he may want to read largely because he follows the writer/publication.

Examples:

- Slow Boring,
- Derek Thompson,
- Cartoons Hate Her,
- I Might Be Wrong,
- Noahpinion long-form essays,
- Singal-Minded,
- author-driven political/cultural newsletters.

The goal is not maximum compression.

Useful output may be as small as:

> **Probably read:** this connects directly to an issue you have been thinking about.

or:

> **Normal issue:** clear thesis, but nothing unusually aligned with your interests today.

The full original remains available in Cockpit's reading/viewing surface according to custody policy.

## 3.4 Screen

**Job:** judge a collection of sparse links/titles and decide which deserve further attention.

Best examples:

- Best of Journalism,
- Techmeme,
- NextDraft,
- The Morning / general publisher digests,
- other link roundups.

Screening should use progressive enrichment rather than fetching and summarizing every destination.

## 3.5 Mine

**Job:** find personally valuable nuggets that are incidental to the apparent main story.

Best examples:

- Feed Me,
- Puck digests,
- mixed food/media/culture newsletters,
- publisher roundups whose headline topic is not the only useful content.

This is one of the most Cockpit-specific jobs:

> **Find the one Jon thing hidden inside 2,000 words of somebody else's stuff.**

A Feed Me issue might have a low-interest primary media-business story but contain a side mention of a new chef at a hotel restaurant with provenance from several restaurants Jon values. Cockpit should be able to surface the side mention more strongly than the headline.

## 3.6 Match

**Job:** compare structured candidates against Interests/Taste and surface plausible hits.

Examples:

- Ticketmaster,
- DPAC,
- Carolina Theatre,
- 9:30 Club,
- local performing-arts feeds,
- cinema listings,
- comics-store release lists,
- possibly product catalogs where structure is strong.

When the source already gives artist, venue, city, date, product, price, etc., deterministic parsing should do the structural work. The model judges personal relevance.

Do not “summarize Ticketmaster.” Match the events.

---

## 4. Processing recipes may compose primitives

Sources do not have to select exactly one primitive.

Examples:

### Feed Me

```text
Brief main issue
+
Mine side references
+
Screen outbound links selectively
```

### Vinous

```text
Brief main editorial report
+
Mine list of recently published reports
+
Match events against wine/travel interests
```

### NYT Cooking

```text
Extract recipes
+
Match against cooking Taste/use cases
+
Brief an unusually useful technique section
```

### Travel digest

```text
Extract named places/experiences
+
Screen sparse outbound links
+
Match against travel Taste/aversions
```

The reusable primitives should stay small. A Handling Policy describes the desired composition in human terms.

---

## 5. Progressive-cost intelligence

Cockpit should not spend expensive model/web work uniformly across material Jon may never care about.

The governing principle is:

> **Spend intelligence in proportion to demonstrated relevance.**

A useful conceptual ladder:

```text
1. INGEST
   provider body / metadata / links
        ↓
2. DETERMINISTIC NORMALIZATION
   dedup, sections, titles, URLs, products, events
        ↓
3. LOCAL / CHEAP UNDERSTANDING
   on-device classification, summary, candidate extraction when adequate
        ↓
4. BATCH RELEVANCE JUDGMENT
   evaluate many candidates together against source purpose + Jon Brain
        ↓
5. SELECTIVE ENRICHMENT
   fetch page metadata / intro / richer context only for promising or ambiguous items
        ↓
6. DEEPER MODEL REASONING
   only where additional understanding materially improves a decision
        ↓
7. FULL CONTENT / SUMMARY
   when Jon opens, saves, or relevance has earned the cost
```

### 5.1 Full-text email is cheap substrate when already present

For newsletters such as Kitchen Projects, the useful article text is already in Gmail. Cockpit can often process it without any web fetch.

An onboard model may be able to produce enough orientation to say:

> Serious technical investigation of how lower air pressure and lower boiling points affect baking; probably low practical relevance to Jon because the techniques primarily matter at high elevation.

That can happen before any cloud enrichment.

### 5.2 Sparse link lists need staged enrichment

Best of Journalism provides many items with almost no context beyond title/link.

Do not summarize twenty-five destination pages merely to decide whether any are interesting.

Start with title, publisher/author when recoverable, URL/domain, page metadata, and known Interests. Batch-rank. Enrich only promising or genuinely ambiguous candidates.

### 5.3 Uncertainty can be shown rather than purchased away

Cockpit does not need to pay to eliminate every uncertainty.

It may say:

> **Possible match — not enough context to tell cheaply.**

Jon can decide whether the title earns a tap. A tap or explicit request can justify further enrichment without being treated as durable Personal Knowledge by itself.

### 5.4 Cost is a product concern, not merely infrastructure

Model/web cost should influence source Handling:

- full-text source already in email -> usually cheap,
- structured offer/event -> very cheap to parse and batch-rank,
- sparse link collection -> cheap screen, selective enrichment,
- ambiguous external article -> more expensive only after relevance survives early stages.

The user should not need to think in tokens, but Cockpit should behave like a product that does.

---

## 6. Finds: the important output object

Many source-processing operations produce a **Find**.

`Find` is a product concept for a surfaced piece of value discovered inside incoming material. It does not imply a universal database entity or one canonical Swift type.

Examples:

- a restaurant opening,
- a hotel worth considering,
- a wine offer,
- a recipe,
- an article,
- a concert,
- a comic release,
- a developer-platform capability change.

A useful Find may carry:

- concise title/identity,
- source/provenance,
- source rationale/evidence,
- Cockpit's reason for surfacing it,
- relevant link(s),
- lightweight extracted metadata,
- destination affordances such as Read Later / Add to Galavant / Add to Yes Chef,
- current relevance judgment,
- user reaction/learning controls.

Do not prematurely unify restaurant, recipe, wine, article, concert, and software-change semantics into a universal `Item` model merely because they can all appear visually as Finds.

---

## 7. Viewing chrome is part of the intelligence loop

Cockpit needs a reader/inspection surface, not a general-purpose Safari replacement.

The value is consistent Cockpit chrome around original material.

Possible controls/context include:

- **Why this is here**
- **Cockpit's take**
- original/full source content
- **Keep / Read Later**
- destination-specific handoff such as **Add to Galavant** or **Add to Yes Chef**
- **Not interested**
- **Tell You why**
- **What I skipped** / related filtered material

The same interaction model can wrap very different sources.

Jon should learn one product behavior:

> Cockpit filtered or interpreted this for me. I can inspect the original, understand the judgment, act on it, and correct the model when the reason matters.

---

## 8. The learning loop

The corpus-driven email design creates a concrete learning loop between Daily/Curate and Jon Brain.

```text
EMAIL / FEEDS
     ↓
source Handling + Brain filter
     ↓
Cockpit surfaces candidates
     ↓
Jon reacts / explains occasionally
     ↓
Brain and/or Handling improves
     ↓
future judgment improves
```

This is deliberately different from passive behavioral tracking.

### 8.1 Ignore/open behavior is weak evidence

If Jon ignores a surfaced item, Cockpit should ordinarily learn little or nothing durable.

If Jon opens an item, that may justify deeper enrichment for the immediate interaction, but should not automatically become a durable Interest.

### 8.2 Explicit negative is useful evidence

`Not interested` can improve source filtering.

Jon may optionally explain why:

> “Don't care about high-altitude cooking.”

That statement can affect future ranking immediately.

### 8.3 Explanation is unusually strong evidence

The most valuable case is when Jon supplies the missing reason:

> “PTA is one of my favorite directors, and I like being up on serious/pretentious current film criticism.”

That is strong declarative evidence and may support durable Personal Knowledge synthesis.

### 8.4 Specificity is cheap; accumulation is expensive

A highly specific negative preference can be useful without deserving a prominent permanent Brain claim.

For example:

> `high-altitude baking -> suppress unless specifically relevant`

may remain a low-level filtering instruction.

Over time, multiple specific corrections may support a more useful synthesis such as:

> Jon values deep cooking technique primarily when it has plausible application to his ambitious home cooking.

Or no broader synthesis may be warranted. That is fine.

> **Specificity is cheap. Accumulation is expensive.**

### 8.5 “Use this” is not always “Know this about me”

Every explicit correction can influence future ranking immediately without automatically becoming distilled Personal Knowledge.

Possible destinations for a correction include:

- this item only,
- this source's Handling,
- a topical/source-local filter,
- Personal Knowledge evidence,
- a durable synthesized Brain claim if warranted.

AI should determine the likely level and preserve provenance; Jon should not maintain the ontology manually.

---

## 9. Handling: human language over taxonomy

Cockpit should not require a preferences screen such as:

```text
Newsletter Type:
[ ] Digest
[ ] Editorial
[ ] Promotional
[ ] Mixed
[ ] Link List
...
```

Instead, a managed source should expose a humane synthesized instruction.

Example:

### Kitchen Projects

> Brief the main technical idea and surface recipes or techniques that seem plausibly useful for my cooking. Don't confuse technical sophistication with relevance. Keep the original issue available to read, and let me explain why something is or isn't for me.

The user can edit this conversationally:

> “Actually, don't summarize every recipe. Tell me the main thesis and call out recipes only when they're especially likely to interest me.”

The AI rewrites the source Handling policy.

### User-facing settings should be contextual, not universal

A source may expose small controls appropriate to its current recipe, such as:

- `Strong matches only` vs. `Include maybes`,
- `Show skipped items`,
- `Preserve full issue` vs. summary/history policy,
- `Combine into Wine Market`,
- `Open in Cockpit reader`,
- `Clear source email after successful processing`,
- a narrowly scoped source disposition policy.

These controls support a source Handling statement. They should not grow into an exhaustive global taxonomy.

---

## 10. First-run / backfill behavior

Cockpit should not ask Jon to configure dozens of sources before Daily becomes useful.

Instead, initial ingestion should infer proposed Handling from real material.

Examples:

> “I receive many wine-retailer offers. I propose combining these into one Wine Market brief rather than showing each email.”

> “Slow Boring looks like a publication you generally want available to read. I propose briefing each issue, not aggressively filtering the publication away.”

> “Feed Me is mixed. I propose a short issue brief plus a separate hunt for restaurant, food, media, and culture nuggets that match you.”

Only material differences should demand attention.

> **AI synthesizes the initial operating model; Jon corrects meaningful exceptions.**

---

## 11. Initial source Handling drafts

These are **seed drafts**, not final settings and not a hard-coded sender switch statement.

They are inferred from the real corpus plus explicit product discussion and are intended to be edited conversationally as Jon clarifies why he subscribes.

### 11.1 Wine retailers — family policy

Applies initially to sources such as K&L Wine Merchants, Woodland Hills Wine Co., Chapel Hill / Hillsborough Wine Company, Gary's Wine, Saratoga Wine Exchange, Cellar d'Or, Southern Hemisphere Wine Center, and similar merchant offer streams.

> **Combine retail wine offers into a Wine Market brief instead of showing individual promotional emails. Extract producer, wine, vintage, price, merchant rationale, relevant critic scores/notes when present, and purchase link. Use my wine Taste and buying patterns to suppress wines that are merely cheap, mass-market, stylistically wrong for me, or otherwise unlikely to be interesting. Surface genuinely compelling values, unusual bottles, strong vintages/producers, and offers that fit known interests. Preserve the merchant's reason for recommending the wine so I can judge the pitch. Keep skipped offers inspectable at low cost.**

Potential source-specific nuance can remain underneath—for example, a local retailer may deserve slightly different treatment from a national merchant—but the output should still consolidate into the market view unless a source earns standalone status.

### 11.2 Direct winery allocations/releases — family policy

Examples include Ferren, Wayfarer, Paul Lato, Radio-Coteau, Rochioli, Clarice, and similar producer-direct mail.

> **Treat winery releases and allocations differently from commodity retail promotion. Surface releases from producers I already value, meaningful allocation deadlines, unusual library/limited bottlings, and changes that might affect whether I buy. Summarize the release rather than repeating winery marketing copy. Do not elevate a release merely because it is scarce. Preserve price, deadline, bottle/format details, and producer rationale when available.**

### 11.3 Vinous

> **Treat Vinous primarily as wine intelligence rather than retail promotion. Brief the main editorial report and separately scan lists of recent reports, regional/vintage coverage, and events for subjects that strongly match my wine interests. A report on a region/style I care about may matter more than the headline article. Surface high-value editorial developments and unusually relevant tastings; suppress routine publication promotion.**

### 11.4 CellarTracker

> **Treat CellarTracker mail as personalized cellar intelligence, not a general wine newsletter. Surface concrete information about bottles I own, drinking windows, unusual community movement, or something that could change what I choose to drink/buy. Avoid re-presenting generic community chatter merely because it comes from a wine service.**

### 11.5 NYT Cooking

> **Mine each issue for recipes and techniques that fit how I actually cook. Prioritize plausible healthy-ish weeknight meals, strong quick techniques, recipes that use equipment/styles I enjoy, and impressive but realistic entertaining dishes. Deprioritize routine desserts/baking that do not fit my current interests and recipes that are clearly wrong for our tastes. Tell me why a surfaced recipe fits, and keep the original recipe link. Do not require opening every recipe page before screening the issue.**

### 11.6 Kitchen Projects

> **Brief the central technical lesson and surface recipes or techniques that seem plausibly useful to an ambitious home cook. I like understanding why cooking works, but technical depth alone is not enough to make something relevant. If an issue is highly specialized—such as high-altitude baking—tell me what it teaches and feel free to recommend skipping it. Keep the full issue available in the Cockpit reader and let my corrections improve future filtering.**

### 11.7 Milk Street

> **Distinguish real editorial cooking content from Milk Street merchandise and promotion. For editorial issues, extract useful techniques and recipes according to my cooking interests; for product sales, surface something only if it is unusually relevant to equipment I actually need or have been considering. Do not let the sender identity cause product marketing to masquerade as cooking intelligence.**

### 11.8 Bon Appétit

> **Screen recipe-heavy sends for a small number of dishes that plausibly fit weeknight cooking, entertaining, or a technique worth learning. Do not surface a recipe merely because it is seasonal or visually appealing. Treat generic subscription/product promotion as disposable unless it contains a specific food idea worth extracting.**

### 11.9 Ali Slagle

> **Treat Ali Slagle as a high-signal cooking source for practical, smart weeknight ideas. Brief the core dish/technique and surface the recipe when it looks likely to enter my real cooking repertoire. Preserve what makes the method unusually efficient or clever rather than giving me a generic recipe summary.**

### 11.10 Andrea Nguyen / Pass the Fish Sauce

> **Surface genuinely useful Vietnamese/Asian techniques, recipes, condiments, or cultural food insights that fit my cooking. Pay attention to strong flavor techniques and practical applications, but use known household taste constraints when relevant. Ignore unrelated newsletter filler unless it hits another strong Interest.**

### 11.11 Nik Sharma / Flavor Files

> **Brief the flavor/technique idea and surface recipes or methods that could materially improve my cooking. Favor transferable technique and interesting flavor construction over cookbook promotion. If the issue is primarily promotional, extract the one useful idea and suppress the rest.**

### 11.12 Paris by Mouth

> **Mine every issue for restaurants, chefs, openings, closings, and food experiences I might plausibly care about. Preserve why Paris by Mouth finds each item interesting, including neighborhood, price, chef provenance, source criticism, and useful comparisons. Do not make me read the whole newsletter to discover a restaurant development. Prefer specific actionable restaurant intelligence over general Paris promotion. When a surfaced place becomes relevant to an actual trip, it should be easy to hand it to Galavant without Cockpit becoming the canonical travel database.**

### 11.13 General travel newsletters / hotel-idea sources

Applies initially to sources such as Fathom/Way to Go and similar curated travel newsletters.

> **Mine for specific hotels, restaurants, places, and experiences with an underlying reason they are worth considering. I am not looking for generic destination inspiration or promotional copy. Use my travel Taste aggressively: refined/characterful lodging, strong food/culture, beautiful settings, realistic pacing, and known aversions such as African safari travel. Preserve the source's rationale and underlying links. If the source gives too little context, enrich promising candidates selectively rather than researching every link.**

### 11.14 Mari on the Map / broad travel roundups

> **Screen broad travel roundups rather than treating every destination as interesting. Surface a specific hotel, route, airline/service development, or destination idea only when it intersects strongly with my actual travel style or likely plans. Ignore generic travel-advisor promotion and listicle filler.**

### 11.15 Roadtrippers

> **Treat Roadtrippers as a possible source of specific road-trip stops and ideas, not as a reason to surface general national-park or travel lifestyle content. Extract only concrete places/routes that look unusually aligned with how we travel. Routine brand/editorial promotion can disappear.**

### 11.16 Hotel marketing (Schloss Elmau and similar)

> **A hotel I have stayed at can be a meaningful source, but do not surface routine seasonal marketing simply because I know the property. Surface a genuinely unusual package, concert/cultural event, restaurant development, or reason to return that fits my interests. Separate active-stay transactional correspondence from later promotional mail.**

### 11.17 Best of Journalism

> **Screen all recommended links cheaply against my Interests and Taste. Do not fetch and summarize every article. Use titles, authors/publications, metadata, and the Brain first; enrich only strong or ambiguous candidates. Surface a small number of strong matches plus worthwhile maybes, with a short explanation of why each might be for me. Keep rejected titles inspectable so I can correct missed interests. When I explain why a hit matters, treat that explanation as strong learning evidence rather than relying on click behavior.**

### 11.18 The New York Times — The Morning

> **Do not summarize a summary by default. Scan the contained items for something unusually aligned with my Interests or current concerns and tease only those hits. If nothing is specifically for me, say little or nothing. Preserve a path to the full issue. The goal is “anything here especially for Jon?” rather than another compressed news digest.**

### 11.19 Washington Post / general news digests

> **Treat broad daily digests primarily as hit-detection streams. Surface a contained story only when it strongly matches an Interest or deserves attention for another explicit reason. Do not reproduce the publisher's own prioritization as if it were personalization. More focused newsletters can be briefed according to their own purpose.**

### 11.20 NextDraft

> **Treat NextDraft as a curated link digest. Brief the day's organizing theme only if useful, then screen individual stories for unusually strong matches. Do not expand every clever headline into a full summary. Keep promising links available and let the rest disappear unless I inspect skipped items.**

### 11.21 Techmeme

> **Screen the technology stories for developments that materially intersect with my current interests—especially AI capabilities, developer tooling, Apple/mobile platforms, and changes that could affect the app family. Routine industry deal/news churn can stay suppressed. When a platform release could expand an actual harness, surface it with the concrete reason it matters.**

### 11.22 Puck daily digests

> **Treat Puck's multi-story digests as item-level material. Mine the issue for entertainment, media, sports-business, technology, or cultural stories that strongly match me rather than assuming the headline story is the relevant one. For a strong hit, preserve enough context to decide whether to open the underlying reporting. Do not summarize unrelated Puck verticals merely because they share one email.**

### 11.23 Feed Me

> **Give me a short orientation to the issue, then separately hunt for highly specific restaurant, food, media, business, and culture references that match my interests. A side mention can be more valuable than the headline story. Ignore routine fashion/beauty/lifestyle material unless something unusually intersects with my Taste or Interests. Preserve the author's specific observation or rationale around a surfaced nugget; that context is often why the mention is useful.**

### 11.24 Slow Boring / Matthew Yglesias

> **Treat Slow Boring as a writer I generally want available rather than a publication to filter aggressively. Brief the thesis enough that I can decide whether to read now, later, or skip. Elevate an issue when it strongly intersects with an existing Interest, but do not infer that skipping an issue means I no longer care about the writer/topic.**

### 11.25 Derek Thompson

> **Treat Derek Thompson as a high-signal writer on technology, economics, culture, and social change. Brief the central argument and tell me when an issue is unusually aligned with something I have been thinking about. Keep the full original available. Use my explicit reactions to refine which of his themes matter most, rather than learning from passive opens.**

### 11.26 Cartoons Hate Her

> **Treat Cartoons Hate Her as a conversational/cultural writer I may want to skim regardless of topic. Give me a concise orientation and call out when an essay overlaps strongly with my interests in culture, media, technology, or social behavior. Do not over-filter the publication into disconnected article nuggets; writer voice is part of why I subscribe.**

### 11.27 I Might Be Wrong / Jeff Maurer

> **Brief the core argument/joke premise and make the full issue easy to read. Surface an issue more strongly when it intersects with topics I clearly follow. Do not reduce the source to political topic tags; the writer's perspective and style are part of the subscription value.**

### 11.28 Noahpinion

> **Distinguish long-form essays from roundup issues. For essays, brief the thesis and relevance. For roundups, screen constituent links/topics and surface the parts most aligned with my technology/economics/culture interests. Do not force one processing style on both formats.**

### 11.29 Singal-Minded

> **Brief the main claim and why it may matter to me, keeping the original available. Treat media/journalism methodology and institutional-behavior stories as potentially higher signal than generic partisan controversy. Let explicit reactions, not reading time, refine the source policy.**

### 11.30 Astral Codex Ten

> **Brief substantive essays enough to decide whether to read and screen community/announcement-style posts much more aggressively. Do not treat every post from the same publication as equally valuable merely because the sender is high-signal.**

### 11.31 The Free Press

> **Process by message shape. For a single long-form feature, brief the thesis. For multi-item front-page/digest sends, screen constituent stories and surface only strong matches. Treat subscription marketing as disposable. Preserve enough source context that I can distinguish a genuinely interesting argument from generic outrage bait.**

### 11.32 The Dispatch / Jonah Goldberg / related newsletters

> **Separate author essays, focused newsletters, and subscription promotion. Brief real editorial pieces according to writer/topic relevance; aggressively suppress generic membership marketing. The fact that multiple newsletters share a publisher should not force them into one Handling policy.**

### 11.33 On the House

> **Mine restaurant/hospitality intelligence for openings, chef moves, notable operators, and specific New York dining developments I might plausibly care about. Surface concrete places/changes with the source's judgment; suppress generic industry chatter unless it intersects with another Interest.**

### 11.34 What's Alan Watching? / Alan Sepinwall

> **Treat this as television criticism rather than generic entertainment news. Surface essays/recaps when they concern shows I watch or broader TV-industry/critical themes I care about. Keep other issues available but low priority. If I reveal a strong showrunner/director/show interest, use that explicitly rather than inferring from every recap click.**

### 11.35 iOS Code Review

> **Surface developments that materially affect how I can build, test, architect, or operate my apps—especially agent/AI tooling, Xcode capabilities, Foundation Models, SwiftUI architecture, background execution, App Intents, and meaningful platform changes. Separate “interesting developer news” from an actual change in what the Cockpit/Galavant/Yes Chef harness can do. Ignore routine beta churn unless it changes a real implementation decision.**

### 11.36 Point-Free

> **Treat Point-Free as an architecture/tooling source relevant to patterns actually used in the app family. Surface library changes, techniques, or releases that could materially improve our current architecture. Do not surface every product update merely because we use Point-Free libraries. Explain the concrete seam or problem a new capability might affect.**

### 11.37 Benedict Evans

> **Screen the newsletter for AI/platform/technology analysis that is unusually relevant to my current thinking. Preserve the high-level argument when it is useful, but avoid surfacing every industry link. If a contained item changes the practical capability landscape for my apps, elevate it separately.**

### 11.38 Ticketmaster

> **Parse artist/event/date/location deterministically and match the event list against my music, comedy, theater, and cultural Interests plus realistic geography. Surface plausible hits; suppress the rest without summarizing the promotional email. A known favorite should be a strong hit. A generic “popular near you” recommendation is not evidence of Interest. Preserve ticket link and date/venue for surfaced events.**

### 11.39 DPAC / Carolina Theatre / local venue streams

> **Treat venue email as an event inventory. Match performers, films, talks, and special events against my Interests and local-life Taste. Surface only plausible hits and unusual events. Venue marketing language should not affect ranking. If a venue announces many events, show the few for me and keep the rest inspectable.**

### 11.40 9:30 Club / out-of-market venue streams

> **Use the same event-matching model but account for geography. A very strong artist Interest may justify surfacing an out-of-market show; routine venue listings should not. Do not treat a venue subscription as evidence that I want every event in that city.**

### 11.41 Silverspot Cinema

> **Mine weekly movie listings for films, directors, actors, repertory screenings, or special events that strongly match my film Interests. Generic release promotion can disappear. A strong director Interest should turn an otherwise ordinary listing into a meaningful hit. Keep showtime/ticket context only for surfaced candidates.**

### 11.42 New Yorker Festival / cultural festivals

> **Treat lineup announcements as structured candidate lists. Match speakers/performers/topics against cultural Interests and realistic travel/geography. Surface a small set of compelling participants or combinations rather than the whole lineup.**

### 11.43 Ultimate Comics

> **Treat store promotions as release lists, not as shopping email. Surface titles/creators/collections tied to strong comics Interests—especially Legion of Super-Heroes and other explicitly known favorites. Ignore generic discount language unless it applies to something I actually care about.**

### 11.44 SoundCloud / broad music discovery mail

> **Screen artists/genres/projects against known music Interests. Surface a new release or discovery only when there is a credible match; do not treat the platform's editorial recommendation as personal relevance. Allow corrections to strengthen or weaken artist/genre Interests explicitly.**

### 11.45 Blank Check / podcast membership notices

> **Treat episode announcements as content availability, not urgent email. Surface an episode when the film/director/topic strongly matches my Interests; otherwise keep it available quietly or clear according to source policy. Do not infer a durable film Interest merely because I subscribe to the podcast.**

### 11.46 Woodworking retail — family policy

Examples include Klingspor, SawStop, JessEm, and similar tool retailers.

> **Treat woodworking retail mail as a filtered equipment/opportunity stream. Surface a product, class, technique, or sale only when it intersects with an active or durable woodworking interest and is unusually useful. Do not show generic store promotions. A class or specialty tool can be more interesting than a percentage-off campaign.**

### 11.47 Woodworking instructional sources

Examples include The Wood Whisperer Guild and Jonathan Katz-Moses educational/event mail.

> **Brief/screen instructional material for techniques, classes, projects, or events that could plausibly improve current woodworking practice. Distinguish educational value from merchandise. Surface a specific lesson/event rather than generic creator promotion.**

### 11.48 Transactional reservations/tickets/travel correspondence

> **Extract the real-world fact, date, reservation/ticket context, change, deadline, or request. Keep consequential correspondence prominent when Jon may need to respond. Once a confirmation is understood and any needed Cockpit context/custody is fulfilled, it may be eligible for Clear under source-specific policy. Do not mix these messages into editorial Travel or Events briefs merely because they mention hotels/restaurants/venues.**

### 11.49 Account/billing/payment notices

> **Surface concrete consequence and deadline, not marketing wrapper. Payment-method expiry, failed renewal, account access, or a meaningful statement notice can require attention even if emotionally unimportant. Routine statements/confirmations may be summarized and cleared only according to explicit source policy.**

### 11.50 Generic retail / disposable promotion

> **Default to suppression unless a specific product/category crosses a known Interest or an explicit source policy says the stream is worth scanning. Do not waste model effort manufacturing summaries of generic sales copy.**

---

## 12. Source Handling is not automatically Personal Knowledge

A Handling statement can include source-specific instructions that do not belong in Jon Brain.

Example:

> “For this travel newsletter, ignore general promotional destination material and extract specific hotels/ideas with rationale.”

That belongs in Handling.

By contrast:

> “Jon has no interest in African safari travel.”

is cross-source Taste/aversion and belongs in Personal Knowledge if explicitly taught/confirmed.

Similarly:

> “For iOS Code Review, surface changes that materially expand the app-family harness.”

is source purpose, not a statement about Jon's identity.

The systems cooperate without collapsing into one another.

---

## 13. Source disposition remains independent of intelligence value

Processing outcome must not accidentally dictate Gmail action.

Examples:

- a newsletter may be mined successfully, preserved in Cockpit, then cleared/archived upstream,
- a market brief may collapse twenty promotional messages and then clear the batch,
- a personal correspondence may be summarized and highlighted but remain in Inbox,
- a reservation confirmation may be extracted and then cleared after custody/attention obligations are satisfied,
- a filtered link digest may be archived while its surfaced Finds remain in Reading.

The existing Product Model rule remains:

> **Source disposition and Cockpit retention/custody are independent decisions.**

The same applies to deduplicated multi-address messages: one semantic interpretation may correspond to multiple provider mutations.

---

## 14. Email surface implications — not yet final UI

The corpus suggests that the primary Email/Daily surface should group by **value delivered**, not Gmail category or sender.

An illustrative—not final—shape:

```text
TODAY

Need Your Attention
  4

Wine Market
  3 worth seeing from 21 offers

Reading
  5 for you
  34 skipped

Cooking
  3 recipes / techniques

Travel & Food
  2 finds

Events
  2 plausible hits

Development
  1 important capability change

Everything Else
  safely handled / available
```

Important cautions:

- do not prematurely turn every domain lens into a permanent tab/section,
- sections should exist because they deliver value in the current corpus,
- direct correspondence requiring attention must remain visually distinct from editorial Finds,
- source Handling and skipped-material access should be reachable without making Daily feel like settings administration,
- viewing chrome should create consistency when descending into heterogeneous material.

The next design step should work screen-by-screen from these real jobs rather than from a generic mailbox layout.

---

## 15. Domain lenses are useful, but not a universal ontology

The corpus supports useful reasoning lenses such as:

- Wine
- Cooking / Food
- Travel
- Restaurants
- Film / TV / Music / Culture
- Development / AI
- Woodworking
- Local events

These lenses can help:

- choose relevant Personal Knowledge projections,
- group a Daily briefing,
- select extraction schemas/prompts,
- choose destination handoffs.

They should not imply one universal taxonomy into which every incoming thing must be forced.

A Feed Me nugget can simultaneously be restaurant intelligence, media/culture context, and a Reading candidate. The product should preserve useful semantics without demanding one canonical folder.

---

## 16. Implementation direction without premature abstraction

Near-term implementation should favor app-local composition over a generic `NewsletterEngine` or platform abstraction.

Useful concrete seams may include:

- Gmail ingestion client,
- deterministic message normalization/deduplication,
- content/link/section extraction,
- source Handling lookup/projection,
- relevant Personal Knowledge projection,
- local/on-device model tasks where adequate,
- selective cloud LLM reasoning,
- selective web enrichment,
- Find creation/presentation,
- source-action coordination.

Do not extract a shared `SourceIntelligenceKit` merely because the concept feels general. Earn the seam through real Cockpit implementation and additional consumers.

The semantic contract is more important than the first set of Swift types.

---

## 17. Governing principles

1. **Personalized briefing, not better inbox.**  
   Cockpit reduces incoming material to attention, Finds, useful briefs, and safe silence.

2. **Source purpose beats newsletter taxonomy.**  
   Ask what Jon wants from the source, not what marketing category the source belongs to.

3. **Sender does not determine processing.**  
   Message and section shape matter.

4. **Interpret below the email boundary.**  
   A side mention can matter more than the headline.

5. **Collapse volume before adding intelligence chrome.**  
   Hundreds of messages must become a small number of meaningful briefing units.

6. **Spend intelligence in proportion to relevance.**  
   Parse cheaply, batch-screen, enrich selectively, summarize deeply only when earned.

7. **Preserve source rationale.**  
   Extraction should not erase why a trusted source recommended something.

8. **Skipped material should be inspectable.**  
   Transparency creates trust and a high-value correction loop.

9. **Explicit explanation beats passive telemetry.**  
   “Why this matters to me” is strong evidence; click/dwell behavior is weak.

10. **Specific filtering guidance need not become identity.**  
    Use corrections immediately at the narrowest useful layer; synthesize upward only when warranted.

11. **Handling and Personal Knowledge cooperate but remain separate.**  
    Source-specific editorial purpose is not automatically a Brain claim.

12. **Source disposition remains independent.**  
    Understanding, preservation, and Gmail Clear/Archive/Trash are separate decisions.

13. **AI proposes the operating model; Jon governs exceptions.**  
    Onboarding should infer Handling, not demand taxonomy administration.

14. **The original remains reachable.**  
    Cockpit adds intelligence and viewing chrome without pretending its summary replaces the source when fidelity matters.

---

## 18. Immediate next step

The conceptual model is now sufficiently grounded to stop expanding email ontology.

The next product-design exercise should be:

> **Design the ordinary Cockpit Email/Daily screen from the real jobs above, screen by screen and decision by decision.**

Questions to answer there include:

- What appears at the top of an ordinary morning?
- How are direct correspondence and consequential transactional mail distinguished from editorial Finds?
- How do consolidated briefs such as Wine Market expand?
- How does a Find open into Cockpit viewing chrome?
- Where does `Why this is here` live?
- How does `Not interested` optionally become `Tell You why`?
- How does `3 for you · 17 skipped` expand without becoming review work?
- Where can Jon see/change a source's human-language Handling statement?
- Which actions are source actions (`Clear`) versus Cockpit actions (`Keep`, `Read Later`, specialist handoff)?
- How does the screen remain a lifestyle briefing rather than a productivity dashboard?

Do not design additional first-class context, Watch, Nudge, or generic agent machinery to solve these questions. The current corpus and near-term harnesses are enough.