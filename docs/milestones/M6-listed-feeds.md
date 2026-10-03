# M6 — Listed feeds (S-l1 … S-l3)

> **Build order, architect-drafted 2026-10-03 with DECISIONS §33.** Three slices that let an RSS Stream
> be Listed instead of Screened, read in a Feeds tab, with an indicator on Today. **Not dispatched:**
> §33 is PROPOSED, and S-l1 carries a schema change and a new synced table, both of which need Jon's
> yes. When Jon resolves §33, the architect carries it into the live docs (AGENTS.md "Shell naming",
> `CONTENT-STREAM-MODEL.md` Handling, `IMPLEMENTATION-CONTRACT.md`, `TODAY-EXPERIENCE.md`, ADR-0002 D11)
> and points `NEXT_UP.md` at S-l1 in the same PR. Each block is self-contained: send it to the executor
> as-is. Branch per slice: `m6/s-lN-short-slug`, one PR each, tick the box here in the PR that completes
> it.

**Decision behind these slices.** DECISIONS §33, settled against `docs/mockups/M6-listed-feeds.html`,
which is the visual spec. Jon settled two points on 2026-10-03: a Feeds tab rather than a sheet over
Today, and a seven-day window. The newest-headline teaser and the name "Feeds" are built as the mockup
shows. If the device pass rejects either one, that's an amendment to §33, not a quiet change.

**Dependency shape.** **S-l1 → S-l2 → S-l3**, strictly. S-l1 is core only and adds no UI, so nothing
can choose Listed until S-l2 ships the tab that shows Listed stories. S-l3 reads S-l1's model and
switches to S-l2's tab. The set floats against S-join and S-c4 (Gate 5), which touch none of these
files.

**Styling.** The Morning Edition foundation exists (`CockpitApp/Theme`: `Theme`, `SectionLabel`,
`HeadlineRow`), so these slices adopt it directly rather than shipping in default styling first. Reuse
the existing type roles and components. Don't add new fonts, colors or spacing constants without
naming the gap in the handoff report. Chrome is the system's (§31): `TabView`, `NavigationSplitView`,
toolbars, swipe actions, context menus.

- [ ] S-l1 — Listed posture: `StreamHandling.listed`, Edition exclusion, `listedPieceStates`, the listed-feeds model
- [ ] S-l2 — Feeds tab: the split view, Dismiss, Later, open through the system, and choosing Listed in Following
- [ ] S-l3 — Today's Feeds door: counts per feed, the newest headline, "Feeds N" on the index line

## Standing rules for every slice

- Verify with `swift test` (CockpitCore), `swiftlint lint --strict`, and an unsigned app build, run
  through `quiet-run` (AGENTS.md). No Simulator or device driving. Name any device-only risk in the
  handoff report and stop.
- Behaviour lives in `@Observable` models or pure functions in `CockpitCore` and is tested there. Views
  don't touch the database.
- **Listed is never judged (§33).** No model call, no `LLMClientKit` import, no generated summary, and
  no Personal Knowledge read or write anywhere in these slices. Everything shown comes from the feed.
- Never change stored `ContentPiece.publisher` / `creator`: `ContentIdentity.derive` hashes the
  publisher, so rewriting it forks identity.
- Gmail is untouched. Nothing here changes Gmail ingest, routing, Today role sections, dispositions, or
  the Process queue's membership rules.
- Cockpit never fetches an article page. The only network traffic is the feed poll that already exists.

---

### S-l1 — Listed posture: `StreamHandling.listed`, Edition exclusion, `listedPieceStates`, the listed-feeds model

**Why.** DECISIONS §33. Jon wants some RSS Streams listed in full rather than screened by the Edition.
This slice adds the posture, keeps Listed pieces out of judgment, and builds the read model and the
opened/dismissed state that S-l2 and S-l3 display. It ships no UI.

