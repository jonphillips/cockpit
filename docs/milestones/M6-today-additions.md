# M6 — Today additions (S-t1 … S-t4)

> **Build order, architect-recorded 2026-09-26 from Jon's product notes.** Four additions to the Today
> surface and its Gmail intake. They don't reopen any Gate 4 decision (D-A–D-G) or anything in the
> Gate 5 contract. Each block is self-contained: send it to the executor as-is. Branch per slice:
> `m6/s-tN-short-slug`, one PR each, tick the box here in the PR that completes it.

**Decisions behind these slices.** DECISIONS §27 (Promotions, new mail only, no source list), §28
(Gmail read state shown and set on open), §29 (Daily links). S-t1 needs no ledger entry: Tech is one
more content role under Gate 4's D-B scheme.

**Dependency shape.** S-t1 floats and is the smallest. **S-t2 → S-t3**: both touch `GmailInboxAPI`,
`GmailIngestion`, and `GmailArtifactProvenance`, so build them in that order. S-t3 also waits for
S-r13 to merge, because S-r13 gives the offer prompt the Find definition that every Promotions offer
will run through. S-t4 floats: it's app-side plus one new table.

**Styling.** Build every slice in default system styling. The visual pass for these surfaces belongs
to the Today/email design process (house rule: arrange → behavior → foundation → per-surface
adoption), not to these slices.

- [ ] S-t1 — Tech section: a content role below Daily news
- [ ] S-t2 — Read state: mirror Gmail's `UNREAD`, bold unread rows, mark read on open, Mark as Unread
- [ ] S-t3 — Promotions intake: new Promotions mail lands in Offers, with no backfill and no source list
- [ ] S-t4 — Daily links: an icon column beside Today, managed in Settings

## Standing rules for every slice

- Verify with `swift test` (CockpitCore), `swiftlint lint --strict`, and an unsigned app build. No
  Simulator or device driving (AGENTS.md). Name any device-only risk in the handoff report and stop.
- Behaviour lives in `@Observable` models or pure functions in `CockpitCore` and is tested there. Views
  don't touch the database.
- Never change stored `ContentPiece.publisher` / `creator`: `ContentIdentity.derive` hashes the
  publisher, so rewriting it forks identity.
- Gmail boundary (ADR-0002) is unchanged except where a slice cites DECISIONS §27 or §28. Every Gmail
  call stays windowed (`maxConcurrentMessageReads`), and the history cursor still advances only after
  a clean commit.
- Read state is provider state, never attention (§28). Nothing in these slices changes Today
  membership, Clear/Dismiss, Edition, or judgment input.

---

### S-t1 — Tech section: a content role below Daily news

**Why.** Jon gets a steady stream of tech newsletters, and today they fall into For you or Grab-bag.
He wants a Tech section in the list and a Tech stop on the section rail, placed right below Daily
news. He'll move newsletters into it himself as they appear, so no seeded rules are needed.

**Build.**
- `ContentRole`: add `case tech` (raw value `"tech"`), `displayName` "Tech", `sortOrder` 3, directly
  after `.dailyNews`. Shift `.opinion` … `.offers` down by one. Sections and the reading-view rail
  (`TodayReadingView.sectionRail`) both sort by `sortOrder`, so placement follows from this alone.
