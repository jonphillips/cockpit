# Done log

History, newest first. The PR that completes a dispatch adds an entry naming its branch
(jon-platform ADR-0005 D5). No dispatch reads this file.

History before 2026-09-29 lives in the milestone ledgers (`docs/milestones/`), the
`docs/handoff-*-report.md` files, and merged PRs.

## 2026-10-03 — M6 S-l1 Listed posture and read model (`m6/s-l1-listed-posture`)

Added the Listed Stream posture, Edition exclusion, synced per-piece open/dismiss state, and the seven-day core feed model with dismiss/undo. Core tests, strict SwiftLint, unsigned iOS build, and handoff shape check pass. The older-build CloudKit decode behavior for a Listed Stream remains an unverified device-only risk for Jon's round trip.

## 2026-09-29 — Adopt the ADR-0005 document shape (`chore/token-discipline`)

Added `NEXT_UP.md`, `verification.md`, `open-questions.md`, and this log; ticked S-v3 (#106) and
S-v4 (#109), which had merged without their ledger boxes being ticked.