**Build.**
- **Posture.** `StreamHandling` gains `case listed` (raw value `"listed"`). `following` keeps its raw
  value and means Screened. Add `handling` to `StreamDraft`, defaulting to `.following`, and have
  `StreamOperations.save` write it. Saving a draft with `.listed` forces `isEssential = false` (§33:
  Essential doesn't apply). A Gmail-transport draft can't be saved as `.listed`: throw a typed error.
  **No migration for the column**: `streams.handling` is `TEXT`. Confirm there's no CHECK constraint or
  stored-value validation; if there is one, stop and report instead of widening it quietly.
- **Edition exclusion.** Add `ListedFeeds.contentPieceIDs(in:)`: every ContentPiece with at least one
  Artifact whose Stream is `.listed`. A piece that reached Cockpit through both a Listed and a Screened
  Stream counts as Listed. `EditionPlanner.buildPlan` unions this set into `excludedContentPieceIDs`
  for both new pieces and carryovers. Keep it **separate from `CurationRouting`**, which is Gmail role
  routing; don't widen `editionExcludedContentPieceIDs`.
- **Table** `listedPieceStates`, synced: `contentPieceID` (TEXT PRIMARY KEY, the ContentPiece ID),
  `openedAt` DATETIME NULL, `dismissedAt` DATETIME NULL. Register it in `CockpitCloudSync`'s table list
  beside `LaterMembership`. One migration, named for this slice. **Don't reuse `todayAttentions`**: it's
  device-local, Gmail-only and terminal, and a Dismiss here is undoable.
- **Window policy.** `ListedFeedPolicy.window = 7 days`. A piece's **listed date** is `publishedAt`,
  else the earliest `acquiredAt` among its Listed Artifacts. A piece is **in the window** when its
  listed date is within seven days of `now`. Pass `now` and a calendar in so tests are deterministic.
- **Read model.** `ListedFeedsRequest` (a `@Fetch` request, like `FollowingRequest`) returns:
  - **sources**: the active Listed Streams in Following order (the order `FollowingRequest` uses), each
    with `name`, `publisher` and its **new count**;
  - **items**: one per in-window, undismissed piece, with title, creator, `canonicalURL`, listed date,
    the owning Stream (the first Listed Stream in Following order, so a story in two feeds appears
    once), `isOpened`, and a **description**: the owning Artifact's `rawSourceText` through
    `HTMLText.normalizedText`, as one line, with an empty string when there is none;
  - **totals**: the overall new count and `showsPublisherLabel` (true when sources span more than one
    `publisher`);
  - **New** = in window, not opened, not dismissed.
- **Model.** `ListedFeedsModel` (`@Observable`) serves the tab and Today. It provides `recordOpened(id:)`
  (sets `openedAt` once and never clears it), `dismiss(id:)`, `dismissAll(streamID:)` where `nil` means
  every listed item, and `undo()`, which reverses the last dismiss or dismiss-all as one step by clearing
  those rows' `dismissedAt`. Later and Library go through the existing destination operations, not
  through new code.
- **No aging job.** The window is a query filter. Pieces Jon never touches get no `listedPieceStates`
  row and simply fall out of the query. Don't delete ContentPieces or Artifacts.

**Prove (core).**
- `StreamHandling.listed` round-trips through `StreamOperations.save`. Saving as Listed clears
  `isEssential`. A Gmail draft saved as Listed throws.
- The planner never offers a Listed piece, new or carried over. A piece with Artifacts from a Listed
  and a Screened Stream is excluded. Switching that Stream back to `.following` makes its future pieces
  candidates again. Dismissed state is untouched by the switch.
- Window: with `now` fixed, a piece published 6 days 23 hours ago is in and one published 7 days 1 hour
  ago is out. A piece with no `publishedAt` uses its earliest Listed `acquiredAt`. A first poll that
  brings 20 entries spanning three weeks lists only the last seven days.
- One story in two Listed Streams yields one item, owned by the first Stream in Following order, and
  counts once in the total and once in that Stream's count.
- New counts exclude opened and dismissed pieces. `recordOpened` is idempotent and keeps the first
  `openedAt`.
- `dismissAll(streamID:)` dismisses only that Stream's items. `dismissAll(nil)` dismisses everything
  listed. `undo()` restores exactly the last batch, and a second `undo()` does nothing.
- `showsPublisherLabel` is false for five NYT Streams and true once an Eater Stream is added.
- The description is deterministic plain text from the feed, and empty when `rawSourceText` is nil.

**Do not.** Add UI. Call a model or generate summaries. Fetch article pages or images. Add per-feed
keyword filters. Add a background aging or deletion job. Put Listed pieces in an Edition, in
`EditionEntry`, or in the Process queue.

**Device-only risks (name them).**
- Sync: a device still on a build without `StreamHandling.listed` can't decode a Listed Stream row.
  Report how the existing decode path fails (skips the row, or fails the whole fetch), and don't add a
  compatibility shim in this slice.

**Done when.** Core tests prove the posture, the exclusion, the window, the per-Stream counts and the
dismiss/undo state. The app builds unchanged.

**Sequencing.** Touches `Domain.swift`, `StreamOperations.swift`, `EditionPlanner.swift`,
`CockpitCloudSync.swift`, a new migration, and new `ListedFeeds*.swift` files in `CockpitCore`. Branch:
`m6/s-l1-listed-posture`.

---

### S-l2 — Feeds tab: the split view, Dismiss, Later, open through the system, and choosing Listed in Following

**Why.** DECISIONS §33. Jon wants a place to go for Listed stories rather than a temporary sheet, with
the source of every story visible when they share one screen. This slice also makes Listed choosable,
because the tab now exists to show what a Listed Stream brings in.

**Build.**
- **Shell.** `ShellModel.Destination` gains `.feeds`, between `.process` and `.later`. `CockpitApp`'s
  `TabView` gets `Tab("Feeds", systemImage: "dot.radiowaves.up.forward", value: .feeds)`. **No badge**
  (§33: Today's counts are orientation, not a badge to clear). Update `ShellModel`'s doc comment.
- **FeedsView** in a system `NavigationSplitView`, per the mockup's second and third frames:
  - **Sidebar:** the title "Feeds", then **All feeds** with the total new count, then each Listed
    Stream grouped under a header with its `publisher`, each with its new count. Selection is kept in
    the tab's own state, so it survives tab switches. The default is All feeds.
  - **List:** a header with the selected source's name in `Theme.queueTitle` and a line "N new · the
    last seven days". Items run newest first under day headers (Today, Yesterday, then weekday names
    for the rest of the window), using `SectionLabel` for the headers. A row is a kicker, the headline
    in `Theme.headline`, then the creator and the one-line description in `Theme.byline`, with the
    time trailing in `Theme.meta`. Reuse `HeadlineRow` if it fits; if it doesn't, name the gap.
  - **Kicker:** the Stream's `name` in small caps, accent ink, shown only in All feeds. When
    `showsPublisherLabel` is true, append " · " and the Stream's `publisher` in tertiary ink.
  - **New** rows carry the existing unread dot. **Opened** rows dim and show a small "Opened" tag.
  - **Tap:** `openURL(canonicalURL)` through the system, as Daily links do (§29), then
    `recordOpened`. Never open it in Cockpit's web view or the quick-look sheet.
  - **Swipe:** leading **Later**, trailing **Dismiss** (with Undo). The context menu has Later, Library
    and Dismiss.
  - **Toolbar:** **Dismiss all** clears the selected source (all items in All feeds), with Undo through
    the existing Undo affordance. Refresh calls the existing `acquireOnLaunchOrRefresh()`.
  - **Empty state:** `ContentUnavailableView` with the text "Nothing new in your feeds" and the
    description "Stories from feeds you list appear here for seven days." With no Listed Streams at
    all, the description instead points to Following → Add Stream.
  - **Compact width:** the system's split-view collapse (sidebar becomes a pushed list) with no custom
    work. The iPhone tab count is a known open question (§33), so don't solve it here.
- **Add Stream.** After discovery, the sheet adds a section titled "How should Cockpit treat it?" with
  two options. **Screen it**: "The Edition judges each story and keeps only what's worth your time.
  Most are declined." **List every story**: "Every new story goes to the Feeds tab for seven days.
  Nothing is judged." The default is Screen it. Its footer says "You can change this later in
  Following." Show the section only for RSS and Atom.
- **Following → edit Stream.** The same choice. While Listed, the Essential toggle is disabled with the
  footer "Essential keeps stories from aging away, so it's off for listed feeds.", and the
  handling-guidance field is hidden (it's kept, unused, §33).
- **Renaming.** Discovery proposes the feed's own title (for NYT, "NYT > Travel"). The kicker shows
  `Stream.name`, so make sure the existing edit sheet lets Jon rename it ("Travel"). Don't strip
  prefixes automatically.

**Prove (core).** S-l1 covers the data. Add tests only for new model logic, such as the day-header
grouping (a pure function: given `now`, a calendar and dates, return Today / Yesterday / weekday
labels, including across midnight and at the window's far edge) and the sidebar's grouping by
publisher in Following order.

**Do not.** Add a tab badge. Open articles inside Cockpit. Add thumbnails, keyword filters, or push
notifications. Put Feeds items in the Process queue or the quick-look sheet. Add a section rail.

**Device-only risks (name them).**
- Whether an `nytimes.com` URL opens in the NYT app (universal link) or Safari on Jon's iPad. Report
  which one, and don't add a workaround.
- Six tabs in the iPad tab bar at the smallest landscape width and in Split View.
- That the sidebar's selection and the list's scroll position survive switching to Today and back.

**Done when.** On device, Jon adds NYT Travel, Dining & Wine, Book Review, Movies and Theater as Listed
(renaming each to its section). The Feeds tab shows them by source with kickers in All feeds. A tap
opens the story in the NYT app or Safari and dims the row. Dismiss and Dismiss all work with Undo, and
none of these stories appears in the Tail.

**Sequencing.** Touches `ShellModel.swift`, `CockpitApp.swift`, `FollowingView.swift`,
`FollowingModel.swift` (draft handling), new `FeedsView.swift` and supporting row views in `CockpitApp`,
and a small grouping helper in `CockpitCore`. Branch: `m6/s-l2-feeds-tab`.

---

### S-l3 — Today's Feeds door: counts per feed, the newest headline, "Feeds N" on the index line

**Why.** DECISIONS §33. Jon wants Today to show at least how many stories are waiting, without feed
rows taking over a column. One compact door does that and switches to the Feeds tab.

**Build.**
- **Core.** `TodayModel` exposes `feedsDoor: FeedsDoor?`, built from `ListedFeedsModel` (or the same
  request): total new count, per-Stream new counts in Following order (Streams with zero new are left
  out), and the newest new item (title, Stream name, listed date). It's `nil` when nothing is new.
- **Placement.** `TodayLandingView` renders the door directly after the offer doors, in the same column
  flow (§30), before Transactional and the Tail, per the mockup's first frame. It's a `SectionLabel`
  "Feeds" with "N new", then a row on `Theme.paperSecondary`: "N new from M feeds" with a trailing
  "Go to Feeds" in the accent, then a line of feed names with counts, then the newest headline in
  `Theme.queueHeadline` with "Newest · {feed} · {time} ago" under it.
- **Tap:** `shellModel.select(.feeds)` with All feeds selected. It doesn't open anything else.
- **Index line:** append "Feeds N" after Offers, in accent ink, only while the door shows.
- **Masthead:** "N to process" stays as it is. Listed items are never counted there.

**Prove (core).**
- `feedsDoor` is nil with no new items and appears with the first one. Opening or dismissing the last
  new item removes it.
- Per-Stream counts follow Following order and leave out Streams with zero new.
- The newest item is the most recent listed date among new items, not among opened ones.
- `TodayModel`'s process count is unchanged by any number of Listed items.

**Do not.** Show feed rows on Today. Add a badge to the Feeds tab. Change the Process queue or its
count. Reorder existing Today sections.

**Device-only risks (name them).**
- The door's height in the third column alongside Food, Wine and the offer doors on the smallest iPad
  in landscape.

**Done when.** On device, Today shows the Feeds door with the right counts and the newest headline. A
tap lands on the Feeds tab at All feeds. After Jon dismisses everything there, the door and the index
entry disappear from Today.

**Sequencing.** Touches `TodayModel.swift`, `TodayLandingView.swift`, and the index-line view. Branch:
`m6/s-l3-feeds-door`.
