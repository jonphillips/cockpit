# Evaluation log

2026-09-11 — D7 Gmail authorization probe reached test-mode setup in Google Cloud: the POC project has an iOS client for Cockpit, `gmail.modify`, and `jon@jonphillips.com` as its test user. The native probe completed authorization on iPad. GoogleSignIn retains the authorization in the device Keychain; no mail was read or changed.

2026-09-11 — The native probe now has a distinct non-interactive stored-authorization check: it calls `restorePreviousSignIn`, then `refreshTokensIfNeeded`, and reports the local Google error without beginning sign-in. This is the D7 day-8 check for the iOS client’s Keychain-managed authorization.

2026-09-11 — Production-unverified publishing and the resulting day-8 check remain pending. The app is still in Testing, where refresh tokens expire after seven days, so this authorization cannot answer D7’s production personal-use question.

2026-09-11 — D7 Gmail OAuth client published to Production, unverified, under the personal-use exemption. The prior Testing-mode grant was revoked at myaccount.google.com/permissions and authorization was re-run on iPad afterwards, so the refresh token now held in the device Keychain is production-issued. This matters: a Testing-issued token carries its own seven-day expiry that publishing does not retroactively lift, and reusing it would have produced a day-8 failure attributable to Testing rather than to the production personal-use question.

~~2026-09-11 — D7 day-8 check is therefore due 2026-09-19, measured from the production re-authorization above, not from the publish. Procedure: leave Cockpit closed until then so the access token is certainly expired and `refreshTokensIfNeeded` genuinely exercises the refresh token, then open the Gmail probe and run the non-interactive stored-authorization check. A green result answers D7 yes and Phase 3 proceeds on `gmail.modify`. A failure answers D7 no and triggers the ADR-0001 fallback: evaluate IMAP with an app password before building Today, verifying app-password availability at that point. ~~ **Superseded — see below.**

2026-09-11 — **D7's day-8 check is retired; no waiting period is required.** The seven-day refresh-token expiry is a property of Testing status, not of being unverified. The client was published to Production on 2026-09-11 and re-authorized afterwards, so its refresh token has indefinite lifetime, subject only to ordinary revocation: user revocation, roughly six months of inactivity, a password change, or exceeding the per-client token cap. Reports of production tokens expiring under the personal-use exemption are anecdotal rather than documented behaviour. The superseded procedure above was written while the client was still in Testing and was not revisited when it was published; keeping it would have idled work for eight days to re-test a limit that no longer applies. D7's remaining question is answered for free by the first Gmail operation made more than an hour after authorization, since access tokens last about an hour. ADR-0001 D7, `docs/V1-SCOPE-AND-SEQUENCING.md` §3 and `docs/CAPABILITY-REALITY-MAP.md` §8 are amended to match. The IMAP fallback is unchanged and still applies if a token ever does die.

2026-09-17 — **M4 S4 production Gmail read is ready for the device-only pass; no provider result is claimed yet.** `Settings → Gmail authorization probe → Read Current Inbox` restores and refreshes the production-issued Keychain authorization, then performs read-only Inbox ingestion. Its success/failure is the D7 longevity result; it must be recorded from the real device in `docs/m4-s4-gmail-observations.md`. Agents do not drive devices or simulators under `AGENTS.md`, so this remains unobserved until Jon runs it. The failure path remains ADR-0001 D7's IMAP/app-password evaluation, before S5.

2026-09-17 — **D7 confirmed on device: the production read succeeded.** Jon ran the probe on his production Google account >1h after authorization; the stored authorization refreshed and ingested 42 Primary-tab messages read-only. D7's IMAP/app-password fallback is not needed; the Gmail spine stands. The device pass also forced two code corrections and surfaced the quota reality that makes `historyId` delta sync a hard Gate-3 ADR requirement — full detail in `docs/m4-s4-gmail-observations.md`. Two probe-UI observation items remain open (surface the returned `historyId`; confirm a new reply re-enters via `INBOX`); they do not block S4.

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

