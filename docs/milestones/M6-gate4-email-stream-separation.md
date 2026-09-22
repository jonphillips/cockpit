# M6 Gate 4 — Email-delivered recurring Stream: the separation test (slice plan)

> **Slice plan, not a single-slice spec.** Architect-recorded 2026-09-21. Gate 4 is milestone-sized and
> carries the major model review, so this is a decomposition + the separation invariants + the concrete
> first checks — not a line-by-line spec. It inherits: **reachable-first is the default** (§24; settled
> with Jon 2026-09-21), the ledger in `M6-decisions-and-sequencing.md`, and the S1/D9 down payment.

## What Gate 4 proves

The whole content model claims **Transport / Artifact / ContentPiece / Stream Handling / source
disposition / Edition state are genuinely separable.** Gate 4 forces the claim under a real recurring
email newsletter that is itself a followed Stream (Yglesias, Puck, Sepinwall) and proves the layers do
not secretly couple. It is the separation test, and it carries the model review.

## The concrete coupling this gate must break

`EditionPlanner` (uncurated-tail candidate gathering) **excludes tail candidates by transport**: any
ContentPiece that has a Gmail `Artifact` is excluded ("a Gmail Artifact is the durable marker that a
ContentPiece came from curated inbox input", `EditionPlanner.swift` ~line 102–110). So **curation role
is currently derived from transport** — Gmail ⇒ curated ⇒ kept out of the tail; RSS/atom ⇒ tail.

That rule conflates *how it was delivered* with *what curation role it plays*. An email-delivered
**followed Stream** is Gmail-transport content that should behave as curated-Stream content (reachable
via Stream Handling), not be excluded for being Gmail and not be dumped into Today's Primary triage as
loose inbox mail. **The discriminator must become Stream membership, not transport:**

- Gmail Artifact **linked to a followed Stream** (`streamID` set, `followState == .active`) → curated
  *Stream* content → reachable-first via Stream Handling.
- Gmail Artifact **with no followed Stream** → loose Primary mail → Today typed triage (unchanged).
- RSS/atom followed Stream → unchanged (modulo the reachable-first model question below).

The schema is already ready for this: `Stream.transport` includes `.gmail`, `Artifact.streamID` links
either transport, and `GmailStreamResolver` already resolves a Gmail Artifact to a configured Stream by
its **locator** (normalized List-ID / sender) using the **same `GmailSeriesKey.locatorKeys` normalizer**
the S1 series key uses. So the recurring-email-series identity is *already unified* — confirm it stays
unified and is not forked into a parallel email-Stream locator.

## Separation invariants (the gate's acceptance tests)

These are the "does the seam hold" assertions. Most are test-backed in core; I5 is device-eval.

- **I1 — transport ≠ curation role.** A Gmail Artifact on a followed Stream is treated as curated-Stream
  content (reachable via its Stream), not excluded-because-Gmail and not routed into Primary Today
  triage. A loose Gmail Primary message (no followed Stream) still goes to Today triage.
- **I2 — disposition ⊥ content.** Archiving/trashing the Gmail source leaves the ContentPiece in its
  Stream and its Edition/Essential state intact (ADR-0002 D8; extends the S1/D9 custody proof).
- **I3 — Stream membership ⊥ transport.** Membership is computed from the provenance locator (List-ID /
  sender), identically for RSS and Gmail; Stream Handling guidance applies regardless of transport.
- **I4 — Edition state ⊥ transport & disposition.** A piece's admission / carry / Essential state is
  independent of transport and of whether its source email is still in `INBOX`.
- **I5 — reachable-first is the default (§24).** A followed Gmail Stream is *reachable* via its Stream,
  not force-promoted into the Edition package. **Essential ≠ promote** (do not silently assume Essential
  means promote — Jon's note). Confirmed on device with real newsletters, after the mechanics land.
- **I6 — §18 guard.** `isSubstantivePrimary` is never used as a Stream / keep / promotion criterion. It
  is a piece-level *attention* signal, not a *durability* or *curation* signal.

## Decomposition (proposed slices)

Ordered so the **mechanics precede the feel** (the recurring method trap: feel can't be judged against a
scaffold, so the gate's architecture ratification must not wait on the placement verdict).

1. **S-a — Decouple curation role from transport.** Replace the transport-based tail exclusion with
   Stream-membership discrimination; audit every other place curation role is derived from transport
   (grep `transport.eq(.gmail)` in routing/curation paths). Prove **I1, I3**. Confirm the identity stays
   unified (`GmailStreamResolver` ↔ `GmailSeriesKey`).
2. **S-b — Route followed-Gmail-Stream pieces to Stream Handling / reachable-first**; confirm loose
   Primary still lands in Today. Establishes the surface; the reachable-first *feel* (I5) is evaluated
   in S-d, on device.
3. **S-c — Prove disposition ⊥ content ⊥ Edition state for a Gmail Stream.** Extend the S1/D9 tests to
   assert Stream membership and Edition/Essential state survive an archive/trash of the source. Prove
   **I2, I4, I6**.
4. **S-d — Gate 4 model review + device eval.** Real Yglesias/Puck/Sepinwall through the whole path;
   confirm reachable-first (I5) feels right; ratify into ADR-0002 / DECISIONS §24. This is where the
   "major model review" happens.

## First checks for the executor

- **The transport exclusion in `EditionPlanner`** (~line 102–110) is the concrete target; enumerate
  every sibling (`grep -rn "transport.eq(StreamTransport.gmail)"` in curation/routing code, not just
  ingest).
- **Can a Gmail Stream be *configured/followed* today?** `GmailStreamResolver` resolves to an
  "explicitly configured Gmail Stream," and `Stream.transport` supports `.gmail` — but confirm the
  follow UI (`FollowingModel` / `StreamOperations`) can actually create/follow a `.gmail` Stream. If not,
  that configuration path is part of S-a/S-b.
- **`EditionCandidateContext.isFromEssentialStream`** already exists (Essential is a Stream-level
  protection in judgment). Confirm Essential is treated as *reachable-first protection*, not
  promote-into-package, and stays separate from `isSubstantivePrimary` (I6).

## Open model questions (settled at the Gate 4 review, not pre-decided here)

1. **Does reachable-first apply to *all* followed Streams (RSS included) now, or only the new Gmail
   ones?** §24 "dissolved the promotion effect for curated streams" in general — which may change the
   *existing* RSS tail-promotion behavior, not just add a Gmail path. This is the central model-review
   question. Do not pre-decide it in S-a; surface it for the review.
2. **Where does a followed-Gmail-Stream piece live relative to Today?** Reachable-first implies reachable
   *via the Stream*, not present in the daily Primary triage — confirm it leaves Today's triage rather
   than appearing in both.
3. **The always-read case.** Yglesias/Puck/Sepinwall are "always read" — does reachable-first serve that,
   or do always-read Streams want a stronger surface than merely reachable? (Answer on device; if it
   pulls hard toward promotion, that reopens I5 — but as an additive keep-side policy *after* the gate,
   never inside it.)
4. **Grab-bag / Feed Me digests became reachable-only (introduced by S-b, PR #57).** A manually-created
   Gmail Stream defaults to `followState == .active` (`Domain.swift` ~line 100), so a grab-bag digest
   (e.g. Feed Me) now *leaves Today entirely* and is reachable only via its Stream. Extraction stays
   durable (`decodedGrabBagItems` still persists), but the digest no longer fans its extracted items
   out into Today triage — the whole issue collapses to a single Stream row that surfaces none of its
   items in any list. This is a genuine surfacing change, not just a routing one, and it answers
   question #3 for grab-bags by side effect of the `.active` default rather than by decision. Confirm at
   the review: is a Feed Me digest a followed Stream (reachable-first is correct), or does an
   items-bearing digest want its extracted items surfaced somewhere (Today, or a richer Stream row)?
   Do not let this ride in silently.

## Gate 4 model review — agenda (architect-recorded 2026-09-22)

> **The mechanics landed; the surface is a stub.** S-a/S-b/S-c (PRs #56/#57/#58) prove the seams hold in
> the model — I1–I4, I6 are test-backed. But a device look at Today (2026-09-22) shows the gate's
> load-bearing concepts have **no legible UI expression**, so the S-d "reachable-first *feel*" eval (I5)
> cannot run yet: there is nothing to feel. This is the recurring-method trap named at the top of this
> doc — feel can't be judged against a scaffold. **Resolve this agenda first, then a surface slice
> (S-d0), then the device eval.** These are review decisions, not implementation choices; do not
> pre-decide them in the surface slice.

**What the device look showed (the evidence).** Today (`CockpitApp/TodayLandingView.swift`) is still the
M5 treatment-typed triage: sections are `EmailTreatment` buckets (Personal / Newsletter / offer /
grab-bag / transactional, via `orientationSummary`), rows show raw sender addresses. **No row is a
Stream and none is labeled by transport.** The only home for reachable-first is `StreamHandlingView`,
reachable *only* from Settings → a stream (`CockpitApp/SettingsView.swift` ~line 68). A followed Gmail
Stream (The Washington Post) appeared in **both** "Fresh this morning" and "Newsletters 64" — the
"appears in both" failure from open question #2, live. So reachable-first, Stream identity, and transport
are all invisible on the surface the user actually reads.

**Q-A — Where do followed Streams live as a first-class place?** Not Settings. Reachable-first only means
something if there is a Streams surface that is a peer to Today / Later / Library. Absent that, "reachable"
degrades to "buried in Settings." Decide whether Streams becomes a top-level surface (and what it is
called) before the surface slice is scoped.

**Q-B — Does the promotion band survive?** "Fresh this morning" is `model.promotedRows`
(`TodayLandingView.swift` ~line 100), a horizontal *promotion* carousel — the exact effect §24 /
reachable-first says to **dissolve** for curated streams. It is the live contradiction with I5. Either it
is the sanctioned always-read surface (Yglesias/Puck/Sepinwall — see Q from open question #3) and we stop
calling promotion dissolved, or it goes. A one-card carousel also reads as a bug, not a feature. Do not
let the band and reachable-first coexist unexamined.

**Q-C — What marks Stream identity on Today, and should followed-Stream issues be on Today at all?** A
followed-Stream issue showing on Today (as WaPo does now, in two places) may mean routing has not actually
removed it, or may mean Today should carry a Stream affordance. Reachable-first (open question #2) implies
it leaves the daily triage and is reachable via its Stream. Decide: does a followed-Stream piece leave
Today, and if any Stream identity shows on Today, what is the mark?

**Q-D — Does the Edition package have a standing entry point, or is compose-on-demand the model?** The
Edition/tail is composed on demand (sparkles control, `TodayView.swift` ~line 79); there is no standing
Edition entry point on the landing screen, which is why "I don't see an Edition package" is the correct
read of what is built. Decide whether that is intended or a missing surface.

These fold in the earlier open model questions (RSS scope #1, appears-in-both #2, always-read #3, grab-bag
#4): #2 is now evidence under Q-C, #3 is the deciding input to Q-B, #4 is a Q-A/Q-C surfacing case.

**Sequencing consequence.** S-d as originally written (model review + device eval in one) splits: the
**model review is this agenda** (resolve Q-A–Q-D on the shipped mechanics); a **surface slice (S-d0)**
builds the resolved surface; the **device eval (the real I5)** runs against S-d0, not against the current
Settings-buried stub.

## Continuity with shipped work

- **S1 + D9 are the down payment.** They already proved *source disposition independent of custody*
  (trash the Gmail source; Later/Library/Find survive). Gate 4 extends the same separation to **Stream
  Handling and Edition state**, so I2 builds directly on the S1/D9 tests rather than starting cold.
- **The series identity is already unified.** A followed Gmail Stream and an S1 series-trash declaration
  key on the *same* normalized List-ID/sender identity. The richest single test of the whole model is
  their composition: a followed Gmail Stream that is *also* declared trash-after-reading — read it
  (reachable via the Stream), the source trashes, and the ContentPiece remains in its Stream/Edition,
  custody intact. That one case exercises all six invariants at once.
