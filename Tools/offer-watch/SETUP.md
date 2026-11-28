# Offer Watch setup (S-w1)

Offer Watch is a read-only process running in Jon's login session. It has no listener. Build the
`OfferWatch` executable in Release with
`~/code/jon-platform/scripts/quiet-run swift build -c release --package-path CockpitCore --product OfferWatch`,
then copy `CockpitCore/.build/release/OfferWatch` to a stable local path. Copy the plist template to
`~/Library/LaunchAgents/com.jonphillips.offerwatch.plist` and replace its uppercase placeholders.
The binary and OAuth client JSON must be readable by Jon only; the refresh token and APNs key are
stored in the login keychain.

1. In the Google Cloud project, use a Desktop OAuth client published to Production and enable
   `gmail.readonly`.
2. Run `offerwatch auth --client <secret.json>` once in Terminal and complete Google sign-in.
3. Run `offerwatch apns-key <key.p8>`. Put the APNs Key ID and Apple Team ID in the LaunchAgent's
   environment values.
4. Run `offerwatch pair <device-name> <device-token> <production|sandbox>` for each Cockpit device.
   `offerwatch pairs` lists pair names and environments only.
5. Create `~/Library/Mobile Documents/com~apple~CloudDocs/Offer Watch/watched.txt`, one sender address
   per line. Access to that folder from a LaunchAgent and whether macOS requires a privacy grant
   are unverified until the live run. Resolve any macOS access prompt based on the observed request.
   The watcher mirrors readable contents to
   `~/Library/Application Support/OfferWatch/watched.txt`; if iCloud Drive cannot be read, it uses
   the last-good local copy and sends a status report. Full Disk Access has not been tested.
6. Load it with `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.jonphillips.offerwatch.plist`.
   Inspect `~/Library/Logs/OfferWatch.error.log`; stop it with `launchctl bootout gui/$(id -u)/com.jonphillips.offerwatch`.
   After fixing a terminal error, restart it with `launchctl kickstart gui/$(id -u)/com.jonphillips.offerwatch`.

Choose one restart posture: keep FileVault on and unlock the Mac manually after a restart, or turn
FileVault off and enable automatic login. Rebuilding the executable changes its ad-hoc signature;
macOS may ask to allow the new binary to access its login-keychain items again; choose Always Allow
for the Offer Watch keychain items if prompted. After a restart, the
LaunchAgent starts when Jon logs in. The watcher searches watched addresses every two minutes, validates the exact
From address and DKIM/SPF authentication result, then sends the subject as a short time-sensitive
alert. It stores message IDs and outcomes locally for 90 days. A send immediately before a crash can
repeat after restart. No mail body is sent in the push payload.
