# Handoff 3 report

Cockpit now follows real Streams. The app root seeds the five publications selected in
`docs/stream-handling-seeds.md` and runs one foreground acquisition entry point on launch; the
same path powers Following's pull-to-refresh. The client is injected, so tests never contact the
network. The five captured public feed responses live in
`CockpitCore/Tests/CockpitCoreTests/Fixtures/streams/`: Slow Boring, Astral Codex Ten, Techmeme,
Point-Free, and Benedict Evans. They are raw recorded bytes, not rewritten sample XML. A fixture
test requires every file to be present and parseable. The turnover test polls Slow Boring, polls
it again unchanged, then polls a derivative with its first real item removed; the old
ContentPiece, Artifact, and source body remain.

Following offers the only Add Stream operation. It discovers a pasted website/feed URL using the
existing deterministic `FeedDiscovery`, proposes only the returned feed metadata and resolved
URL, and gives the user an editable confirmation form. The neutral `General` Interest Area is the
deterministic proposal for a newly discovered Stream, because no feed metadata can honestly state
why Jon follows it. It is an editable starting value, not a classification. Saving finds an
existing case-insensitive Interest Area deterministically or creates the named one. The seeded
five share `Technology & Making`: that is their deliberately simple management home, not a new
taxonomy. All twenty-one seed drafts remain in the evidence document; M1 stores the five selected
texts only and never parses or acts on them.

`Stream.handlingGuidance` is now an additive, non-null text column with an empty default for
existing rows. The migration also adds `consecutiveFailureCount` and `lastFailureDescription`.
A successful poll records its receive time, makes health healthy, and clears the failure evidence.
A fetch, discovery, parse, or database failure marks only that Stream failed, retains the original
error's diagnostic description, and increments the count; another bad feed does not stop the
rest of the foreground run. Healthy rows show no health treatment. There is intentionally no
`stale` state or cadence inference: a quiet feed is not evidence of a failure. Pause and Stop
Following both exclude a Stream from the poll query while preserving the Stream and every stored
Artifact/ContentPiece.

The only non-trivial literal values are the five stable seed UUIDs and their Interest Area UUID.
They are fixed source identities for idempotent first-install seeding, rather than random IDs
minted during a repeat launch. No timeout, age, cadence, stale threshold, background task, Gmail
integration, auto-Library policy, judgment, Edition, Personal Knowledge, or source-deletion path
was added. M1 does not interpret Handling prose.

Verification: `swift test --package-path CockpitCore` passes 27 tests, including discovery/add,
recorded fixture parsing, real-feed identity/idempotence, turnover retention, launch/refresh
polling, paused/stopped exclusion, and failure evidence. `swiftlint lint --strict --no-cache` and
`git diff --check` pass. `xcodegen generate` passes. The unsigned generic-iOS build passes with
`xcodebuild -scheme Cockpit -destination 'generic/platform=iOS' -skipMacroValidation
CODE_SIGNING_ALLOWED=NO build`. The only build warning is pre-existing App Intents metadata
extraction with no AppIntents dependency. No UI, simulator, device, live CloudKit, or live
post-capture feed behavior is claimed; the app's one-time production feed fetch remains the
appropriate device-only risk.
