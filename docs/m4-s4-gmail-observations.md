# M4 S4 — Gmail read-only observation notes

**Status:** implementation worksheet; complete from the first device read before Gate 3.

The production read path calls only Gmail `GET` endpoints:

1. `users/me/profile` — records the account identity and current `historyId` returned by Gmail;
2. `users/me/messages?labelIds=INBOX` — walks all current-Inbox pages and reports the page count;
3. `users/me/messages/{id}?format=full` — reads each current-Inbox message, retaining its Gmail
   message ID, thread ID, body, and classification headers locally.

No call in the path labels, archives, trashes, marks read, or otherwise mutates Gmail.

## First production read

Run **Settings → Gmail authorization probe → Read Current Inbox** on Jon's device. The result is
the D7 refresh-token observation: success confirms the production-issued Keychain authorization
refreshed and completed a real Gmail read; failure stops the Gmail spine and triggers the ADR-0001
D7 IMAP/app-password evaluation before S5.

- [x] Result recorded: **2026-09-17, Jon's production Google account, success.** The read ran well
      over an hour after authorization, so the ~1h access token was refreshed from the stored
      authorization — D7's production-longevity question is answered affirmatively.
- [x] Message count and page count: **42 messages, 1 page** — scoped to the Primary tab
      (`category:primary`) and bounded to 100. This is *not* the full Inbox (see quota finding below).
- [ ] Returned Gmail `historyId`: retrieved from `users/me/profile` and carried on the snapshot, but
      the probe UI does not surface it, so presence is not yet confirmed by eye. Delta sync needs it
      (see finding A); surfacing or logging it is a cheap follow-up.
- [ ] Confirm message/thread IDs are distinct on multi-message threads: the read included at least
      one 2-message thread ("Domenico, me 2"); per-message `threadID` is retained but distinctness on
      that thread was not inspected in detail.
- [ ] Confirm a newly received reply reappears through current `INBOX` membership: not tested.
- [x] Per-message partial failure / retry: none observed — all 42 reads succeeded on first attempt.

## What the first production read taught

**A. Full-Inbox ingest is not viable in one pass; `historyId` delta sync is now a hard ADR
requirement, not an option.** Gmail's category tabs all carry the `INBOX` label, so Jon's Inbox is
~40k messages (Promotions 16,212; Updates 14,295; Social 310; Purchases 447; Forums 84) behind a
41-message Primary tab. `messages.get` bills 5 quota units against a **per-minute per-user** "Total
Query Cost" ceiling, so reading everything trips `userRateLimitExceeded`. A per-minute quota cannot
be cleared by short backoff. Any read beyond a bounded Primary window — and any *repeated* read —
must fetch deltas via `historyId`, not re-list the Inbox. The Gate-3 ADR must specify this.

**B. Gmail throttling surfaces as both HTTP 429 and HTTP 403 `userRateLimitExceeded` (domain
`usageLimits`).** Retry logic must treat the `usageLimits` 403 as retryable, not fatal, and must
preserve the error body to distinguish it from a configuration/scope 403 (`accessNotConfigured`,
insufficient scope). Both are now handled in `GmailInboxAPI`.

**C. Gmail's own category labels are incomplete, which validates the §24 header-based S5 design.**
Much of Primary — the newsletters (Substack, NYT, WaPo, Yglesias) — carries no `CATEGORY_*` label at
all, so `labelIds=CATEGORY_PERSONAL` under-read (4 of 41). The `category:primary` *search operator*
resolves the tab correctly. The lesson for S5: the personal-vs-publication split cannot rely on
Gmail's categorization being present; it must use the retained RFC headers (`List-ID`, `Precedence`,
sending domain, To/Cc cardinality). This is what §24 chose.

**D. Two defects were exposed only by a real device + account, as AGENTS.md predicts.** Both were
build-, test-, and lint-clean:
- an iPad nested-`NavigationStack` crash (`AnyNavigationPath.Error.comparisonTypeMismatch`) — the
  probe view wrapped itself in a second navigation stack inside the Settings stack;
- an unbounded per-message fan-out that fired a `messages.get` for every Inbox message at once.

**E. Provisional constants, to be settled by the ADR, not frozen here.** Per-message read
concurrency (6), the retry backoff schedule (1/2/4/8s + `Retry-After`), the 100-message cap, and the
Primary-only scope are pragmatic probe choices, not tuned against measured Gmail behavior.

## Deliberately not settled by S4

This slice captures evidence but does not establish the provider-mutation contract. Gate 3 will use
the completed observations to decide message-versus-thread action semantics, account boundaries,
pagination/delta strategy, retained provider IDs, re-entry, partial-failure retry, Undo capability,
and the exact commit barrier before any provider mutation.
