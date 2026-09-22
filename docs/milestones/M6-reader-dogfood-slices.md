# M6 — Reader dogfood slices (S-r1 … S-r5)

> **Build order, architect-recorded 2026-09-22 from Jon's device dogfooding of the S-d0 surface.**
> These make the Today reading split usable day to day ahead of the S-d device eval. They do not
> reopen any Gate 4 decision (D-A–D-G). Each block is self-contained: send it to the executor as-is.
> Branch per slice: `m6/s-rN-short-slug`, one PR each, tick the box here in the PR that completes it.

**Dependency shape:** S-r1 → S-r2 → S-r5. S-r3 and S-r4 float (S-r3 is easiest after S-r2 because both
touch `ReaderView.swift`).

- [x] S-r1 — Queue flow: disposed issues leave the queue, advance to next, Undo
- [ ] S-r2 — Reader chrome: actions in the toolbar, inline Tell Cockpit, Delete archives
- [ ] S-r3 — Reader facts: sender names, received dates, links open in Safari
- [ ] S-r4 — Sync on open/foreground (throttled)
- [ ] S-r5 — Plain-text reply in thread (DECISIONS §26)

## Standing rules for every slice

- Verify with `swift test` (CockpitCore), `swiftlint lint --strict`, and an unsigned app build. No
  Simulator or device driving (AGENTS.md). Name any device-only risk in the handoff report and stop.
- Behaviour lives in `@Observable` models or pure functions in `CockpitCore` and is tested there. Views
  do not touch the database.
- Never change stored `ContentPiece.publisher` / `creator`: `ContentIdentity.derive` hashes the
  publisher, so rewriting it forks identity. All sender prettifying is display-only.
- Gmail boundary (ADR-0002) is unchanged except where a slice cites DECISIONS §25 (amended) or §26.

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
- `TodayView`: run the existing `refreshToday()` on first appearance and on `scenePhase` → `.active`
  when the policy allows. Automatic runs do not surface a missing-authorization error (manual Refresh
  still does).

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
