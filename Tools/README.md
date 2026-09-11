# Development tools

## Judgment fixture harvest

`JudgmentFixtureHarvest` is a one-time, read-only development executable. It is not linked by
`CockpitApp` or `CockpitCore`; its output is test data only. It requests Gmail messages using an
access token supplied in `GMAIL_ACCESS_TOKEN`, makes only `GET` requests, and only writes the two
paths passed on its command line.

Copy `judgment-fixture-harvest.example.json` outside the repository, replacing the Gmail sender
allowlist and Stream contexts with Jon's editorial sources. The allowlist is mandatory: the tool
does not write correspondence, transactional, or account mail to disk. It also imports the named
recorded RSS fixtures as the deterministic top-up.

```sh
GMAIL_ACCESS_TOKEN='...' swift run --package-path CockpitCore JudgmentFixtureHarvest \
  --config /secure/path/judgment-fixture-harvest.json \
  --fixtures CockpitCore/Tests/CockpitCoreTests/Fixtures/judgment/fixtures.json \
  --labels CockpitCore/Tests/CockpitCoreTests/Fixtures/judgment/labels.json \
  --after 2026-08-28 --before 2026-09-12
```

The time interval is explicit so re-running produces the same candidate window. Fixture IDs use
Cockpit's normal derived identity. Existing confirmed labels are preserved by ID; newly harvested
rows have no label or substantive-primary value. The label-side record retains the current Gmail
disposition and read state, then derives a `dispositionPrior` only as a review hint: trash →
`never`, archived read → `surface`, archived unread → `quiet`, inbox → `uncertain`. It is not
stored in a fixture and cannot reach a judgment prompt.

Jon must confirm every `label` (`surface` / `quiet` / `never`) and
`isSubstantivePrimary` in `labels.json` before M2 begins. The offline `JudgmentEval` test does not
substitute a model call; it proves that the frozen inputs and confirmed labels can be evaluated by
a stub and reports the six contract metrics.

`judgment-fixture-harvest.rss-only.json` is the checked-in smoke-test configuration. It produces
real RSS-derived fixtures but intentionally no Gmail candidates, so it is not the S4 corpus.
