# Effort — Morning prep

Status: Ready
Summary: One refresh operation gets mail and feeds ready before Jon opens Cockpit, started by a Shortcuts automation at about 6:50, backed up by iPadOS background refresh, and caught up visibly on open when neither ran.

Implements: [DECISIONS.md](../../DECISIONS.md) §35, [ADR-0001](../../ADR-0001-PERSISTENCE-AND-EXECUTION.md) D1 and
[ADR-0002](../../ADR-0002-GMAIL-INTEGRATION-AND-DISPOSITION.md) D7 as amended 2026-11-25. There's no change to the
persisted schema, CloudKit, or Edition. If a slice seems to need one, stop and raise a `question-for-architect`.

**The promise:** usually ready by 7; when it isn't, Cockpit catches up on open and says so. iPadOS gives an app no
reliable clock trigger, so nothing here depends on one firing.

Two slices, in order. S-p1 is the operation and the main trigger. S-p2 is the backup trigger and the line on Today. The
S-p1 PR runs closeout with `--keep-brief` and sets S-p2 as the next dispatch. S-p2 doesn't wait for S-p1's device gate,
because a main trigger that doesn't fire makes the backup more useful.

## What's there now

- Mail and feeds start from SwiftUI `.task`s (`CockpitApp.swift` ~108–128), so nothing else can start them.
- Feeds poll only on a cold launch or a manual refresh. `scenePhase == .active` syncs mail and never polls feeds.
- Feeds poll one at a time on URLSession's default timeouts, so one stalled feed can use up a background window.
- `GmailInboxIngestor.ingest` runs offer extraction before it advances the cursor. A cutoff there repeats the whole read.
- `EmailTreatmentProcessor.process` writes all its outputs at the end, so a cutoff loses finished ones.
- `FeedIngestor` calls `markFailed` for any error, including cancellation.
- There are no App Intents and no `BGTaskScheduler` code.

## S-p1 — The operation, the intent, and feeds on return

### `MorningPrep` in `CockpitCore`

One shared, dependency-injected operation. Every caller uses it: the launch and activation paths, pull-to-refresh on
Today, Feeds, and Following, the intent, and S-p2's background task. **The old entry points stop orchestrating on their
own.**

- **Request:** a trigger (`open`, `manual`, `automation`, `backgroundRefresh`) and an optional time budget. Which steps
  run derives from the trigger. Don't add booleans.
- **Single flight:** a second caller joins the run in progress. If that run is unattended and the joiner is `open` or
  `manual`, the joiner's own extra work (policies; a step the budget cut off) follows it. Cancelling one waiter
  doesn't cancel the run.
- **Freshness:** an `automation`, `backgroundRefresh`, or `open` run skips mail synced within the last 5 minutes
  (`GmailAutoSyncPolicy`, unchanged) and feeds polled within the last 30. `manual` skips neither. Mail and feeds
  are judged separately.
- **Gmail authorization** sits behind an injected access-token client. Move the restore-and-refresh code out of
  `GmailInboxIngestModel` and share the one in `GmailDispositionWiring` (it already handles a signed-in user). An
  unattended run **never** presents sign-in. A missing or rejected token is a recorded result, and feeds still run.

**Order, inside the budget:**

1. **Mail.** Sync changes, write each message, reconcile departures, advance the cursor. Feeds may overlap, but must
   not delay it.
2. **Feeds.** At most 4 at once, each with a 10-second **total** limit (a resource timeout; `timeoutInterval` alone
   measures idle time). Seeding still comes first. One feed's failure never stops the others.
3. **Offer summaries.** On-device only, as now, with whatever time is left. Never a frontier call.

**Unattended budget:** 20 seconds, then cancel what's left, record, and return, which leaves margin inside iPadOS's
roughly 30. Foreground runs have no budget.

### Fixes the order depends on

- Advance the Gmail cursor before extraction. `ingest` then no longer decides when extraction runs. The existing rule
  holds: any message failure keeps the cursor back.
- Because a cut-off summary no longer comes back through the cursor, step 3 works from stored state: offers on Today
  with no summary, newest first, at most 10 a run, one attempt each per run. Extend `processUnextractedPieces` rather
  than adding a second query. Persist each result as it finishes.
- Cancellation isn't a feed failure: `CancellationError` and `URLError.cancelled` leave `StreamPollState` untouched.
  The 10-second timeout **is** a failure.

### Trash policies wait for Jon

An unattended run makes no Gmail write of any kind. `applyEnabledPolicies` runs only for `open` and `manual`, and
it runs **even when the mail sync was skipped as fresh**, so mail fetched at 6:50 gets its policies when Jon opens the
app at 7. It's already idempotent. A policy failure still never fails a read.

### Opening the app

- Launch and `scenePhase == .active` both make one `open` request, replacing the separate mail and feed tasks. Showing
  what's stored never waits on it. When it finishes, reload the queue, Today, and listed feeds, as the mail path does now.
- `.active` fires at launch too. Single flight and freshness absorb it; a test proves one launch makes one run.
- `.NSCalendarDayChanged` keeps its reload and starts no run.

### The intent

`PrepareCockpitIntent` in the app target, "Prepare Cockpit", with an `AppShortcutsProvider` so it appears in Shortcuts
with no setup.

- `supportedModes` is `.background`. `authenticationPolicy` is `.alwaysAllowed`, so a locked iPad doesn't stop it. It
  returns no mail-derived text, since the result can show on a locked screen: its dialog is at most "Cockpit is ready"
  or "Cockpit couldn't finish".
