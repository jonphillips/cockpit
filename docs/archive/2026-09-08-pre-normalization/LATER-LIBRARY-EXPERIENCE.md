# Cockpit Later and Library Experience

**Status:** Working product/interaction decision  
**Date:** 2026-09-08

## Purpose

This document defines the current product model for Cockpit's two retained-content experiences:

- **Later** — material the user explicitly wants another chance to read/watch/consider.
- **Library** — durable personal reference material Cockpit should catalog and make meaningfully retrievable over time.

It extends:

- `docs/CONTENT-EXPERIENCE.md`
- `docs/CONTENT-STREAM-MODEL.md`
- `docs/IPAD-FIRST-EXPERIENCE.md`
- `ARCHITECTURE.md`

The distinction exists because one `Keep` bucket was trying to represent two materially different intents.

The governing model is:

```text
Today
Edition
Later
Library
Settings
```

`Edition` is the current user-facing name for the rolling Content newspaper. `Content` remains a useful internal/product-domain term for the broader subsystem.

---

## 1. Core distinction

### Later

Later means:

> **I do not want this to disappear with the edition. Give me another chance at it.**

Later is deferred attention, not durable reference custody.

Typical examples:

- an essay the user wants to read when there is more time,
- a YouTube video worth watching later,
- a restaurant/hotel piece that looks interesting but does not deserve permanent catalog status yet,
- an Essential article the user wants to move out of the active Edition without losing it.

### Library

Library means:

> **This belongs in my durable personal corpus. I expect Cockpit to remember, catalog, enrich, and help me retrieve it later.**

Typical examples:

- Andrew Harper issues/reports,
- durable travel references,
- technical papers,
- useful PDFs/reports,
- articles or videos explicitly promoted from Later,
- recurring Stream material admitted automatically under an explicit Library policy.

### Product law

> **Later preserves explicit deferred attention. Library preserves durable resources.**

---

## 2. Top-level navigation

For now, Later and Library each earn their own primary destination.

The current shell is:

```text
Today
Edition
Later
Library

Settings
```

This is intentionally more explicit than hiding both under `Saved`.

The four primary content/life modes answer different questions:

```text
Today      What should register now?
Edition    What is worth consuming?
Later      What did I deliberately defer?
Library    What durable material do I want Cockpit to retain and understand?
```

### Navigation principle

> **Primary navigation reflects distinct recurring modes of use, not every important subsystem.**

`Following`/Stream management remains under Settings rather than becoming another primary destination.

---

## 3. Edition to Later

Saving from Edition should normally mean **Save for Later**, not `Keep` with ambiguous semantics.

Conceptually:

```text
Edition Item
   ↓
Save for Later
   ↓
Later
```

Saving to Later resolves the Item from the active Edition while preserving it for intentional return.

A user should not have to both `Save for Later` and then separately `Clear` the Item from Edition.

### Product principle

> **Save for Later means “take this out of the newspaper, but do not let me lose it.”**

Opening an Item is still `Seen`, not saved.

---

## 4. Later is always explicit

Cockpit should never silently decide that an Item belongs in Later.

Later reflects direct user intent.

Admission paths may include:

- Save for Later from Edition,
- Add to Later from Library,
- Share/Capture directly to Later where a concrete interaction earns it.

AI may recommend that something seems worth saving, but the membership itself should be explicit.

### Product law

> **Later is never automatic.**

---

## 5. Later does not silently age away

Once the user explicitly saves something to Later, Cockpit should not quietly delete it after an arbitrary aging window.

That would violate the reason Later exists.

Older Items may:

- fall lower in ordinary sort order,
- become visually quieter,
- become candidates for Cleanup,
- receive richer summaries when Cockpit helps resolve the backlog.

But they remain until explicit removal or promotion.

### Product law

> **Later may get stale; it may not silently forget.**

---

## 6. Later must actively resist becoming a graveyard

Later should not become a second version of a 400-subscription YouTube graveyard.

Cockpit should provide a first-class **Cleanup** experience when deferred material accumulates or ages.

A likely trigger is age-based and/or volume-based, for example:

```text
12 items have been in Later for 30+ days
Clean Up
```

The language should remain calm rather than guilt-inducing.

Avoid:

