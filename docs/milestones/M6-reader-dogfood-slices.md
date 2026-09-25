# M6 — Reader dogfood slices (S-r1 … S-r13)

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

**Today navigation (S-r11), recorded 2026-09-24 from Jon's iPad dogfooding.** Four display-only fixes
that keep Jon oriented in Today: Highlights peek in a sheet, the reading split gets a way back, the
Reader toolbar stops dropping a row when a divider drag starts, and a section rail jumps down the
queue. No
schema, identity, Gmail, or judgment changes. Amends D-E for Highlights only (see the gate doc).

**Finds list tidy-up (S-r12), recorded 2026-09-25 from Jon's dogfooding.** Settings → Finds reads as
a raw dump: the rows come out in UUID order, dismissed Finds never leave, and there's no way back to the
email a Find came from. Jon's question was "what am I supposed to be doing with those?", so the list has
to answer it. Display and query only: no schema, identity, Gmail, or judgment changes. Build it after
Gate 5's S-c3, because both touch `PendingFindListModel`. **Amended 2026-09-25** after Jon's device pass:
pending rows get visible Save / Dismiss buttons, and a Reader opened from Finds closes after it disposes
its source (see the S-r12 block).

**Find definition (S-r13), recorded 2026-09-25 from Jon's dogfooding.** The Finds list fills with
Techniques and Capabilities from tech newsletters: ideas, not things an app could take, so they can
never resolve. (The Tools there are products and stay Finds.) Neither prompt says what a Find is. S-r13
gives both prompts DECISIONS §3's definition (clarified the same day) plus a deterministic backstop. It
changes judgment and extraction only: no schema, identity, Gmail, or list changes. Build it after
S-r12.

- [x] S-r1 — Queue flow: disposed issues leave the queue, advance to next, Undo
- [x] S-r2 — Reader chrome: actions in the toolbar, inline Tell Cockpit, Delete archives
- [x] S-r3 — Reader facts: sender names, received dates, links open in Safari
- [x] S-r4 — Sync on open/foreground (throttled)
- [x] S-r5 — Plain-text reply in thread (DECISIONS §26)
- [x] S-r6 — Confirmed-Find barrier for offer disposition (DECISIONS §24 amendment, 2026-09-23)
- [x] S-r7 — Email fit: capped fit-to-column zoom
- [x] S-r8 — Reader column: header aligns with the email
- [x] S-r9 — Per-publisher zoom: adjust once, remembered per series
- [x] S-r10 — Open in Mail: hand off to the exact message in Mail.app
- [x] S-r11 — Today navigation: Highlights sheet, way back, one-row toolbar, section rail
- [x] S-r12 — Finds list tidy-up: grouped by what's needed, newest first, dismissed hidden, open the source
- [ ] S-r13 — Find definition: ideas aren't Finds, in both prompts and at persist

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

---

### S-r11 — Today navigation: Highlights sheet, way back, one-row toolbar, section rail

**Goal.** Moving around Today never strands Jon. A Highlight is a quick look that keeps him on the
orientation surface. The reading split always has a visible way back. The Reader toolbar stays on one
row whatever the divider has done. A rail on the reading list jumps to any section and shows how much
is left in each.

**Decision (Jon, 2026-09-24).** D-E stands for section rows and the tail: they open the reading split.
**Highlights cards are the exception:** they open the Reader in a sheet over the orientation surface,
because a Highlight is a sampler ("a quick way in"), and entering the split for it leaves Today. This
brings back the pre-S-d0c sheet presentation for Highlights only. The sheet is still a full Reader, and
every Reader path keeps the same safety boundary.

**Build.**