---

2026-09-15 — **M3 S5 · `m3-s5-v1` holds the floor; the earlier 0.136 was a batch-omission artifact.** Model `claude-sonnet-5`, prompt `m3-s5-v1`, full 357-fixture frozen corpus, **batch size 25** (`COCKPIT_EVAL_BATCH=25`, 15 batches), Mac-over-API, **empty Personal Knowledge**. Run after the `JudgmentEngine` re-request pass (M3 S5) landed. Read under DECISIONS §22 (agreement demoted to context; essential-false-quiet is the one gate).

| metric | `m2-s2-v1` baseline (batch 50) | first `m3-s5-v1` (batch 50) | **this run (`m3-s5-v1`, batch 25)** |
|---|---|---|---|
| **fail-closed pieces** | 0 | 31 | **0** |
| **essential false-quiet (the gate)** | 0.068 | 0.136 | **0.051** |
| agreement (context, §22) | 0.421 | 0.483 | 0.528 |
| false-surface | 0.179 | 0.154 | 0.103 |
| substantive-primary accuracy | 0.534 | 0.525 | 0.548 |
| pieces admitted | 125 | 145 | 157 |
| cost / batch · total | $0.181 · $1.446 | $0.188 · $1.504 | $0.112 · $1.678 |
| latency max / batch | 122.7s | 130.5s | 74.7s |

Reading it honestly:

- **The gate held and improved: essential-false-quiet 0.051 ≤ 0.068, on a clean run (0 fail-closed).** The first `m3-s5-v1` run read 0.136 with **31** pieces failing closed — those were silent batch omissions (the model returning valid JSON with a short `judgments` array), *not* editorial drops, and they mechanically inflated false-quiet because a fail-closed piece counts as not-surfaced. The S5 re-request pass (`JudgmentEngine` re-asks for just the omitted subset, bounded ≤2 rounds) removed all 31, and false-quiet fell to 0.051. This confirms the 0.136 was an omission artifact, and that the `m3-s5-v1` claim-naming prompt does not regress the floor.
- **Not a single-variable comparison.** This run changed *two* things vs the 0.068 baseline — prompt version **and** batch size (25 vs 50). `targetSize` is per-call, so batch 25 admits a larger fraction (157 vs 125, ~44% vs ~35%), which inflates agreement (0.528) and admit count. Per §22 those are context, not the headline; the floor is unaffected by batch size and is the number that matters here.
- **Latency 74.7s** (batch 25) is down from 122.7s (batch 50) but still over the §7 60s budget on Mac-over-API — smaller batches are a real latency lever; the warm-device figure is still owed by Jon's pass.
- **Benign test-assertion failures:** `incompleteFixtureCount == 3` (the 3 permanently-unlabelled rows) and `maxLatency < 60` (Mac-over-API). Neither is the gate.
- **Still owed for the full S5 / Gate-2 answer:** the *effect of a real grown claim set* on this clean engine. The prior PK-sensitivity probe (50 moved / 15–18 flips, one 50-slice) predates the re-request fix. The primary Gate-2 record comes from the Option B run — real claims through `PersonalKnowledgeProjector`, default batch 50 — which gives the production-realistic floor **and** the admission/rank delta in one run.

---

