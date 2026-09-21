# M6 S1 — Trash a declared briefing series after reading

> **Slice spec for the executor.** Self-contained: it is the first M6 candidate but does not depend on
> an M6 plan. Architect-defined 2026-09-21 (Jon's briefings ask). It extends the ratified explicit
> disposition-policy model (ADR-0002 D7; the `GmailDispositionPolicy` primitive from M5 S8) with one
> new, tightly-guarded shape. Read this whole spec before starting; the guards are the point.

## The job, in one sentence

Let Jon **declare a newsletter series** (NYT "The Morning", WaPo, Techmeme, …) as *trash-after-reading*,
so that once declared, **reading** one of those pieces in the Today reader **trashes it silently** — no
per-message Archive-vs-Trash microdecision — while staying fully reversible and leaving a trace he can
consult but does not have to.

## Why this is safe, and inside the authority model

This is **explicit, per-series establishment**, not learned deletion. It obeys ADR-0002 §8
("knowledge does not grant agency") the same way the M5 S8 policies do:

- **You are the threshold.** A series becomes trash-after-reading only by an explicit declaration
  gesture. The app never infers it from observed behaviour. There is *no* "trained enough" moment — one
  deliberate act, and the series is declared; until then it behaves normally.
- **The trigger is a human read, not a sync.** Unlike `offerWithFind` / `loginCode` (which auto-apply
  on sync because the value is already captured elsewhere), a briefing's value *is* the thing you read,
  so it is disposed only when you have actually read it in the reader. An **unread** declared piece is
  never touched. "I don't want these deleted automatically" stays literally true.
- **Trash, never Delete; reversible; custody untouched.** It rides the existing
  `GmailDispositionService` barrier and Undo log (ADR-0002 D4/D5/D6). Gmail's ~30-day Trash window plus
  the local Undo log are the net. Trashing the *source* never removes any Find / Later / Library item it
  produced (ADR-0002 D8).
- **Guarded to newsletters.** A series can be declared, and auto-trash can fire, **only** for
  `EmailTreatment.newsletter` mail. Person-to-person Primary mail can never enter this path.

## Data model

New table, one row per declared series. Presence = declared; deleting the row un-declares. There is no
`enabled` flag and no action column — the only action in v1 is trash-after-reading, and the unit of
control is the series.

```
@Table("gmailSeriesDispositions")
struct GmailSeriesDisposition {
  @Column(primaryKey: true) let seriesKey: String   // normalized, see below
  let establishedAt: Date
}
```

Add a migration alongside the existing `GmailDispositionMigration.swift` pattern and register the table
where the others are registered.

### The series key — normalized List-ID, sender fallback

Key on the **normalized `List-ID`** locator, falling back to the **normalized sender mailbox** when
List-ID is absent. Do **not** key on `Stream.ID`: Streams are *manually configured*
(`GmailStreamResolver`), and Jon must be able to declare any newsletter series whether or not he ever
set up a Stream for it. Do **not** use subject regex.

Reuse the existing normalization so resolver and policy cannot drift:
- `GmailStreamResolver.locatorKeys(_:)` (List-ID angle-bracket normalization) and
  `GmailHeaderParser.senderKey(from:)` (sender mailbox) already exist.
- Extract the List-ID normalization into a small shared helper (e.g. `GmailSeriesKey`) that both
  `GmailStreamResolver` and this slice call. New surface:

```
enum GmailSeriesKey {
  /// The series key for a Gmail-backed ContentPiece: normalized List-ID, else normalized sender.
  /// Returns nil for non-Gmail or non-newsletter pieces, or when neither header is present.
  static func seriesKey(forContentPieceID: ContentPiece.ID, in db: Database) throws -> String?
}
```

Two different List-IDs from the same From: address (e.g. NYT "The Morning" vs NYT account notices) must
produce **different** keys — that is the whole reason for keying on List-ID.

## Operations (core, DB-only, no provider calls)

```
enum GmailSeriesDispositionOperations {
  static func declare(seriesKey: String, at: Date, in db: Database) throws        // upsert
  static func undeclare(seriesKey: String, in db: Database) throws                // delete row
  static func isDeclared(seriesKey: String, in db: Database) throws -> Bool
  static func declaredKeys(in db: Database) throws -> [String]
}
```

The newsletter guard lives at the model layer (declaration is only offered for newsletter pieces) **and**
is re-checked at application time via `GmailSeriesKey.seriesKey` (which returns nil for non-newsletter).

## Application — read-triggered, in the reader

Drive this from the Today reader, **not** from the sync-time `GmailDispositionPolicyService`.

- **Trigger point:** when a piece that was presented in the reader is **left** — the reader is
  dismissed, or `disposeAndAdvance` / `model.begin(contentPieceID:)` advances off it. Reuse the existing
  leave/advance plumbing in `TodayOriginalReaderPane.swift`.
- **On leave of piece P:** resolve P's series key; if it is declared **and** P is newsletter **and** P is
  not already trashed (`GmailDispositionOperations.hasTrashLogEntry`), apply
  `dispositionService.apply(.trash, toContentPieceID: P, ...)` (the same service `TodayModel` already
  holds), then reload the projection. The barrier verifies P's ContentPiece is committed before mutating
  — always true for a piece that was on Today and read.
- **Unread pieces are untouched.** A declared-series row that is never opened stays on Today.
- **Once per message.** The `hasTrashLogEntry` guard makes re-entry / re-read idempotent.

Add to `TodayModel` (or the reader model that owns disposition):

```
func applySeriesTrashOnLeave(_ pieceID: ContentPiece.ID) async   // the trigger above
func seriesTrashState(for row: TodayRequest.Row) async -> Bool   // is this row's series declared?
func declareSeriesTrash(for row: TodayRequest.Row) async         // newsletter-guarded
func undeclareSeriesTrash(for row: TodayRequest.Row) async
```

### Interaction with D9 reconciliation (already correct — add a test)

An auto-trash is a **Cockpit-initiated** disposition, so the D9 external-only reconciliation
(`TodayAttentionOperations.clearDeparted`) will **skip** it (it has an un-reversed disposition-log
entry) and never strand it behind the terminal attention marker. Undo therefore returns the row to
Today even after a sync observed the trash. Assert this in a test.

## UI

**Reader (`TodayOriginalReaderPane.swift`) — declared-series piece = fate hidden.**
- Do **not** render the primary Archive button or the Trash/Undo primary decision for a piece whose
  series is declared. The default path has **zero** disposition decisions.
- The `⋯` menu for a declared-series piece carries only: the sender-treatment submenu (unchanged),
  **"Stop auto-trashing [series]"** (un-declare, affects the whole series going forward), and **"Undo
  disposition"**. No per-message keep-this-one in v1 — the escape for "oops, wanted that one" is Undo
  from the trace (below) or un-declaring the series.
- For an **un**declared newsletter piece, the `⋯` menu gains **"Always trash [series] after reading"**
  (the declaration gesture). `[series]` label = the piece's publisher. Non-newsletter pieces never show
  either item.

**Trace — "Recently trashed" (the consultable-but-ignorable net).**
- A small toolbar affordance on Today opens a sheet listing recent trashes (sender · subject · when),
  each with **Undo**, backed by `GmailDispositionOperations.recent(in:)` filtered to `.trash`. Reuse the
  existing `undoDisposition` path for Undo. This is what lets the fate be hidden *and* trustworthy: he
  never has to look, but can.
- Keep it lean: one new `FetchKeyRequest` (recent trash entries joined to sender/subject) + one sheet
  view. No pagination beyond `recent(limit:)`.

**Settings — optional, defer if it grows the slice.** A read-only list of declared series with
un-declare would be nice, but per-series management already exists in the reader menu; do not build a
Settings surface in this slice unless it falls out for free.

## Scope

**In:** the table + migration; `GmailSeriesKey` (shared normalization) + operations; the newsletter
guard; the read-triggered application in the reader; hiding the disposition decision for declared
pieces; the declare / un-declare menu gestures; the "Recently trashed" trace sheet with Undo; the ADR
amendment; tests.

**Out (name them, don't build them):**
- **Propose-and-confirm nudge** ("you keep trashing this — automate it?"). Pure sugar; a later slice. The
  primary path is explicit declaration.
- **Per-message "keep this one before it trashes"** — Undo/un-declare cover it in v1.
- **Subject-template fallback** when List-ID is absent (v1 is List-ID → sender only).
- **Retroactive trashing** of already-read pieces at declaration time (only pieces read *after*
  declaration are affected; declaring from the open reader and then leaving that piece does trash it,
  because you are leaving it read).
- **Global master on/off switch** and a Settings management surface.
- Any non-reader "seen" trigger, and the (a) one-tap-default variant (we chose (b) hidden-fate).

## ADR

Amend **ADR-0002 D7** with a subsection (or add **D10**): *"Read-triggered, series-scoped disposition
preferences."* State: the trigger is a human read in the reader (never sync, never arrival); the scope
is a user-declared set of series keyed on normalized List-ID (sender fallback), guarded to newsletter
mail; declaration is explicit only (no inference, no learned authority — propose-and-confirm, if later
added, remains a proposal); the action is Trash behind the existing barrier/Undo, custody untouched
(D8). Follow the lightweight amendment style used for D9 (update the Status header date).

## Definition of done

- `swift test` (CockpitCore) green, including new tests:
  1. Declaring a newsletter series records it; declaring a non-newsletter piece is refused/guarded.
  2. Series key: List-ID drives it; two List-IDs from one sender → two keys; sender fallback when no
     List-ID.
  3. Read (present → leave) of a **declared** piece trashes it (barrier + log) and removes it from
     Today; an **undeclared** series piece, left the same way, is untouched.
  4. An **unread** declared-series piece on Today is not trashed.
  5. Undo returns the row to Today and untrashes it — **including** after an interleaved delta sync
     (the D9 tie-in).
  6. Once-per-message: re-reading a declared piece does not double-trash.
  7. Custody: a Find / Later item produced by the briefing survives the source trash (D8).
  8. Un-declaring stops future auto-trash.
- `swiftlint lint --strict` clean.
- Unsigned `xcodebuild` of the app: BUILD SUCCEEDED.
- Not device-verified by the executor: flag for Jon's eyeball the two feel-critical paths — the reader
  with the disposition decision **hidden** for a declared series, and the "Recently trashed" trace with
  Undo.
