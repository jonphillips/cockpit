# M6 — Reader dogfood slices (S-r1 … S-r10)

> **Build order, architect-recorded 2026-09-22 from Jon's device dogfooding of the S-d0 surface.**
> These make the Today reading split usable day to day ahead of the S-d device eval. They do not
> reopen any Gate 4 decision (D-A–D-G). Each block is self-contained: send it to the executor as-is.
> Branch per slice: `m6/s-rN-short-slug`, one PR each, tick the box here in the PR that completes it.

**Dependency shape:** S-r1 → S-r2 → S-r5. S-r3 and S-r4 float (S-r3 is easiest after S-r2 because both
touch `ReaderView.swift`).

**Email fit (S-r7 … S-r9), recorded 2026-09-23 from Jon's iPad dogfooding.** Fixed-width HTML emails
(Substack and similar, about 550–650px) render 1:1 in the Reader: a narrow column with wide margins on
iPad, while the Cockpit header sits at the pane's leading edge and the email is centered. These slices
are display-only: no schema, identity, Gmail, or judgment changes. S-r7 → S-r8 → S-r9, built in that
order: S-r9's controls rely on the web-view width S-r8 adds.

**Mail hand-off (S-r10), recorded 2026-09-23.** One tap opens the exact message in Mail.app for real
email work. It's a link, not composition: DECISIONS §26 is unchanged. Build it after S-r9, because both
touch the Reader toolbar, view, and model.

- [x] S-r1 — Queue flow: disposed issues leave the queue, advance to next, Undo
- [x] S-r2 — Reader chrome: actions in the toolbar, inline Tell Cockpit, Delete archives
- [x] S-r3 — Reader facts: sender names, received dates, links open in Safari
- [x] S-r4 — Sync on open/foreground (throttled)
- [x] S-r5 — Plain-text reply in thread (DECISIONS §26)
- [x] S-r6 — Confirmed-Find barrier for offer disposition (DECISIONS §24 amendment, 2026-09-23)
- [x] S-r7 — Email fit: capped fit-to-column zoom
- [x] S-r8 — Reader column: header aligns with the email
- [x] S-r9 — Per-publisher zoom: adjust once, remembered per series
- [ ] S-r10 — Open in Mail: hand off to the exact message in Mail.app

## Standing rules for every slice

- Verify with `swift test` (CockpitCore), `swiftlint lint --strict`, and an unsigned app build. No
  Simulator or device driving (AGENTS.md). Name any device-only risk in the handoff report and stop.
- Behaviour lives in `@Observable` models or pure functions in `CockpitCore` and is tested there. Views
  do not touch the database.
- Never change stored `ContentPiece.publisher` / `creator`: `ContentIdentity.derive` hashes the
  publisher, so rewriting it forks identity. All sender prettifying is display-only.
- Gmail boundary (ADR-0002) is unchanged except where a slice cites DECISIONS §25 (amended) or §26.
- S-r7 … S-r9: keep the Reader web view's security posture exactly as it is: page JavaScript off,
  non-persistent data store, no in-view navigation, links go out through `EmailLinkPolicy`. Don't
  turn on scrolling inside the web view: its height still comes from observing `contentSize`.
- S-r7 … S-r9: zoom goes through a root CSS `zoom` in a stylesheet the sanitizer appends, and nothing
  else. Never use `WKWebView.pageZoom`: on iOS it scales the laid-out page without re-laying it out,
  so any zoom above 1 pushes the email past the pane's right edge (found on device, 2026-09-23).
  Never rewrite the email's own CSS/layout and never use a transform scale.

---

### S-r1 — Queue flow: disposed issues leave the queue, advance to next, Undo

**Goal.** Archive/Trash from the reading queue behaves like a mail client: the item leaves, the next
item opens in the Reader, and Undo is one tap away.

**Decision (Jon, 2026-09-22).** A followed-Stream issue whose Gmail source is disposed — by Cockpit,
by a series trash-on-leave, or externally (archived in Mail.app, reconciled by delta sync) — **leaves the
Today reading queue**. It **stays in its Stream** (Stream Handling), with Edition/Essential state and
custody untouched. The queue is attention, not membership; I2/I4 are unchanged. This aligns the queue
with `TodayRequest` (orientation), which already hides disposed/cleared followed pieces.