2026-09-15 — **M3 S5 · Gate-2 primary: a real 30-claim set moves relevance hard, in the right direction, and the S5 claim-naming path fires on real data.** Model `claude-sonnet-5`, prompt `m3-s5-v1`, full 357-fixture frozen corpus, **default batch 50**, Mac-over-API. The corpus was judged twice in one session — **bare** (empty PK) then **taught** (Jon's real 30 claims: 8 Fact / 12 Interest / 10 Taste, projected through `PersonalKnowledgeProjector` with `[Claim ID: …]`). This is the paired, variance-controlled Gate-2 measurement (DECISIONS §22).

| metric | bare (empty PK) | **taught (30 claims)** |
|---|---|---|
| pieces admitted | 127 | **99** |
| agreement (context, §22) | 0.449 | 0.364 |
| **essential false-quiet (the floor)** | 0.102 | **0.102** |
| false-surface | 0.077 | 0.103 |
| substantive-primary accuracy | 0.545 | 0.415 |
| cost / composition | $0.220 | $0.199 |

Effect of the grown claim set: **movedPieces 278 / 357** (admission or rank changed), **admissionFlips 58**, **attributedAdmissions 54** (admitted pieces whose rationale named a claim), **distinctCitedClaims 12** of 30. Cost total $3.35 (both passes), latency max 243s.

Reading it under §22:

- **PK is emphatically not decorative, and it moves in the right direction.** 278 of 357 pieces moved; teaching the 30 claims made the edition **more selective** (127 → 99 admitted), not more permissive. That is the editorial discrimination a finite personalized edition is supposed to show — the Gate-2 headline answer is a clear yes.
- **The S5 claim-naming path fires on real data:** 54 admitted pieces attributed to a specific claim, drawing on 12 distinct claims (the software / AI / personal-information-systems / newsletters / wine interests that overlap this news-and-tech-heavy corpus; travel/comics/woodworking claims rarely matched, as expected). So the Reader's "Because you care about X…" rationale is populated by real judgment, not a hand-written string — S5 done-criterion 1 confirmed against the live model.
- **PK did not regress the floor: essential-false-quiet is identical bare vs taught (0.102 = 0.102).** This is *by design* — Essential substantive-primary material is protected regardless of PK, so PK churns the discretionary edition and leaves the Essential guarantee untouched. The gate is therefore recorded as a **paired** comparison (taught ≤ bare), not against an absolute constant.
- **essential-false-quiet is too small-count for an absolute gate.** Across clean runs of the *same* prompt it has read 0.051, 0.068, and 0.102 — ~3–6 pieces of ~59 Essential-substantive, so a 3-piece nondeterministic swing doubles it. The `m3-s5-v1` test assertion was corrected to gate on the same-session bare run (variance-controlled) rather than the historical 0.068. **Recommended:** DECISIONS §22 should state the floor as a paired bare-vs-taught delta, not a fixed number. *(Ratified at Architecture Gate 2, 2026-09-16 — DECISIONS §22.2 is the standing definition; this flag is closed.)*
- **§22 vindicated, concretely.** Agreement *dropped* with PK (0.449 → 0.364) precisely because the edition got more selective — a better edition scoring worse on agreement-vs-`surface`. This is the exact confound §22 demoted, now demonstrated rather than argued.
- **Flag for Gate 2 — substantive-primary accuracy fell with PK (0.545 → 0.415).** `isSubstantivePrimary` is a *type* property, independent of taste/interest (DECISIONS §18); PK should not move it. That it does is evidence the single judgment pass lets PK bleed into the type classification. It is also a noisy metric, but the direction is a real signal worth raising at the gate (candidate: separate the type call from the editorial call, per the M2-S1 cost decision's "mechanical grunt-work onboard" direction).
- **Benign test-assertion failure:** `incompleteFixtureCount == 3` (the permanently-unlabelled rows). Fail-closed instrumentation was added to this run's output for future comparability.

Verdict: **M3 S5 done-criterion 3 is met** — a recorded run shows a real PK change moving admission/rank (278 / 58) with the Essential floor held (paired 0.102 = 0.102), under §22 discipline. Carried to Gate 2: the paired-floor definition and the substantive-primary bleed.

---

## Architecture Gate 2 — closed 2026-09-16

M3's slice ledger (S1–S5) is complete; Gate 2 inspected and closed. The headline
question — *did PK growth change admission/rank among contested pieces in a
direction Jon endorses, with essential-false-quiet held against a same-session
control?* — is answered **yes**: the 2026-09-15 M3-S5 primary run moved 278/357
pieces, flipped 58 admissions, made the edition *more* selective (127 → 99), and
held the Essential floor (paired 0.102 = 0.102). PK is not decorative.

Gate rulings (architect, 2026-09-16):

- **Paired floor ratified.** DECISIONS §22.2 stands as written — the
  essential-false-quiet gate is a same-session paired delta (bare vs taught /
  old-prompt vs new), not the absolute ~0.068. The open flag above is closed.
- **Substantive-primary bleed → ratified M4 scope.** The 0.545 → 0.415 drop under
  teaching is the single judgment pass letting PK move a *type* property (§18).
  Remedy: split the type/classification call from the editorial call — an M4 slice,
  advancing both correctness and the M2-S1 cost lever. Not gate-blocking.
- **Auto-Library reconciled to Phase 7.** DECISIONS §18's "Phase 2" corrected to
  match V1-SCOPE §3 (Phase 7, after explicit Library + custody are trustworthy).
- **No schema inflation.** 30 claims (8 Fact / 12 Interest / 10 Taste) — Fact /
  Taste / Interest were sufficient; the 150-claim full-projection threshold
  (JUDGMENT-CONTRACT §2) is nowhere near stressed, so the subject-overlap subset is
  not built. No salience/confidence/trajectory machinery added (V1-SCOPE §Phase 2).
- **Frontier stays for the editorial call**; the type-call split is where a
  cheaper/onboard pass can later live once it can emit the schema.

M4 opens on the Phase-3 cutline (Gmail read-only Today → Gate 3), carrying the
type/editorial split, offline controls, and the inline-body Reader. See
`docs/milestones/M4-gmail-today.md`.

## M4 S1 — Type/editorial split

2026-09-16 — **First paired split run — the substantive-primary bleed is closed, but the floor
number is inconclusive: one editorial batch timed out and its fail-closed pieces inflated
essential-false-quiet. This run does not close S1.** Model `claude-sonnet-5` (Claude Sonnet 5),
`typePromptVersion=m4-s1-type-v1`, `editorialPromptVersion=m4-s1-editorial-v1`, batch size **50**,
grown-PK bare-vs-taught over the full 357-fixture corpus with the same 30-claim set used at Gate 2.

| metric | bare | taught |
| --- | --- | --- |
| agreement | 0.441 | 0.333 |
| essential-false-quiet | 0.051 | **0.169** |
| false-surface | 0.128 | 0.026 |
| substantive-primary accuracy | 0.658 | 0.619 |
| mean pieces admitted | 127 | 81 |
| cost / composition | $0.311 | $0.268 |
| **failClosed** | **0** | **50** |

movedPieces 225, admissionFlips 70, attributedAdmissions 51, distinctCitedClaims 9. Cost total
$4.63 (both runs), latency max **176.5s**.

Reading it:

- **The substantive-primary bleed is closed — the slice's primary goal.** Teaching moved
  substantive-primary accuracy only 0.658 → 0.619 (Δ0.039), versus the M3 single-pass collapse this
  slice exists to fix (0.545 → 0.415, Δ0.130). The type pass receives no PK by construction, so the
  small residual is nondeterministic noise between two independent PK-free type passes, not a bleed.
  Split-pass separation works.
- **The essential-false-quiet "regression" is an artifact, not a PK floor breach.**
  `failClosed(taught/bare) = 50/0`. 50 is exactly one composition batch (`compositionSize = 50`), so
  one **editorial** batch failed wholesale in the taught run — correctly not retried (a whole-batch
  failure is transport-level, not a partial omission). Fail-closed pieces are scored not-admitted, so
  the Essential-substantive ones among the 50 count as false-quiet and pushed the metric to 0.169.
  The bare run, whose editorial pass carries no PK, failed nothing (0.051).
- **Root cause is the DC-3 load lever biting.** Latency maxed at **176.5s** — ~3× the 60s budget for
  one 50-candidate composition. The M4 editorial call carries ~2× the input of the old single pass
  (full bodies + the 30-claim PK projection + type metadata, JUDGMENT-CONTRACT §7). The taught
  editorial batch grew heavy enough to run ~176s and time a whole batch closed; the lighter bare and
  type batches did not.

Actions taken this session (code, not yet re-measured):

- **Editorial composition size reduced 50 → 30** (`JudgmentEvalLiveTests.compositionSize`, override
  `COCKPIT_EVAL_BATCH`), so a single editorial call stays inside a workable latency. The deeper lever
  — trimming the body the editorial pass resends, or an Interest-Area split with a second pass
  (JUDGMENT-CONTRACT §1) — is parked for Jon.
- **Reliability gate added to the grown-PK test**, checked *before* the floor: a run with any
  fail-closed piece now fails as a reliability failure and prints grouped fail-closed reasons
  (`taughtFailClosedReasons` / `bareFailClosedReasons`), so a timeout can no longer masquerade as a
  PK floor regression. `runFrozenCorpus` already gates on `splitFailClosed.isEmpty`.

Status: **S1 engineering is complete and the bleed is demonstrated closed; the floor is not yet
cleanly measured.** Pending, at batch 30, for Jon to run and endorse — the `failClosedReasons` output
will confirm the timeout diagnosis:

1. `runFrozenCorpus` — the same-session single-pass-vs-split-pass control (DC-2 floor; DC-3 split
   type/editorial cost + latency). Not run this session.
2. `runFrozenCorpusWithGrownPersonalKnowledge` — a clean bare-vs-taught with `failClosed = 0`, so
   essential-false-quiet is a real PK number and substantive-primary-accuracy stability (DC-1) is
   recorded without the artifact.

2026-09-16 (later) — **Batch-30 re-run: `runFrozenCorpus` (single-pass vs split) is a clean pass on
substance — DC-2 met.** `failClosed(single/split) = 0/0`; the batch-size reduction removed the
timeout. Same-session control, bare PK on both arms:

| metric | single-pass control | split |
| --- | --- | --- |
| agreement | 0.525 | 0.523 |
| essential-false-quiet | 0.051 | **0.034** |
| false-surface | 0.179 | **0.051** |
| substantive-primary accuracy | 0.551 | **0.681** |
| mean pieces admitted | 161 | 150 |
| cost / composition | $0.137 | $0.211 |

- **DC-2 floor: held, and better.** Split essential-false-quiet 0.034 ≤ single-pass 0.051. The split
  does not regress the floor against its own same-session control — it improves it.
- **DC-2 accuracy: the split's headline win.** Substantive-primary accuracy **0.551 → 0.681**
  (+0.130) against the same-session single-pass, and above the M3-S5 baseline (0.545). Separating the
  PK-free type call from the editorial call measurably improves the type decision, not just isolates
  it. False-surface also fell hard (0.179 → 0.051).
- **DC-3 cost: within budget, with the 2× input confirmed.** Split $0.211/composition < $1.00.
  `splitTypeCost $1.228` ≈ `splitEditorialCost $1.308` over the corpus — the two passes cost about the
  same because both currently send the full bodies (~2× input, JUDGMENT-CONTRACT §7). Split corpus is
  ~1.5× the single-pass cost per composition ($0.211 vs $0.137).
- **DC-3 latency: over the §7 budget — the noted lever.** `splitLatencyMax 114.9s` per composition at
  batch 30. The split runs type-then-editorial sequentially (editorial needs the type metadata), so it
  inherently ~doubles per-composition latency, and the offsetting win — moving the PK-free type pass to
  a faster/cheaper model — is deferred behind the schema blocker. Recorded, not gate-blocking (DC-3
  explicitly allows "note the lever"). The §7 "<60s on a warm device" target is Jon's device-pass call
  on real hardware, not this Mac+API+concurrency-4 measurement, which inflates per-composition latency.

Two test-assertion corrections made after this run (code, green locally):

- `incompleteFixtureCount == 0` → `<= knownUnlabelledFixtureCount` (3). It is a pure label property
  (`rows − complete`, needing a confirmed `label` + `isSubstantivePrimary`) — the 3 permanently-
  unlabelled corpus rows, unrelated to the split. Asserting zero wrongly claimed a fully-labelled
  corpus; both live tests carried the wrong assertion.
- The `runFrozenCorpus` latency hard-gate `< 60` is now **recorded** with a pathological-hang ceiling
  (`< 240`), per DC-3's "confirm within budget or note the lever." Single-pass latency is now printed
  alongside split's for the delta.

Also this session: **the eval harness now judges compositions concurrently** (bounded
`withTaskGroup`, default 4, `COCKPIT_EVAL_CONCURRENCY`); bare/taught and control/split stay sequential
so total in-flight is exactly the cap. Identical dollar cost, ~4× less wall time on a corpus run.

Still pending for full DC-1 sign-off: the batch-30 `runFrozenCorpusWithGrownPersonalKnowledge` line
(`JudgmentEvalPKGrown …`) with `failClosed(taught/bare) = 0/0`, confirming substantive-primary
accuracy no longer moves bare-vs-taught. Then Jon's lived-use endorsement of the split edition.

2026-09-16 (later still) — **Batch-30 grown-PK run: DC-1 confirmed (bleed closed); the diagnosis was
corrected and the reliability hole fixed.** `runFrozenCorpusWithGrownPersonalKnowledge` at batch 30,
30-claim set, full corpus bare vs taught:

| metric | bare | taught |
| --- | --- | --- |
| essential-false-quiet | 0.034 | 0.051 |
| false-surface | 0.154 | 0.000 |
| substantive-primary accuracy | 0.681 | 0.647 |
| mean pieces admitted | 160 | 87 |

movedPieces 193, admissionFlips 87, attributedAdmissions 61, distinctCitedClaims 11.
`failClosed(taught/bare) = 30/0`, latency max 111.3s.

- **DC-1 confirmed — the bleed is closed.** Substantive-primary accuracy moves **0.681 → 0.647**
  bare-vs-taught (Δ0.034, noise between two independent PK-free type passes), versus the M3 single-pass
  **0.545 → 0.415** (Δ0.130). The type call no longer tracks taste. The 30 editorial-failed pieces keep
  their real type classification (the type pass succeeded), so they do not distort this axis.
- **PK is not decorative:** 193 moved, 87 admission flips, 61 admissions attributed to a specific
  claim across 11 distinct claims; teaching made it *more* selective (false-surface 0.154 → 0.000,
  admitted 160 → 87).
- **The floor is still blocked by 30 fail-closed — but the reliability gate corrected the diagnosis.**
  `taughtFailClosedReasons = 30× "…isn't in the correct format."` — a **JSON decode failure at 111s,
  not a timeout.** One taught editorial batch (batchSize 30) returned truncated/malformed JSON; the
  envelope decode threw, and a whole-envelope failure took all 30 pieces down with no re-request. The
  earlier batch-50 "timeout at 176s" was almost certainly this same truncation, misread before the
  `failClosedReasons` instrumentation existed. The 30 not-admitted pieces inflate taught's
  essential-false-quiet to 0.051; the true taught floor is ≤ that.

**Fix — tolerant envelope decode (`JudgmentEnvelope`, this session).** A truncated top-level envelope
was a hole in the per-piece fail-closed guarantee (JUDGMENT-CONTRACT §3): the whole batch died before
per-piece handling ran. The decoder now tries the strict decode, and on failure **salvages the
complete leading objects** from the cut-off array; the missing tail falls through to the per-piece
"no judgment" path, which the existing re-request loop fetches in a small follow-up call. Only a
response with *nothing* recoverable still fails the whole pass. Applies to all three passes
(editorial, classification, single-pass control); deterministic truncated-envelope tests added; build
+ `swiftlint --strict` green.

Next: re-run the same one-line `runFrozenCorpusWithGrownPersonalKnowledge` command. With salvage in
place the truncated batch should degrade to a recovered partial omission (`failClosed = 0/0`), giving
a clean taught floor to compare against bare — the last number owed before Jon's endorsement.

2026-09-16 (clean run) — **`failClosed(taught/bare) = 0/0`. The tolerant decode held; the grown-PK
run passes. S1's eval is complete — all three done-criteria met on recorded runs.** Batch 30, 30-claim
set, full corpus:

| metric | bare | taught |
| --- | --- | --- |
| agreement | 0.520 | 0.381 |
| essential-false-quiet | 0.051 | **0.017** |
| false-surface | 0.077 | 0.077 |
| substantive-primary accuracy | 0.720 | 0.684 |
| mean pieces admitted | 151 | 103 |
| cost / composition | $0.212 | $0.217 |

movedPieces 192, admissionFlips 74, attributedAdmissions 64, distinctCitedClaims 13, latency max
113.2s, cost total $5.16.

- **Reliability: clean.** No fail-closed on either arm; the truncation that took 30 pieces down last
  run degraded to a recovered partial omission via `JudgmentEnvelope` salvage — the whole test passed.
- **DC-1 (bleed closed): confirmed, twice.** Substantive-primary 0.720 → 0.684 bare-vs-taught
  (Δ0.036), matching the prior clean run's Δ0.034 — noise between two PK-free type passes, versus the
  M3 single-pass Δ0.130 directional collapse. The type call no longer tracks taste.
- **DC-2 (paired floor): held and improved.** Taught essential-false-quiet **0.017 ≤ bare 0.051**,
  same-session — teaching lowers false-quiet, it does not regress it. With the control run's
  substantive-primary 0.551 → 0.681, DC-2 is fully satisfied.
- **PK not decorative:** 192 moved, 74 flips, 64 admissions attributed across 13 distinct claims;
  teaching made the edition more selective (151 → 103, false-surface flat at 0.077).
- **DC-3:** cost $0.217/composition (< $1.00); latency 113s/composition — over the 60s §7 budget, the
  known two-pass lever tracked in DECISIONS §23 (resolution deferred to the type-model swap).

**S1 verdict: the type/editorial split is proven.** It closes the PK bleed into the type call
(Δ0.130 → Δ~0.035), improves substantive-primary accuracy (0.551 → 0.681 vs the single-pass control)
and false-surface, holds the Essential floor, and — via the truncation fix surfaced along the way —
made the whole composition resilient to a capped model response. Remaining to close the slice: Jon's
lived-use endorsement that the split edition *feels* right on real morning content (the manual pass
M4-S1 reserves), then tick the box.

2026-09-16 (device pass) — **On-device recompose: ~6 minutes, $0.48. Cost fine; latency ~6× the §7
budget — the DECISIONS §23 trigger fired.** A real recompose on an iPad (whole day re-judged from
scratch) cost **$0.48** (under the $1.00/composition budget) and took **~360s** — about 6× the 60s
warm-device target, on the hardware the budget is about. This resolves the §23 proxy caveat: the
latency breach is real, not a Mac-over-API artifact. Root cause is the monolithic production path —
`composeIfNeeded` sends the whole day to `engine.judge` as one large type call + one large editorial
call, sequentially, with none of the batching/concurrency the eval harness uses. Recorded and
actioned as **M4 · S6 — Composition latency** (parallelize the PK-free type pass; the editorial pass
stays one finite-package call), sequenced before the Gmail spine. See DECISIONS §23 (triggered).

2026-09-18 — **M5 S5 · Tail-compose observability and bounded failure.** The 2026-09-16 iPad
recompose above remains the real-device evidence: **~360s / $0.48**, so cost remains within the $1.00
budget and latency remains roughly **6×** the 60s target. The composition path now reports its actual
coarse phase — planning, type screening, editorial selection, then saving — and bounds an attempt at
eight minutes. A timeout cancels before materialization, surfaces a retryable error, and leaves no
opened Edition or entries; the next compose re-drives the existing recoverable `composing` row. The
model test covers that adversarial path plus a definite empty-tail state. The remaining device pass is
not another latency measurement: confirm that this progress language reads as working rather than
broken, and decide whether the already-recorded ~360s is tolerable pending the deferred model swap.
