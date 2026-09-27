# M6 — Morning Edition: Today, Process, and the email reader (S-v1 … S-v4)

> **Build order, architect-recorded 2026-09-27 from the Morning Edition design kickoff.** DECISIONS §31
> is the decision record and `docs/mockups/morning-edition.html` is the visual spec *and* the
> acceptance test. These slices don't reopen any Gate 4 decision beyond the amendments §31 records
> (D-D, D-E, D-F), or anything in the Gate 5 contract. Each block is self-contained: send it to the
> executor as-is. Branch per slice: `m6/s-vN-short-slug`, one PR each, tick the box here in the PR that
> completes it.

**How this follows the house process.** jon-platform `docs/ios/ui-and-platforms.md`, "Visual craft":
arrange (the mockup and §31, done) → build behavior in default styling → foundation, once per app →
per-surface visual adoption. So: **S-v1** is the foundation and changes no surface. **S-v2** is the one
structural move (the Process tab and the quick-look sheet), built in default system styling and judged
for function. **S-v3** and **S-v4** are visual-adoption slices over surfaces whose structure is now
proven. Their done-criterion is literally "matches `docs/mockups/morning-edition.html` on device", and
Jon's device pass is the gate.

**Dependency shape.** S-v1 and S-v2 are independent, so build them in either order or in parallel.
**S-v3 needs S-v1 and S-v2. S-v4 needs S-v1 and S-v2**, and floats against S-v3. Both S-v3 and S-v4 touch
`TodayView.swift`, so whichever lands second rebases.

- [x] S-v1 — Foundation: asset catalog and `AccentColor`, `Theme` tokens, type roles, bundled Newsreader
- [ ] S-v2 — Process tab and quick look: the structural move, in default styling
- [ ] S-v3 — Today visual adoption: masthead, columns, section labels, rows
- [ ] S-v4 — Reader, quick look, and Process visual adoption: the letter, the newsletter strip and footer, the queue

## Standing rules for every slice

- Verify with `swift test` (CockpitCore), `swiftlint lint --strict`, and an unsigned app build. No
  Simulator or device driving (AGENTS.md). Name any device-only risk in the handoff report and stop.
  Visual fidelity is a device-only risk in every S-v slice by definition, so say so and stop; don't
  try to close it with screenshots.
- Behavior lives in `@Observable` models or pure functions in `CockpitCore` and is tested there. Views
  don't touch the database. Theme values (colors, fonts) are app-side SwiftUI and have no core tests.
  Anything with logic, such as the letter-vs-designed decision or the queue position, is core and tested.
- **Native chrome.** `TabView`, `NavigationSplitView`, `.toolbar`, sheets, swipe actions, context menus,
  and Undo are the system's, with only the tint changed (§31). No custom back buttons, no custom
  dividers, no restyled tab bar or toolbar backgrounds. Theme work touches Cockpit's own content only.
- **Emails keep their design (§25, §31).** Never re-typeset, restyle, or inject CSS into an email body.
  The one exception is S-v4's letter width cap, and it's applied to the web view's *frame* from outside.
- **No new judgment.** Nothing in these slices calls a model, changes Today membership,
  Clear/Dismiss, Edition, role routing, or judgment input. The "Asks for a reply" chip, the asks strip
  with dates, the attachment chips, and the masthead's "1 asks for a reply" are in the mockup but
  **not built**: they wait on their own DECISIONS entry (see the ledger in
  `M6-decisions-and-sequencing.md`). The layout must read right without them.
- The repo is public. Fixtures, previews, and test data use invented people, as the mockup does. Never
  real names or messages.
- iPhone composition isn't designed (§31). On compact width, take the system's default collapse
  (split view → stack, the multi-column Today → one column) and nothing more.

---

### S-v1 — Foundation: asset catalog and `AccentColor`, `Theme` tokens, type roles, bundled Newsreader

**Why.** §31 and the house rule: the foundation comes before any surface polish, or every surface
re-derives type, color, and spacing and drifts. Cockpit has no asset catalog today.

