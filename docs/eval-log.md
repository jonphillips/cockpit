# Evaluation log

2026-09-11 — D7 Gmail authorization probe reached test-mode setup in Google Cloud: the POC project has an iOS client for Cockpit, `gmail.modify`, and `jon@jonphillips.com` as its test user. The native probe completed authorization on iPad. GoogleSignIn retains the authorization in the device Keychain; no mail was read or changed.

2026-09-11 — The native probe now has a distinct non-interactive stored-authorization check: it calls `restorePreviousSignIn`, then `refreshTokensIfNeeded`, and reports the local Google error without beginning sign-in. This is the D7 day-8 check for the iOS client’s Keychain-managed authorization.

2026-09-11 — Production-unverified publishing and the resulting day-8 check remain pending. The app is still in Testing, where refresh tokens expire after seven days, so this authorization cannot answer D7’s production personal-use question.

2026-09-11 — D7 Gmail OAuth client published to Production, unverified, under the personal-use exemption. The prior Testing-mode grant was revoked at myaccount.google.com/permissions and authorization was re-run on iPad afterwards, so the refresh token now held in the device Keychain is production-issued. This matters: a Testing-issued token carries its own seven-day expiry that publishing does not retroactively lift, and reusing it would have produced a day-8 failure attributable to Testing rather than to the production personal-use question.

~~2026-09-11 — D7 day-8 check is therefore due 2026-09-19, measured from the production re-authorization above, not from the publish. Procedure: leave Cockpit closed until then so the access token is certainly expired and `refreshTokensIfNeeded` genuinely exercises the refresh token, then open the Gmail probe and run the non-interactive stored-authorization check. A green result answers D7 yes and Phase 3 proceeds on `gmail.modify`. A failure answers D7 no and triggers the ADR-0001 fallback: evaluate IMAP with an app password before building Today, verifying app-password availability at that point. ~~ **Superseded — see below.**

2026-09-11 — **D7's day-8 check is retired; no waiting period is required.** The seven-day refresh-token expiry is a property of Testing status, not of being unverified. The client was published to Production on 2026-09-11 and re-authorized afterwards, so its refresh token has indefinite lifetime, subject only to ordinary revocation: user revocation, roughly six months of inactivity, a password change, or exceeding the per-client token cap. Reports of production tokens expiring under the personal-use exemption are anecdotal rather than documented behaviour. The superseded procedure above was written while the client was still in Testing and was not revisited when it was published; keeping it would have idled work for eight days to re-test a limit that no longer applies. D7's remaining question is answered for free by the first Gmail operation made more than an hour after authorization, since access tokens last about an hour. ADR-0001 D7, `docs/V1-SCOPE-AND-SEQUENCING.md` §3 and `docs/CAPABILITY-REALITY-MAP.md` §8 are amended to match. The IMAP fallback is unchanged and still applies if a token ever does die.

## M2 S2 — Judgment

2026-09-13 — **First real-model JudgmentEval run — machinery verified, but the agreement number cannot yet be produced because the corpus has no confirmed labels.** Model `claude-sonnet-5` (Claude Sonnet 5), prompt version `m2-s2-v1`, full 357-fixture frozen corpus judged in 8 composition-sized batches of 50 (one real Anthropic call each). Run through the harness on a Mac against the live API — not a warm device.

