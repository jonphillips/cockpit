# Effort — Offer watch

Status: Ready
Summary: A read-only mail client on Jon's Mac polls Gmail, judges possible sell-out offers on device, and pushes them to his iPad and iPhone, after a silent trial proves the filter.

Implements: [ADR-0003](../ADR-0003-OFFER-WATCH-MAIL-CLIENT.md) and [DECISIONS.md](../DECISIONS.md) §34. Read
ADR-0003 first; its D1 and D2 invariants bind every slice. There's no change to Cockpit's persisted
schema or CloudKit in either slice. If a slice seems to need one, stop and raise a
`question-for-architect`.

Two slices with a gate between them. **S-w1 is dispatchable now and can run on any Mac**, so the trial
doesn't have to wait for the Mini. **S-w2 stays closed until Jon passes the gate.** The PR that completes
S-w1 trims this brief to the remainder and sets `Status: Blocked` on the trial gate. The architect
adds the gate to `device-passes.md` in review.

## S-w1 — The watcher, silent

No push and no app change. Everything lands in `CockpitCore`, plus `tools/offer-watch/`.

**Package.** Add an `OfferWatch` executable and an `OfferWatchSupport` library, with tests in
`CockpitCoreTests`, following `JudgmentFixtureHarvest`/`JudgmentFixtureSupport`. Move the Desktop OAuth
flow out of `GmailFixtureToken` into a small library both executables use. `GmailFixtureToken` keeps its
behavior and its stdout contract.

**Commands.**

- `offerwatch auth --client <secret.json>`: Desktop sign-in with `gmail.readonly`, refresh token in the
  login keychain.
- `offerwatch run`: the loop. It's the only thing the LaunchAgent starts.
- `offerwatch report [--days N]`: writes the trial report (below).

**The loop.**

1. Every 2 minutes, mint an access token and call `GmailInboxClient.live(accessToken:).inboxChanges`.
2. First run: baseline only (`currentInbox`, store `historyID`, set the Promotions epoch to now). No
   message from the baseline reaches the gate or the model.
3. Each changed message goes through the gate, then the model, then the ledger. Advance the cursor only
   after every message in the batch is recorded. Ignore `departedMessageIDs`.
4. Handle an expired history cursor by taking a new baseline and logging the gap. Check how
   `GmailInboxAPI` surfaces that today (a 404 on `startHistoryId`), and add the narrowest public error
   case it needs. `accountChanged` stops the loop and logs. Transient failures back off and retry.

**Gate (tier 1).** Bulk mail per ADR-0003 D4, and at least one marker in the subject or the text. Start
with: "seats", "reservations open", "reservations are open", "tickets", "on sale", "limited",
"sell out", "sold out", "winemaker dinner", "tasting menu", "pop-up", "allocation", "waitlist",
"book now", "RSVP". Keep the markers in one table so the trial can change them with one small PR.
Convert HTML to text with SwiftSoup. A message with almost no text (an image-only campaign) gates on
its subject and is marked `imageOnly` in the ledger.

**Model (tier 2).** Use `OnDeviceModelClient` behind the `ModelClient` boundary, with `responseFormat`
structured output (`jon-platform` ADR-0004): `isScarceOffer`, `kind`, `title`, `when`, `deadline`,
`evidence`. Validate deterministically: `evidence` must appear verbatim in the message text (normalize
only whitespace and case), or the verdict is `rejectedEvidence`. Record `modelUnavailable` as its own
outcome, not as a "no".

**Lists.** `watched.txt` and `muted.txt`, one sender address per line. Muted is dropped before the model
and logged. Watched has no effect in this slice except marking report rows; S-w2's fallback uses it.