- overdue counts,
- streaks,
- productivity scores,
- nagging daily notifications,
- automatic deletion.

### Cleanup principle

> **Later never silently deletes; Cockpit actively helps the user decide when Later has gone stale.**

---

## 7. Later Cleanup experience

Cleanup should be a purpose-built resolution mode rather than simply filtering the ordinary list by age.

Each stale Item can receive a slightly richer AI-assisted orientation than it had when first saved.

Example:

```text
Andrew Harper · Burgundy hotels
Saved 41 days ago

Cockpit's take:
Strong reference for current Burgundy planning.
Probably worth keeping permanently.

Recommended: Move to Library
```

Another:

```text
YouTube · Xcode workflow video
Saved 47 days ago

Cockpit's take:
Mostly superseded by newer material you already saw.
Probably safe to remove.

Recommended: Remove from Later
```

The user can rapidly assign one of three outcomes:

- **Keep in Later**
- **Move to Library**
- **Remove from Later**

The UI should support multi-select / bulk acceptance of recommendations with easy exception editing before applying.

AI proposes; deterministic app operations perform the actual membership changes after user approval.

### Useful recommendation inputs

Cockpit may consider:

- age,
- whether the Item has been opened,
- whether newer material supersedes it,
- whether its Subjects remain active in recent Library searches,
- whether it looks reference-worthy rather than merely consumable,
- whether related Library material already exists,
- whether current Personal Knowledge/context still makes it relevant.

These inputs should improve judgment, not become a user-visible scoring system.

---

## 8. Library admission is stronger and may be automatic

Library admission represents a stronger custody/catalog intent than Later.

It can happen through:

- explicit `Add to Library`,
- promotion from Later,
- direct PDF/report import,
- Share Sheet / Capture to Library,
- **automatic admission under an explicit Stream Library policy**.

The last case is important.

Example:

```text
ANDREW HARPER

Edition Handling:
Surface especially relevant new material.

Library Handling:
Catalog every new issue.
Preserve downloadable original when available.
```

A new issue can therefore be admitted to Library even if Cockpit decides it does not deserve placement in that day's Edition.

### Product laws

> **Library admission and Edition selection are independent decisions.**

> **Library may be automatic under an explicit user-approved admission policy.**

---

## 9. Automatic Library policies are prospective only

Turning on an automatic Library policy should apply only to material arriving from that point forward.

It should **not** silently backfill years of prior issues or initiate a large historical crawl/download.

If historical import is ever useful, it should be a separate explicit operation with clearly bounded scope.

V1 decision:

> **No automatic backfill.**

Stopping/changing a Library admission policy affects future admission; it does not silently delete Items already cataloged.

---

## 10. Later and Library are memberships, not duplicate Items

The same underlying Content Item may simultaneously belong to Edition, Later, and/or Library at different moments.

Conceptually:

```text
Content Item
   ├── Edition membership
   ├── Later membership
   └── Library membership
```

This should not create duplicate copies of semantic identity, provenance, summary, Subjects, or Publisher metadata.

Example:

An Andrew Harper Burgundy report may already be in Library because of automatic admission. While planning Burgundy, the user can also `Add to Later` so it becomes part of current deferred attention.

Removing it from Later does not remove it from Library.

### Product principle

> **Later and Library express different relationships to the same underlying material.**

---

## 11. Library is not an unread queue

A Library Item may be:

- unread,
- partly read,
- fully read,
- a reference the user repeatedly returns to,
- something retained mainly for future search/context.

Read state may be useful presentation metadata, but it is not the organizing principle of Library.

Do not turn Library into another completion system.

### Product principle

> **Library means worth retaining, not “I still owe myself a read.”**

---

## 12. Library enrichment: Subjects, not manual tags

Cockpit should automatically enrich Library Items with semantic metadata rather than require user tag maintenance.

Likely derived metadata includes:

- concise summary,
- Interest Area,
- Subjects,
- people,
- places,
- Publisher/Creator,
- Stream/provenance,
- media/content type,
- why the Item mattered or was admitted,
- relationships to other retained material where useful.

Examples:

```text
Burgundy
Beaune
Meursault
Wine travel
Hotels
Restaurants
```

These may appear visually as chips/facets, but the user should not be asked to maintain a tag database.

