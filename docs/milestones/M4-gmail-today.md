# M4 — The Gmail transport opens, and the daily loop deepens

> **DRAFT for architect review.** Drafted 2026-09-16, immediately after Architecture Gate 2 closed
> (`docs/eval-log.md`, 2026-09-16). This is the proposed sliced build order for M4. The contract
> numbers and definitions cited are not reinterpreted here.

## What M4 is

M3 delivered a real iPad shell and turned the harness's Personal-Knowledge signal into a product
signal: a real 30-claim set moved 278/357 pieces and 58 admissions in the right direction while the
Essential floor held (Gate 2, `docs/eval-log.md`). The morning loop is now genuinely pleasant to live
in — and that lived use exposed the next two jobs.

M4 has two jobs, in the same **dogfooding-first / open-a-new-transport** shape M3 used:

1. **Deepen the existing loop where daily use hurts.** Three things M3 left owed now bite every
   morning: the Reader stops at the summary and sends Jon to Safari to actually read (DECISIONS §20);
   there is no way to keep a piece for a flight or a tunnel (Offline controls, V1-SCOPE §1); and the
   single judgment pass lets Personal Knowledge bleed into the `isSubstantivePrimary` *type* call —
   the Gate-2 finding (0.545 → 0.415 under teaching) whose remedy the architect ratified into M4.
2. **Open the second transport — Gmail read-only Today (V1 Phase 3 → Architecture Gate 3).** Ratified
   out of M3 on 2026-09-15; Phase 2 and Phase 3 have no dependency on each other, so M4 opens Gmail
   as its own milestone with its own gate. The milestone's real architectural deliverable is the
   **Gmail integration ADR written from observed semantics** — not the surface.

```text
read what Cockpit already holds, inline (Reader body)
→ keep it deliberately (Offline until / Keep Offline)
→ stop PK bleeding into the type call (split type from editorial)
→ open Gmail read-only → Today (Worth Seeing / Personal-Consequential / quiet)
→ Reader → Clear (attention only; no mutation)
→ write the Gmail integration ADR from what the provider actually did
```

M4 ends at **Architecture Gate 3** (`docs/V1-SCOPE-AND-SEQUENCING.md` Phase 3). Only after that gate
does source *mutation* (Phase 4 dispositions) become enabled — read-only comes first by contract
(EMAIL-INTELLIGENCE-MODEL §13; DECISIONS §7).

## The gate before M4 begins

**M4 opens on a closed Gate 2** (`docs/eval-log.md`, 2026-09-16) — done. Two carry-ins are ratified
Gate-2 output rather than fresh decisions:

- **Split the type/classification call from the editorial call** (S1 below). Ratified at Gate 2 as
  the remedy for PK bleeding into `isSubstantivePrimary` (DECISIONS §18 Gate-2 finding). It also
  advances the M2-S1 cost lever — the type/subjects/summary pass is exactly the "mechanical grunt-work"
  a cheaper/onboard model can eventually own once it can emit the schema.
- **Auto-Library stays at Phase 7**, reconciled at Gate 2 (DECISIONS §18) — **not** M4.

The Gmail spine has one standing precondition already met: the D7 auth spike is done and a
production-issued refresh token is in the Keychain (`docs/eval-log.md`, 2026-09-11). D7's remaining
production-longevity question is answered *for free* by the first Gmail read made more than an hour
after authorization (access tokens last ~1h) — S4 confirms it in passing. If that read fails, the
ADR-0001 fallback stands: evaluate IMAP with an app password before Today is designed around the
Gmail API.

## Slice ledger

- [ ] **S1 — Split the type/classification call from the editorial call** *(Gate-2 carry-in; no Gmail dependency)*
- [ ] **S2 — Reader inline body** *(DECISIONS §20; no Gmail dependency)*
- [ ] **S3 — Offline controls: `Offline until [date]` and `Keep Offline`**
- [ ] **S4 — Gmail read-only ingest: Inbox → provider Artifact → email ContentPiece**
- [ ] **S5 — Today: Worth Seeing / Personal-Consequential / quiet handling, Reader, Clear**
- [ ] **Architecture Gate 3 — write the Gmail integration ADR from observed semantics**