- `ContentRolePresentation`: color `.cyan` (teal is already Grab-bag's) and symbol `cpu`.
- Exhaustive switches: the compiler will list them. `TodaySurfaceRows.sectionView` renders Tech like
  Daily news (plain `emailRow`s), and `EmailTreatmentProcessor.extractionTreatment` needs no case
  (the default already applies).
- **No migration.** `contentRoleRoutingRules.role` is unconstrained `TEXT`. Confirm there's no CHECK
  constraint or stored-role validation elsewhere; if there is one, stop and report instead of widening
  it quietly.
- **No seeded rules.** The Reader's Move to Section menu and Settings → sub-feed routing both iterate
  `ContentRole.allCases`, so Tech appears in them automatically. That's how Jon routes newsletters.

**Prove (core).**
- `ContentRole.allCases.sorted(by: sortOrder)` puts `.tech` immediately after `.dailyNews`, and every
  `sortOrder` is unique.
- A routing rule with `role: .tech` round-trips through the table and resolves a piece to `.tech` in
  `CurationRouting.snapshot`.
- A Today projection with Tech rows yields a Tech section between Daily news and Opinion.

**Do not.** Seed tech List-IDs. Add a classifier or model call to guess Tech. Change any other role's
raw value.

**Done when.** On device, Jon moves a tech newsletter to Tech from the Reader. Later issues land in a
Tech section below Daily news, and the rail shows a Tech stop in the same position.

**Sequencing.** Touches `ContentRoleDomain.swift`, `ContentRolePresentation.swift`,
`TodaySurfaceRows.swift`, and tests. Floats. Branch: `m6/s-t1-tech-section`.

---

### S-t2 — Read state: mirror Gmail's `UNREAD`, bold unread rows, mark read on open, Mark as Unread

**Why.** DECISIONS §28. Jon wants a mail client's de-bold. Cockpit already fetches every message's
`labelIds` (`GmailInboxMessage.labelIDs`) and then discards them. Label changes are already history
events that re-read the message, so the mirror costs no new reads.

**Build.**
- **Persist the mirror.** Add a nullable `providerIsUnread` (`INTEGER`) column to `artifacts` in a new
  migration. For a Gmail Artifact, `GmailInboxIngestor.record` sets it from
  `labelIDs.contains("UNREAD")` on every insert and update. `nil` means unknown (legacy rows, non-Gmail
  transports). Don't put it in `providerProvenance`: provenance is ingest evidence, and this value
  changes. Follow whatever sync treatment `artifacts` already gets, and don't add sync machinery.
- **One-time refresh.** Legacy rows are `nil`, which renders as read, so an upgrade doesn't show a wall
  of false bold. After the migration, the next sync re-reads labels once for Gmail Artifacts whose
  pieces are currently in Today, using the same windowed reads. Record completion so it never repeats.
  If a cheaper `format=minimal` read is available in the client, use it: it costs the same quota but
  moves less data.
- **Project it.** `TodayRequest.Row` and `TodayReadingQueueRequest.Row` gain `isUnread: Bool`, true
  when any Gmail Artifact of the piece has `providerIsUnread == true`.
- **Render it.** Unread rows keep today's `.headline` title. Read rows use regular weight at the same
  size. Add no dot and no badge. Offer publisher rollups are bold when any row in the group is unread.
- **Mark read on open.** Add `GmailDispositionAPI.markRead(messageID:)` / `markUnread(messageID:)`
  (`messages.modify`, removing or adding `UNREAD`) behind a small `GmailReadStateService` in
  `CockpitCore`. When `ContentPieceReaderModel` shows a Gmail piece whose mirror says unread, it calls
  `markRead` for each of that piece's unread Gmail messages, never the thread (ADR-0002 D1). On
  success, set `providerIsUnread = false` locally so the row de-bolds without waiting for a sync. On
  failure, log it and change nothing: the row stays bold and the next open retries.
  - This covers every Reader entry point: the reading queue (including auto-advance after a
    disposition), the Highlights sheet, Later, Library, and Finds → open source.
- **Mark as Unread.** An item in the Reader's existing More menu (`ReaderDispositionToolbar.moreActions`),
  shown for Gmail pieces that are currently read. It calls `markUnread` and sets the mirror to `true`
  on success. Don't add a toolbar button: S-r11's one-row toolbar stays one row.
- **Not a disposition.** These calls don't write `gmailDispositionLogEntries` and don't pass through
  the D4 barrier.

**Prove (core).**
- Recording a message whose labels include `UNREAD` stores `true`. Re-recording it without `UNREAD`
  (a delta after Jon read it in Mail) stores `false`.
- A piece with two Gmail Artifacts, one unread, projects `isUnread == true`.
- Opening an unread Gmail piece calls `markRead` once per unread message and flips the mirror. Opening
  a read piece makes no call. A failing client leaves the mirror `true` and throws nothing to the view.
- Mark as Unread calls `markUnread` and flips the mirror back.
- An RSS piece never projects unread and never triggers a Gmail call.
- Clear, Dismiss, Archive, and Trash leave `providerIsUnread` untouched. Marking read doesn't change
  `TodayRequest` or `TodayReadingQueueRequest` membership.
- The one-time refresh runs once, is bounded to pieces in Today, and doesn't run again after it
  completes.

**Do not.** Mark read on Clear, Archive, Trash, swipe, or list scroll. Mark a whole thread. Let read
state touch attention, Edition, judgment, Personal Knowledge, or ordering. Add a retry queue or an
error banner.

**Device-only risks (name them).**
- Auto-advance means that marching down the queue marks each message read as it's shown. That's
  intended (Mail does the same), but report it if it feels wrong in use.
- Offline, opens can't mark read, so rows stay bold until a later open succeeds online.

**Done when.** On device: rows Jon hasn't opened are bold. Opening one de-bolds it in Cockpit, and
Gmail shows it read. A message read in Mail.app de-bolds after the next sync. Mark as Unread
restores the bold in both places.

**Sequencing.** Touches a new migration, `GmailIngestion.swift`, `GmailDispositionAPI.swift` (or a
sibling), `ContentPieceReaderModel.swift`, `TodayRequest.swift`, `TodayReadingQueueRequest.swift`,
`TodaySurfaceRows.swift`, `TodayReadingQueueRow.swift`, and `ReaderDispositionToolbar.swift`. Build
before S-t3. Branch: `m6/s-t2-read-state`.

---

### S-t3 — Promotions intake: new Promotions mail lands in Offers, with no backfill and no source list

**Why.** DECISIONS §27. The offer pipeline already exists: the Offers role, the on-device offer summary
and its one Find (`EmailTreatmentProcessor`, run by ingest for new pieces), and S-r6's barrier. But
every Gmail read is scoped to `category:primary`, so the offers Jon wants never arrive. He manages his
promo senders upstream and doesn't want a source list.

**Build.**
- **Epoch.** Add a nullable `promotionsSince` (`DATETIME`) column to `gmailSyncStates` in a new
  migration. The first successful sync that runs this code sets it to that sync's start time, on both
  the backfill path and the delta path. It never moves afterwards.
- **Membership query.** `GmailInboxAPI.promotionsInboxMessageIDs(since:)` lists with
  `labelIds=INBOX` and `q=category:promotions after:<epoch seconds>`, `maxResults=500`, the same
  bounded shape as `primaryInboxMessageIDs`. Gmail's `after:` accepts Unix seconds, which avoids the
  date-only operator's timezone ambiguity.
- **Delta.** In `inboxChanges`, the membership set is Primary ∪ Promotions-since-epoch.
  `primaryChangedIDs` / `departedChangedIDs` take the union (rename them if the names start lying).
  An old promo that surfaces in history through a label change isn't in the epoch-scoped set, so it's
  neither fetched nor ingested. As a departure it's a no-op, because Cockpit never held it.
- **Backfill.** `currentInbox()` (no cursor) stays Primary-only. Promotions begins with the first
  delta after the epoch is set.
- **Provenance.** `GmailInboxMessage` carries which membership set admitted it
  (`inboxCategory: .primary | .promotions`), and `GmailArtifactProvenance` records it as an optional
  field, where `nil` for legacy rows means Primary. It is rewritten on each re-record, so it reflects
  the most recent read.
- **Routing default.** In `routeDecision`, `.unconfigured` resolves to `.offers` when the piece's
  Gmail provenance says Promotions, and to `.forYou` otherwise (unchanged). Everything that already
  outranks `.unconfigured` still does: a followed Stream (priority 0), a List-ID or sender rule, a
  mute, and `isTransactional`.
- **Discovery.** `discoveredLocators` lists only locators that fall through to `.forYou`, so
  Promotions-defaulted locators aren't "discovered". The Reader's Move to Section is Jon's correction
  path for them.
- **Offers pass.** No change. Ingest already hands new pieces to `EmailTreatmentProcessor`, and
  `extractionTreatment` treats `.offers` as `.offer`.
- `EmailTreatmentClassifier` doesn't change.

**Prove (core).**
- The Promotions list request's `q` is exactly `category:promotions after:<epoch seconds>` with
  `labelIds=INBOX`.
- With a fake client, a changed ID in Promotions-since-epoch is fetched and ingested. A changed ID
  that is neither Primary nor in the epoch-scoped set is not fetched. A Primary changed ID behaves
  exactly as before.
- The epoch is set on the first sync, on both the backfill and delta paths, and it isn't moved by
  later syncs. The backfill path makes no Promotions request.
- Routing: a Promotions piece with no rule resolves to `.offers`. With a List-ID rule to `.wine` it
  resolves to `.wine`. A muted rule mutes it, and transactional markers make it `.transactional`. A
  Primary piece with no rule still resolves to `.forYou`.
- A Promotions-defaulted locator doesn't appear in `discoveredLocators`.
- A Promotions piece that ingests with a fake model client persists an offer summary and a
  `PendingFind`, and it lands in Today's Offers section, excluded from the Edition tail.

**Do not.** Backfill any Promotions mail, or widen the epoch. Add a sender list, allowlist, opt-in,
or Settings switch (§27). Read Social, Updates, or Forums. Add an auto-trash policy for promos. Give
Promotions its own cursor or cadence.

**Device-only risks (name them).**
- Gmail's `after:` with epoch seconds, checked against real Promotions mail on this account.
- A long gap between syncs means a larger catch-up, and each offer runs the on-device model during
  ingest. Report the catch-up time if it's noticeable. Don't add a cap in this slice: a cap would
  hold mail back silently.
- If Jon drags a message between Gmail tabs, `inboxCategory` follows it on the next re-read.
  Routing follows, unless an explicit rule is in place.

**Done when.** On device, a promotional email that arrives after the slice ships appears in Offers
with its summary and a proposed Find. Nothing from before the epoch appears. Primary behavior is
unchanged.

**Sequencing.** Touches a new migration, `GmailSyncState.swift`, `GmailInboxAPI.swift`,
`GmailInboxModel.swift`, `GmailArtifactProvenance.swift`, `GmailIngestion.swift`,
`CurationRoutingDiscovery.swift` (`routeDecision`, `discoveredGmailLocators`), and tests. Build after
S-t2 and after S-r13 merges. Branch: `m6/s-t3-promotions-intake`.

---

### S-t4 — Daily links: an icon column beside Today, managed in Settings

**Why.** DECISIONS §29. Jon has a few places to visit daily, including at least two Apple News
channels. Cockpit shows them as a quiet checklist next to Today. It opens each one, remembers that it
was visited today, and does nothing else with it.

**Build.**
- **Table** `dailyLinks`: `id` (UUID; user-authored, so a random ID is fine. Follow ADR-0001 for
  user-authored rows), `title` TEXT, `url` TEXT, `symbolName` TEXT, `sortOrder` INTEGER,
  `lastVisitedAt` DATETIME NULL, `createdAt` DATETIME.
- **Core.** `DailyLinkOperations` provides add, update, delete, move, and `recordVisit(id:at:)`. A pure
  `DailyLink.isVisited(on:calendar:)` compares `lastVisitedAt` with the local calendar day. A
  `DailyLinkModel` (`@Observable`) serves both Today and Settings. URL validation accepts `http` and
  `https` with a host, which covers `https://apple.news/…`. Trim whitespace, and reject everything
  else with an inline message.
- **Icons.** A curated set of about 16 SF Symbols in one place in `CockpitCore`, for example
  newspaper, globe, link, book, chart.line.uptrend.xyaxis, cloud.sun, sportscourt, film, music.note,
  cart, fork.knife, wineglass, cpu, quote.bubble, building.columns, and star. The default is `link`.
- **Today, regular width.** A trailing column about 56pt wide on `TodayLandingView` (the orientation
  surface only, not the reading split) with one icon button per link, in order. The accessibility
  label is the title, and a long press or hover shows it. A link visited today is dimmed with
  secondary styling and a small check. A tap calls `openURL`, then `recordVisit`. With no links, the
  column isn't shown at all.
- **Today, compact width.** A toolbar `Menu` (symbol `link`) that lists the links, with a checkmark on
  the ones visited today. The same tap behavior applies.
- **Settings → Daily links.** A list with add and edit in one sheet (title, URL, icon picker),
  drag-to-reorder, and swipe to delete. A footer line explains Apple News: "In News, open a channel,
  tap Share → Copy Link, and paste it here."

**Prove (core).**
- Add, update, delete, and move keep `sortOrder` dense and stable. A deleted link doesn't leave a gap
  that reorders the others unexpectedly.
- `isVisited(on:)` is true after a visit the same local day and false after the next midnight. Test
  with a fixed calendar and time zone, including a visit at 23:59 checked at 00:01.
- URL validation accepts `https://apple.news/Tabc`, `https://example.com`, and ` http://x.y/ `
  (trimmed). It rejects `applenews://…`, `ftp://…`, `example.com` with no scheme, and the empty
  string.
- `recordVisit` sets only `lastVisitedAt`.

**Do not.** Fetch favicons, titles, previews, or anything else from a link's destination. Open links
in the Reader's web view. Keep a visit history beyond `lastVisitedAt`. Feed visits to judgment,
ranking, or Personal Knowledge. Add folders, tags, or import. Hand-roll an `applenews://` scheme.

**Device-only risks (name them).**
- Whether an `apple.news` channel link opens straight into News on Jon's iPad or passes through
  Safari first. Report which one happens, and don't add a workaround in this slice.
- The column's width against the Today content on the smallest iPad in landscape and in Split View.

**Done when.** On device, Jon adds his two Apple News channels and his other daily sites in Settings.
They appear as icons beside Today, a tap opens each one in News or Safari, the icon dims for the rest
of the day, and it's back the next morning.

**Sequencing.** Touches a new migration, new `DailyLink*.swift` files in `CockpitCore`,
`TodayLandingView.swift`, `TodayView.swift` (compact toolbar), `SettingsView.swift`, and a new Settings
view. Floats. Branch: `m6/s-t4-daily-links`.