### Product principle

> **Tags are presentation; Subjects are meaning.**

Avoid V1 workflows such as:

- Add tag
- Rename tag
- Merge tags
- Clean up tags

unless real use later proves they are needed.

---

## 13. Library search is semantic, not merely literal

Searching Library for `Burgundy` should not be limited to Items that contain the exact string.

Retrieval should be able to combine:

- literal text search,
- canonical Subject/entity matches,
- related places/entities,
- semantic similarity,
- structured metadata such as Publisher/Stream/Interest Area.

Thus a Burgundy search may find Items about Beaune or Meursault that are clearly semantically part of the same planning corpus.

The user should not need to understand whether `Burgundy` is technically a tag, entity, Subject, or semantic query.

---

## 14. Recent searches are temporary attention

The Library should prominently expose recent searches as tappable shortcuts.

Example:

```text
Recent
Burgundy · Dolomites · PTA · SwiftUI · Riesling
```

Behavior should be simple:

- tapping reruns the search,
- newest/repeated searches rise,
- old searches naturally fall away,
- eventually they disappear from the prominent Recent list,
- disappearance does not remove any Subjects or Library Items.

This creates a useful working-memory layer without inventing `Projects` merely because the user is temporarily planning Burgundy.

### Product principle

> **Subjects are durable meaning. Recent searches are temporary attention.**

---

## 15. Library browse structure

V1 Library should probably combine:

- prominent search,
- recent searches,
- Interest Area browse,
- automatically emerging Subject facets,
- Publisher/Creator or Stream grouping where useful,
- download/offline status where relevant.

A publisher/Stream may naturally look collection-like without requiring a separate user-managed Collections model.

For example, Andrew Harper can provide a natural browse grouping of retained issues because those Items already share Stream/Publisher metadata.

Do not introduce folders/collections until a real user need is demonstrated.

---

## 16. Storage doctrine: sync understanding, not payloads

Library must honor Cockpit's existing artifact-custody/storage architecture.

For most retained material, synced canonical state should be lightweight metadata/understanding such as:

- stable identity,
- title,
- canonical URL / provider locator,
- Publisher/Creator,
- Stream/provenance,
- Interest Area,
- Subjects/entities,
- summary/interpretation,
- admission reason,
- relevant timestamps/state,
- lightweight preview metadata.

Large underlying assets should normally **not** be CloudKit-synced merely because the Item is in Library.

Examples of device-local or re-fetchable payloads:

- full article HTML,
- newsletter body,
- PDFs,
- transcripts,
- video,
- large images/attachments.

### Architectural principle

> **Library syncs understanding, not payloads.**

And:

> **Canonical synced state should preserve meaning and enough provenance to reacquire content when possible; large assets are opt-in custody, not default sync payload.**

---

## 17. Library membership and device download are separate

Library membership is durable synced catalog state.

Offline/download state is device-local.

Conceptually:

```text
In Library             synced canonical metadata
Downloaded on iPad     device-local asset availability
Downloaded on iPhone   independent device-local asset availability
```

A Library Item might therefore show:

```text
Andrew Harper · Burgundy Report 2026
Downloaded on this iPad · 18 MB
```

while the iPhone knows the report exists but does not carry the PDF.

Likely actions:

- Download
- Remove Download
- perhaps later `Keep this Stream available offline on this iPad`

Offline behavior should not imply CloudKit blob synchronization.

---

## 18. Artifact custody is not the same as Library

Cockpit may retain source material for processing, provenance, recovery, or Stream policy without surfacing every retained Artifact in Library.

Likewise, an Item may be in Library while its large underlying bytes are not locally present on the current device.

### Product law

> **Cockpit custody is technical/product responsibility. Library is a user-facing durable corpus. They are related but not identical.**

---

## 19. Removal semantics must be precise

Actions should affect only the intended layer.

### Remove from Later

Removes Later membership only.

If the Item is also in Library, it remains there.

### Move to Library

Adds Library membership and ordinarily removes it from Later as part of the cleanup/resolution action, unless the user explicitly wants both memberships.

### Remove from Library

Removes durable Library membership and normally removes any local downloaded asset associated only with that Library custody decision.

It does not automatically mutate the original website/email/provider artifact.

### Remove Download