**Build.**
- **Asset catalog.** Add `CockpitApp/Assets.xcassets` with an `AccentColor` color set: light `#A5620F`,
  dark `#E3A755` (the mockup's `.me` `--a`). In `project.yml`, set
  `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor` on the Cockpit target so the same
  color drives the system tint, and regenerate the project with XcodeGen. This is the **only** place
  the accent's value is written.
- **Neutral color sets** in the same catalog, under a `Theme` folder, each with light and dark values
  taken from the mockup's `.me` / `.me.dark` variables. They are `Paper` (`--p`), `PaperSecondary` (`--p2`),
  `Ink` (`--k`), `InkSecondary` (`--k2`), `InkTertiary` (`--k3`), `Rule` (`--r`), and `Ground` (`--ground`).
- **`Theme`** (app target, `CockpitApp/Theme/Theme.swift`): semantic tokens as static members, which
  are the neutrals above plus `accent = Color.accentColor`. Also `accentSoft` (chip fill) and
  `accentInk` (chip text), both **mixed in code** from `Color.accentColor` with `Color.mix(with:by:)`
  against `Paper`/`Ink`. Tune the mix fractions to land near the mockup's `--as` / `--ak` in both
  appearances. Add spacing constants (the row and section rhythms the mockup uses) and
  `readingMeasure = 620` (pt at 100% text size, the letter width in the mockup). There is no Theme
  protocol and no environment plumbing yet: prove in one app first (ui-and-platforms.md,
  "Prove in one app, then extract").
- **Newsreader, bundled.** Add the variable TTFs for roman and italic from the upstream OFL release
  (google/fonts `ofl/newsreader`) under `CockpitApp/Fonts/`, with `OFL.txt` beside them. List them in
  `UIAppFonts` through `project.yml`'s `info.properties`.
- **Type roles** (static `Font` members on `Theme`, e.g. `Theme.headline`; not `Theme.Type`, which is
  the metatype), each built with
  `Font.custom(_:size:relativeTo:)` so Dynamic Type scales them. Sizes come from the mockup:

  | Role | Face | Mockup size | Used by |
  | --- | --- | --- | --- |
  | `masthead` | Newsreader italic | 40 | Today's day name |
  | `leadHeadline` | Newsreader medium | 23 | Today's lead story |
  | `headline` | Newsreader medium | 16 | Today rows |
  | `queueHeadline` | Newsreader medium | 14.5 | Process sidebar rows |
  | `queueTitle` | Newsreader medium italic | 24 | "This morning" over the queue |
  | `articleTitle` | Newsreader medium | 30 | the header over a letter |
  | `nextHeadline` | Newsreader medium | 21 | the "next in queue" footer card |
  | `lede` | Newsreader italic | 15.5 | the lead story's preview line |
  | `sectionLabel` | SF bold, uppercased, tracked ~0.16em | 10 | section labels, kickers |
  | `byline` | SF | 12 | source and author lines |
  | `meta` | SF, monospaced digits | 11.5 | times, counts |

  Bylines and controls stay SF (§31). Don't set fonts on system controls.
- **Primitives** (app target, `CockpitApp/Theme/`): only the two that at least two surfaces need.
  - `SectionLabel`: a small-caps label with a count, set off by a 1pt `Ink` rule above.
  - `HeadlineRow`: a headline, a byline, a trailing time, and an optional unread dot in `accent`.
  Each gets a `#Preview` in light and dark with invented content. Nothing adopts them yet.

**Prove.** There's no core logic, so core tests don't change. The unsigned build must pass with the
catalog compiled and the fonts in the bundle. Add a test in `CockpitCore` only if you put logic there
(you shouldn't need to).

**Do not.** Touch any existing surface. Theme system controls, the tab bar, or toolbars. Write the
accent's hex value anywhere but the color set. Add a shared theme package or a jon-platform change.
Load fonts from the network.

**Device-only risks (name them).**
- Whether iOS applies Newsreader's `opsz` axis automatically by point size. If 30pt titles look like
  enlarged text cuts (or 14.5pt rows like shrunk display cuts), report it. The fallback is static
  instances, decided at review.
- Mixed chip text (`accentInk` on `accentSoft`) contrast in both appearances. §31 notes this as the
  thing to recheck whenever the accent changes.

**Done when.** The app builds with the global accent coming from `AccentColor`, so the system tint
turns amber everywhere with no code change. On device or in Xcode previews, the `SectionLabel` and
`HeadlineRow` previews match the mockup's type and color in light and dark.

**Sequencing.** Touches `project.yml`, the regenerated `Cockpit.xcodeproj`, a new `Assets.xcassets`,
new `CockpitApp/Theme/*` and `CockpitApp/Fonts/*`. Floats. Branch: `m6/s-v1-foundation`.

---

### S-v2 — Process tab and quick look: the structural move, in default styling

**Why.** §31. Today is an `isReading` switch in `TodayView`: tapping any row replaces the whole
surface with the reader ("Today is a bit of an illusion"), and the way back is a custom button that
iPad window controls can cover. The fix is structural. Process becomes its own tab holding the one
ordered queue (Gate 4 D-F), and Today opens a quick-look sheet instead of swapping itself out. Build it
in default system styling. S-v3 and S-v4 style it.

**Build.**
- **Shell.** `ShellModel.Destination` gains `case process` between `.today` and `.later`, titled
  "Process". `CockpitRootView` adds `Tab("Process", systemImage: "list.bullet.rectangle", value: .process)`
  in that position. Add `ShellModel.process(from contentPieceID: ContentPiece.ID?)`. It selects
  `.process` and hands the ID to the queue model (see below). Keep `ShellModel` free of queue state, and update its doc comment ("four primary destinations").
- **One queue behind both tabs.** Hoist `TodayReadingQueueModel` out of `TodayView`'s `@State` into
  `CockpitRootView`, and pass the same instance to Today and Process. A disposition in either tab
  removes the item from both, under the existing "disappear, with Undo" rule. Reload both projections
  after any disposition, whichever tab made it. If `@Fetch` observation already does this, prove it,
  and don't add manual reloads.
- **Process tab.** `ProcessView` (rename and trim `TodayReadingView`):
  - `NavigationSplitView` with the system column width (`navigationSplitViewColumnWidth` ideal 300).
  - **Remove** the custom divider (`TodayReadingDivider.swift`, `ReadingPaneWidth` drag handling, the
    `cockpit.today.reading-list-width` `@AppStorage`). **Remove** the section rail. **Remove** both
    "Back to Today" buttons, the `done` closure, and `.toolbarVisibility(.hidden, for: .tabBar)`.
    Jon decided 2026-09-27 to drop the rail and divider: Today is now the section overview and
    "Process from here" jumps anywhere.
  - The sidebar keeps the queue exactly as it is: one list in role order, sections as headers, swipe
    to archive or trash, and selection. The existing Undo toolbar item stays.
  - **Previous / Next** toolbar buttons (`chevron.up` / `chevron.down`) move the selection through the
    queue without disposing anything. Don't assign keyboard shortcuts in this slice (see device-pass
    items).
  - **Queue position (core).** `TodayReadingQueueModel` exposes `position: (index: Int, total: Int)?`
    for the "1 of 17" line and `doneRoles: [ContentRole]` / `doneCount: Int` for the "7 done · …" line.
    Count the pieces that **left the queue by a Cockpit disposition** (archive, trash, series trash,
    Dismiss) since the model was created. Keep them in memory only, with no table, and reset them when
    the local day changes. Undo takes a piece back out of the done set. `total = remaining + done`, and
    `index = done + selectedIndex + 1`. A role appears in `doneRoles` once every piece of that role
    counted today is done. Show these in default styling (a caption over the list).
- **Series trash on leave (M6 S1), restated for tabs.** Today, leaving the Reader means changing
  selection or tapping Back to Today. With tabs, the triggers are: (1) the Process selection changes,
  as now; (2) **the user switches away from the Process tab**, which replaces Back to Today; and (3) the
  quick-look sheet closes, as the Highlights sheet does now. For trigger (2), when the piece is
  trashed and leaves the queue, the selection moves to its neighbour
  (`ReadingQueueSelection.neighbour`), so coming back to Process lands on the next item and the
  position still holds. Put the tab-leave rule in a core method (`leaveProcess()`) and test it.
- **Today.** Delete the `isReading` switch and `beginReader`. Today is always the `NavigationStack`
  landing surface.
  - **Quick look for every headline.** Generalize `TodayHighlightReaderSheet` into
    `TodayQuickLookSheet`. Every Today row that used to enter Reading now opens it: role-section rows
    and Tail rows. Offer doors still open review mode. Keep the existing presentation, which follows
    §25's pane rules: `.presentationSizing(.page)`, `.large` only, the zoom transition from the row, and
    the web view store preloaded on tap.
  - The sheet's toolbar gets **Done** (leading) and **Process from here**. Process from here dismisses
    the sheet, then calls `shellModel.process(from: row.id)`. Show it only when the piece is in the
    queue. Disposition actions stay as they are in the Reader toolbar. Disposing from the sheet closes
    it, and the row disappears with Undo.
  - **Remove the Highlights row** (`TodayLandingView.highlights`, `TodayModel.highlightRows`, and their
    tests). This amends Gate 4 D-D (§31; decided at spec, see DECISIONS §31 "Architect resolution").
  - **Today toolbar:** add a **Process** button (`Label("Process \(queueCount)", systemImage: …)`,
    `.borderedProminent`). It selects `.process` and keeps the queue's current selection. With no
    selection it selects the first item. Refresh stays. **Recent trashes** and **Recompose tail** move
    into a trailing **More** (`ellipsis`) menu. No search: the mockup's search glyph isn't a feature.
  - Today rows keep their swipe and context-menu dispositions (Archive, Later, Trash; Dismiss for Tail
    rows), so items can be cleared without opening them.
- **Teaching becomes a toolbar button that opens a sheet.** In the Reader toolbar, a
  `lightbulb` button opens the existing `ReaderTeachingView` in a sheet. Remove the inline "Tell Cockpit
  why this matters" field from `ReaderSupportingViews` (§31's evidence: it read as a reply box). The
  teaching model and its writes are unchanged.
- **Reader toolbar order** (structure only, still default styling), matching the mockup: the leading
  prominent action is **Reply** when reply is available for the piece (§26), otherwise **Archive**
  (Dismiss for Tail pieces). Then a group of Later, Library, Trash (Archive joins it when Reply leads),
  then Text size, Teach, and More.

**Prove (core).**
- `ShellModel.process(from:)` selects `.process`. With the queue model wired as the executor designs
  it, the selected piece becomes the given ID. A `nil` ID keeps the current selection.
- One database, both models: archiving through `TodayReadingQueueModel` removes the piece from
  `TodayModel`'s sections, and archiving through `TodayModel` removes it from the queue. Undo brings it
  back to both.
- `leaveProcess()` applies series trash to the selected piece when its series is declared, and the
  selection moves to the neighbour. It's a no-op for an undeclared series, and the selection stays.
- Queue position: with 3 pieces in For you and 2 in Daily news, archiving both For you pieces with a
  Daily news piece selected gives `doneCount == 2`, `doneRoles == [.forYou]`, and a position of 3 of 5.
  Undo on one gives 2 of 5 and empty `doneRoles`. A day change resets the counts.
- `TodayModel` no longer exposes `highlightRows`, and the Gate 4 I5 Highlights invariant test is
  removed along with the row. Nothing else surfaces a piece that isn't in a section.

**Do not.** Add a custom back button, divider, or rail. Hide the tab bar. Persist the done set. Give
Process its own queue request: it is `TodayReadingQueueRequest`, unchanged, offers still excluded
(§30). Restyle anything (S-v3/S-v4).

**Device-only risks (name them).**
- Tab-switch timing for series trash: whether a trash on leaving Process is visible as a flicker on
  return.
- Whether `.sidebarAdaptable` with five tabs still reads well in the iPad sidebar form and on iPhone.
- Scroll position and selection survive switching tabs and back (the system should keep both).

**Done when.** On device: Today never swaps itself out. Tapping any headline opens a large quick look,
and Done returns to exactly where Today was. Process from here lands on that item in the Process tab.
Archiving in Process removes the item from Today too, with Undo. Leaving Process and coming back keeps
the position. There's no custom back button anywhere, and the tab bar stays visible in Process.

**Sequencing.** Touches `ShellModel.swift`, `CockpitApp.swift`, `TodayView.swift`,
`TodayLandingView.swift`, `TodayReadingView.swift` (→ `ProcessView.swift`), `TodayReadingDivider.swift`
and `ReadingPaneWidth.swift` (deleted), `TodayHighlightReaderSheet.swift` (→ `TodayQuickLookSheet.swift`),
`TodayReadingQueueModel.swift`, `TodayModel.swift`, `ReaderView.swift`, `ReaderDispositionToolbar.swift`,
`ReaderSupportingViews.swift`, and tests. Floats against S-v1. Branch: `m6/s-v2-process-tab`.

---

### S-v3 — Today visual adoption: masthead, columns, section labels, rows

**Why.** §31's visual language on the overview: Newsreader for Cockpit's text, small-caps labels and
rules instead of cards, dense (about 20 items on an iPad in landscape without scrolling), no gauges.
The structure is proven by S-v2, so this is styling and arrangement only.

**Build** (regular width; compact width is one column in the same order).
- **Masthead.** The day name in `masthead` (e.g. "Saturday"), then the date and "N to process" in
  `byline`, where N is the queue count. A 2pt `Ink` rule sits under the masthead. It replaces the
  "This morning" header and `orientationSummary`'s sentence.
- **Daily links move into the masthead** (amends §29's trailing icon column; decided at spec). Show
  them trailing, as compact chips: the existing `DailyLinkGlyph` (symbol or Photos thumbnail) plus the
  title, with the visited check in `accent`. The same tap does `openURL` + `recordVisit`. Delete the
  trailing `DailyLinksColumn`. The compact-width toolbar `Menu` is unchanged. If the chips don't fit on
  one line, the ones that don't fit go into a trailing overflow `Menu`.
- **Index line.** One line of section names with counts (`meta`), in role order, ending with Offers
  and its count. A 1pt `Rule` sits under it. It's orientation, not a badge to clear.
- **Columns.** Sections flow into **three columns** in `ContentRole.sortOrder` (first column about 1.3×
  the width of the others, with 1pt `Rule` separators). Keep sections whole. Fill columns greedily by
  row count so heights balance. Put this assignment in a pure function in core
  (`TodayColumnLayout.columns(for sections: [(role, rowCount)], count: 3)`) and test it. The mockup's
  order of Food, Wine, Grab-bag doesn't override `sortOrder`.
- **Section labels.** `SectionLabel` (S-v1) with the count. No cards, no materials, no rounded
  backgrounds on sections.
- **Rows.** `HeadlineRow`: headline in `headline` (up to two lines), source in `byline`, time in `meta`.
  **Unread is the dot only.** Remove the bold-unread weight from S-t2's rows (amends §28's
  presentation; decided at spec). The transactional due-date flag stays as an `accentSoft` chip after
  the headline where one exists.
- **Lead story.** The first For you row gets the lead treatment: `leadHeadline`, byline with day, and
  its existing `summary` as a `lede` line. The mockup's quoted ask and "Asks for a reply" chip are
  **not** built (standing rules). With no For you rows, there's no lead.
- **Offers.** Under an Offers `SectionLabel`, **one compact row per offer door**, not per piece:
  "Wine · 6 offers · Review", with the kept count if any. §30's doors are unchanged in substance.
  They're restyled from thumbnail cards to rows, and the hero thumbnails stay in review mode. A tap
  opens review mode as now. This reads the mockup's single "14 offers from 9 senders" row as
  per-role (decided at spec).
- **The Tail stays** (Jon, 2026-09-27). Essentials, From the Tail, and Essential Backlog flow as ordinary
  sections after the role sections, styled the same way, with Dismiss in their swipe and context
  menus. The compose/recompose control is in the More menu from S-v2. When the tail is composing,
  a one-line status goes under the From the Tail label. Show text, not a gauge: the existing honest
  progress text (M5 S5).
- **Toolbar.** The system toolbar, untouched apart from the tint. **Process N** is `.borderedProminent`
  (amber, from the global tint).
- Background is `Paper`. Light and dark both follow the system appearance.

**Prove (core).**
- `TodayColumnLayout`: sections stay whole and in `sortOrder` across columns. Column heights (by row
  count) are balanced within one section's size. One section gives one column. An empty input gives
  empty columns.
- The Today projection still has the same membership and order as before S-v3. This slice changes
  presentation only, so assert that the existing section tests pass unchanged.

**Do not.** Add cards, shadows, gradients, or progress rings. Theme the tab bar, toolbar, or sheets.
Build the ask chip or the asks count. Change membership or ordering. Add search.

**Device-only risks (name them).** Density: about 20 items visible on an 11" iPad in landscape without
scrolling. Masthead chip overflow with Jon's real Daily links. The column balance with a heavy Opinion
day. Dark-mode rule and ink contrast.

**Done when.** Today matches `docs/mockups/morning-edition.html` on device, in light and dark, apart
from the elements the standing rules exclude (ask chip, asks count, search). The Tail sections and the
per-role Offers rows are this slice's additions to the mockup.

**Sequencing.** Needs S-v1 and S-v2. Touches `TodayLandingView.swift`, `TodaySurfaceRows.swift`,
`DailyLinksView.swift`, `TodayView.swift` (toolbar styling), a new `TodayColumnLayout.swift` in core,
and tests. Branch: `m6/s-v3-today-visual`.

---

### S-v4 — Reader, quick look, and Process visual adoption: the letter, the newsletter strip and footer, the queue

**Why.** §31. Email bodies ran about 170 characters a line, and the reader had no frame of its own.
Emails keep their design (§25): Cockpit owns only the ground, a strip or header above, and a footer
below. Letters with no design of their own get a width cap and margins applied from outside.

**Build.**
- **Designed vs. letter (core).** A pure decision `EmailPresentation.kind(html:) -> .designed(width) |
  .letter`. It is `.designed` when `EmailDesignWidth.detect` returns a width, and `.letter` otherwise
  (including plain-text bodies). This is the only switch between the two treatments below. Don't use
  role or sender.
- **Letter treatment.** Above the email, a Cockpit header: the role as a kicker (`sectionLabel`,
  `accent`), the subject in `articleTitle`, then the sender (semibold) · the publisher, with the full
  date trailing, in `byline`. A 1pt `Ink` rule sits under it. The web view's **frame** is capped at
  `Theme.readingMeasure × textSize` and leading-aligned with the header, with the mockup's margins. The
  HTML, fonts, bullets, and links are untouched: no CSS injection, no reflow.
- **Designed (newsletter) treatment.** The email sits on `Ground`, centered at its design width
  (the existing S-r7 fit and S-r9 per-sender size). Above it, the **strip**: kicker (role), publisher in
  small caps, date, and a trailing text-size capsule showing the current per-sender size (e.g. "115%
  for this sender"). A tap on the capsule opens the existing Text Size menu. The existing ⌘+ / ⌘− / ⌘0
  shortcuts stay.
- **Dark mode.** A designed email renders as its sender made it: light, as a sheet of paper on the
  dark `Ground`, unless the HTML declares dark support (a `color-scheme` meta or a
  `prefers-color-scheme` media query; detect it statically in core). A letter follows the system
  appearance **only if** its HTML sets no text or background colors of its own (a static check in core).
  Otherwise it renders light, on a light panel. Neither case modifies the email.
- **Footer** (after the email, same width as the email or letter column): the custody line
  (`ReaderCustodyLine`, restyled), then in Process only a **next card**. The card shows "Next in
  {role} · k of n" (position within that role's section), the next headline in `nextHeadline`, and its
  source, with a trailing **Archive and continue** (`.borderedProminent`). That's the existing
  archive-and-advance. For Tail pieces it's **Dismiss and continue**. With no next item, the card
  says the queue is clear.
- **Process sidebar.** `PaperSecondary` background. "This morning" in `queueTitle` with the S-v2
  position ("8 of 17") in `meta`, and the S-v2 done line ("7 done · For you, Transactional, Daily news")
  with an `accent` check. Section headers use a smaller `sectionLabel` with counts. Rows are
  `queueHeadline` and byline, with time trailing. The current row is `Paper` with a 1pt `Rule` inset,
  in place of the system selection highlight. Everything else is the system list.
- **Quick-look sheet.** It gets the same header or strip, body, and custody line as the Process
  reader, without the next card. Its toolbar is the system's.
- **Toolbar.** The S-v2 order, system-styled. The leading action is `.borderedProminent` (Reply for
  letters, Archive for newsletters).

**Prove (core).**
- `EmailPresentation.kind`: a 600px-table newsletter fixture is `.designed(600)`. A bare
  `<p>`/`<ul>` letter is `.letter`. A plain-text body is `.letter`. Reuse `EmailDesignWidth` fixtures
  where they fit.
- Dark-support detection: true for `<meta name="color-scheme" content="light dark">` and for an
  `@media (prefers-color-scheme: dark)` block. False for neither.
- Letter self-coloring detection: false for a bare letter, true when `body`/`p` carries an inline
  `color` or `background`.
- Next-card data: for the selected piece, the next queue row, its role's section position, and the
  "queue clear" case at the end.

**Do not.** Inject CSS, change fonts, or reflow any email. Invert or darken a designed email. Cap a
designed email's width. Build the asks strip, date chips, or attachment chips. Theme the toolbar or
sheet chrome.

**Device-only risks (name them).** The letter measure at each text size. Dark-mode letters with odd
inline colors. The strip's alignment with the email's left edge (S-r8's rule). A web view frame cap
against Split View widths.

**Done when.** The Process tab (letter and newsletter, top and end of issue) and the quick-look sheet
match `docs/mockups/morning-edition.html` on device, in light and dark, apart from the elements the
standing rules exclude. A letter reads at a comfortable measure. A newsletter reads exactly as its
sender designed it, on Cockpit's ground.

**Sequencing.** Needs S-v1 and S-v2. Touches `ReaderView.swift`, `ReaderViewContent.swift`,
`ReaderBodyContentView.swift`, `TodayOriginalReaderWebView.swift` (frame only, not the sanitizer's
output), `ReaderCustodyLine.swift`, `ProcessView.swift`, `TodayQuickLookSheet.swift`, a new
`EmailPresentation.swift` in core, and tests. Branch: `m6/s-v4-reader-visual`.

---

## Device-pass items (Jon)

§31 marked four choices "confirm on device". They were decided at spec so the slices can be built
(DECISIONS §31, "Architect resolution"), and each is **built as the mockup shows and confirmed on the
S-v slice's device pass**. If one doesn't hold up, it's a DECISIONS amendment plus a small follow-up
slice. Don't quietly revert it.

| Choice | Built in | Amends | Revert path if it fails on device |
| --- | --- | --- | --- |
| Highlights row dropped | S-v2 | Gate 4 D-D | bring back a pointer-only row over the columns (I5 invariant returns with it) |
| Daily links in the masthead | S-v3 | §29 (trailing column) | the S-t4 trailing column, restyled |
| Unread dot as the only read-state mark | S-v3 | §28 presentation (S-t2's bold) | bold plus dot |
| Teaching as a toolbar button that opens a sheet | S-v2 | S-r2's inline Tell Cockpit | none expected: the inline field was the §31 evidence |

Also for the device pass:
- **Keyboard shortcuts in Process.** The mockup labels "Archive and continue" ⌘↓, but ⌘↓ is
  scroll-to-end inside a web view. Choose shortcuts for Previous / Next / Archive and continue on device,
  and record them here.
