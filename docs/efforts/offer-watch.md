# Effort — Offer watch

Status: Ready
Summary: A read-only client on Jon's Mac alerts his iPad and iPhone about mail from senders he lists, then adds an on-device filter for other offers and polling of restaurants' own sites, each proven silently first.

Implements: [ADR-0003](../ADR-0003-OFFER-WATCH-CLIENT.md) and [DECISIONS.md](../DECISIONS.md) §34. Read
ADR-0003 first; its D1, D2, and D7 boundaries bind every slice. There's no change to Cockpit's persisted
schema or CloudKit in any slice. If a slice seems to need one, stop and raise a
`question-for-architect`.

Three slices, in order. **S-w1 is dispatchable now and needs no model.** Its PR trims it from this brief,
and S-w2 stays Ready. The PR that completes **S-w2** sets `Status: Blocked` on the filter trial, and the
architect adds the trial to `device-passes.md` in review. **S-w3 opens when that trial passes**, because it
relies on the same on-device judgment. Everything runs on any Mac, so nothing has to wait for the Mini.

**Never, in any slice (ADR-0003 D7):** automated booking, fetching a booking platform's pages, or working
around a block.

## S-w1 — Watched senders and alerts

The whole alert path, with no model.

**Package.** Add an `OfferWatch` executable and an `OfferWatchSupport` library, with tests in
`CockpitCoreTests`, following `JudgmentFixtureHarvest`/`JudgmentFixtureSupport`. Move the Desktop OAuth flow
out of `GmailFixtureToken` into a small library both executables use. `GmailFixtureToken` keeps its behavior
and its stdout contract. Add the narrowest public Gmail call this needs (list by query, then get); the
message read already asks for `format=full`, so confirm `Authentication-Results` survives it.

**Commands.**

- `offerwatch auth --client <secret.json>`: Desktop sign-in with `gmail.readonly`, refresh token in the login
  keychain.
- `offerwatch apns-key <path>`: stores the `.p8` key in the keychain.
- `offerwatch pair <name> <token> <production|sandbox>`, and `pairs` to list them.
- `offerwatch run`: the loop. It's the only thing the LaunchAgent starts.

**The loop.** Every 2 minutes: read the list, search `from:` (ADR-0003 D3), and for each new message check the
exact address, the authentication result, and the entry's first-seen time, then send and record it. A newly
installed watcher takes its start time as a baseline and never alerts on older mail. Transient failures back
off and retry. An account change stops the loop and reports.

**Lists.** `watched.txt` holds one address per line, in `iCloud Drive/Offer Watch/`, with a last-good copy under
`~/Library/Application Support/OfferWatch/`. Find out whether a LaunchAgent process can read that folder, and
document what permission it takes. If macOS won't allow it, fall back to the local path and say so in the PR.

