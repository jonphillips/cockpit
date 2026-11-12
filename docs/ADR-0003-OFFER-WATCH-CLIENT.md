# ADR-0003 — Offer watch: a read-and-notify client on Jon's own Mac

**Status:** Accepted when Jon merges its plan PR (jon-platform ADR-0005 D9)
**Date:** 2026-11-04
**Ledger:** [DECISIONS §34](DECISIONS.md)
**Build:** [efforts/offer-watch.md](efforts/offer-watch.md)

---

## Context

Cockpit reads mail only when it's open. An offer that can sell out, such as a winemaker dinner or a
reservation release, can be gone before Jon next opens the app. iOS can't close that gap on its own:
`BGProcessingTask` is opportunistic (ADR-0001 D1), and timing is exactly what this feature needs.

Jon has an Apple Silicon Mac mini arriving in about two weeks. It can run all the time, in his house,
under his account. The question is whether using it this way breaks ADR-0001 D1 ("No server, no worker,
no hosted ingest") and DECISIONS §13.

Jon's framing, 2026-11-04: "It's essentially another client with the power to read and notify. Sounds
like an email client to me." This ADR adopts that framing and writes down what keeps it true.

The same day, Jon added two sources: particular senders that should always get through, and polling of
event pages. He ruled out automated reservations. Reading the booking platforms' terms then ruled out
polling their pages too (D7).

**Three routes lead to one alert path, built in this order:**

1. **Watched senders** (D3): no filter and no model. Useful from the first day.
2. **Model filter on other bulk mail** (D4): silent until a trial passes.
3. **Restaurants' own sites** (D5): silent until a trial passes.

---

## D1 — The watcher is a client, not a server.

ADR-0001 rejected a VPS because a third-party server could turn the personal-use exemption into an
annual security assessment, and because of its local-first and credential-custody costs. The Mini
differs on the first count: it's Jon's hardware and only Jon's mailbox. It behaves like a mail app and
feed reader left running on a desk.

**These conditions make it a client. Each one is an invariant, not a preference:**

1. It runs on hardware Jon owns and physically controls. A rented or hosted Mac doesn't qualify.
2. It reads one mailbox, Jon's, plus public pages he lists. It has no other users and no accounts of its
   own.
3. It only makes outbound requests. It has no listener, no open port, no public endpoint, and no web UI.
4. It signs in through an OAuth **Desktop** client and keeps its token in that Mac's keychain.
5. Mail-derived data stays on that Mac, apart from the alert in D6.
6. The developer side has no access, because there's no developer-side system.

Breaking any of these reopens ADR-0001's "Why not a server" in full. It also needs a new decision, not
a code review.

**What Google's text says (read 2026-11-04).** Google's
[restricted-scope verification page](https://developers.google.com/identity/protocols/oauth2/production-readiness/restricted-scope-verification)
ties the assessment to data accessed through a third-party server. One passage on the same page omits
"third-party" and refers to a server generally, so this ADR doesn't rest on that one word. It rests on
two independent grounds:

- **Sole user.** The page says verification isn't needed when you're the only user of your app. That's
  the exemption Cockpit's client already uses (ADR-0001 D7), and adding a second client for the same
  single user doesn't change it.
- **No server role.** Under the conditions above, the watcher serves nobody. It's an installed client
  that happens to stay on.

This is the project's reading of Google's published text, not a ruling from Google. If the app ever
gains a second user, both grounds need a fresh look.

ADR-0001's other two objections are answered by D2 (no server-authored state in the sync channel) and
by D8 (custody and monitoring stay small, and are accepted).

## D2 — Its powers are read and notify. Nothing else.

- **Mail scope is `gmail.readonly`.** It can't archive, trash, label, mark read, or send. Provider
  disposition stays with Cockpit under ADR-0002.
- **Web access is a plain anonymous GET** of a listed page (D5). No login, no cookies, no forms, and no
  script execution.
- **It never writes Cockpit's database or CloudKit.** It creates no Artifact, ContentPiece, Find, or
  Edition row, and it isn't an ingester in the ADR-0001 D2 sense. Cockpit behaves the same with the Mini
  switched off.
- **It changes no attention state.** An alert doesn't suppress, rank, or reorder anything on Today, so
  ADR-0002 D11 ("organized, never judged") still holds. Its judgment answers one question, "should this
  interrupt Jon?", and the result lives only in its own ledger.
- **It reads no Personal Knowledge.** This ADR and §34 are the explicit mandate for one notification
  feature (DECISIONS: "Knowledge does not grant agency"). Other notification kinds need their own.
- **The model has no tools.** Mail and web text are untrusted. On-device output can only become one
  structured verdict and one alert line, and it can't act.

**Name collisions.** `EmailTreatment.offer` is a presentation tag on retail-shaped mail, and an alert is a
separate thing. "Watched" is deliberately not "Listed", which is a Stream posture (§33).

## D3 — Watched senders always get through.

A plain list of sender addresses. Mail from one of them alerts with no scarcity gate and no model call,
including mail that isn't an offer, because that's what listing a sender means. The subject line becomes
the alert text.

- **Read by search, not by the delta.** Each poll runs `messages.list` with a `from:` query for the list
  and an `after:` time, then `messages.get` for anything new. That finds Watched mail in any tab, and mail
  that a Gmail filter skipped the Inbox with. It costs about 5 quota units per idle poll, plus 20 per new
  message. It needs no history cursor.
- **Exact match after fetch.** Gmail's `from:` search is loose, so code compares the actual address before
  alerting. An entry is one address, with no patterns and no conditions.
- **Authenticated mail only.** The message must show a DKIM or SPF pass in `Authentication-Results`.
  Otherwise it's logged, so a forged From can't interrupt Jon.
- **Adding a sender never fires old mail.** Each entry only counts for mail newer than when the watcher
  first saw that entry.
- **The list lives in iCloud Drive**, as plain text Jon can edit in Files on his iPad. The watcher reads it
  and keeps a last-good copy, and an unreadable list keeps the old one and raises a D8 report. This needs
  the Mini signed in to iCloud Drive. A background process reading iCloud Drive is untested here, and if
  macOS blocks it, the list falls back to a local file edited on the Mac itself.
- **Not a rules engine (AGENTS.md).** The list holds addresses and nothing else, and it changes only when
  Jon edits it.

Platform alerts are mail too. Resy's Notify emails and similar messages can be Watched like any sender (D7).

## D4 — Other bulk mail goes through a filter, and no mail leaves the Mac for judgment.

**Read.** Every 2 minutes it calls the public `GmailInboxClient.live(accessToken:)` and its `inboxChanges`
closure, the same Primary plus Promotions read Cockpit uses (ADR-0002 D2, DECISIONS §27). That's about 13
quota units per idle poll, plus 20 per new message, against a ceiling of 6,000 per minute. The cursor and
Promotions epoch live on the Mini and advance only after every message in the batch is recorded. First run
takes a baseline only. An expired cursor takes a new baseline and logs the gap. Pub/Sub (`users.watch`)
would add a Google Cloud subscription to save a delay of up to two minutes, so polling stays.

**Tier 1: deterministic gate.** Bulk mail only (`List-Unsubscribe`, `List-ID`, or `Precedence: bulk`),
with scarcity or booking language in the subject or text. `EmailTreatmentClassifier` is not reused: its
offer markers are retail words ("sale", "discount"), so "reservations open" wouldn't match, and it needs
Artifact state the watcher doesn't have. Senders on the **Muted** list stop here.

**Tier 2: on-device model.** Survivors go to `OnDeviceModelClient` in `LLMClientKit`, which costs nothing
per message. It returns structured output: is this time-limited and able to sell out, what is it, when is
it, what's the deadline, and a verbatim evidence quote. Code then checks that the quote really appears in
the message, and drops the verdict if it doesn't.

- **No frontier call.** The Mini holds no model API key, so mail-derived text has no route to a model
  provider. Adding one needs an amendment backed by trial evidence.
- **Model unavailable.** Recorded as its own outcome, never as a "no", and raised as a D8 report. Watched
  senders are unaffected.
- **Silent until proven.** This route logs would-alert rows and notifies nobody until the
  [trial](efforts/offer-watch.md) passes and Jon turns it on.

## D5 — Restaurants' own sites are polled, politely, from a list.

A list of pages Jon chooses, in the same iCloud Drive folder. A page gets on the list only after its terms
and `robots.txt` have been read and don't forbid this. A site that forbids it isn't added.

- **Prefer a feed.** RSS, Atom, or a calendar feed needs no change detection, so use one where the site has
  one.
- **Cadence.** Hourly with jitter, one request at a time, with `If-None-Match` and `If-Modified-Since`. Code
  enforces a floor of 30 minutes. At about 24 requests per page per day, this is negligible for the Mini and
  for the site.
- **Honest and easy to stop.** A plain identifying user agent and `robots.txt` obeyed on every fetch. Any
  `403`, `429`, or challenge page backs off, and repeats park the page with a D8 report. It never works
  around a block: no proxies, no browser fingerprints, no CAPTCHA handling.
- **The page's own HTML only.** It doesn't load subresources, iframes, or scripts, so availability inside an
  embedded booking widget is never read. Pages that need JavaScript to show their content aren't supported,
  and adding that would need rendered browsing and a plan change (`WebExtractorKit` stays deferred).
- **What counts as news.** First fetch takes a baseline. Later fetches compare normalized text blocks, and
  only new blocks go to the on-device model with the same question and evidence check as D4.
- **Silent until proven.** The same trial approach applies, because page noise is a different problem from
  mail noise.

## D6 — It notifies through APNs directly.

The watcher sends an HTTP/2 POST to Apple's push service, signed with a JWT from a `.p8` key held in the
Mini's keychain. It needs no provisioning profile.

- **Payload.** Title is the sender or site name. Body is one short line, under Apple's alert limits, with
  URLs stripped. A custom key identifies the source. No email body text and no links from content.
- **Interruption.** `time-sensitive`, so an allowed alert can break through Focus. Quiet hours are left to
  Jon's Focus settings. Cockpit needs Apple's Time Sensitive Notifications capability.
- **Tap, for mail.** Opens that message in Cockpit, found by `GmailArtifactProvenance.messageID`, syncing
  first if needed. The ordinary read rule (§28) applies. Mail outside Cockpit's read, such as Updates, shows
  a plain state with a way to open it in Gmail.
- **Tap, for a site.** Opens the page **from Jon's list**, never a link found on the page.
- **Pairing.** Cockpit's Settings shows each device's push token, and Jon pastes it into the Mini's config.
  Tokens rarely change. APNs reports a dead token (`410`), and the watcher then tells Jon through the other
  paired device.
- **A cap.** At most 5 interrupting alerts a day across all routes, then further ones arrive `passive`.
  Cockpit stays calm even if a listed sender or a filter misbehaves.

Apple's servers carry this text, as they already do for Cockpit's CloudKit sync, so the payload stays
minimal and the privacy page says so. That's the one exception to D1's condition 5.

**Rejected.** *CloudKit subscription:* no token handling, but it needs a signed Mac app with the iCloud
entitlement, and `CKSubscription.NotificationInfo` has no interruption level, so time-sensitive would need
a notification service extension as well. *Pushover or ntfy:* quickest to build, but they put mail-derived
text on another company's servers, which is what ADR-0001 was avoiding.

## D7 — Booking platforms are out, permanently. Their own alerts are in.

This is a boundary, not a deferral.

- **No automated booking,** by Jon's decision.
- **No polling of booking platforms' pages.** The watcher refuses `resy.com`, `opentable.com`,
  `exploretock.com`, and `sevenrooms.com`, on the list and through redirects. Not booking doesn't make it
  acceptable: OpenTable's terms bar automated means used to access, search, or monitor its service without
  express authorization, and Resy's terms (June 9, 2025) bar crawling its pages and scraping its content. Both
  reserve cancelling reservations and closing accounts, so the realistic cost is Jon's own accounts. Terms
  were read 2026-11-04. Tock's and SevenRooms' weren't read in full, and they're refused as the conservative
  default.
- **No third-party page monitors** pointed at those platforms. That's the same act through someone else.
- **Use what they offer.** Resy Notify alerts by email and by push through Resy's app, and Tock and OpenTable
  have equivalents. Those emails arrive as ordinary mail and can be Watched (D3). Resy's own push may well be
  faster, in which case it's the better channel and the watcher is a backstop.

Reconsider only if a platform offers authorized access for this use.

## D8 — It runs as a logged-in LaunchAgent, and its failure modes are named.

The keychain and on-device model need a user session, so it runs as a LaunchAgent under Jon's login. After
a power cut it needs that session back. FileVault blocks automatic login, so Jon chooses during setup:
FileVault on with a manual unlock after restarts, or automatic login with FileVault off.

- **What it can report itself.** A dead Gmail grant, an unavailable model, a rejected push token, an
  unreadable list, or a parked page each send an alert. These alerts have their own daily limit and don't
  count against D6's cap.
- **Heartbeat.** One `passive` notification a day, with a fixed collapse ID so it replaces itself: "Offer
  watch: checked 8:02, 41 screened, 0 alerts."
- **Accepted gap.** If the Mini dies outright, nothing can say so. A stale heartbeat shows it only when Jon
  looks. Closing that gap needs an outside party, which this ADR declines for now.

## D9 — It lives in `CockpitCore`, not jon-platform.

An `OfferWatch` executable and an `OfferWatchSupport` library join the package, following
`JudgmentFixtureHarvest` and `JudgmentFixtureSupport`. It's one use, so there's no shared kit (AGENTS.md §
jon-platform rule). The Desktop sign-in in `GmailFixtureToken` moves into a small library that both
executables use. The iOS app doesn't link any of the watcher.

---

## Alternatives considered

- **A full Cockpit peer on the Mac (same app, same sync).** Most literally "another client", and it would see
  Jon's overrides and sender lists. Rejected for now: it adds a third syncing writer and an unattended device
  that has to keep up with every schema migration, all to send a notification. Reconsider if the watcher
  turns out to need Cockpit's data.
- **Cockpit background refresh only.** Free and already allowed, but iOS decides when it runs, so it can't
  promise timing.
- **A hosted or rented Mac.** Fails D1's first condition.
- **Model filter first, Watched senders later.** The original order. A Watched sender has no filter to prove,
  so waiting on a trial would delay the part that's useful immediately.

## Consequences

- ADR-0001 D1's "No server" stands. Its "on device" now includes Jon's own always-on Mac for this one
  read-and-notify job, and for nothing else in the Cockpit pipeline.
- Jon takes on a small piece of custody: a Gmail refresh token and an APNs key on one Mac. The refresh token
  dies on the usual revocations (ADR-0001 D7), and D8 reports that.
- `docs/legal/privacy.html` changes when alerts ship, not before.
- Timing remains outside Cockpit's control. An email can arrive too late for the hottest releases, and
  hourly page checks won't catch something that sells out in minutes.

## What would reverse this

- The filter trial can't reach its bar with on-device judgment. Then Watched senders remain the feature, and
  a frontier call on survivors needs an amendment.
- The site trial can't get page noise down. Then drop D5 and keep the rest.
- A second user or hosted hardware (D1).
- Alerts Jon stops acting on. The Mini should be turned off and the feature retired rather than tuned forever.
