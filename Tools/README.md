# Development tools

Both tools below are one-time, read-only development executables. Neither is linked by `CockpitApp`
or `CockpitCore`; their output is test data only. Gmail access is always read-only (`GET` requests
and the `gmail.readonly` scope); no message is ever archived, trashed, or modified.

The harvest runs as a preflight (`discover`) followed by the body-bearing pull (`export`), so the
sender allowlist is confirmed before any message body is written to disk.

## 0. Mint a Gmail access token — `GmailFixtureToken`

A Mac-only helper that produces a short-lived access token for the two Gmail steps below. It reads a
Google **Desktop-app** OAuth client (`client_secret_*.json`, the `installed` variant) that you keep
outside the repo, runs the authorization-code + PKCE flow over a loopback redirect, and prints only
the access token to stdout.

```sh
export GMAIL_ACCESS_TOKEN=$(swift run --package-path CockpitCore \
  GmailFixtureToken --client /secure/path/desktop-client.json)
```

- **First run** opens the browser, requests offline access, and stores the resulting refresh token
  in the macOS **login keychain** (you may see a one-time keychain-access prompt).
- **Later runs** refresh silently from the keychain and print a fresh access token.
- The refresh token is never written to the repo or any fixture file; only the keychain holds it.

Access tokens last about an hour. If `discover`/`export` fails with HTTP 401, re-run the command
above to mint a fresh one.

## 1. Preflight — `JudgmentFixtureHarvest discover`

Discovers which Gmail `From` addresses correspond to each seeded publication, using **metadata only**
— it fetches `From` headers, never bodies, and writes no message content. It reads the editorial
seeds in [`Tools/stream-seeds.json`](stream-seeds.json) (a machine-readable projection of
`docs/stream-handling-seeds.md` — the sources Jon already identified, with their handling intent),
prints a `From → count` table per publication for confirmation, and writes a candidate harvest
config carrying each seed's Stream/Interest context.

```sh
swift run --package-path CockpitCore JudgmentFixtureHarvest discover \
  --seeds Tools/stream-seeds.json \
  --out /secure/path/judgment-fixture-harvest.json \
  --after 2026-08-28 --before 2026-09-12
```

The five feed-backed Streams in the seeds are taken from recorded RSS fixtures and skipped by Gmail
discovery, so a Substack that arrives by both feed and email is not harvested twice. Each seed's
`interestArea` is left blank for Jon to confirm. Only the highest-count sender per publication is
written to the config; add any others shown in the table, and remove anything not editorial. **This
is the point at which the sender allowlist is confirmed.**

## 2. Harvest — `JudgmentFixtureHarvest export`

Pulls the full messages for the confirmed allowlist plus the recorded RSS backfill, and freezes the
fixtures and labels. Existing confirmed labels are preserved by ID, so a re-export never orphans
them; newly harvested rows have no label or substantive-primary value.

```sh
swift run --package-path CockpitCore JudgmentFixtureHarvest export \
  --config /secure/path/judgment-fixture-harvest.json \
  --fixtures CockpitCore/Tests/CockpitCoreTests/Fixtures/judgment/fixtures.json \
  --labels CockpitCore/Tests/CockpitCoreTests/Fixtures/judgment/labels.json \
  --after 2026-08-28 --before 2026-09-12
```

The time interval is explicit so re-running produces the same candidate window; fixture IDs use
Cockpit's normal derived identity. If Gmail plus feed backfill falls short of 200, that is a real
finding about corpus volume — report it rather than padding with synthetic material.

The label-side record retains the current Gmail disposition and read state, then derives a
`dispositionPrior` **only as a review hint** (trash → `never`, archived read → `surface`, archived
unread → `quiet`, inbox → `uncertain`). The prior is never stored in a fixture and cannot reach a
judgment prompt.

Jon must confirm every `label` (`surface` / `quiet` / `never`) and `isSubstantivePrimary` in
`labels.json` before M2 begins. The offline `JudgmentEval` test does not substitute a model call; it
proves the frozen inputs and confirmed labels can be evaluated by a stub and reports the six contract
metrics.

## Checked-in smoke config

[`judgment-fixture-harvest.rss-only.json`](judgment-fixture-harvest.rss-only.json) exports real
RSS-derived fixtures with intentionally no Gmail candidates, so it runs without a token and is not
the S4 corpus. [`judgment-fixture-harvest.example.json`](judgment-fixture-harvest.example.json)
documents the `export` config shape by hand; in practice `discover` generates it for you.
