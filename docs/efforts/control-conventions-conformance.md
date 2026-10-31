# Effort — Control conventions conformance

Status: Ready
Summary: Rows lose the circled `…` for context menus, and the amber accent that the decisions specify actually reaches the screen.

Implements: jon-platform `docs/ios/ui-and-platforms.md` § Controls (adopted 2026-10-31) and
[DECISIONS.md](../DECISIONS.md) §31 (the accent is amber, defined once; the chrome is the system's apart
from the tint). No schema change, and no change to disposition semantics.

## 1. The accent doesn't reach the screen (defect, do first)

On Jon's iPad on 2026-10-31, Today renders in **system blue**: the selected tab, the trailing
toolbar button, the unread dots, and "Feeds 5". The asset catalog's `AccentColor` is amber
(`project.yml` sets `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME`), and `Theme.accent` is
`Color.accentColor`. So something between the two is dropping it. Find out what: a stale build,
the asset not compiling into the app target, a `.tint` override higher in the tree, or system
chrome under the SDK 27 tab bar ignoring the global accent. Fix it at the cause. If the system
tab bar really does ignore the asset accent, apply `.tint(Theme.accent)` once at the root and
note why in DECISIONS §31.

## 2. Row actions

Replace the circled `…` triggers on list rows with a `.contextMenu` holding the same items. Keep
the existing swipe actions, and add swipes only where a row has none and one action dominates:

- `TodaySurfaceRows.swift` ~94 (the email rows: the about 30 glyphs on Today).
- `TodaySupportingRows.swift` ~129.
- `PendingFindListView.swift` ~67.

`ReaderDispositionToolbar.swift` ~181 is a **toolbar** `…`, which the convention allows, so leave it.

## 3. Category bar and links

- The section bar's counts already follow the house form (`Opinion 31`). Keep them.
- Check the selected section against the house selected-chip rule (accent fill at about 20%, accent
  text, semibold). If the bar is plain text by design (Edition look, DECISIONS), keep it, and
  write that in the PR.

## Done when

- Today on device shows amber chrome and amber unread dots, with the cause named in the PR.
- No `ellipsis.circle` on a list row (`grep -rn ellipsis.circle CockpitApp` shows only the reader
  toolbar). Each removed trigger's items are reachable by context menu.
- Tests and drift checks green. Before/after iPad screenshots of Today in the PR.
