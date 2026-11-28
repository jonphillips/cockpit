# Device passes & held gates

Jon's checklist: real-device gates. **Not executor work; the executor never reads this file.**
`NEXT_UP.md`'s **Owed** line points here. Moved from `NEXT_UP.md`'s Owed list on 2026-10-30
(jon-platform ADR-0005 D10). When a gate clears, delete it and note it in `DONE-LOG.md`.

Device work belongs to Jon. Agents do not drive UI, simulator, or device.

## Gates

- **M6 S-join device gate.** Complete the Cockpit ↔ Yes Chef real-email round trip, decline and
  dismiss paths, interrupted-receiver case, custody check, and split-view race review; ratify the
  boundary. See [`M6-gate5-find-handoff-slice-plan.md`](milestones/M6-gate5-find-handoff-slice-plan.md)
  §6. S-c4 follows this gate.
- **M6 S-l2/S-l3 device pass.** Verify universal-link routing, six-tab and split-width layout, tab
  selection and scroll retention, midnight rollover, and Today door height; include compact-width
  Feeds selection collapse behavior. Re-check the Stream editor crash fix: add a feed with a text
  field still focused and tap Follow, then rename a feed and tap Save, with no crash either time.
  Brief: [`archive/M6-listed-feeds.md`](milestones/archive/M6-listed-feeds.md).
- **Background disposition (PR #122).** Trash all on 10+ real offers clears immediately and the
  progress/Undo bar settles correctly; Undo mid-batch restores applied messages and leaves unstarted
  messages untouched, and leaving review carries Undo to Today; forced Gmail failure shows the alert
  over Today and Offer Review and returns failed rows; token reuse works across token expiry. Brief:
  [`archive/M6-background-disposition.md`](milestones/archive/M6-background-disposition.md).
- **Control conventions (cockpit PR 128).** Today's chrome and unread dots are amber on the iPad, and each row action the `…`
  used to hold is in the row's context menu on Today, the tail, and Finds. Brief:
  [`archive/control-conventions-conformance.md`](efforts/archive/control-conventions-conformance.md).
- **morning-prep, S-p1:** Jon tests the Prepare Cockpit Time of Day automation with the iPad locked and idle, Cockpit suspended, and Cockpit system-killed; Settings › Morning prep shows the outcomes. ([brief](efforts/archive/morning-prep.md))
- **morning-prep, S-p2:** Run the 10-morning trial: set the 6:50 Shortcuts automation, use Cockpit normally, and check whether at least 8 of 10 mornings show Ready in Settings › Morning prep. ([brief](efforts/archive/morning-prep.md))