S1–S3 deepen the existing loop and have no Gmail dependency, so they can start immediately and in any
order; they are sequenced first because they improve daily dogfooding and de-risk nothing by waiting.
S4 → S5 → Gate 3 is the Gmail spine and is ordered.

## Standing rules for every M4 slice

The M1–M3 standing rules carry over unchanged. The ones that bite hardest in M4:

**Read-only before mutation — by contract.** M4 reads Gmail and never mutates it. No Archive, no
Trash, no read/unread writes. `Clear` is a **Cockpit attention** action, not a provider action
(DECISIONS §7; TODAY-EXPERIENCE §6) — it must not touch Gmail state. Provider mutation is Phase 4,
behind the Gate-3 ADR (DECISIONS §7: "external mutation happens only after Cockpit successfully
commits any result it promises to retain").

**`Clear` is Today's action; `Dismiss` is Edition's.** Different words for different operations
(DECISIONS §7, §15; TODAY-EXPERIENCE §6). Do not unify them.

**The ADR is written from observed behaviour, not designed up front.** The whole point of a read-only
phase is to learn message-vs-thread identity, account boundary, pagination/delta, new-reply re-entry,
and failure/retry from the real provider before committing the contract (V1-SCOPE §Phase 3;
EMAIL-INTELLIGENCE-MODEL §10, §13). Do not pre-freeze the Gmail schema in S4/S5.

**Knowledge does not grant agency** (PK-MODEL §11). Nothing in Gmail analysis — not a classification,
not a "quiet handling" — may acquire disposition authority. Automatic Archive/Trash exists only under
an explicit user policy, and not until Phase 4 (DECISIONS §7).

**The eval floor still gates the judgment change.** S1 alters the judgment pass, so it is measured
through `JudgmentEval` against the frozen corpus under the **paired** essential-false-quiet discipline
ratified at Gate 2 (DECISIONS §22.2): a same-session control run (old single-pass vs new split-pass),
floor not regressed. Substantive-primary accuracy is the metric S1 is trying to move — record it.

**Verification: model state is tested; pixels are Jon's pass** (`AGENTS.md`). The Today layout, the
Reader body typography, and the offline-badge presentation are Jon's device pass. Agents ship the
tested models (the Gmail ingest/normalization, the Today projection, the Reader join, the offline
state machine) and hand the look to Jon.

---

## S1 — Split the type/classification call from the editorial call

**Branch:** `m4/s1-type-editorial-split` · **PR title:** `M4 · S1 — Type/editorial split`

The Gate-2 finding made concrete: the M3-S5 paired run showed `isSubstantivePrimary` accuracy falling
**0.545 → 0.415** when the same corpus was taught (`docs/eval-log.md`, 2026-09-15). PK moved a *type*
property it has no business touching (DECISIONS §18). The single judgment pass conflates the
classification question (*is this the Stream's primary authored work, or an accessory?*) with the
editorial question (*of what arrived, which ~20 deserve this morning, ranked, sectioned, deduped?*).

### Read first

`docs/JUDGMENT-CONTRACT.md` §2–4 (the projection in, the structured output, per-piece fail-closed);
DECISIONS §18 (type vs value, and the Gate-2 finding) and §22 (the paired floor); the M2-S2 judgment
engine and the M3-S5 re-request pass; `docs/eval-log.md` (the baseline this is measured against).

### Scope

- **`isSubstantivePrimary` (and the mechanical subjects/summary extraction) become a separate
  classification pass** that does **not** receive the Personal-Knowledge projection — it is a type
  call, PK-free by construction (JUDGMENT-CONTRACT §2). The editorial pass keeps PK and does admission
  / rank / section against `targetSize`.
- **Frontier stays on the editorial call** (the taste-laden finite-package judgment); the type pass is
  where a cheaper/onboard model can later live *when it can emit the schema* (M2-S1 cost decision).
  M4 does the split; the model swap is not required here and stays behind the schema blocker.
- **No new judgment machinery** beyond separating the two calls and their prompts/versions.

### Done-criteria

1. The type/classification pass receives no PK projection; a `JudgmentEval` run shows
   substantive-primary accuracy no longer moves bare-vs-taught (the bleed is closed), verified through
   the judgment output.
2. Recorded `JudgmentEval` run: substantive-primary accuracy improves against the M3-S5 baseline, and
   essential-false-quiet does not regress against a **same-session control** (single-pass vs split-pass),
   per DECISIONS §22.2, in `docs/eval-log.md`.
3. Cost/latency of the two-pass shape recorded (a second call has a cost; confirm it stays within the
   §7 budget or note the lever).

### Out of scope

The actual onboard/Haiku model swap (behind the schema blocker; a later cheapest-lever eval).
Auto-Library's use of the type flag (Phase 7). Any change to what the editorial call *does* with PK.

---

## S2 — Reader inline body

**Branch:** `m4/s2-reader-inline-body` · **PR title:** `M4 · S2 — Reader inline body`

Ratified intent, DECISIONS §20. Today the one investigate-this-item surface stops at the `summary` and
Open Original is the only way to actually read — so the Reader sends Jon out of the app every morning.
The substance is already modelled: `LocalNormalizedText` holds the text (device-local) and
`bodyCompleteness` already rides the Reader projection. The work is a `leftJoin` plus honest rendering,
**not** a browser.

### Read first

`docs/DECISIONS.md` §20; `docs/IPAD-FIRST-EXPERIENCE.md` §7–8; `docs/IMPLEMENTATION-CONTRACT.md`
§Body completeness; `ContentPieceReaderRequest` / `ContentPieceReaderModel` (the projection to extend);
`LocalNormalizedText`; ADR-0001 D6 (why the text is device-local and completeness is the synced signal).

### Done-criteria

1. A ContentPiece whose device holds `LocalNormalizedText` renders that body inline beneath the
   summary: `bodyCompleteness = full` reads inline; `truncated` reads inline **plus** Open Original for
   the remainder; `teaser` shows preview only with Open Original as the sole path. Verified through the
   Reader model's projection, not a UI snapshot.
2. A piece that synced in with `bodyCompleteness = full` but **no local text on this device** renders
   honestly — states the body is not held here, offers Open Original, asserts no substance it lacks
   (the D6 custody case; adversarial test on the projection).
3. Open Original is the fallback, not the default: absent/secondary when a full body reads inline.
4. A digest / non-substantive-primary piece keeps its compact contents-preview card (DECISIONS §19),
   not a full inline body.
5. **No** network fetch of the original to fill body (no scrape) — held/derived text only.
   `swift test` + `swiftlint --strict` green; typography/geometry handed to Jon's device pass.

### Out of scope

Reader typography/geometry (deferred), HTML-fidelity polish, and the offline *controls* themselves
(S3 — this slice renders the substance those controls retain).

---

## S3 — Offline controls: `Offline until [date]` and `Keep Offline`

**Branch:** `m4/s3-offline-controls` · **PR title:** `M4 · S3 — Offline controls`

V1-SCOPE §1 and IPAD-FIRST §8 — especially important on mobile. Per-piece, not bulk, in V1.

### Read first

`docs/V1-SCOPE-AND-SEQUENCING.md` §1 (Custody and offline); `docs/IPAD-FIRST-EXPERIENCE.md` §8;
ADR-0001 D6 (`LocalAvailability` / normalized-text custody, device-local); `docs/IMPLEMENTATION-CONTRACT.md`
(`LocalAvailability` state); DECISIONS §6 (custody and offline availability).

### Scope

- **`Offline until [date]`** — a per-piece explicit offline promise with **visible expiry** (initially
  ~30 days). Distinct from device-local automatic cache: this is a user promise, not cache policy
  (V1-SCOPE §1; a Product law).
- **`Keep Offline`** — an indefinite per-piece promise.
- Both are explicit state on `LocalAvailability`, surfaced in the Reader; nothing silently expires
  before its date, and expiry is honest and visible.

### Done-criteria

1. A piece marked `Offline until [date]` carries visible expiry and retains its device-local substance
   until that date; `Keep Offline` retains indefinitely. Verified through the `LocalAvailability` model.
2. Automatic cache eviction never removes a piece under an active offline promise (adversarial test:
   eviction pass respects the promise).
3. Expiry is visible and honest; a lapsed promise degrades to the ordinary cache/Open-Original story
   without asserting substance it no longer holds.
4. Per-piece only; `swift test` + `swiftlint --strict` green; badge/affordance presentation to Jon.

### Out of scope

Bulk / Stream-wide offline rules, trip-aware preparation, travel download (all deferred, V1-SCOPE §1).

---

## S4 — Gmail read-only ingest: Inbox → provider Artifact → email ContentPiece

**Branch:** `m4/s4-gmail-ingest` · **PR title:** `M4 · S4 — Gmail read-only ingest`

The first half of the Gmail spine: read the Inbox and normalize it into the existing Artifact →
ContentPiece spine, **read-only**. This is where the real provider semantics are first observed — the
raw material for the Gate-3 ADR.

### Read first

`docs/EMAIL-INTELLIGENCE-MODEL.md` §10, §13; ADR-0001 D7 (the auth spike, refresh token, `gmail.modify`
scope — read-only usage of it now); `docs/ADR-0001-PERSISTENCE-AND-EXECUTION.md` D3 (derived identity —
how an email becomes a ContentPiece without a random id); DECISIONS §7 (source disposition is separate
and not yet enabled); the existing RSS ingest path (the Artifact → ContentPiece shape to reuse, not
re-invent).

### Scope

- **Confirm the token in passing** — the first read >1h after authorization answers D7's production
  question for free (`docs/eval-log.md`, 2026-09-11). Record the result.
- **Read the current Inbox** (read-only) and **normalize each message into a provider Artifact**, then
  project to an **email ContentPiece** through the existing spine (derived identity, ADR-0001 D3). No
  new universal entity; the email ContentPiece is a ContentPiece.
- **Observe and record the semantics the ADR will settle** — message vs thread, account boundary,
  pagination/delta, provider IDs retained, new-reply re-entry, partial failure/retry. This slice's job
  is to *surface* them, not to freeze them.
- **No mutation, no `Clear` yet** — ingest and normalization only.

### Done-criteria

1. Gmail Inbox reads through the stored authorization; the D7 production-longevity result is recorded
   in `docs/eval-log.md`. (On failure: stop and evaluate the IMAP fallback per ADR-0001 D7 before S5.)
2. A message becomes a provider Artifact and an email ContentPiece via the existing derived-identity
   spine — no random id, no new universal entity — verified through the ingest model.
3. The observed provider semantics (message/thread, account, pagination/delta, IDs, re-entry, failure)
   are captured as notes toward the Gate-3 ADR, in the PR and/or a scratch doc.
4. Nothing mutates Gmail. `swift test` + `swiftlint --strict` green.

### Out of scope

Any provider mutation (Phase 4). The Today surface and `Clear` (S5). Finalizing the Gmail contract
(Gate 3). Email-delivered recurring **Streams** (Phase 5).

---

## S5 — Today: Worth Seeing / Personal-Consequential / quiet handling, Reader, Clear

**Branch:** `m4/s5-today-surface` · **PR title:** `M4 · S5 — Today`

The second half: turn the ingested Inbox into the Today surface `docs/TODAY-EXPERIENCE.md` specifies,
landing in the Today destination the M3 shell already built (which currently shows the M2 Edition
summary as a placeholder).

### Read first

`docs/TODAY-EXPERIENCE.md` §5, §6 (the surfaces and `Clear`); `docs/EMAIL-INTELLIGENCE-MODEL.md`
(analysis and quiet handling); DECISIONS §7 (`Clear` is attention-only; disposition is separate and
not enabled); the M3-S1 Today container and the one ContentPiece-driven Reader (the same Reader serves
email pieces).

### Scope

- **Analysis over the ingested email ContentPieces** into **Worth Seeing / Personal-Consequential /
  inspectable quiet handling** (TODAY-EXPERIENCE §5). AI may classify and summarize; it acquires no
  disposition authority (AI boundary; DECISIONS §7).
- **The one Reader serves email pieces** — reached from Today, same investigate-this-item surface
  (IPAD-FIRST §7; the M3-S1 ContentPiece-driven Reader). Email pieces get inline body per S2 where the
  substance is held.
- **`Clear` resolves Today attention** — a Cockpit attention action, **no Gmail mutation**
  (DECISIONS §7; TODAY-EXPERIENCE §6). Distinct from Edition's `Dismiss`.
- **Quiet handling is inspectable**, never silent deletion (V1-SCOPE §Today; nothing is destroyed).

### Done-criteria

1. Ingested email ContentPieces surface as Worth Seeing / Personal-Consequential / quiet handling;
   quiet handling is inspectable, not silent. Verified through the Today projection model.
2. `Clear` resolves Today attention and provably **does not** mutate Gmail (adversarial test: no
   provider write on `Clear`).
3. An email piece opens in the one ContentPiece-driven Reader with inline body where held; it carries
   no Edition-only affordances (no rationale/Dismiss — it is not an Edition entry).
4. `swift test` + `swiftlint --strict` green; the Today layout is Jon's device pass.

### Out of scope

Gmail dispositions (`Leave`/`Archive`/`Trash`) and any mutation (Phase 4, behind Gate 3). The
email-delivered recurring Stream (Phase 5). A rules engine, auto-unsubscribe, reply/composition
(out of V1, DECISIONS §7).

---

## Jon's manual and device pass

Same shape as M1–M3: the work only Jon can do, gating what follows.

### During S1 — the eval read is yours to endorse

Agents produce the paired `JudgmentEval` run; whether the split-pass edition *feels* right (and that
substantive-primary is being called correctly on real morning content, not just scoring better) is a
lived-use judgment.

### During S2–S3 — the reading and offline feel

Whether the inline body reads well and whether the offline promise feels trustworthy (visible expiry,
honest degradation) are device-pass calls (IPAD-FIRST §7–8).

### During S4–S5 — real Inbox semantics

The Gmail semantics that feed the Gate-3 ADR only appear against Jon's real Inbox. Agents ship the
tested ingest/Today models; Jon's use is what surfaces message/thread, account, and re-entry behaviour
the ADR must settle — and confirms Today *feels* like attention, not another feed.

---

## Architecture Gate 3 — write the Gmail integration ADR from observed semantics

The checkpoint M4 ends at (`docs/V1-SCOPE-AND-SEQUENCING.md`, Architecture Gate 3;
EMAIL-INTELLIGENCE-MODEL §13). This gate's deliverable is **a written ADR**, settled from what the
provider actually did in S4–S5, not from design intent. Settle:

- message vs thread identity/actions;
- account identity and multi-account behaviour if required;
- refresh / pagination / delta strategy;
- which provider IDs are retained;
- re-entry on new replies (without inventing a permanent parallel thread-resolution state, DECISIONS §7);
- partial failures / retries;
- undo capabilities where Gmail permits;
- what must be committed before any mutation (the disposition barrier, DECISIONS §7);
- the relationship from email Artifact to email-delivered ContentPiece.

**Only after this gate does source mutation (Phase 4 dispositions) become enabled.**

---

## Not in M4 — the M5+ cutline (proposed)

- **Gmail dispositions** — `Leave` / `Archive` / `Trash`, the disposition barrier, and bounded recent
  dispositions / Undo (Phase 4, Gate 4-adjacent). Follows Gate 3; mutation stays behind the ADR.
- **Email-delivered recurring Stream** (Phase 5) — the always-read newsletters (Yglesias, Puck,
  Sepinwall) flowing from Gmail into Edition under Stream Handling / Essential. **Read first at that
  time:** DECISIONS §21 (OPEN HYPOTHESIS) — do not silently assume `Essential` means "promote into
  Edition"; the reachable-first vs promote question is parked there. This phase is the critical test
  that Transport / Artifact / ContentPiece / Stream Handling / source disposition / Edition state are
  genuinely separate (Gate 4, major model review).
- **The type-call model swap** — moving the S1 classification pass to a cheaper/onboard model once it
  can emit the schema (M2-S1 cost decision; cheapest lever is a Haiku-vs-Sonnet eval first). Deferred
  behind the known schema blocker.
- **Auto-Library policy** — Phase 7, reconciled at Gate 2 (DECISIONS §18). After explicit Library +
  custody are trustworthy; must **not** reuse `isSubstantivePrimary` as the keep-criterion.
- **First specialist Find handoff** — the receiver for Pending Finds (Phase 6, Gate 5). Extraction has
  been accumulating orphans since M2 S5; the receiver is later.