- `allowedExecutionTargets` is `.main`. The database and the single-flight operation live there.
- It's a plain intent, **not** `LongRunningIntent`. Apple documents that protocol's extra time, but not whether an
  automation on a locked iPad gets it, and it adds a Live Activity. Adopt it only if the trial shows runs hitting the budget.
- Consult the `app-intents-specialist` and `app-intents-whats-new-27` skills if available.

**Launch without a window.** An intent can start the app with no scene. Check that everything the run needs is set up in
`CockpitApp.init`, not in a view. `bootstrapDatabase` is under `try!`; a launch before the first unlock after a restart
could crash there. Don't redesign launch for it. Name it in the PR as unverified.

### The record

A device-local store over `UserDefaults`, shaped like `EmailZoomPreferenceStore`. Not a table, and not synced. Keep
14 days, and no mail content, senders, subjects, or feed names.

- **Each run:** trigger, start, end, and a result for each step. Mail: synced with a count, skipped as fresh, not
  authorized, failed, or out of time. Feeds: succeeded of attempted, skipped, or out of time. Summaries: done of
  waiting. Model these as enums with associated values.
- **Write it at start as well as at the end,** so a run iPadOS killed reads as "didn't finish", not as nothing.
- **Each day:** when Jon first opened the app after 4 AM local, recorded even if the run was skipped as fresh.
- **Ready** is derived, never stored: an unattended run that finished after 4 AM and before that first open, with mail
  synced or fresh and every feed attempted. A feed that failed its own request still counts as attempted.

Settings gains a "Morning prep" screen: the last 14 days with ready / not ready, the time, and the trigger, with each
run's step results under it, and one plain line on setting up the automation. The model is `@Observable` in `CockpitCore`.

### Tests (injected clock, clients, store; no network)

- Two callers make one run; an `open` joining an unattended run gets its policies and its cut-off steps afterwards; a
  cancelled waiter doesn't cancel the run.
- Freshness for mail and feeds separately; `manual` bypasses both; a return after 30 minutes polls feeds (today's defect).
- An unattended run makes zero disposition and read-state calls; the next `open` applies policies with mail fresh.
- Cursor advanced when extraction is cut off; the skipped offer is summarized next run; a finished summary survives a
  cutoff; a message failure still holds the cursor.
- The budget ends mail, feeds, and summaries at each point and records it; a stalled feed doesn't delay the others; never more
  than 4 feeds at once; cancellation leaves `StreamPollState` alone; a timeout marks it failed.
- Missing authorization: feeds still run, and no sign-in is presented.
- Record: killed run, 14-day pruning, first open, and the ready rule across 4 AM, a time-zone change, and a
  daylight-saving change.

### Done when

Tests, lint, and the unsigned build pass per [verification.md](../../verification.md). Closeout per ADR-0005 D16, with
`--keep-brief`, and a gate line for the S-p1 device check below.

### Jon's device check for S-p1

Create a Time of Day automation that runs "Prepare Cockpit" and doesn't ask first. Test it with the iPad locked and idle
for over an hour, with Cockpit suspended, and again after Cockpit has been killed by the system. Settings › Morning prep
shows what happened. If it never fires while locked, tell the architect; S-p2 goes ahead either way.

## S-p2 — The backup trigger and the line on Today

### Background refresh

- `.backgroundTask(.appRefresh("com.jonphillips.cockpit.morning-prep"))` on the scene, calling `MorningPrep` with
  `backgroundRefresh` and the same 20-second budget. In `project.yml`, add `fetch` to `UIBackgroundModes` and the identifier to
  `BGTaskSchedulerPermittedIdentifiers`, then `xcodegen generate` (jon-platform `docs/ios/drift-control.md`).
- Request the next one for the next 5:30 AM local, whenever the app goes to the background and at the **start** of each
  background run. Put the scheduler behind an injected client and the date rule in `CockpitCore`. A request that iPadOS
  refuses (Background App Refresh off, say) shows on the Settings screen.
- When an unattended run already succeeded after 4 AM, a later background run records "already ready" and stops.
- No `BGProcessingTask`.

### The line on Today

One quiet line by the masthead date, from the record. Text only, no color, and no tap target beyond a link to the Settings screen.

- Ready: "Ready at 6:52".
- Running: "Catching up…".
- Caught up on open: "Updated at 7:04".
- A problem: what's missing, plainly, such as "Mail not updated: sign in to Gmail" or "2 of 9 feeds didn't load".

Don't show it at compact width if it crowds the date. The accessibility text says the same thing. Follow DECISIONS §31's
Morning Edition design.

### Tests

Next 5:30 AM before and after 5:30, across midnight and daylight-saving changes; rescheduled at the start of a run even if
the run fails; already-ready stops; a refused request surfaces; the line's text for each state.

### Done when

As S-p1, with ordinary closeout, and a gate line for the trial below.

## Gate — the 10-morning trial (Jon's)

Set the automation for 6:50 and use Cockpit normally for 10 mornings. **It passes when 8 or more read "ready"** in
Settings › Morning prep. The screen shows why the others weren't.

- **Runs hit the budget:** try `LongRunningIntent`.
- **The automation doesn't fire, and background refresh doesn't cover it:** the next option is a silent push from Jon's Mac at
  6:50. That widens ADR-0003 D2, so it needs its own decision. iPadOS can delay or drop silent pushes too.
- **Nothing reaches 8 of 10:** keep the catch-up on open, which stands alone.

## Out of scope

Composing the tail (it stays manual: up to about three minutes in evals, and it's a paid call). Any Gmail write from an
unattended run. Any notification. A Mac peer, or any work on the Mac mini. Silent push. A frontier model call. Conditional feed
requests (`ETag`). A schedule picker in Cockpit, because Shortcuts owns the time. Anything about the schema or CloudKit.