**State.** All of it lives in Application Support: first-seen times, pairings, and a ledger keyed by source ID
(JSON or a small SQLite file, whichever is simpler; no SQLiteData, and it's not a Cockpit table). Keep ledger rows
for 90 days. Never commit real mail, and any fixture is synthetic.

**APNs.** HTTP/2 to `api.push.apple.com` or `api.sandbox.push.apple.com` per pairing, a JWT signed with CryptoKit
(ES256, reused for 20–60 minutes), and the payload, cap, heartbeat, and self-reports in ADR-0003 D6 and D8. A
`410` or `BadDeviceToken` marks the pairing dead and reports through another. Record each send in the ledger. A
crash between send and record can repeat an alert, and that's acceptable.

**App.** The app registers for nothing today, and has no delegate adaptor or notification code, although
`aps-environment` and the `remote-notification` background mode are already set.

- Add `UIApplicationDelegateAdaptor`, `registerForRemoteNotifications`, and a `UNUserNotificationCenter`
  delegate. Keep the logic in a testable `@Observable` model in `CockpitCore`.
- Settings row "Offer alerts": requests notification permission only when Jon taps it, and shows this device's
  token and APNs environment with a copy button. The token is held in memory or `UserDefaults`. It's not a table
  and not synced.
- Add the Time Sensitive capability in `project.yml` (`com.apple.developer.usernotifications.time-sensitive`).
  Follow `docs/ios/drift-control.md`. The App ID change is Jon's.
- Tap: read the Gmail message ID, find the ContentPiece through `GmailArtifactProvenance.messageID`, and open it
  in the existing reader. If it isn't there, run the existing ingest once and retry. If it's still absent, which
  is expected for mail in tabs Cockpit doesn't read, show a plain state with Retry and Open in Gmail. Don't open
  any URL taken from content.

**Running it.** `tools/offer-watch/` holds a LaunchAgent plist template and a short `SETUP.md`: build in release,
install, `auth`, the APNs key, pairing, load the agent, read logs, and the FileVault choice in ADR-0003 D8. The
process opens no listener (ADR-0003 D1).

**Legal.** Update `docs/legal/privacy.html`: Jon's own always-on Mac can read the mailbox read-only, and a short
line derived from an email passes through Apple's push service to reach his devices. No new recipient beyond Apple.

**Tests** (injected client, clock, sender, no network): exact address match against a loose search hit; a failed
authentication result doesn't alert; a new entry doesn't fire older mail; first run doesn't alert; re-reading a
message doesn't resend; payload shape and limits; JWT claims and reuse window; the cap into `passive`; the heartbeat's
collapse ID; dead-token handling; an unreadable list keeps the last-good copy and reports; the tap model across found,
found-after-ingest, and absent; permission is never requested at launch.

**Done when.** Tests, lint, and the unsigned build are green per `docs/verification.md`. The iOS app links none of
the watcher. Device delivery, Focus break-through, tap routing, both APNs environments, and a live run are named in
the PR as owed, and the architect adds them to `device-passes.md`.

### Jon's part

- Confirm the Desktop OAuth client is in the Google project already **published to Production** (ADR-0001 D7). A
  client in Testing loses its token after seven days. Add `gmail.readonly` to the consent screen if it isn't there.
- Create the APNs `.p8` key and turn on the Time Sensitive capability in the developer portal.
- Install it (`SETUP.md`), pair each device, and allow Cockpit's time-sensitive notifications in the Focus modes
  where he wants them.
- Start `watched.txt` with the restaurants that matter. Sign up for their mailing lists and turn on Resy Notify
  or similar where he wants a specific table.

## S-w2 — Model filter, silent

Add the second route, off by default. `offerwatch.json` has `"filterAlerts": false`, and nothing in this slice can
notify from this route until Jon changes that.

**The read.** `GmailInboxClient.live(accessToken:).inboxChanges` every 2 minutes, per ADR-0003 D4. First run takes
a baseline only (`currentInbox`, store `historyID`, set the Promotions epoch to now). Advance the cursor only after
every message in the batch is recorded, and ignore `departedMessageIDs`. Take a new baseline on an expired history
cursor and log the gap: check how `GmailInboxAPI` surfaces that today (a 404 on `startHistoryId`), and add the
narrowest public error case it needs. Skip any message the Watched route already handled.

**Gate.** Bulk mail per ADR-0003 D4, and at least one marker in the subject or the text. Start with: "seats",
"reservations open", "reservations are open", "tickets", "on sale", "limited", "sell out", "sold out", "winemaker
dinner", "tasting menu", "pop-up", "allocation", "waitlist", "book now", "RSVP". Keep the markers in one table so
the trial can change them with one small PR. Convert HTML to text with SwiftSoup. A message with almost no text (an
image-only campaign) gates on its subject and is marked `imageOnly` in the ledger. `muted.txt` is one address per
line, and a muted sender is logged and dropped before the model.

**Model.** Use `OnDeviceModelClient` behind the `ModelClient` boundary, with `responseFormat` structured output
(`jon-platform` ADR-0004): `isScarceOffer`, `kind`, `title`, `when`, `deadline`, `evidence`. Validate
deterministically: `evidence` must appear verbatim in the message text (normalize only whitespace and case), or the
verdict is `rejectedEvidence`. Record `modelUnavailable` as its own outcome, not as a "no", and raise a self-report.

**Trial report.** `offerwatch report [--days N]` writes a local Markdown file with:

- each would-alert row: date, sender, subject, kind, title, when, deadline, evidence, the delay from Gmail's
  `internalDate` to the verdict, and a blank `wanted?` column;
- each row the model said no to, with the reason;
- a compact list of bulk mail that failed the gate (sender and subject only), so Jon can spot misses;
- counts per day, and any `modelUnavailable` or cursor gaps.

**Tests** (injected client, clock, model): baseline never reaches the gate; the gate on bulk and non-bulk mail; a
confirmation-shaped message doesn't pass; evidence validation; the cursor holds when a message fails; re-reading
doesn't produce a second row; `modelUnavailable` is recorded and the loop continues; expired cursor re-baselines;
muted senders skip the model (assert zero model calls); `filterAlerts: false` can't send, and `true` sends through the
S-w1 path and counts against the cap.

**Done when.** Tests and lint are green. A live trial is Jon's: name it in the PR as owed.

## Gate — the filter trial

Turn on Apple Intelligence on that Mac and leave the route silent for two weeks, then fill the `wanted?` column. Jon
decides from the report, and records numbers (no mail text) in `docs/eval-log.md`. Proposed bar, which Jon can change:

- at least 2 weeks of real mail, with the loop up throughout apart from named gaps;
- at least 4 of every 5 would-alert rows are ones Jon would have wanted;
- no more than about 2 unwanted rows a week;
- any offer Jon knows he missed is explained, and fixed by a marker or by Watching the sender where it can be;
- the delay from `internalDate` to verdict is within about 5 minutes at the 95th percentile.

If it passes, Jon sets `filterAlerts` to `true`. Marker changes during the trial are small PRs. If the on-device
model can't reach the bar, the filter stays off, Watched senders remain the feature, and ADR-0003's "What would
reverse this" applies. Don't widen scope inside this effort.

The trial also checks whether real offers are arriving in Gmail tabs this route doesn't read. If they are, that's a
plan change, or a reason to Watch that sender.

## S-w3 — Restaurants' own sites (closed until the filter trial passes)

Add the third route, off by default (`"siteAlerts": false`). Follow ADR-0003 D5.

- **The list.** `sites.txt` beside `watched.txt`: one HTTPS URL per line, with a comment recording when its terms and
  `robots.txt` were read. Parse it strictly.
- **Refusals in code.** A fixed table of booking platforms (ADR-0003 D7) is refused on the list and when a redirect
  lands there. A site whose `robots.txt` disallows the page is parked. `robots.txt` is cached for at most 24 hours.
- **Fetching.** `URLSession` with an ephemeral configuration and no cookies. Hourly with jitter, one request at a time,
  with a 30-minute floor enforced in code. Conditional headers, a plain identifying user agent with no personal contact
  details, and a size limit. HTML, RSS, Atom, and ICS only. No subresources.
- **Blocks.** `403`, `429`, or a challenge page backs off exponentially. Three days of that parks the page and sends a
  self-report. No retry from another identity, and no bypass of any kind.
- **Change detection.** Extract main text with SwiftSoup into normalized blocks. The first fetch stores hashes only. Later
  fetches send only new blocks to the model, with the D4 structured output and evidence check. Feed entries use their
  entry IDs. Pages with no usable text are parked as unsupported.
- **Alerts.** Same path, cap, and ledger, keyed by page and block hash. The tap opens the listed URL. Add this to the app
  model, and validate that it's HTTPS.
- **Report.** Add site rows to the trial report, with a count of pages changed against rows that reached a verdict.

**Tests** (injected transport and clock; no network): refused hosts, on the list and via redirect; the `robots.txt`
disallow path; the 30-minute floor; `304` makes no model call; first fetch doesn't alert; a re-ordered page with no new text
makes no model call; `429` backs off and parks; no cookie is ever stored; `siteAlerts: false` can't send.

**Done when.** Tests and lint are green. A live trial is Jon's: two weeks silent against the same bar, then he sets
`siteAlerts` to `true`, or ADR-0003's reversal applies and the route stays off.

## Out of scope

Reply, archive, or any Gmail write. Writing to Cockpit's database. Personal Knowledge as an input. Other notification kinds.
Booking links, or any link from content, in a payload. Finds. A frontier model call. A Mac UI, a listener, or any remote control
of the watcher. `users.watch`. Rendered browsing or JavaScript pages. Sign-in to any site.
