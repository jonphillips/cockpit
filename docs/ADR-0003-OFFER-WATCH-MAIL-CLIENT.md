# ADR-0003 — Offer watch: a read-and-notify mail client on Jon's own Mac

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
under his account. The question is whether polling Gmail from it breaks ADR-0001 D1 ("No server, no
worker, no hosted ingest") and DECISIONS §13.

Jon's framing, 2026-11-04: "It's essentially another client with the power to read and notify. Sounds
like an email client to me." This ADR adopts that framing and writes down what keeps it true.

---

## D1 — The watcher is a mail client, not a server.

ADR-0001 rejected a VPS because a third-party server could turn the personal-use exemption into an
annual security assessment, and because of its local-first and credential-custody costs. The Mini
differs on the first count: it's Jon's hardware and only Jon's mailbox. It behaves like Apple Mail
left running on a desk.

**These conditions make it a client. Each one is an invariant, not a preference:**

1. It runs on hardware Jon owns and physically controls. A rented or hosted Mac doesn't qualify.
2. It reads one mailbox, Jon's. It has no other users and no accounts of its own.
3. It only makes outbound requests. It has no listener, no open port, no public endpoint, and no web UI.
4. It signs in through an OAuth **Desktop** client and keeps its token in that Mac's keychain.
5. Mail-derived data stays on that Mac, apart from the alert in D5.
6. The developer side has no access, because there's no developer-side system.

Breaking any of these reopens ADR-0001's "Why not a server" in full. It also needs a new decision, not
a code review.

**What Google's text says (read 2026-11-04).** Google's
[restricted-scope verification page](https://developers.google.com/identity/protocols/oauth2/production-readiness/restricted-scope-verification)
ties the assessment to data accessed "from or through a third-party server". One passage on the same
page drops "third-party" and says "from or through a server", so this ADR doesn't rest on that one
word. It rests on two independent grounds:

- **Sole user.** The page says verification isn't needed when you are the only user of your app. That's
  the exemption Cockpit's client already uses (ADR-0001 D7), and adding a second client for the same
  single user doesn't change it.
- **No server role.** Under the conditions above, the watcher serves nobody. It's an installed client
  that happens to stay on.

This is the project's reading of Google's published text, not a ruling from Google. If the app ever
gains a second user, both grounds need a fresh look.

ADR-0001's other two objections are answered by D2 (no server-authored state in the sync channel) and
by D6 (custody and monitoring stay small, and are accepted).

## D2 — Its powers are read and notify. Nothing else.

- **Scope is `gmail.readonly`.** It can't archive, trash, label, mark read, or send. Provider
  disposition stays with Cockpit under ADR-0002.
- **It never writes Cockpit's database or CloudKit.** It creates no Artifact, ContentPiece, Find, or
  Edition row, and it isn't an ingester in the ADR-0001 D2 sense. Cockpit behaves the same with the Mini
  switched off.
- **It changes no attention state.** An alert doesn't suppress, rank, or reorder anything on Today, so
  ADR-0002 D11 ("organized, never judged") still holds. Its judgment answers one question, "should this
  interrupt Jon?", and the result lives only in its own ledger.
- **It reads no Personal Knowledge.** This ADR and §34 are the explicit mandate for one kind of
  notification (DECISIONS: "Knowledge does not grant agency"). Other notification kinds need their own.

**Name collision.** `EmailTreatment.offer` is a presentation tag on retail-shaped mail. An offer-watch
alert is a separate thing, and neither one implies the other.

## D3 — It reads by polling the existing delta.

Every 2 minutes it calls the public `GmailInboxClient.live(accessToken:)` and its `inboxChanges`
closure. That's the same Primary plus Promotions read Cockpit uses (ADR-0002 D2, DECISIONS §27).

- **Cost.** About 13 quota units per idle poll (profile, `history.list`, two `messages.list`), plus 20
  per new message, against a ceiling of 6,000 per minute. No pre-check is worth adding.
- **Why not `users.watch`.** Pub/Sub would add a Google Cloud subscription and a moving part to save a
  delay of up to two minutes. Polling stays until a measured delay proves it costs Jon something.
- **Its own cursor.** The cursor, Promotions epoch, and ledger live on the Mini. The cursor advances
  only after every message in the batch is recorded, mirroring ADR-0002 D2.
- **First run never alerts.** It takes a baseline only, so old mail can't fire. If Gmail rejects an
  expired cursor, it takes a new baseline and logs the gap.

Mail in Updates or Forums is out of the read if Jon's account has those tabs on. The trial checks
whether that hides real offers.

## D4 — It filters in two tiers, and no mail leaves the Mac for judgment.

**Tier 1: deterministic gate.** Bulk mail only (`List-Unsubscribe`, `List-ID`, or `Precedence: bulk`),
with scarcity or booking language in the subject or text. The Mini checks this before any model call.
`EmailTreatmentClassifier` is not reused: its offer markers are retail words ("sale", "discount"), so
"reservations open" wouldn't match, and it needs Artifact state the watcher doesn't have.

**Tier 2: on-device model.** Survivors go to `OnDeviceModelClient` in `LLMClientKit`, which costs
nothing per message. It returns structured output: is this time-limited and able to sell out, what is
it, when is it, what's the deadline, and a verbatim evidence quote. Deterministic code then checks that
the quote really appears in the message, and drops the verdict if it doesn't.

- **No frontier call in this ADR.** The Mini holds no model API key, so mail-derived text has no route
  to a model provider. Adding one needs an amendment backed by trial evidence.
- **Model unavailable.** Survivors from a Watched sender (below) alert unscreened and say so. Others
  are logged. A broken model must not look like a quiet week.
- **Not a rules engine (AGENTS.md).** There are fixed markers in code and two plain lists on the Mini,
  **Watched** and **Muted** senders. There are no user-written conditions and no learning. A sender
  changes lists only when Jon edits a list.

The filter has to earn its alerts. Nothing notifies until the silent trial passes
([the brief's gate](efforts/offer-watch.md)).

## D5 — It notifies through APNs directly.

The watcher sends an HTTP/2 POST to Apple's push service, signed with a JWT from a `.p8` key held in the
Mini's keychain. It needs no provisioning profile, and no iCloud sign-in for notifying.

- **Payload.** Title is the sender's display name. Body is one short line from the model or subject,
  under Apple's alert limits. Custom key is the Gmail message ID. No body text, no booking links.
- **Interruption.** `time-sensitive`, so an allowed alert can break through Focus. Quiet hours are left
  to Jon's Focus settings. Cockpit needs Apple's Time Sensitive Notifications capability.
- **Tap.** Opens that message in Cockpit, not a link from the email. Cockpit finds it by
  `GmailArtifactProvenance.messageID`, syncing first if needed. The ordinary read rule (§28) applies.
- **Pairing.** Cockpit's Settings shows each device's push token, and Jon pastes it into the Mini's
  config. Tokens rarely change. APNs reports a dead token (`410`), and the watcher then tells Jon
  through the other paired device.
- **A cap.** At most 5 interrupting alerts a day, then further ones arrive `passive`. Cockpit stays
  calm even if the filter misbehaves.

Apple's servers carry this text, as they already do for Cockpit's CloudKit sync, so the payload stays
minimal and the privacy page says so. That's the one exception to D1's condition 5.

**Rejected.** *CloudKit subscription:* no token handling, but it needs a signed Mac app with the iCloud
entitlement, and `CKSubscription.NotificationInfo` has no interruption level, so time-sensitive would
need a notification service extension as well. *Pushover or ntfy:* quickest to build, but they put
mail-derived text on another company's servers, which is what ADR-0001 was avoiding.

## D6 — It runs as a logged-in LaunchAgent, and its failure modes are named.

The keychain and on-device model need a user session, so it runs as a LaunchAgent under Jon's login.
After a power cut it needs that session back. FileVault blocks automatic login, so Jon chooses during
setup: FileVault on with a manual unlock after restarts, or automatic login with FileVault off.

- **What it can report itself.** A dead Gmail grant, an unavailable model, or a rejected push token each
  send an alert. These alerts have their own daily limit and don't count against D5's cap.
- **Heartbeat.** One `passive` notification a day, with a fixed collapse ID so it replaces itself:
  "Offer watch: checked 8:02, 41 screened, 0 alerts."
- **Accepted gap.** If the Mini dies outright, nothing can say so. A stale heartbeat shows it only when
  Jon looks. Closing that gap needs an outside party, which this ADR declines for now.

## D7 — It lives in `CockpitCore`, not jon-platform.

An `OfferWatch` executable and an `OfferWatchSupport` library join the package, following
`JudgmentFixtureHarvest` and `JudgmentFixtureSupport`. It's one use, so there's no shared kit (AGENTS.md
§ jon-platform rule). The Desktop sign-in in `GmailFixtureToken` moves into a small library that both
executables use. The iOS app doesn't link any of it.

---

## Alternatives considered

- **A full Cockpit peer on the Mac (same app, same sync).** Most literally "another client", and it
  would see Jon's overrides and sender lists. Rejected for now: it adds a third syncing writer and an
  unattended device that has to keep up with every schema migration, all to send a notification.
  Reconsider if the watcher turns out to need Cockpit's data.
- **Cockpit background refresh only.** Free and already allowed, but iOS decides when it runs, so it
  can't promise timing.
- **A hosted or rented Mac.** Fails D1's first condition.

## Consequences

- ADR-0001 D1's "No server" stands. Its "on device" now includes Jon's own always-on Mac for this one
  read-and-notify job, and for nothing else in the Cockpit pipeline.
- Jon takes on a small piece of custody: a Gmail refresh token and an APNs key on one Mac. The refresh
  token dies on the usual revocations (ADR-0001 D7), and D6 reports that.
- `docs/legal/privacy.html` changes when alerts ship, not before.
- Email timing remains outside Cockpit's control. For the hottest releases, the email itself can arrive
  too late, and this design can't fix that.

## What would reverse this

- The trial can't reach its bar with on-device judgment. Then choose between sender-only alerts, an
  amendment allowing a frontier call on survivors, or dropping the feature.
- A second user or hosted hardware (D1).
- Alerts Jon stops acting on. The Mini should be turned off and the feature retired rather than tuned
  forever.