Deletes local asset bytes from the current device while preserving Library membership and synced metadata.

A future `Forget completely` operation, if ever needed, should remain explicitly different from these membership/device actions.

---

## 20. Relationship to Streams

Streams can influence both Edition and Library through independent policies.

Example:

```text
ANDREW HARPER STREAM

Edition:
Screen new issues for especially relevant material.

Library:
Automatically catalog every new issue prospectively.

Transport/custody:
Preserve or reacquire original according to supported provider behavior.
```

Stopping a Stream stops future recurring ingestion/admission but should not destroy existing Later/Library memberships or durable knowledge.

Changing automatic Library admission should be prospective.

### Product principle

> **A Stream may feed Edition selectively and Library comprehensively.**

---

## 21. Relationship to Personal Knowledge

Library is not the Jon Brain.

A Library Item is retained material; Personal Knowledge is synthesized understanding about the user.

Library use may provide evidence when the user explicitly explains why something matters, but mere retention should not automatically create broad permanent Taste/Interest claims beyond what is justified.

Conversely, Personal Knowledge can improve Library search, Cleanup recommendations, and Edition relevance.

---

## 22. What Later/Library must not become

### Later must not become

- an unread-count machine,
- a second task list,
- an automatically filled recommendation bucket,
- an infinite guilt backlog,
- a silent auto-expiring queue.

### Library must not become

- a manually tagged filing cabinet,
- a universal cloud document warehouse,
- a duplicate copy of every artifact Cockpit has ever processed,
- a forced-read archive,
- a folder/collection taxonomy project before real use earns it.

---

## 23. Design laws

1. **Today, Edition, Later, Library, and Settings are the current primary shell labels.**
2. **Edition is the user-facing rolling newspaper; Content remains the broader product/domain concept.**
3. **Later means explicit deferred attention.**
4. **Library means durable personal reference corpus.**
5. **Saving from Edition goes to Later and resolves the Item from the active Edition.**
6. **Later is never automatic.**
7. **Later never silently ages away.**
8. **Cleanup is a first-class Later anti-graveyard mechanism.**
9. **Cleanup uses AI to summarize/recommend; the user approves deterministic membership changes.**
10. **Library may receive automatic admission under an explicit Stream policy.**
11. **Automatic Library admission is prospective only; no automatic backfill.**
12. **Edition selection and Library admission are independent.**
13. **Later and Library are memberships around the same underlying Item, not duplicated semantic records.**
14. **Library is not an unread queue.**
15. **Library uses automatic Subjects/semantic enrichment rather than manual tag management.**
16. **Recent searches express temporary attention and naturally fall away.**
17. **Library syncs understanding/metadata; large payloads remain re-fetchable or device-local unless explicit custody requires more.**
18. **Library membership and per-device download state are separate.**
19. **Artifact custody is not synonymous with Library membership.**
20. **Removal actions must state exactly which membership or local payload they affect.**

---

## 24. Open questions / validate in UI and implementation

The model is sufficiently resolved to begin visual/implementation work. Remaining questions are concrete:

### Later ordinary view

- Default sort: newest-saved first, recently interacted, or a Cockpit-assisted relevance sort?
- Should Later expose Interest Area/Subject filters prominently, or remain intentionally simpler than Library?
- What age/volume heuristic should make Cleanup visible without becoming nagging?

### Cleanup

- Is `30+ days` the initial deterministic threshold, or should the trigger combine age + item count?
- Should AI recommendations be generated lazily when Cleanup opens or progressively maintained in the background opportunities Cockpit already has?
- Exact bulk interaction for `Keep in Later / Move to Library / Remove`.

### Library

- Exact balance among recent searches, Interest Areas, Subjects, Publisher/Stream groupings, and chronological recent additions.
- Whether an automatically admitted Stream deserves an obvious Library-level `Always download on this iPad` control in V1 or only manual per-item download initially.
- What durable asset types require stronger custody because the authoritative original may disappear.

### Cross-document terminology

- Existing docs still use `Content` as the user-facing destination and `Keep` as a broad retained action in several places. A repository-wide consistency pass should update those passages to the newer `Edition`, `Later`, and `Library` semantics without mechanically replacing technical uses of `content`, `keep`, or `custody`.