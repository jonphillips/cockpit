# Done log

History, newest first. The PR that completes a dispatch adds an entry naming its branch
(jon-platform ADR-0005 D5). No dispatch reads this file.

History before 2026-09-29 lives in the milestone ledgers (`docs/milestones/`), the
`docs/handoff-*-report.md` files, and merged PRs.

## 2026-10-03 — M6 S-l2/S-l3 Feeds tab and Today door (`m6/s-l2-feeds-tab-and-door`)

Added the Feeds split view and Listed choice in Following, plus Today's shared Feeds door with new
counts and newest headline. Core tests, strict SwiftLint, unsigned iOS build, and handoff shape check
pass. Device-only checks remain with Jon: universal-link routing, six-tab width, tab selection and
scroll retention, midnight rollover while open, and the Today door's smallest-landscape layout.

## 2026-10-03 — M6 S-l1 Listed posture and read model (`m6/s-l1-listed-posture`)

Added the Listed Stream posture, Edition exclusion, synced per-piece open/dismiss state, and the seven-day core feed model with dismiss/undo. Core tests, strict SwiftLint, unsigned iOS build, and handoff shape check pass. The older-build CloudKit decode behavior for a Listed Stream remains an unverified device-only risk for Jon's round trip.

## 2026-09-29 — Adopt the ADR-0005 document shape (`chore/token-discipline`)

Added `NEXT_UP.md`, `verification.md`, `open-questions.md`, and this log; ticked S-v3 (#106) and
S-v4 (#109), which had merged without their ledger boxes being ticked.