**State.** All of it lives under `~/Library/Application Support/OfferWatch/`: cursor, epoch, lists, and a
ledger keyed by Gmail message ID (JSON or a small SQLite file, whichever is simpler; no SQLiteData, and
it's not a Cockpit table). Keep ledger rows for 90 days. Never commit real mail, and any fixture is
synthetic.

**Trial report.** A local Markdown file with:

- each would-alert row: date, sender, subject, kind, title, when, deadline, evidence, the delay from
  Gmail's `internalDate` to the verdict, and a blank `wanted?` column;
- each row the model said no to, with the reason;
- a compact list of bulk mail that failed the gate (sender and subject only), so Jon can spot misses;
- counts per day, and any `modelUnavailable` or cursor gaps.

**Running it.** `tools/offer-watch/` holds a LaunchAgent plist template and a short `SETUP.md`: build in
release, install, `auth`, load the agent, read logs, and the FileVault choice in ADR-0003 D6. The process
opens no listener (ADR-0003 D1).

**Tests** (injected client, clock, model, no network): baseline never alerts; the gate on bulk and
non-bulk mail; a confirmation-shaped message doesn't pass; evidence validation; the cursor holds when a
message fails; re-reading a message doesn't produce a second row; `modelUnavailable` is recorded and the
loop continues; expired cursor re-baselines; muted senders skip the model (assert zero model calls).

**Done when.** Package tests and lint are green per `docs/verification.md`. The iOS unsigned build still
passes with no app changes. Nothing in the iOS app links the new targets. A live run is Jon's: name it
in the PR as unverified.

### Jon's part

- Confirm the Desktop OAuth client is in the Google project already **published to Production**
  (ADR-0001 D7). A client in Testing loses its token after seven days and would quietly end the trial.
  Add `gmail.readonly` to the consent screen if it isn't there.
- Install it (`SETUP.md`), on the current Mac now or the Mini when it arrives. Turn Apple Intelligence on
  for that Mac.
- Keep it running for two weeks, then fill the `wanted?` column.

## Gate — the trial

Jon decides from the report, and records numbers (no mail text) in `docs/eval-log.md`. Proposed bar, which
Jon can change:

- at least 2 weeks of real mail, with the loop up throughout apart from named gaps;
- at least 4 of every 5 would-alert rows are ones Jon would have wanted;
- no more than about 2 unwanted rows a week;
- any offer Jon knows he missed is explained, and fixed by a marker or a list where it can be;
- the delay from `internalDate` to verdict is within about 5 minutes at the 95th percentile.

Marker changes during the trial are small PRs. If the on-device model can't reach the bar, stop and go
to "What would reverse this" in ADR-0003. Don't widen scope inside this effort.

## S-w2 — Notify (closed until the gate passes)

**Watcher.**

- An APNs sender: HTTP/2 to `api.push.apple.com` or `api.sandbox.push.apple.com` per paired device, a
  JWT signed with CryptoKit (ES256, reused for 20–60 minutes), and the `.p8` key in the keychain via a
  new `offerwatch apns-key` command.
- `offerwatch pair <name> <token> <production|sandbox>` and a `pairs` listing.
- Payload per ADR-0003 D5, with a body fitted to Apple's limit. Custom key `gmailMessageID`.
- The daily cap of 5, then `passive`; the heartbeat; the self-reports (dead Gmail grant, model down, dead
  token). A `410` or `BadDeviceToken` marks that pairing dead and reports through another pairing.
- The model-unavailable fallback for Watched senders (ADR-0003 D4), labeled "unscreened".
- Record the send result in the ledger. A crash between send and record can repeat an alert, and that's
  acceptable.

**App.** The app registers for nothing today, and has no delegate adaptor or notification code, although
`aps-environment` and the `remote-notification` background mode are already set.

- Add `UIApplicationDelegateAdaptor`, `registerForRemoteNotifications`, and a `UNUserNotificationCenter`
  delegate. Keep the logic in a testable `@Observable` model in `CockpitCore`.
- Settings row "Offer alerts": requests notification permission only when Jon taps it, and shows this
  device's token and APNs environment with a copy button. The token is held in memory or
  `UserDefaults`. It's not a table and not synced.
- Add the Time Sensitive capability in `project.yml` (`com.apple.developer.usernotifications.time-sensitive`).
  Follow `docs/ios/drift-control.md`. The App ID change is Jon's.
- Tap: read `gmailMessageID`, find the ContentPiece through `GmailArtifactProvenance.messageID`, and open
  it in the existing reader. If it isn't there, run the existing ingest once and retry. If it's still
  absent, show a plain "Not synced yet" state with Retry. Don't open a URL from the payload.

**Legal.** Update `docs/legal/privacy.html` in this slice, not earlier: Jon's own always-on Mac can read
the mailbox read-only, and a short line derived from an email passes through Apple's push service to reach
his devices. No new recipient beyond Apple.

**Tests.** Payload shape and limits; JWT claims and reuse window; cap into `passive`; collapse ID on the
heartbeat; dead-token handling; the tap model across the found, found-after-ingest, and absent cases;
permission is never requested at launch.

**Done when.** Tests, lint, and the unsigned build are green. Device delivery, Focus break-through, tap
routing, and both APNs environments are named in the PR as owed, and the architect adds them to
`device-passes.md`.

### Jon's part

Create the APNs `.p8` key and turn on the Time Sensitive capability in the developer portal. Pair each
device. Allow Cockpit's time-sensitive notifications in the Focus modes where he wants them.

## Out of scope

Reply, archive, or any Gmail write. Writing to Cockpit's database. Personal Knowledge as an input. Other
notification kinds. Booking links or any link in the payload. Finds. A frontier model call. A Mac UI, a
listener, or any remote control of the watcher. `users.watch`. Updates and Forums tabs, unless the trial
shows real misses there, which comes back as a plan change.