- **Agreement / essential-false-quiet / false-surface / substantive-primary-accuracy: `n/a`.** All 357 fixtures scored `incomplete`. `labels.json` (frozen in M1 S4, commit 6545210) is still in its *seeded* state — `dispositionPrior` + Gmail metadata only, with **zero** confirmed `label` (`surface`/`quiet`/`never`) or `isSubstantivePrimary` on any row. The M1 "After S4 — the labelling pass" gate ("M2's first slice does not start until the labels exist") was not actually completed; the seed was committed as if it were the labelled set. **The agreement number is blocked on Jon's labelling pass, not on the engine.** This corrects the earlier claim that "all 354 fixtures have confirmed labels."
- **Cost: $0.182 per composition, $1.456 total across 8 compositions** — well under the §7 <$1.00/composition budget. (Prompt caching not enabled; these are uncached input + output priced against the Cockpit-owned Sonnet sheet, $2/$10 per MTok.)
- **Latency: max 122.7s for one composition — over the §7 <60s budget.** This is a Mac-over-API figure, not the warm-device number ADR-0001 D1 asks for, but it is a real signal that a 50-candidate composition can exceed a minute. Candidate levers per §7: smaller per-composition batch, shorter excerpts, or a cheaper substantive-primary/subjects pass. To be re-measured on a warm device in Jon's pass.
- **Pieces admitted: 126 of 357** (~16/composition against a target of 20) — appropriately selective, not padding.
- **Fail-closed: 3 of 357 pieces** failed closed with a recorded error and stayed in the batch (per-piece, not whole-batch — JUDGMENT-CONTRACT §3). All three were *omissions* — Sonnet silently dropped them from a batch response ("no judgment for this candidate"), no transport error or truncation. The per-piece decoder proved itself on real output: the omissions cost those 3 pieces, not their ~50-candidate batch. Evidence that large batches occasionally shed items; a later refinement could re-request just the missing pieces.
- **Personal Knowledge demonstrably moves relevance (Gate-2 early signal, not decorative).** A paired real-model run over one 50-candidate slice, with vs. without a taught interest ("politics, midterms, trump, dispatch"), moved **48 pieces** (admission or rank) including **13 admission flips**.

Not recorded as an agreement number because there is no ground truth to agree with yet. Re-run once the labelling pass lands; that run produces the first true agreement + essential-false-quiet figures, and is what gates any prompt/model change from here.

2026-09-13 — **First true agreement number — labelling pass complete (354/357 confirmed).** Same run as above (model `claude-sonnet-5`, prompt `m2-s2-v1`, 357 fixtures in 8 batches of 50, Mac-over-API), now measured against Jon's confirmed labels. Baseline `m2-s2-v1`:

| metric | value |
|---|---|
| agreement | **0.421** |
| **essential false-quiet (the gating metric)** | **0.068** |
| false-surface | 0.179 |
| substantive-primary accuracy | 0.534 |
| pieces admitted | 125 / 357 (~15.6/composition, target 20) |
| cost / composition | **$0.181** ($1.446 total) |
| latency max / composition | 122.7s |
| fail-closed pieces | 0 |
| incomplete fixtures (unlabelled) | 3 |

Reading these honestly:

- **The corpus is 89% `surface` (316/357), yet the model admits only 125.** So the low agreement (0.421) is dominated by the model dropping ~190 pieces Jon marked `surface`. The overall false-quiet on `surface` material is ~60% — the model is far more selective than the labels. This is a **definition tension, not just model quality**: the prompt optimises a finite ~20-piece daily edition ("finite over comprehensive; prefer omitting a weak piece"), while the labels appear to mark "I'd want to see this" broadly. Gate 1/2 must resolve which the number should measure — retune `targetSize`/editorial posture, or re-scope what `surface` means — before chasing the agreement figure. A model admitting everything would score 0.89 agreement trivially, so agreement alone is a poor headline here.
- **Essential false-quiet is 0.068** — the one metric the contract says gates model changes. The model protects Essential substantive-primary material (only ~7% dropped) even while being aggressive elsewhere. This is the encouraging result and the right thing to hold as the regression floor.
- **Substantive-primary accuracy 0.534** is near coin-flip — a concrete `m2-s2-v1` weakness to improve with prompt work, measured against this baseline.
- **Cost $0.181/composition** confirms the §7 <$1 budget with headroom. **Latency 122.7s** exceeds the §7 <60s budget (Mac-over-API; warm-device figure still owed by Jon's pass) — a real signal to shrink batch size or split the substantive-primary/subjects pass.
- **PK sensitivity (this run): 50 pieces moved, 18 admission flips** — PK is not decorative.
- **Fail-closed 0** this run (all 357 returned); the 3 `incomplete` are the 3 rows still missing `isSubstantivePrimary`, excluded from metrics.

This is the baseline every future `m2-s2-v*` prompt/model change is measured against: adopt a change when it lifts agreement without regressing essential-false-quiet above 0.068.
