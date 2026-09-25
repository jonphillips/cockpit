# ADR-0002 — Gmail Integration and Provider Disposition

**Status:** Accepted (2026-09-19) — Gate 3 closed. Ratified once the three empirical open items were
observed on the real account (M5 S6; see `docs/eval-log.md` 2026-09-19). Phase 4 mutation may proceed
behind the barrier. **Amended 2026-09-21 (D9, D10)** to ratify reflecting Gmail-side departures out of
Today and read-triggered, series-scoped disposition preferences.
**Date:** 2026-09-17 (Accepted 2026-09-19; amended 2026-09-21)
**Phase:** 3 gate — closes M4 and must be settled before source mutation is enabled (Phase 4).

---

## Context

Phase 3 / M4 S4 shipped read-only Gmail ingest (PR #31): the Inbox reads through the
production-issued authorization and each message becomes a provider Artifact and an email
ContentPiece through the existing derived-identity spine. `docs/V1-SCOPE-AND-SEQUENCING.md`
(Architecture Gate 3) requires an integration ADR, written **from real provider behavior**, before
`Archive`/`Trash` become executable. This is that ADR.

The disposition *policy* boundary is already ratified in `docs/DECISIONS.md` §7 and elaborated in
`docs/EMAIL-INTELLIGENCE-MODEL.md`: Cockpit owns its own attention state; the three provider
dispositions are `Leave` / `Archive` / `Trash`; automatic Archive/Trash requires an explicit
user-established policy; nothing mutates before a promised durable result is committed; no
`Delete Forever`, no rules engine, no learned deletion in V1. This ADR does not reopen those
decisions — it turns them into an executable contract and answers the mechanical questions §7 left
open, using the evidence in `docs/m4-s4-gmail-observations.md`.

The device read forced one finding to the front: Gmail's category tabs all carry the `INBOX` label,
so the real Inbox is ~40k messages (Promotions 16,212; Updates 14,295) behind a 41-message Primary
tab; `messages.get` bills **20 quota units** against a **per-minute per-user** ceiling of **6,000
units** (Google's published Gmail API limits, effective 2026-05-01). Full-inbox, re-read-every-time
ingest is not viable. That is why several decisions below are non-negotiable rather than open.

> **Quota correction (2026-09-18).** This ADR was drafted assuming `messages.get` = 5 units, the
> pre-2026-05-01 figure. Google's current published cost is **20 units** — 4× higher — which only
> strengthens the case against full-inbox ingest and reshapes the D2 backfill pacing. The documented
> constants are recorded in D2; what remains genuinely empirical (still Open) is whether they hold on
> this account under a real paced backfill, which the first delta-sync build (M5 S6) measures.

The Gate-3 checklist (V1-SCOPE) is answered decision-by-decision. Where S4 did not produce evidence,
the item is listed under **Open — measure before ratifying** rather than guessed.

---

## D1 — Message is the unit; thread is retained context, not the action target.

Disposition acts on the **message**. `Archive` and `Trash` apply to the message the user resolved,
not to its thread. Cockpit retains `threadID` on every Artifact for grouping and re-entry reasoning,
but does not, in V1, archive or trash a whole thread as one action, and does not build a threading
UI (EMAIL-INTELLIGENCE §1 excludes it).

Rationale: message-level disposition is the smallest authority that satisfies the product, and it
maps 1:1 onto the Gmail label operations in D5. Thread-level actions are a later, explicit extension
if evidence demands one.

**Retained provider identity** (already built in S4, restated as the contract):

- Artifact `providerID` = `gmail:{canonical-account}:message:{messageID}` — stable, provider-scoped,
  the mutation target key.
- `threadID`, `rfcMessageID`, and the classification headers are retained as device-local
  `providerProvenance`.
- ContentPiece `id` is derived (ADR-0001 D3), never random; re-ingest of the same message converges.

---

## D2 — Read strategy: `historyId` delta sync is mandatory, category-scoped, with a quota budget.

The read side has three standing rules, forced by the quota evidence:

1. **Delta sync via `historyId`.** After a first bounded backfill, every subsequent read asks Gmail
   `users/me/history.list?startHistoryId=…` for what changed, and never re-lists the Inbox. The
   snapshot already carries the profile `historyId`; it must be persisted per account and advanced
   only after a sync commits. This is the durable answer to "prevent the backlog re-costing every
   refresh" and to keeping the archived-message set consistent (a label change is a history event).
2. **Category-scoped reads.** The attention surface is read per category, not as one undifferentiated
   `INBOX`. S4 scopes to `category:primary` (the search operator, because Gmail does not stamp
   `CATEGORY_PERSONAL` on all Primary mail). Promotions/Social/Updates are in scope for later stages
   (promo sifting, retail/wine Finds) but are read on their own budget and cadence, not folded into
   the Primary read.
3. **A quota budget.** Documented Gmail API costs (effective 2026-05-01): `messages.get` = **20**
   units, `messages.list` = 5, `messages.modify` (Archive) = 5, `messages.trash` = 20,
   `messages.untrash` = 5, `history.list` = 2; the ceiling is **6,000 units per user per minute**
   (≈100/sec). So a delta sync's dominant cost is the `messages.get` per changed message (20 units →
   ~300 gets/minute/user ceiling), and backfill of a large category proceeds in bounded, paced batches
   across minutes, not in one pass. Concurrency is windowed (S4 uses 6 in flight). The Gmail batch
   endpoint may reduce round-trips but does **not** reduce quota units and is optional.

**Open — measure before ratifying:** whether the documented ceiling holds on this account under a real
paced backfill (429/`userRateLimitExceeded` behavior at the edge); the batch endpoint's real benefit;
the backfill pacing that reads Promotions/Social without user-visible stalls. The unit *constants*
above are no longer open — they are Google's published figures; what is open is their behavior under
load on this account, which the M5 S6 delta-sync build measures.

---

## D3 — Throttle, retry, and partial-failure semantics.

**Throttling** surfaces as HTTP 429 **and** as HTTP 403 `userRateLimitExceeded` (domain
`usageLimits`); the two are equivalent and both retryable. Retry honors a `Retry-After` header when
present, otherwise exponential backoff, and preserves the error body so a `usageLimits` 403 is never
confused with a configuration/scope 403 (`accessNotConfigured`, insufficient scope), which is fatal.
(Implemented in `GmailInboxAPI` at S4.)

**Partial failure** is resolved in favor of progress, not atomicity: a sync commits the messages it
read successfully, records per-message failures, and lets the failed messages re-enter on the next
delta sync (they remain in `INBOX`, so `history.list` will re-surface them). S4's transport is
currently all-or-nothing (one failed `messages.get` discards the batch); Phase 4 must move to
partial commit, because an all-or-nothing read cannot coexist with a disposition barrier that
depends on per-message commit (D4).

Rationale: this aligns with §7's "new replies naturally re-enter" principle — the same mechanism that
handles a new reply handles a transient per-message failure, so no parallel retry-queue state is
invented.

---

## D4 — The disposition barrier: commit, verify, then mutate. Per message.

No message is archived or trashed until every durable result Cockpit promised for it — ContentPiece,
normalized text, Find/Pending Find, retained understanding — is committed to the local database and
the write is verified. This restates EMAIL-INTELLIGENCE §5 as an executable ordering:

```text
read message → classify/extract → persist ContentPiece/Find/understanding
             → verify commit → advance historyId → apply provider disposition
```

The barrier is **per message**, which is why D3 requires per-message commit. If commit fails, the
message keeps its `INBOX` label and its current disposition is a no-op; it re-enters next sync. A
disposition is attempted only against a message whose promised results are already durable.

---

## D5 — The three dispositions map to label operations; no permanent delete.

| Disposition | Gmail operation | Reversible? |
| --- | --- | --- |
| `Leave in Inbox` | no-op (keep `INBOX`) | n/a |
| `Archive` | `messages.modify` removing `INBOX` | yes — re-add `INBOX` |
| `Trash` | `messages.trash` | yes — `messages.untrash`, within Gmail's ~30-day Trash window |

`Delete Forever` (`messages.delete`) is **not** implemented in V1 (DECISIONS §7). Trash is the
strongest destructive authority Cockpit takes, and Gmail's Trash lifecycle is the safety net.

Requesting `Archive` for a message not in `INBOX`, or `Trash` for one already trashed, is idempotent
and treated as success.

---

## D6 — Undo is a bounded, inspectable local disposition log.

Every applied disposition is written to a local, device-owned log: message `providerID`, the
operation, the timestamp, and the inverse operation. Recent dispositions are inspectable and each is
individually reversible for a bounded window where Gmail permits it (Archive always; Trash until
Gmail purges the message). Undo issues the inverse label operation and records that it did so; it is
not a separate "parallel thread-resolution state" (§7).

**Open — measure before ratifying:** Gmail documents a **30-day** Trash auto-purge window, so that is
the recorded reversibility horizon; the empirical part — that `messages.untrash` actually recovers a
Cockpit-trashed message within it — is only exercisable once `Trash`/Undo exist (M5 S7), not a
standalone measurement now. Also: whether the log is synced across devices or device-local (lean
device-local first, consistent with ADR-0001 D2).

---

## D7 — Authority model: explicit per-action first; policies are explicit and user-established.

V1 starts at **explicit per-action** disposition: the user resolves a message and its Gmail
disposition is applied. The only automation permitted is an **explicit user-established policy** (e.g.
"Trash disposable retail offers after extracting a Find"); AI may **classify** a message to apply an
authorized policy and may **propose** a new policy, but never acquires destructive authority from
observed behavior (DECISIONS §7, §8 "knowledge does not grant agency"). Explicitly out of V1: a
generalized rules/Disposition-Rule engine, learned auto-deletion, automatic unsubscribe, and broad
reply/composition (V1-SCOPE out-of-scope list; the narrow in-thread plain-text reply is ratified in
DECISIONS §26). Add only the smallest explicit recurring policies
needed to prove the authority model (V1-SCOPE Phase 4).

---

## D8 — Account and Artifact→ContentPiece relationship.

**Account:** single account in V1. The `providerID` is already namespaced by canonical account
(`gmail:{account}:message:{id}`), so multi-account is a later widening, not a reshape. Multi-account
disposition/authority is deferred; no evidence yet requires it.

**Artifact → ContentPiece:** unchanged from S4 and ADR-0001. The email Artifact is device-local
provider evidence; the email ContentPiece is the shared, provider-neutral result; `Artifact.id ≠
ContentPiece.id`, and disposition acts on the **Artifact/provider message**, never on the
ContentPiece. Clearing a Gmail source in Today is not clearing the ContentPiece from Edition
(EMAIL-INTELLIGENCE §6; §7).

---

## D9 — Reflecting Gmail-side departures out of Today (amendment, 2026-09-21).

Ratifies the reconciliation shipped in PR #54. Two things forced it: messages the user
archived/trashed **directly in Gmail** stayed on Today, and even a disposition **from Cockpit** left
the row until a full re-read. Today was "growing and growing" instead of reflecting the provider.

**The decision.** A delta sync (`history.list`, D2) already distinguishes changed messages still in
Primary from changed messages that left it. The complement — changed-but-no-longer-Primary — is the
**departure set** (`GmailInboxAPI.departedChangedIDs`). On each delta sync the ingestor clears those
messages' Today concerns, so the surface reflects Gmail without re-costing the backlog. This is a
Today-surface resolution only:

- **No provider write.** Reconciliation issues no `messages.modify`/`trash`; it only reads the delta
  Cockpit already fetched. It cannot violate the barrier (D4) because it mutates nothing at the provider.
- **Custody untouched (D8).** Clearing a Today concern is not clearing the ContentPiece; the Artifact,
  ContentPiece, normalized text, and any Find/Later/Library custody are all retained. A reconciled
  departure removes only the *attention*, never the *knowledge*.
- **One-directional — orientation, not a live mirror.** The clear is terminal: a later un-archive in
  Gmail does **not** auto-resurface the row on Today. Today orients the user for the day; it is not a
  second Gmail client that tracks Inbox membership in both directions. New mail re-enters through the
  normal ingest path (D3); a resurrected old message does not.

**External-only.** Reconciliation records its terminal clear (the reused `TodayAttention` marker, see
below) **only for departures Gmail made on its own** — an archive/trash performed outside Cockpit. A
departure that **Cockpit itself caused** (an Archive/Trash whose disposition-log entry is still
un-reversed, D6) is excluded, because that row is already hidden by `TodayRequest` **and is still
reversible**. If reconciliation also stamped the terminal marker for it, a later Undo would re-add the
message in Gmail and clear the log entry, yet the marker — which nothing un-clears — would strand the
row off Today, silently breaking the D6 undo guarantee. So reconciliation is the strict *complement*
of Cockpit-initiated disposition, never an overlap:

| Departure cause | Hidden from Today by | Reversible by Undo? |
| --- | --- | --- |
| Cockpit Archive/Trash | un-reversed disposition-log entry (D6) | yes |
| External Gmail archive/trash | terminal `TodayAttention` clear (this D9) | no (one-directional) |

**Marker reuse, ratified.** Reconciliation reuses the `TodayAttention` "cleared" marker rather than
inventing a parallel table. This widens the marker's meaning from "the user's explicit `Clear`" to
"this concern is resolved for Today — by an explicit `Clear` **or** an external Gmail departure." The
widening stays inside §7/§8: it grants no destructive authority (no provider mutation) and crosses no
custody boundary (D8). It does not extend to Cockpit-caused departures, per *External-only* above.

---

## D10 — Read-triggered, series-scoped disposition preferences (amendment, 2026-09-21).

Cockpit may apply an explicit series-scoped Trash preference when Jon has declared that newsletter
series and then leaves the piece in the Today Reader. The trigger is a human read in the Reader —
never sync, arrival, or any passive behavior — because the briefing's value is the material Jon has
actually read. An unread declared piece is untouched.

The scope is a user-declared set of series keyed by normalized Gmail `List-ID`, falling back to the
normalized sender mailbox only when `List-ID` is absent. It is deliberately independent of `Stream.ID`:
Streams are manually configured and must not be required for this provider preference. The path is
guarded to `EmailTreatment.newsletter` both when the declaration is offered and again when the action
is applied, so Primary/person-to-person mail and other treatments can never enter it. Declaration is
explicit only; observed reads may not establish authority, and a future propose-and-confirm nudge
would remain a proposal until accepted.

The action is Gmail `Trash`, applied through D4's existing commit barrier and D6's bounded Undo log.
It is once per message, idempotent against an existing Trash log entry, fully reversible while Gmail
permits `untrash`, and leaves ContentPiece custody plus any Find, Later, or Library result untouched
(D8). Removing the declaration row stops future automatic Trash; it does not undo prior dispositions.

---

## D11 — Curated Gmail is organized, never judged; RSS stays the judged tail (Gate 4, 2026-09-25).

Ratifies Gate 4 (`docs/milestones/M6-gate4-email-stream-separation.md`) after the S-d0 build (PRs #60–#63),
Jon's S-d device evaluation, and the reader dogfood slices (S-r1 … S-r11).

**Gmail never enters Edition judgment.** Curation role comes from routing, not from a model:
`CurationRouting` resolves each Gmail-backed ContentPiece to a content role (List-ID / sender locator,
editable in Settings → Sub-feed routing). Followed-Stream and Today-triage Gmail pieces are both
excluded from the Edition planner (`editionExcludedContentPieceIDs`) and appear in Today's role
sections in arrival order. Nothing curated is suppressed, declined or ranked by a model (DECISIONS §24).

**RSS is unchanged.** RSS Streams remain the uncurated tail: judged, admitted or declined, ranked
within `targetSize`, and Essential RSS keeps both halves of §15. This is Jon's intent, not a transport
shortcut. He reads RSS elsewhere, and Cockpit's job for RSS is only to filter it (DECISIONS §24, Gate 4
ratification).

**The layers are separate.** Transport, Artifact, ContentPiece, Stream Handling, source disposition
(D4–D6, D9, D10) and Edition state vary independently:
- a Gmail disposition never touches ContentPiece custody, Later, Library or a Find (D8, D9);
- routing a sub-feed to a different section changes only its Today placement.

**Always-read Streams get no special surface.** Listing in their section, plus the pointer-only
Highlights row, is the treatment. No pinned or promoted setting exists or is planned.

## Open items — settled at ratification (M5 S6)

The three Gate-3 items that gated ratification were observed on the real account on 2026-09-19
(`jon@jonphillips.com`, Simulator; full evidence in `docs/eval-log.md`). The fourth is deferred to S7
by construction, because Trash does not exist until then.

- **Multi-message thread distinctness** *(settled — D1)* — a real 2-message thread ingested as two
  Artifacts with distinct message IDs sharing one thread ID. The message is the unit.
- **New-reply re-entry** *(settled — D3/D4)* — a reply that returned to Primary `INBOX` re-surfaced
  through `history.list` on the next delta sync, and the cursor advanced only on commit.
- **Quota constants** *(settled under a real paced backfill — D2)* — a 79-message Primary backfill read
  through the six-wide fetch window committed with zero failures and no 429/`userRateLimitExceeded`.
  The published figures (D2, corrected 2026-09-18: `messages.get` is 20, not the drafted 5) hold on this
  account; the 6,000/min/user ceiling was not approached, as expected with Primary capped at 100.
- **Trash purge window** *(deferred to S7 — D6)* — Gmail's documented 30-day auto-purge is the recorded
  horizon. The empirical part — Cockpit `untrash` recovering within it — rides M5 S7, when Trash exists.

## Consequences

- Phase 4 may implement `Leave`/`Archive`/`Trash` and the barrier once the four open items are
  measured; the policy and safety constraints are already fixed here.
- Delta sync (`historyId`) becomes a build requirement of the first mutation slice, not an
  optimization — mutation changes labels, and only `history.list` keeps the read set consistent
  without re-costing the backlog.
- The transport's all-or-nothing read (S4) must become per-message partial commit before the barrier
  can be trusted.

## Amends

On ratification: `docs/DECISIONS.md` §7 (from policy to executable contract; reference this ADR),
`docs/V1-SCOPE-AND-SEQUENCING.md` Phase 4, `docs/EMAIL-INTELLIGENCE-MODEL.md` §5. Supersedes the
open-questions list in `docs/m4-s4-gmail-observations.md` once its four measurements are recorded.
