# Verification

The standing pattern for every dispatch. Run each command through
`~/code/jon-platform/scripts/quiet-run`, so only errors and verdicts reach context
(jon-platform `docs/agent-workflow.md` § Token discipline).

```bash
qr=~/code/jon-platform/scripts/quiet-run
$qr swift test --package-path CockpitCore
$qr swiftlint lint --strict --no-cache
$qr xcodebuild -scheme Cockpit -destination 'generic/platform=iOS' -skipMacroValidation CODE_SIGNING_ALLOWED=NO build
~/code/jon-platform/scripts/check-handoff     # warn-only document-shape hygiene (ADR-0005)
```

Run `xcodegen generate` first when `project.yml` or the file list changed. Start with the
narrowest test (`swift test --filter …`) and run the full set once before marking a PR ready.

**No UI, simulator, or device testing** (AGENTS.md): name device-only risks in the PR as
unverified and stop. A milestone's standing rules can add slice-specific checks.
