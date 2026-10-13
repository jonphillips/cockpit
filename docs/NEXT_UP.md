# Next Up — Background disposition: rows leave at once, Gmail confirms behind them

**Slices:** M6 · S-d1 + S-d2
**Briefs:** docs/milestones/M6-background-disposition.md §Standing rules, §S-d1, §S-d2 (decision: ADR-0002 D6 amendment, 2026-10-12)
**Done when:** per the briefs. Offers Trash all and single-row Trash/Archive remove rows immediately, Gmail calls run in the background (window of 4), Undo is live from the first moment until the batch settles, and a failure raises an alert and brings the failed rows back.
**Notes:** Branch `effort/background-disposition`. No schema, migration, or sync change; the D4 barrier order is unchanged. Floats ahead of S-c4.

**Owed:**
- M6 S-join device gate: complete the Cockpit ↔ Yes Chef real-email round trip, decline and dismiss paths, interrupted-receiver case, custody check, and split-view race review; ratify the boundary. See `docs/milestones/M6-gate5-find-handoff-slice-plan.md` §6.
- M6 S-l2/S-l3 device pass: verify universal-link routing, six-tab and split-width layout, tab selection and scroll retention, midnight rollover, and Today door height; include compact-width Feeds selection collapse behavior. Re-check the Stream editor crash fix: add a feed with a text field still focused and tap Follow, then rename a feed and tap Save, with no crash either time.
- S-c4 follows these gates.

Device work belongs to Jon. Agents do not drive UI, simulator, or device.
