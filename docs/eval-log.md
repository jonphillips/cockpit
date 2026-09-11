# Evaluation log

2026-09-11 — D7 Gmail authorization probe reached test-mode setup in Google Cloud: the POC project has an iOS client for Cockpit, `gmail.modify`, and `jon@jonphillips.com` as its test user. The native probe completed authorization on iPad. GoogleSignIn retains the authorization in the device Keychain; no mail was read or changed.

2026-09-11 — The native probe now has a distinct non-interactive stored-authorization check: it calls `restorePreviousSignIn`, then `refreshTokensIfNeeded`, and reports the local Google error without beginning sign-in. This is the D7 day-8 check for the iOS client’s Keychain-managed authorization.

2026-09-11 — Production-unverified publishing and the resulting day-8 check remain pending. The app is still in Testing, where refresh tokens expire after seven days, so this authorization cannot answer D7’s production personal-use question.

2026-09-11 — D7 Gmail OAuth client published to Production, unverified, under the personal-use exemption. The prior Testing-mode grant was revoked at myaccount.google.com/permissions and authorization was re-run on iPad afterwards, so the refresh token now held in the device Keychain is production-issued. This matters: a Testing-issued token carries its own seven-day expiry that publishing does not retroactively lift, and reusing it would have produced a day-8 failure attributable to Testing rather than to the production personal-use question.

2026-09-11 — D7 day-8 check is therefore due 2026-09-19, measured from the production re-authorization above, not from the publish. Procedure: leave Cockpit closed until then so the access token is certainly expired and `refreshTokensIfNeeded` genuinely exercises the refresh token, then open the Gmail probe and run the non-interactive stored-authorization check. A green result answers D7 yes and Phase 3 proceeds on `gmail.modify`. A failure answers D7 no and triggers the ADR-0001 fallback: evaluate IMAP with an app password before building Today, verifying app-password availability at that point.
