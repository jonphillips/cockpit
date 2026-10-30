# M6 — Background disposition: rows leave at once, Gmail confirms behind them

> **Slice spec for the executor.** Architect-defined 2026-10-12 from Jon's report that trashing is slow,
> worst on the Offers review page with Trash all. Two slices, one branch: S-d1 → S-d2. No schema, no
> migration, no sync change. The D4 barrier and D6 log are unchanged; only *when the row leaves the
> screen* changes (ADR-0002 D6 amendment, 2026-10-12).

## What's wrong today (evidence from the code, 2026-10-12)

Nothing literally blocks the main thread, but every disposition is awaited in full before the UI moves:

- `OfferReviewModel.trashAll()` runs `GmailDispositionService.apply(.trash, …)` **one email at a time**
  and reloads only after the last one. With N offers the cards stay on screen for N serial round trips.
  The "Trash all N" button stays enabled the whole time, so a second tap starts a second pass. Two
  concurrent applies for the same message can both pass `activeEntry` and log twice.
- Each round trip is heavy: `GmailDispositionWiring.client()` calls `accessToken()`, which is
  `@MainActor` and runs `GIDSignIn.restorePreviousSignIn` + `refreshTokensIfNeeded` **for every
  message**, then the HTTP call (up to 4 retries with 1/2/4/8 s back-off on throttling), then a DB read
  and a DB write.
- Undo only appears when the whole batch finishes. If Jon leaves review mode mid-batch, the work
  continues in an orphaned `Task`. `didChangeBatch` hands the result to `TodayModel.lastOfferBatch`
  only at the end.
- Single-row Trash/Archive (Today rows, quick look, Process, Reader) has the same shape at N = 1: the
  row waits for the token dance and the HTTP call before it leaves.

## The behaviour Jon wants

1. Tapping Trash (or Trash all) removes the rows **immediately**.
2. The Gmail calls run in the background, a few at a time.
3. **Undo is available from the first moment** and stays until the batch has settled and Jon dismisses
   it. Undo on a batch that's still running stops it: unstarted emails are never trashed, in-flight
   ones finish and are then untrashed.
4. If anything fails, Jon gets an **alert**, and the emails that weren't trashed come back.

## Standing rules

- Verify per `docs/verification.md`. No Simulator or device driving. Device-only risks go in the PR as
  unverified.
- Behaviour lives in `CockpitCore` `@Observable` models and is tested there with a fake
  `GmailDispositionClient`. Views don't touch the database.
- **The barrier is untouched.** `GmailDispositionService.apply` keeps its order: verify the commit,
  mutate Gmail, *then* write the log entry. Nothing is written ahead of the mutation. Optimistic
  hiding is in memory only. No new table, column, or "pending" row.
