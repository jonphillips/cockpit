# ADR-0002 — Gmail Integration and Provider Disposition

**Status:** Draft — Gate 3 proposal. Ratify before any Phase 4 mutation.
**Date:** 2026-09-17
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
tab; `messages.get` bills 5 quota units against a **per-minute per-user** ceiling. Full-inbox,
re-read-every-time ingest is not viable. That is why several decisions below are non-negotiable
rather than open.

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
3. **A quota budget.** `messages.get` = 5 units; the ceiling is per-minute per-user. Backfill of a
   large category proceeds in bounded, paced batches across minutes, not in one pass. Concurrency is
   windowed (S4 uses 6 in flight). The Gmail batch endpoint may reduce round-trips but does **not**
   reduce quota units and is optional.

**Open — measure before ratifying:** the exact per-minute unit ceiling on this account; the batch
endpoint's real benefit; the backfill pacing that reads Promotions/Social without user-visible
stalls.

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

**Open — measure before ratifying:** Gmail's actual Trash purge window on this account; whether the
log is synced across devices or device-local (lean device-local first, consistent with ADR-0001 D2).

---

## D7 — Authority model: explicit per-action first; policies are explicit and user-established.

V1 starts at **explicit per-action** disposition: the user resolves a message and its Gmail
disposition is applied. The only automation permitted is an **explicit user-established policy** (e.g.
"Trash disposable retail offers after extracting a Find"); AI may **classify** a message to apply an
authorized policy and may **propose** a new policy, but never acquires destructive authority from
observed behavior (DECISIONS §7, §8 "knowledge does not grant agency"). Explicitly out of V1: a
generalized rules/Disposition-Rule engine, learned auto-deletion, automatic unsubscribe, and broad
reply/composition (V1-SCOPE out-of-scope list). Add only the smallest explicit recurring policies
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

## Open — measure before ratifying

These Gate-3 items had no S4 evidence and must be observed on device before this ADR moves from Draft
to Accepted:

- **Multi-message thread distinctness** — S4 read at least one 2-message thread but did not inspect
  per-message `id`/`threadID` distinctness. Confirm before relying on D1.
- **New-reply re-entry** — confirm a reply returning a thread to `INBOX` re-surfaces through
  `history.list` (the assumption D3/D4 lean on).
- **Quota constants** — the per-minute unit ceiling, batch-endpoint benefit, and safe backfill pacing
  for the large categories.
- **Trash purge window** — the real reversibility horizon for D6.

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