1. **Highlights open in a sheet.**
   - `TodayLandingView` gains an `openHighlight: (TodayRequest.Row) -> Void` closure. Only the
     Highlights cards call it. Section rows, Offers roll-ups, and tail rows keep calling `openReader`.
   - `TodayView` owns `@State var highlightRow: TodayRequest.Row?` and presents it with
     `.sheet(item:onDismiss:)`: `NavigationStack { ReaderView(…) }` with `.presentationSizing(.page)`,
     `.presentationDetents([.large])`, `.presentationDragIndicator(.visible)`, and
     `.navigationTransition(.zoom(sourceID: row.id, in: readerTransition))`. The cards already carry
     `matchedTransitionSource`. In the sheet, add a leading `Button("Done", systemImage: "checkmark")`
     that dismisses it. Swipe-down dismisses too.
   - Configure `ReaderView` from the piece's reading-queue row, looked up in `readingQueueModel.rows`
     (the I5 projection-consistency test guarantees it's there): same `editionContext` and
     `isReachableStreamPiece` as the split detail. Extract the `editionContext(for:)` builder out of
     `TodayReadingQueueDetail` so both call sites share it. Its `clearSelection` dismisses the sheet.
   - `queueContext` archives and trashes through `TodayModel.archive(_:)` / `trash(_:)`, the same path
     the landing row menu uses, then dismisses the sheet. Never through `TodayReadingQueueModel`:
     that model moves the split's selection and sets the split's Undo, and neither applies here.
   - `onDismiss`: `await readingQueueModel.applySeriesTrashOnLeave(id)` (the one M6 S1 boundary every
     Reader path shares), then reload `model.$content` and `readingQueueModel`, so a disposed piece
     leaves the landing (M5: disposed items disappear).
2. **A way back from the reading split.** The `Done` item in `TodayReadingView` is attached outside
   the split's columns, so iPadOS never shows it. That's the lost affordance.
   - Move it into the list column's toolbar at `.topBarLeading`:
     `Button("Back to Today", systemImage: "chevron.backward")`, calling the existing
     `finishReading()` (which still applies series trash-on-leave to the open piece).
   - When `columnVisibility == .detailOnly`, show the same button at `.topBarLeading` in the detail
     column, so it's never lost. Keep the system sidebar toggle as it is.
3. **The Reader toolbar stays on one row.** *(As shipped, 2026-09-24. This replaces the planned
   commit-on-release fix, which device testing ruled out.)*
   - *Cause.* With `.sidebarAdaptable`, iPadOS fits the floating tab bar into the same row as the
     split's navigation bars. A divider drag makes it re-decide. When it gives up, it moves every
     column's bar below the tab bar and never moves them back. It isn't about toolbar width: removing
     Reply and Open in Mail changed nothing, and the list column's bar dropped too.
   - *Fix.* `TodayReadingView` hides the tab bar with `.toolbarVisibility(.hidden, for: .tabBar)`.
     Reading is a focused sub-mode of Today and has its own Back to Today (item 2). With no tab bar,
     there's nothing for the bars to stack under. Apply it only to the Today reading split, never to
     `ReaderView`: Later, Library, Following, and the Highlights sheet reuse `ReaderView` and have no
     Back to Today.
   - *Divider.* Live resize, as before S-r11. The drag state stays in `TodayReadingView`, and the
     stored width updates as the finger moves. `ReadingPaneWidth.draggedWidth(start:translation:current:)`
     skips the write when the clamp leaves the width unchanged. Tried and dropped: committing on release
     with a preview line. On device, the drag felt dead.
   - *Cost.* To reach Later, Library, or Settings from the reading split, go Back to Today first.
   - *Narrow detail.* In `ReaderDispositionToolbar`, put Archive and Trash in their own
     `ToolbarItemGroup` with `.visibilityPriority(.high)` (iOS 27), so Reply, Open in Mail, and Dismiss
     go to overflow first. Archive stays the only `.borderedProminent` action.
4. **Section rail on the reading list.**
   - **Presentation mapping.** Add `CockpitApp/ContentRolePresentation.swift` with
     `ContentRole.color` and `ContentRole.symbolName`, using exhaustive switches with no `default`.
     Move `sectionColor(_:)` there from `TodaySurfaceRows.swift`, so the landing's section dots and the
     rail share one mapping. Symbols:

     | Role | Symbol |
     | --- | --- |
     | For you | `person.crop.circle` |
     | Transactional | `creditcard` |
     | Daily news | `newspaper` |
     | Opinion | `quote.bubble` |
     | Grab-bag | `square.grid.2x2` |
     | Food | `fork.knife` |
     | Wine | `wineglass` |
     | Offers | `tag` |

     Any role added later (for example `arts`, which is in progress) must get a color and a symbol,
     and the missing switch case stops the build until it does.
   - **Model.** `TodayReadingQueueModel` gains `selectedRole: ContentRole?`, the role of the section
     containing `selectedContentPieceID`, or nil. Counts come from `sections[i].rows.count`. No new
     query.
   - **View.** `TodayReadingQueueSidebar` wraps the `List` in a `ScrollViewReader` and hosts a vertical
     rail in a **leading** `safeAreaInset`, like a mini menu, so rows never run under it. *(As shipped:
     on the trailing edge, the rail sat under the divider handle and fought its drag.)*
     - The rail is top-aligned, inside the list column, with a hairline on its trailing edge. The
       divider handle keeps the list's trailing edge to itself.
     - It has one item per non-empty section, in queue order. Each item is the role's symbol, tinted
       with the role's color, over its count in `.caption.monospacedDigit()`, with a 44pt minimum
       target.
     - The item for `selectedRole` gets a tinted capsule background: that's where Jon is reading.
     - Tapping an item calls `proxy.scrollTo(section.rows[0].id, anchor: .top)`. It **never** changes
       selection, because a selection change fires series trash-on-leave on the open piece.
     - Accessibility label per item: "Wine, 3 messages".
     - Hide the rail when there's only one section.
     - If the items outgrow the column's height, the rail scrolls.

**Prove.**
- `ReadingPaneWidth.draggedWidth`:
  - nil when the clamped result equals the current width (including a drag past either bound while
    already at it);
  - the clamped value otherwise.
- `TodayReadingQueueModel.selectedRole`:
  - nil with no selection;
  - the right role for a selected row;
  - it follows selection when `archive(_:)` advances to a neighbour in the next section;
  - nil after the last row is disposed.
- The sheet's queue-row lookup is already guaranteed. `landingItemsOpenInQueue` asserts every
  `TodayRequest` row is a reading-queue row, and Highlights are drawn from those rows. Keep that test
  passing; no new test is needed for it.
- The existing `applySeriesTrashOnLeave` and S-r1 queue tests pass unchanged.

**Do not.**
- Don't change what the Highlights row contains (D-D/I5). Only its presentation changes.
- Don't send section rows, Offers roll-ups, or tail rows to the sheet.
- Don't archive or trash from the sheet through `TodayReadingQueueModel`.
- Don't let a rail tap change selection.
- No scrubbing along the rail, and no rail on the orientation surface.
- No schema, query, or Gmail change.

**Device-only risks (name them).**
- Checked on iPad (Jon, 2026-09-24): with the tab bar hidden, the bars stay on one row through
  divider drags. The drag works but is finicky; that's accepted for now.
- `scrollTo` landing under a pinned section header.
- Row legibility at the 268pt minimum list width once the rail takes its share.
- The zoom transition from a card inside a horizontal `ScrollView`.
- A Reader sheet presented over a `NavigationStack` inside a `sidebarAdaptable` tab.

**Done when.**
- On iPad, tapping a Highlight opens its Reader in a sheet, and dismissing it returns to the same
  scroll position on the orientation surface. Archive or Trash in the sheet dismisses it, and the piece
  is gone from the landing.
- The reading split shows Back to Today top-left at all times.
- After any divider drag, the navigation bars stay on one row. The tab bar is hidden while reading.
- The rail jumps to each section, and its counts fall as pieces leave.

**Sequencing.** Touches `TodayView.swift`, `TodayLandingView.swift`, `TodayReadingView.swift`,
`TodaySurfaceRows.swift`, `ReaderDispositionToolbar.swift`, and `TodayReadingQueueModel.swift`. If the
in-progress `arts` role lands first, rebase onto it; the exhaustive switches will name what it needs.
Branch: `m6/s-r11-today-navigation`.

### S-r12 — Finds list tidy-up: grouped by what's needed, newest first, dismissed hidden, open the source

**Why.** A Find waits in Settings → Finds until an app can take it (APP-FAMILY §5). Today the list
doesn't say that, and it can't be scanned:
- `PendingFindListRequest` orders by `PendingFind.id`, a derived UUIDv5, so the order is effectively
  random.
- Dismissed Finds stay in the list forever.
- A row can't open the ContentPiece it came from.

**Build.**
- **Group by what's needed.** Three sections, in this order:
  - **Needs a decision:** `pending`. Visible Save and Dismiss buttons on the row, and the same two
    as swipes. *(Amended 2026-09-25: swipe-only hid the decision. Recipe rows looked fine only because
    they also carry "Send to Yes Chef"; every other kind showed no way to decide.)*
  - **Saved:** `confirmed` and `referred`. "Send to Yes Chef" stays on recipe Finds, and S-c2's strand
    row stays as is.
  - **Resolved:** `handedOff` and `declined`, with S-c2's labels ("Added to Yes Chef" / "Declined by
    Yes Chef").

  Hide empty sections.
- **Newest first within each section.** Order by the source piece's `publishedAt`, falling back to
  `ContentPiece.createdAt`, then by `name`. `PendingFind` has no timestamp of its own, and this slice
  doesn't add one: the table syncs through CloudKit, so a new column would be a schema change.
- **Hide dismissed by default.** Add a "Show Dismissed" toggle in the list's toolbar menu, so a
  mistaken swipe can still be found and saved again. When the toggle is on, dismissed Finds appear
  in a fourth section at the bottom with a visible Save button (and a Save swipe). This is a view
  filter, not a state change.
- **Open the source.** Tapping a row pushes `ReaderView(contentPieceID:)` for the Find's
  ContentPiece, the same way Later and Library host the Reader (`ContentPieceListView`). Keep the
  row's actions as buttons and swipes so they don't fight the tap.
- **Close the Reader after it disposes its source.** *(Added 2026-09-25 from Jon's device pass: from
  Finds, Archive / Trash left the Reader open with no sign anything happened.)* Outside Today's queue,
  every Reader disposition path ends in `ContentPieceReaderModel.archiveSource()` / `trashSource()` and
  nothing closes the view. (Library doesn't close it either; there the Reader is a split-view detail,
  so it doesn't matter. The original risk line below claimed otherwise and was wrong.)
  - `archiveSource()` and `trashSource()` return `Bool` (`@discardableResult`): `true` when the
    disposition committed.
  - `ReaderView` takes an optional `onSourceDisposed: (@MainActor () -> Void)?`, the same shape of
    seam as `ReaderQueueContext`. The Settings route passes `{ model.popSettings() }`
    (`SettingsView.model` is the `ShellModel`). Today, Later, Library, and Stream Handling pass
    nothing and behave exactly as now.
  - Route every non-queue disposition through one helper in the Reader that calls the model and, on
    `true`, calls `onSourceDisposed`. That covers the toolbar's Archive / Trash / Delete, Send Reply &
    Archive, the offer card's Save Find (which trashes), and Send to Yes Chef from the Reader (which
    trashes). Don't use `@Environment(\.dismiss)`: in Library's split view it would do the wrong thing.
  - The Find itself is untouched: archiving the email is a decision about the email, not the Find
    (DECISIONS §3). The row stays where it was in the list.
  - No new Undo banner. Undo stays in the Reader's ⋯ menu and the Recent Trash sheet.
- **Say what the list is for.** A footer under the first section, one or two lines: Finds wait here
  until an app can take them; recipes can go to Yes Chef now; the rest keep until an app exists.
  Keep the empty state.

**Prove (core).**
- The model's sections group rows as above, and the request orders them (publishedAt desc, createdAt
  fallback, name tie-break). Section membership comes from one exhaustive switch on the state.