**Build.**
- `TodayReadingQueueRequest.row(for:inputs:)`: drop the `!followedStream` exemption so any Gmail piece
  in `clearedIDs` or `disposedIDs` is excluded. Nothing else about membership changes.
- `TodayReadingQueueModel`:
  - `archive(_:)` / `trash(_:)`: if the row is the current selection, compute its neighbour **before**
    the write — the next row in queue order, else the previous, else `nil` — and select it on success.
    A swipe on a non-selected row leaves selection alone. On failure selection is unchanged.
  - Keep a `lastDisposition` (content piece ID, title, archive/trash) for an Undo banner; a new
    disposition replaces it; `undoLastDisposition()` reverses it through the existing
    `GmailDispositionService.undo`, reloads, and re-selects the restored piece.
- `GmailSeriesDispositionOperations.applyTrashOnLeave`: skip when the piece has **any** active
  (unreversed) disposition, not just a trash entry. Otherwise archive → auto-advance → selection change
  fires trash-on-leave and trashes a message the user just archived.
- Reader in the queue: add a `ReaderQueueContext` (like `EditionReaderContext`) carrying
  `archive`/`trash` closures that call the queue model. `TodayReadingQueueDetail` passes it;
  `ReaderDispositionToolbar` uses it when present, else falls back to `ContentPieceReaderModel`'s own
  `archiveSource`/`trashSource` (Later/Library contexts keep today's behaviour).
- `TodayReadingView`: a bottom banner "Archived “Title” · Undo" / "Trashed … · Undo" driven by
  `lastDisposition`, sharing the existing error inset. Dismisses on the next disposition or tap.

**Prove.**
- A followed Gmail Stream issue, archived: gone from `TodayReadingQueueRequest`, still returned by the
  Stream Handling request for its Stream, Edition entry state unchanged (extend
  `Gate4DispositionSeparationTests`). Same for an externally departed (`clearDeparted`) issue.
- Archiving the selected middle row selects the next; the last row selects the previous; the only row
  selects `nil`; archiving a non-selected row keeps selection; a failing client keeps selection.
- Undo restores the row to the queue and selects it.
- A declared trash-after-reading series piece that was archived is **not** trashed on leave.

**Do not.** Do not touch Stream membership, Edition state, or `TodayAttention` semantics. No review
section for disposed items (disappear + Undo is the settled pattern).

**Done when.** Archive/Trash from row swipe or Reader toolbar advances to the next item, the disposed
item leaves the queue (followed or not), and Undo brings it back.

---

### S-r2 — Reader chrome: actions in the toolbar, inline Tell Cockpit, Delete archives

**Goal.** Nothing but teaching lives below the email. Actions are in the nav bar; Delete archives.

**Build.**
- Move `ReaderActionControls`' buttons into the Reader's toolbar (`ReaderDispositionToolbar` or a
  sibling `ReaderToolbar`). Trailing, in this order:
  - **Email pieces:** Archive (prominent; `.keyboardShortcut(.delete, modifiers: [])`), Trash,
    Save for Later, Add to Library, then a `…` menu.
  - **Non-email pieces:** Save for Later, Add to Library, `…` menu.
  - **Edition context:** Dismiss joins the group (leading edge of it) as today.
  - **`…` menu:** Move to section… (email), Offline ▸ (Offline until / Keep Offline / Stop Keeping
    Offline — the existing `OfflineAvailabilityControls` actions), Correct this understanding (when a
    reader-taught claim exists), Undo disposition (email).
  - Keep the offline *status* label (e.g. "Available offline until …") inline under the header, only
    when it is not ordinary cache.
- Replace the "Tell Cockpit why this matters" button with a one-line `TextField` (prompt: "Tell
  Cockpit why this matters") plus a submit button (`arrow.up.circle.fill`), at the bottom of the
  Reader content. Return submits. While reviewing, show inline progress. Submit runs the existing
  proposal flow; the sheet opens **only** at the proposal stage for explicit confirmation
  (Personal Knowledge still requires confirmation — AGENTS.md AI boundary). Cancel clears the text.
- `ContentPieceReaderModel`: add `submitTeachingReason()` (trim; empty → no-op; otherwise review →
  `.proposal`). Retire the `.reason` sheet stage from the Reader path.
- Delete key: the shortcut must not fire while the Tell Cockpit field is focused. Gate it with
  `@FocusState` (disable the shortcut when focused) rather than relying on responder-chain ordering.

**Prove.** Model tests: empty submit is a no-op; submit with text lands in `.proposal`; cancel clears
text and stage; confirm still requires `saveTeachingButtonTapped`.

**Device-only risk (name it).** Delete key behaviour with an iPad hardware keyboard, and toolbar
overflow at narrow split widths.

**Done when.** The Reader has no action buttons below the body except the Tell Cockpit field, Delete
archives the current email (advancing per S-r1), and teaching still requires confirmation.

---

### S-r3 — Reader facts: sender names, received dates, links open in Safari

**Goal.** Rows read as English, show when mail arrived, and links in an email work.

**Build.**
- **Sender display.** `SenderDisplayName.make(from:)` in CockpitCore (next to `GmailHeaderParser`):
  `"Matthew Yglesias" <m@x.com>` → `Matthew Yglesias` (unquote, unescape `\"`); `Name <addr>` → `Name`;
  `<addr>` or bare address → the address. Use it for every displayed sender: reading-queue
  `sourceLabel` fallback, `TodaySurfaceRows` publisher lines and roll-up titles, Reader header. Group
  roll-ups by the raw value as today; only the label changes.
- **List dates.** Every reading-queue row and orientation row shows its received date/time
  (`.dateTime.month().day().hour().minute()`, as `TodaySurfaceRows` line ~114 already does for one
  row type).
- **Reader age note.** `ReceivedAgeLabel.text(received:now:calendar:)` in CockpitCore, used as a small
  caption at the top of the Reader:
  - same calendar day → `Today · 3 hours ago` (`12 minutes ago` under an hour; `Just now` under a
    minute);
  - previous calendar day → `Yesterday · Sep 21`;
  - otherwise → `4 days ago · Sep 18` (calendar days; add the year when it differs).
  Hours-ago appears **only** for today. Add `receivedAt` to `ContentPieceReaderRequest.Row` using the
  queue's rule (`publishedAt ?? max(artifact.acquiredAt) ?? createdAt`) — extract that rule into one
  shared helper rather than copying it.
- **Links (DECISIONS §25 amended).** In `TodayOriginalWebViewCoordinator`, a user-activated link
  (`.linkActivated`, or a `target=_blank` via `createWebViewWith`) whose scheme is `http`, `https`, or
  `mailto` opens externally (`UIApplication.shared.open`) and the web view navigation is cancelled.
  Everything else stays cancelled; the initial `loadHTMLString` is still the only navigation the web view
  performs. Put the decision in a pure `EmailLinkPolicy.externalURL(for:isUserActivated:)` in CockpitCore.

**Prove.** `SenderDisplayName` cases above plus empty/garbage input; `ReceivedAgeLabel` at 00:01 vs
23:59 boundaries, 59 s, 59 min, yesterday, 4 days, prior year; `EmailLinkPolicy` rejects `javascript:`,
`file:`, `data:`, `cid:`, `about:blank`, and non-user-activated navigations.

**Done when.** No raw `<address>` appears in any list or Reader header, every row has a date/time, the
Reader shows the age note, and tapping an unsubscribe link opens Safari.

---

### S-r4 — Sync on open/foreground (throttled)

**Goal.** Mail archived elsewhere drops out of Cockpit without remembering to tap Refresh.

**Context.** Delta sync already reconciles Gmail-side departures (`departedMessageIDs` →
`TodayAttentionOperations.clearDeparted`, ADR-0002 D9). A sync is `profile` + `history.list` page(s) + one
Primary `messages.list` + one `messages.get` per new/changed Primary message — not per held item.
Today, it only runs when Refresh is tapped. (S-r1 makes departed *followed* issues leave the queue too.)

**Build.**
- `GmailAutoSyncPolicy.shouldSync(lastSyncedAt:lastAttemptAt:now:isSyncing:)` in CockpitCore: true when
  not syncing and the later of the persisted `GmailSyncState.updatedAt` and an in-memory last-attempt
  time is older than 5 minutes (or absent). The attempt time keeps a failing sync from retrying on every
  foreground.
- The app shell runs the existing Gmail ingest on launch and on `scenePhase` → `.active` when the
  policy allows, including when another tab is selected. `TodayView` reloads its local projection
  after a successful ingest. Automatic runs do not surface a missing-authorization error (manual
  Refresh still does). This follows Jon's 2026-09-23 app-wide foreground refinement.

**Pre-check (Jon, before assigning).** Archive a non-followed For you email in Mail.app, tap Refresh in
Cockpit, confirm it leaves Today. `history.list` is filtered with `labelId=INBOX`; if an archive is *not*
reconciled, add to this slice: drop the `labelId` filter from `GmailInboxAPI.listHistory` (departure is
still "changed and not in the Primary set"; message reads are unchanged because they are already limited
to changed ∩ Primary).

**Prove.** Policy table: nil/nil → sync; 4 min → no; 6 min → yes; syncing → no; recent failed attempt →
no.

**Done when.** Opening Cockpit or returning to it syncs at most once per 5 minutes.

---

### S-r5 — Plain-text reply in thread (DECISIONS §26)

**Goal.** Reply to a personal email without leaving Cockpit. Narrow by decision: see DECISIONS §26 for
what is and is not in scope.

**Build.**
- **Headers at reply time, not persisted.** Fetch `From`, `Reply-To`, `Subject`, `Message-ID`,
  `References` with `messages.get?format=metadata&metadataHeaders=…` for the Artifact's `messageID`.
  Do not add them to `GmailArtifactProvenance`; no migration.
- **Pure builder** `GmailReplyMessage.make(original:fromAddress:body:)` in CockpitCore → RFC 5322 text
  (CRLF): `From` = the account address (`GmailArtifactProvenance.accountID`), `To` = `Reply-To` ?? `From`,
  `Subject` = `Re: ` + original unless it already starts with `Re:` (case-insensitive), RFC 2047-encode a
  non-ASCII subject, `In-Reply-To` = original `Message-ID`, `References` = original `References` +
  ` ` + `Message-ID`, `MIME-Version: 1.0`, `Content-Type: text/plain; charset=UTF-8`,
  `Content-Transfer-Encoding: base64`. No quoted original (the thread carries it).
- **Client** `GmailReplyClient` (`@Dependency`, like `GmailDispositionClient`): `replyHeaders(messageID)`
  and `send(raw:threadID:)` → `POST messages/send` with base64url `raw` and `threadId`. Live
  implementation next to `GmailDispositionAPI`; app wiring reuses `GmailDispositionWiring`'s token
  refresh. The granted `gmail.modify` scope already authorizes `messages.send` — no re-consent.
  **No automatic retry on send** (not idempotent: a retried 5xx can double-send). Retry `replyHeaders`
  like other reads.
- **Model** `ReaderReplyModel` (CockpitCore, `@Observable`): recipient display (via S-r3's
  `SenderDisplayName` if landed, else raw), subject, body, `isSending`, `errorMessage`;
  `send(thenArchive:)`. On failure the body is kept. On success the sheet closes; with `thenArchive` it
  archives through the S-r1 queue context (so the queue advances) or the Reader model outside the queue.
- **UI.** Reply button (`arrowshape.turn.up.left`) first in the Reader toolbar, for Gmail pieces whose
  resolved role is For you or Transactional. Sheet: To and Subject read-only, `TextEditor` body, Cancel /
  Send / Send & Archive; ⌘↩ sends.

**Prove.** Builder: Re: not doubled; References chaining with and without an original References;
Reply-To preferred; CRLF; non-ASCII subject encoded; body base64 round-trips. Model with a fake client:
success closes and (optionally) archives; send failure keeps body and surfaces error; send is called
exactly once per tap (no retry); empty body disables Send.

**Do not.** No reply-all, CC/BCC, forward, new compose, attachments, rich text, drafts persistence, or
any Cockpit table for sent mail. Not offered on newsletter roles.

**Device-only risk (name it).** Live send, threading in Gmail/Mail.app, and the metadata fetch.

**Done when.** Jon can reply to a For you email from the Reader and the reply appears in the same
thread in Gmail.

---

### S-r6 — Confirmed-Find barrier for offer disposition

**Goal.** A model-proposed Find cannot authorize Trash. Only a Find Jon kept can satisfy the explicit
`offerWithFind` policy.

**Build.** Add `PendingFindState.confirmed`; handed-off Finds imply confirmation. Re-proposing a Find
updates descriptive fields without downgrading its state. Add DB-only confirm/dismiss operations. The
offer policy barrier accepts confirmed or handed-off Finds only. Reader offers with pending proposals
show a compact card with Save Find / Not This; confirmation immediately rechecks that offer through the
existing policy, disposition barrier, once-per-message guard, and Undo log. The Finds list shows state
and offers swipe Save / Dismiss actions through its model.

**Prove.** Pending and dismissed Finds do not match; confirmed and handed-off Finds do. Re-persisting
does not downgrade confirmed or dismissed state. Confirmation trashes exactly the offer and writes its
Undo entry only when the policy is enabled. Full ingest with a model-proposed Find disposes nothing.

**Device-only risks (name them).** An older device build may fail to decode the synced `confirmed` raw
value in PendingFind, and its upsert may reset that state to `pending` when it re-proposes the Find.
Jon still needs to check the Reader proposal card on device.

**Done when.** Offer Trash requires a Find Jon confirmed, and the UI exposes explicit Save / Not This
decisions without views accessing the database.

---

### S-r7 — Email fit: capped fit-to-column zoom

**Goal.** A narrow fixed-width email grows to use the Reader pane up to a comfortable cap. An email
wider than the pane shrinks to fit instead of being clipped. Fluid emails are unchanged.

> **Amended 2026-09-23 after device checks of #74.** The first build used `WKWebView.pageZoom`. On iOS
> it scales the laid-out page without re-laying it out, so zooms above 1 ran off the right edge. A
> width-measuring backstop then misread that as the email's width and was reverted. This block
> describes what #74 shipped.

**Build.**
- `CockpitCore`: `EmailDesignWidth.detect(html:)` / `detect(in:)`, a pure SwiftSoup function that
  returns the email's fixed design width in CSS px, or `nil` for fluid layouts. It reads the outermost
  layout containers under `<body>` (the first few nesting levels of `table`/`td`/`div`/`center`):
  `width="N"` attributes and inline `width` / `max-width` / `min-width` in px, ignoring `!important`.
  It takes the widest value in the 320–1200 range. `detect(in:)` reuses the sanitizer's parsed
  document, so each email is parsed once.
- `CockpitCore`: `EmailFitZoom`.
  - Constants: cap `1.3` (body copy around 20pt; filling a landscape iPad pane would be about 1.6×),
    floor `0.5`, and `horizontalGutter` 16 CSS px a side (covers the default body margin; without it
    a fixed-width table at an exact fit is cut off).
  - `zoom(designWidth:availableWidth:)`: the exact fit,
    `availableWidth / (designWidth + 2 × horizontalGutter)` clamped to `0.5…1.3`; `nil` → `1.0`.
  - `bands(designWidth:)`: 5% zoom steps from 0.5 to 1.3. Each starts at the viewport width where
    its zoom fits, so a band never overflows and trails the exact fit by less than one step. `nil`
    for fluid email.
  - `bandedZoom(designWidth:viewportWidth:)`: the zoom the bands apply at a width.
  - `stylesheet(designWidth:)`: the bands as `html { zoom: … }` rules, the floor unconditional and
    the rest in `@media (min-width: …px)`.
- `TodayOriginalHTML.sanitizedForWebView`:
  - replace any `<meta name="viewport">` with one `width=device-width, initial-scale=1`, so CSS px
    equal points and media queries see the web view's width;
  - append the stylesheet last in `<head>` as `<style id="cockpit-email-fit">`. Fluid email gets
    none.
- `TodayOriginalWebViewStore`: `preferredContentMode = .mobile`, because iPad's default desktop mode
  lays out at 980px and mostly ignores the viewport tag. There is no zoom state, width tracking, or
  reload on resize: WebKit re-picks the band itself when the pane changes width.

**Prove.**
- Detection, with synthetic fixtures only (no real newsletter HTML in the repo):
  - a `max-width: 550px` wrapper → 550;
  - a `<table width="600">` outer with nested narrower tables → 600;
  - an outer `width="100%"` with a `600` inner → 600;
  - `max-width: 600px !important` → 600, and `min-width: 600px` → 600;
  - all fluid → `nil`, and a 1px spacer or a 2000px value is ignored.
- Exact fit: 550 in 950 → 1.3 (capped). 700 in 800 → about 1.09. 600 in 390 → about 0.62, and
  the email plus gutters fits. `nil` → 1.0.
- Bands:
  - 550 in 952 → 1.3, with the cap starting at 757px;
  - 600 in 390 → 0.6;
  - across many widths and design widths, no band overflows and each is within one step of the
    exact fit;
  - fluid → no stylesheet.
- Sanitizer: the viewport meta is replaced, not duplicated. The fit stylesheet is last in `<head>`
  for fixed-width email and absent for fluid email.

**Device-only risks (name them).** Checked on iPad 2026-09-23 (Negroni: 1.3×, centered, nothing
clipped). Still to see: iPhone, and the body height after a resize changes the band.

**Do not.** Don't enable page JavaScript or add app-injected JavaScript. No user-facing controls
(S-r9).

**Done when.** On a landscape iPad, a 550px newsletter renders about 715pt wide and centered. A wide
email fits the pane on iPhone. Fluid emails look as before. Resizing the pane re-fits without
reloading.

---

### S-r8 — Reader column: header aligns with the email

**Goal.** The Cockpit header (title, sender, date) and the email read as one document: same column,
same leading edge.

**Build.**
- The store needs the detected width. Have the sanitizer return it with the HTML, for example
  `(html: String, designWidth: Double?)`, and have `TodayOriginalWebViewStore` publish it. Don't
  run detection a second time.
- `ReaderBodyView` reports the web view's own width through `onGeometryChange`. With
  `initial-scale=1`, that width in points is the viewport width the media queries see. Measure the
  web view, not the pane: the pane includes padding.
- `CockpitCore`: `EmailColumn.width(designWidth: Double?, viewportWidth: Double) -> Double`, a pure
  function. Returns `designWidth × EmailFitZoom.bandedZoom(designWidth:viewportWidth:)`, capped at
  the viewport width, or the viewport width when the design width is `nil`. Use `bandedZoom`, the
  zoom the stylesheet actually applies, not the exact fit.
- `ReaderView`: constrain the header block, and the other Reader content above and below the body
  (summary, pending-Find card), to that width, centered in the pane:
  `.frame(maxWidth: column).frame(maxWidth: .infinity)`. Fixed-width emails center themselves, so
  the leading edges line up. With no HTML body (inline/unavailable/preview), keep today's layout.
- The column follows width changes. Animate only if it's free: a jumpy layout is worse than no
  animation.

**Prove.**
- Column width: for a fixed email narrower than the pane after zoom, it's `design × bandedZoom`. For
  a wider one, it's the viewport width. For fluid email, it's the viewport width.
- The column changes exactly when the band changes.

**Device-only risks (name them).** Alignment is to the email's outer container. Some emails pad their
content inward, so the text edge may sit a little inside the header edge. Jon judges whether that's
acceptable. No further heuristics in this slice. Checked on iPad 2026-09-23 (#76): the header sits on
the email's column edge. Still to see: a fixed-width email whose outer container isn't centered (a
`<table width="600">` with no `align="center"` or `margin: auto`). It sits at the leading edge, so the
centered header is off by about half the leftover width, not a small inset. If that turns up often,
it's a small follow-up: detect whether the email centers itself, and don't center the column when it
doesn't.

**Do not.** Don't restyle the header's type or change Reader chrome. Don't touch the web view's own
margins.

**Done when.** On iPad, the header's leading edge sits on the email's column edge for fixed-width
emails, and nothing changes for fluid emails.

---

### S-r9 — Per-publisher zoom: adjust once, remembered per series

**Goal.** When the auto-fit isn't right for a newsletter, Jon adjusts it once and every later issue
from that publisher opens at the same adjustment.

**Build.**
- Store an **adjustment step**, not an absolute zoom: an integer in `-3…+5`, each step ×1.1 on top of
  the S-r7 fit. The same preference then works on iPhone, iPad, and split view.
- Per viewport width `w`, the target zoom is:
  - **Fixed-width email:** `max(0.5, min(auto(w) × 1.1^step, w / F, 2.0))`, where `auto` is the S-r7
    fit and `F = designWidth + 2 × EmailFitZoom.horizontalGutter`. A manual step may pass the 1.3 auto
    cap, but never the width that fills the pane: the web view doesn't scroll, so anything wider is
    cut off and unreachable. The 0.5 floor still wins when an email is too wide even at 0.5.
  - **Fluid email:** `clamp(1.1^step, 0.5, 2.0)` as a single unconditional rule. Its percentage
    widths still fill the view at any zoom.
- Generalize the S-r7 bands to take the step: `EmailFitZoom.bands(designWidth:adjustmentStep:)` and
  `stylesheet(designWidth:adjustmentStep:)`, with step 0 producing exactly S-r7's output. The target
  never decreases as the width grows, so bands keyed on 5% zoom steps stay valid. Each band starts
  at the narrowest width that reaches its zoom, so none overflows. The ceiling lives in the
  stylesheet per width. The stored step never changes with the pane, so a step clamped in a narrow
  pane applies in full in a wider one.
- Applying a step: regenerate the sanitized HTML with the new stylesheet and reload. Page JavaScript
  stays off and there is no app-injected script. Keep the current `contentHeight` until the new
  page reports its size, so the Reader doesn't jump to 44pt and back. The outer scroll position
  should survive.
- `larger()` does nothing when `bandedZoom` at the current web-view width (from S-r8) wouldn't rise
  with the next step, so no hidden steps pile up. The menu's larger control is disabled there.
  `smaller()` likewise stops at the floor.
- Key: `GmailSeriesKey.seriesKey(forContentPieceID:in:)` (List-ID, else sender), so two
  publications from one sender stay distinct. Pieces without a series key get a session-only
  adjustment that isn't saved.
- Persistence: device-local, `UserDefaults`, injectable, following the `FrontierPreference` idiom.
  This is a per-device display preference. It isn't synced, it isn't in SQLite, and it isn't
  Personal Knowledge or Stream Handling. Step 0 removes the key.
- The reader model exposes the series key (fetched in Core, not in a view) and the
  `larger()` / `smaller()` / `reset()` actions. The store applies the resulting stylesheet.
- Controls:
  - ⌘+ / ⌘− / ⌘0 keyboard shortcuts while the Reader is visible.
  - A "Text Size" control in the Reader's ⋯ menu: smaller, larger, and "Fit" (reset). Show the
    current percentage.
  - Pinch: a simultaneous `MagnifyGesture` on the web view that snaps to the nearest step when the
    gesture ends. If it fights WKWebView's own gestures on device, drop pinch and say so in the
    report. The keyboard shortcuts and menu are the required path.
- S-r8's column follows the stepped zoom: `EmailColumn` takes the step too.

**Prove.**
- Step 0 output is byte-identical to S-r7's.
- Positive steps pass 1.3 but never exceed `w / F` or 2.0 at any width. Negative steps stop at 0.5.
- Bands stay ascending, and none overflows.
- A fluid email gets one rule at `1.1^step`.
- `larger()` at the ceiling leaves the step unchanged.
- Persistence:
  - adjusting saves under the series key, and a new piece with the same key opens at that step;
  - two List-IDs from one sender don't share;
  - reset removes the key;
  - a piece without a series key doesn't persist;
  - the injected defaults are isolated per test.

**Device-only risks (name them).**
- The reload flicker when a step is applied, and whether the height and outer scroll position hold.
- Pinch gesture conflicts.
- Keyboard shortcuts while focus is in the inline Tell Cockpit field: they must not steal ⌘+ from
  text editing if the system claims it.

**Do not.** No per-piece persistence, no syncing, no learning a zoom from behaviour. It changes only
when Jon explicitly adjusts it. No `pageZoom` and no app-injected JavaScript to swap the stylesheet.

**Done when.**
- Jon bumps Feed Me up one step on iPad and the next Feed Me issue opens at that size.
- "Fit" returns it to auto.
- A different newsletter from the same sender is unaffected.
- On iPhone, pressing larger on a fixed-width email stops once the email fills the pane, and nothing
  is cut off.

---

### S-r10 — Open in Mail: hand off to the exact message in Mail.app

**Goal.** When an email needs real email work (forward, reply-all, attachments, careful composition),
one tap in the Reader opens that exact message in Mail.app. Cockpit owns triage and understanding;
Mail owns exceptional email work. This is a hand-off link, not composition. DECISIONS §26 is unchanged.

**Background.** Mail.app resolves `message:` URLs built from the RFC 5322 `Message-ID`. Apple doesn't
document the mechanism, but it has worked for a long time. Jon verified that this exact form opens the
message (from a Mail → Notes drag):
`message:%3C7A.8E.15342.8EF44BA6@i-0a25a4edc84d77c0e.mta1vrest.sd.prd.sparkpost%3E`
Cockpit already stores the value: `GmailArtifactProvenance.rfcMessageID`, captured at ingest from the
`Message-ID` header. No new fetch, no schema change.

**Build.**
- **Pure helper** `MailMessageLink` in CockpitCore: `static func url(rfcMessageID: String?) -> URL?`.
  Trim whitespace, then strip one surrounding `<` `>` pair if present. Return nil if the remaining ID
  is empty or contains whitespace. Build `"message:" + "%3C" + encoded(id) + "%3E"`. Leave the
  RFC 3986 unreserved set plus `@` unencoded (`A–Z a–z 0–9 - . _ ~ @`) and percent-encode everything
  else, notably `+ = / $ % #`, which appear in Gmail-generated IDs. Construct with `URL(string:)`.
  Don't use `URLComponents`: `message:` is opaque, with no `//`. This is the only place that knows the
  scheme, so it can be swapped out if Apple ever breaks it.
- **Provenance lookup, once.** `ReaderReplyModel.load()` (in `GmailReplyService.swift`) has a loop
  that finds the newest Artifact for a ContentPiece and decodes its `GmailArtifactProvenance`. Other
  places re-decode it too. Extract a small CockpitCore helper, e.g.
  `GmailArtifactProvenance.latest(forContentPiece:in:)`, that keeps that loop's semantics: artifacts
  newest `acquiredAt` first, first one that decodes wins. Use it from both `ReaderReplyModel` and the
  Reader model. Leave the other decode sites alone in this slice (`GmailSeriesKey`,
  `CurationRouting`, `CurationRoutingDiscovery`, `EmailTreatment`, `GmailStreamResolver`).
- **Model.** `ContentPieceReaderModel` gains `mailMessageURL: URL?`, set by a new
  `loadMailMessageLink()`. `ReaderView.readerAppeared()` calls it next to `loadRoutingResolution()` and
  `loadEmailZoomPreference()`. The value is nil unless `isGmailSource` is true and a provenance with a
  usable `rfcMessageID` exists. Views never read the database.
- **UI.** In `ReaderDispositionToolbar`, add `Button("Open in Mail", systemImage: "envelope")`.
  - Show it when `model.mailMessageURL != nil`.
  - Put it right after Reply, or first when Reply is absent.
  - Plain style: Archive stays the only `.borderedProminent` action.
  - Offer it for every email role, newsletters included, not only the roles Reply is limited to.
  - Open the URL through the Reader's existing `openURL` environment action, using the
    `openURL(_:completion:)` form. If `accepted` is false (Mail is missing), show a short non-blocking
    message ("Couldn't open Mail") and don't retry.
- Opening Mail has no side effects: no disposition, no attention-state change, no queue advance.

**Prove.**
- `MailMessageLink`:
  - The Notes fixture above round-trips exactly: input
    `<7A.8E.15342.8EF44BA6@i-0a25a4edc84d77c0e.mta1vrest.sd.prd.sparkpost>` gives that exact string.
  - Input without brackets gets wrapped.
  - nil, empty, `<>`, whitespace-only, and internal whitespace all give nil.
  - A Gmail-shaped ID, `<CAF+ab=cd/ef@mail.gmail.com>`, encodes `+ = /`.
- Reader model:
  - an email piece with `rfcMessageID` gives a URL;
  - an email piece whose provenance lacks it gives nil;
  - a non-email piece gives nil;
  - no Artifact on this device gives nil.
- `ReaderReplyModel` tests still pass after the lookup is extracted.

**Do not.**
- No schema or migration change.
- No syncing of `Artifact` or provenance.
- No persisted URL.
- No Gmail-web or Gmail-app fallback.
- No attempt to detect whether Mail found the message.
- No changes to Reply or to the scope of DECISIONS §26.

**Device-only risks (name them).**
- Whether Mail.app on iPad resolves the link, in particular:
  - for a message Cockpit has already **archived** in Gmail, which lives only in All Mail;
  - for a Gmail-originated ID containing `+` or `=`.
- A miss is silent: `openURL` reports success once Mail launches, even if Mail can't find the
  message.
- Only the ingesting device has the button. `Artifact` isn't in the CloudKit sync set, so on a
  non-ingesting device (e.g. iPhone) the button is hidden. That's intended for now.
- Toolbar overflow at narrow split widths, which adds to S-r2's risk.

**Done when.** On the ingesting iPad, tapping Open in Mail in the Reader for a Gmail piece opens that
exact message in Mail.app. The button is absent where there's no Message-ID.

**Sequencing.** S-r10 touches `ReaderDispositionToolbar.swift`, `ReaderView.swift`, and
`ContentPieceReaderModel.swift`, all of which S-r9 is also changing. Build it after S-r9 merges, or
rebase onto it. Branch: `m6/s-r10-open-in-mail`.