- Gmail calls stay windowed. New constant `maxConcurrentDispositions = 4` (below the read path's 6).
- No new destructive authority. The queue runs only dispositions Jon just tapped. Policies, series
  trash, and the sync path keep calling `GmailDispositionService` directly.
- Default system styling. Copy follows the house voice: short and plain.

---

### S-d1 — Disposition queue, and Offers Trash all on it

**Build.**

- **`GmailDispositionQueue`** (CockpitCore, `@MainActor @Observable`), one app-scoped instance.
  `CockpitApp` creates it next to `ListedFeedsModel` and passes it to `TodayModel` and
  `OfferReviewModel` the same way.
  - `submit(_ disposition: GmailSourceDisposition, contentPieceIDs:, label:) -> Batch.ID` returns
    synchronously after recording the batch. IDs that are already in a live batch are dropped (this
    fixes the double-tap and double-log race). `.leave` is a no-op.
  - `Batch`: `id`, `disposition`, `contentPieceIDs`, `label` (for example "Offers" or "Wine"), `phase`
    (`.running`, `.undoing`, `.settled`), `applied: [GmailDispositionLogEntry]`, `failures`.
  - `hiddenContentPieceIDs: Set<ContentPiece.ID>` is every ID in a batch that isn't settled, plus
    applied IDs until their owners have reloaded. Projections subtract this set.
  - Work runs in a `Task` the queue owns, with a `TaskGroup` window of `maxConcurrentDispositions`
    calling the existing `GmailDispositionService.apply`. The service and `DatabaseWriter` are already
    `Sendable`, so the network and DB work run off the main actor. Results come back to the main actor
    one at a time.
  - `undo(_ batch:)`: works in every phase. While running, it stops dispatching new IDs (the
    unstarted ones were never trashed, so they just un-hide) and waits for in-flight applies. Then it
    reverses `applied` with the existing `GmailDispositionService.undo(_:in:)`. Phase is `.undoing`
    meanwhile, and the batch's IDs stay hidden until the reverse settles, so rows don't flicker in
    and out.
  - `dismiss(_ batch:)` is offered only once the batch is `.settled`. The Undo bar can't disappear
    before Gmail has confirmed.
  - **Failures.** When a batch settles with failures, the failed IDs leave `hiddenContentPieceIDs` (the
    emails come back) and the queue sets `alert: DispositionAlert?`. Copy: title "Couldn't trash 3 of
    12 emails" (or archive, or restore for an Undo failure), message = the first error's
    `localizedDescription`. A batch where everything failed leaves no Undo bar, only the alert. An Undo
    failure leaves the un-restored entries in the batch, so Undo can be tried again. Recent Trash still
    lists each message, as now.
  - **Reload handshake.** On settle, the queue calls a `didSettle` hook. `TodayModel` reloads
    `$content` / `$offers` / recent trashes, `OfferReviewModel` reloads if it's alive, and only then
    does the queue release the applied IDs from the hidden set. Applied rows are hidden by their log
    entry by then (`TodayRequest`), so nothing flashes back.
  - Cancellation of the queue's own task (app teardown) is the one case where an unstarted ID is
    neither applied nor failed: it un-hides, and it's not alerted.
- **Offer review on the queue.** `OfferReviewModel.trashAll()` becomes a synchronous
  `queue.submit(.trash, contentPieceIDs: rows.map(\.id), label: role.displayName)`. `rows` subtracts
  `queue.hiddenContentPieceIDs`, so the grid empties at once and `isClear` becomes "no visible rows
  and a batch exists for this role". Delete `lastBatch`, `didChangeBatch`, `statusMessage`'s
  batch-count copy, and `undoLastBatch` (the bar calls the queue). Keep/unkeep are unchanged.
- **Today on the queue.** `TodayModel.offerDoors`, the Offers index count, and the door counts
  subtract the hidden set, so a door with every offer pending disappears at once. Replace
  `lastOfferBatch` / `offerUndoMessage` / `rememberOfferBatch` / `undoLastOfferBatch` /
  `dismissOfferUndo` with reads of the queue's latest offer batch. `TodayModel.trashAll` /
  `archiveAll` have no app caller. Delete them, or route them through the queue if a test still needs
  them.
- **Undo bars.** `OfferReviewFinishBar` and `TodayView.bottomBanner` read the same batch. Running:
  "Trashing 12 emails…" with **Undo**. Undoing: "Restoring…" with no buttons. Settled: "Trashed 12
  emails" with **Undo** and **Dismiss**, as today. Leaving review mode mid-batch shows the same bar on
  Today.
- **Alert.** Present `queue.alert` with one OK button from the root (`TodayView`) and from
  `OfferReviewView`, because a sheet covers the root. Clearing `alert` on OK clears it for both.
- **Token reuse** (`GmailDispositionWiring`, app-side). Use `GIDSignIn.sharedInstance.currentUser`
  when it's present, and fall back to `restorePreviousSignIn` only when it's nil. Keep
  `refreshTokensIfNeeded`, which only hits the network near expiry. This removes the per-message
  sign-in restore. It's the same `accessToken()` that reply and read state use, so they benefit too.

**Tests** (CockpitCore, fake client whose `trash`/`untrash` suspend on a gate the test opens):

- Submit hides every ID synchronously, and `OfferReviewModel.rows` / `TodayModel.offerDoors` exclude
  them before any client call returns.
- At most `maxConcurrentDispositions` client calls are in flight at once.
- Resubmitting an ID that's already live doesn't call the client twice or log twice.
- Undo while running: unstarted IDs never reach `trash`, in-flight ones are `untrash`ed after they
  land, every log entry ends up reversed, and all rows are visible again.
- Partial failure: failed IDs come back, succeeded ones stay hidden by their log entry after settle,
  `alert` names the counts, and Undo reverses only the applied ones.
- Total failure: no Undo bar state, alert set, all rows back.
- Undo failure: un-restored entries remain undoable, and the alert says "restore".
- No flicker: across settle, an applied ID is never absent from both the hidden set and the
  log-filtered projection.
- Replace the existing `OfferReviewTests` batch tests ("Trash all preserves kept Finds…", "Today Undo
  restores…", "A partial Trash…") with queue-based equivalents. Kept Finds stay kept through trash and
  Undo, per §30. UUIDs are assigned out of order under concurrency, so assert on sets, not order.

**Device-only (unverified, for the PR).** Trash all on a real batch of 10 or more offers clears
instantly. The bar reads "Trashing…", then "Trashed". Undo mid-batch restores everything in Gmail.
Leaving review mode mid-batch carries the bar to Today. The alert appears once, on top, with
review mode open and with it closed (airplane mode forces a failure). Token reuse holds across a
token expiry.

---

### S-d2 — Single-row Trash and Archive on the queue

**Build.** Route the explicit, tapped single-row dispositions through `queue.submit` with one ID:

- `TodayModel.trash(_:)` / `archive(_:)` (Today rows, quick look).
- `TodayReadingQueueModel.trash` / `archive` (`applyDisposition`). Selection advances and
  `lastDisposition` is set **at submit**, not after the call returns. Its Undo calls `queue.undo` for
  that batch (cancel if still running). `rows` subtracts the hidden set.
- `ContentPieceReaderModel.trashSource()` / `archiveSource()` return `true` on submit, so the Reader
  closes at once through `onSourceDisposed`. A failure surfaces through the queue alert. The Reader's
  own `undoDisposition()` stays as is, because by the time Jon can reach it the batch has settled.

**Out:** series trash on leave (`applySeriesTrash*`), `GmailDispositionPolicyService`, and Undo from
Recent Trash. These stay direct. They're silent or already-settled paths.

**Tests.** For each of the three models: the row leaves before the client returns, a failure brings
it back and sets the queue alert, and Undo while pending never calls `archive`/`trash` for an unstarted
ID. Process selection advances to the same neighbour as before.

**Device-only (unverified).** Today, Process, quick look, and Reader Trash/Archive each feel instant.
A forced failure (airplane mode) alerts and the row returns.

---

## Ledger

- [x] S-d1 — Disposition queue, and Offers Trash all on it
- [x] S-d2 — Single-row Trash and Archive on the queue