- Dismissed Finds are excluded unless the model's show-dismissed flag is set.
- Saving from the dismissed section restores `confirmed`.
- A Find whose piece has no `publishedAt` sorts by `createdAt`.
- `archiveSource()` / `trashSource()` return `true` on a committed disposition and `false` when the
  client fails (the model's existing failing-client setup). The close itself is view wiring and isn't
  tested.

**Do not.**
- No new column on `PendingFind`.
- Don't hard-delete dismissed Finds.
- Don't auto-dismiss or age anything out: nothing leaves this list without Jon's act.
- Don't add receivers or actions for non-recipe kinds. Galavant and the rest stay deferred.
- Don't change the S-r6 barrier or when disposition policies run.

**Device-only risks (name them).**
- From Finds, Archive / Trash / Delete / Send Reply & Archive / Save Find on an offer / Send to Yes
  Chef each close the Reader back to the list once, and a failed disposition leaves it open with its
  error.
- Tap-versus-swipe conflicts on rows that also carry inline buttons, and whether rows read as tappable
  without a chevron.

**Done when.**
- Settings → Finds shows Needs a decision / Saved / Resolved, newest first, with no dismissed rows
  until the toggle is on.
- Tapping a Find opens its email or article in the Reader.
- The footer tells Jon what the list is for.
- Every pending row shows Save and Dismiss without swiping.
- Archiving or trashing from a Reader opened from Finds lands back on the list.

**Sequencing.** Touches `PendingFindListRequest.swift`, `PendingFindListModel.swift`, and
`PendingFindListView.swift`; the 2026-09-25 amendment adds `SettingsView.swift`, `ReaderView.swift`,
`ReaderViewContent.swift`, `ReaderDispositionToolbar.swift`, and `ContentPieceReaderModel.swift`.
Build after Gate 5's S-c3, which refactors the send path in the same model. Branch:
`m6/s-r12-finds-list-tidy`.

---

### S-r13 — Find definition: ideas aren't Finds, in both prompts and at persist

**Why.** Jon's Finds list (2026-09-25) holds Techniques and Capabilities pulled from tech newsletters
(its Tools are products and stay Finds). The ideas can't resolve: no app will ever take a technique, so
Save only parks it under Saved forever. They also pollute the orphan-Find evidence that DECISIONS §3
relies on. The cause is that neither prompt says what a Find is:
- `JudgmentPrompt` (editorial pass, and the single-pass control) says only "finds empty when no
  concrete useful thing is present".
- `EmailTreatmentPrompt` (the offer treatment in `EmailTreatmentProcessor`) asks for "exactly one
  useful Pending Find candidate".

DECISIONS §3 was clarified the same day and `JUDGMENT-CONTRACT.md` now states the rule. This slice
implements it.

**Build.**
- **One definition, shared.** Add a single prompt fragment in `CockpitCore` (for example
  `FindDefinition.promptText`) and interpolate it wherever a prompt asks for Finds: the editorial
  prompt, the single-pass control prompt, and the offer prompt. Wording, close to:
  > A Find is a thing a specialist app could admit: a place, product, dish, bottle, book, event, or
  > stay. Software and hardware tools are products. Ideas are never Finds: not a technique,
  > capability, pattern, practice, argument, insight, trend, or tip. When a piece's value is its
  > ideas, return no Finds.

  Keep the existing `recipe` routing-hint sentence as it is.
- **Offer prompt.** Keep "exactly one" and the schema's required `find`: an offer is a domain offer
  by classification, and S-r6's barrier relies on its Find. Add the definition so that the one Find
  is a thing.
- **Deterministic backstop.** In `PendingFindOperations.persist`, skip any proposal whose `kind`,
  lowercased and trimmed, is on a short idea-kind list: `technique`, `capability`, `pattern`,
  `practice`, `approach`, `method`, `concept`, `idea`, `insight`, `argument`, `trend`, `tip`,
  `lesson`, each with its plural spelled out (`capabilities`, not a stemmer). Leave `framework` and
  `tool` off: a software framework is a product. Put the list next to `RecipeCandidateKind` as an enum
  with a `matches(_:)` in the same style. It's a drift guard, not a classifier: don't grow it into one,
  and don't consult `name` or `descriptor`.
  - The guard runs before the insert/update branch, so a declined proposal neither creates a row nor
    updates an existing one. Rows already persisted are never touched.
  - It sits in `persist` so it covers both callers: `EditionEntryWriter` and
    `EmailTreatmentProcessor`. For an offer, the summary still persists when its Find is declined;
    that offer simply has no Find (it can't satisfy `offerWithFind`, which is correct).
- **Bump prompt versions:** `JudgmentEngine.editorialPromptVersion` and
  `singlePassControlPromptVersion`, and the offer prompt's version if it has one (add one if it
  doesn't, following the judgment pattern).

**Prove (core).**
- `persist` skips `technique`, `Techniques`, ` capability `, and `Capabilities`; keeps `restaurant`,
  `recipe`, `tool`, `framework`, `book`, and `product`; and writes nothing when every proposal is
  declined.
- A declined proposal whose ID matches an existing row (same kind, name, and URL) leaves that row
  exactly as it was, state included.
- An offer output whose Find is declined still persists its summary and creates no `PendingFind`.
- Every prompt that asks for Finds contains `FindDefinition.promptText` (one assertion per prompt, so
  a new prompt without it fails loudly).

**Prove (eval), recorded in `docs/eval-log.md`.** Run the live eval (`COCKPIT_RUN_JUDGMENT_EVAL=1`)
on the old and new editorial prompt versions over the frozen corpus, and tally Finds by kind (add the
tally to the eval report; it's a count, not a new metric). Record:
- idea-kind proposals before → after, which should reach zero or near it;
- thing-kind proposals before → after, especially Feed Me and Bon Appetit, which must not drop
  materially;
- a sample of what Benedict Evans and Techmeme now yield.

The six existing metrics must not regress. The offer prompt runs on device, so its effect is a
device-only risk (see below).

**Do not.**
- Don't dismiss, delete, or migrate existing idea-kind Finds. Jon dismisses them with S-r12's buttons:
  nothing leaves the list without his act.
- Don't route ideas anywhere else: no Personal Knowledge proposal, no Library admission, no new
  "idea" destination. Model output never becomes Personal Knowledge (AGENTS.md AI boundary).
- Don't add a `kind` enum, a schema change, or kind validation beyond the idea-kind guard. `kind` stays
  a free-text routing hint.
- Don't change the offer schema, the S-r6 barrier, or the list.

**Device-only risks (name them).**
- On-device offer extraction may still return an idea kind for a course, webinar, or service offer.
  The guard catches listed kinds; watch the list for new ones and report them rather than extending the
  guard in this slice.

**Done when.**
- Recomposing after the slice adds no new Technique, Capability, or similar Finds from tech
  newsletters, and restaurants, recipes, wines, products, and tools still arrive.
- `eval-log.md` has the before/after tally.

**Sequencing.** Touches `JudgmentPrompt.swift`, `EmailTreatmentProcessor.swift`, `PendingFind.swift`,
`FindHandoff.swift` (or a sibling file for the kind list), `JudgmentEngine.swift` (versions), and the
eval report in `JudgmentEngineTests.swift`. Build after S-r12, so that Jon can dismiss the existing
idea Finds from the list. Branch: `m6/s-r13-find-definition`.
