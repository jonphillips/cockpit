# ADR-0001 — Persistence, Execution Model, and Ingest Ownership

**Status:** Accepted
**Date:** 2026-09-08
**Phase:** 0 — must be settled before feature work hardens persistence

---

## Context

The V1 plan called for a Phase 0 ADR covering Artifact/ContentPiece identity, provenance, membership invariants, lifecycle constraints, custody, and initial Personal Knowledge shape. Those are now in `docs/IMPLEMENTATION-CONTRACT.md`.

Review of the corpus found three further questions that are expensive to reverse and were unaddressed anywhere: **where processing runs**, **which device ingests**, and **how identity is derived**. A fourth, Gmail authorization viability, is cheap to answer now and expensive to discover in Phase 3.

---

## D1 — Processing runs on device. Foreground-first, background best-effort.

Cockpit ingests, judges, and enriches entirely on the user's devices. No server, no worker, no hosted ingest.

Composition happens at **first app launch after the day boundary**:

```
launch → is there an open Edition for today?
  no  → fetch all following Streams
      → normalize Artifacts
      → derive ContentPieces
      → one judgment pass
      → write Edition + EditionEntries, state = open
  yes → present the existing Edition unchanged
```

`BGProcessingTask` is registered as an opportunistic pre-warm so the common case is that the morning Edition is already composed. It is never relied upon. If it did not run, the app composes in the foreground behind a visible "composing today's edition" state.

Once `Edition.state = open`, the entry set is stable for the day. Intraday admission appends; it never recomposes or reorders.

### Why not a server

A server is the technically obvious answer to "compose the Edition before Jon wakes up," and it is rejected for three reasons, in order of weight:

1. **Gmail compliance.** `gmail.modify` is a Google restricted scope. Personal-use apps are exempt from verification, but the security assessment requirement attaches to apps that can access restricted data *from or through a third-party server*. Putting ingest on a VPS converts a defensible personal-use exemption into a plausible CASA obligation, which is an annual four-figure cost and a recurring audit for a single-user app. Staying on device is worth real money here.
2. It contradicts the local-first architecture the whole jon-platform house is built on, and would make SQLiteData+CloudKit a sync channel for server-authored state rather than device-authored state.
3. It introduces credential custody, deployment, and monitoring for one user.

### Honest consequence

Morning stability is achieved by **materializing** the Edition, not by composing it early. The first launch of the day pays a visible composition cost. That is the accepted trade.

### What would reverse this

Composition latency at real Stream volume exceeding roughly 60 seconds on a warm device, or `BGProcessingTask` proving so unreliable that every morning is a foreground wait. Measure at Gate 1.

---

## D2 — One designated ingesting device, plus convergent identity as a safety net.

A `Settings → Integrations` value names the ingesting device. Non-ingesting devices read the synced result and may compose nothing. The iPad is the default.

This is belt and braces with D3: even if two devices ingest concurrently, convergent identity means they produce the same primary keys rather than duplicates. The designation exists to avoid duplicated LLM cost, not to avoid corruption.

If the designated device has not composed by a threshold, any device may take over and update the designation.

---

## D3 — ContentPiece identity is derived, not random.

`ContentPiece.id = UUIDv5(cockpitNamespace, canonicalIdentityString)`

Canonical identity string, first available wins:

1. canonical URL after normalization (strip `utm_*`, `fbclid`, `ref`, fragment; lowercase host; strip trailing slash)
2. provider stable ID (`youtube:{videoID}`, `gmail:{rfc822MessageID}`)
3. RSS/Atom GUID when the feed marks it permanent
4. SHA-256 of normalized title + publisher + publication date

Two devices, or the same item arriving through two Streams, converge on one row without a merge operation. This is what makes conservative deduplication cheap and CloudKit-safe.

Artifacts keep random IDs and record their own provenance. Multiple Artifacts pointing at one ContentPiece is the normal and expected case for cross-Stream arrival.

---

## D4 — Normalized text is stored for every textual ContentPiece.

See `docs/IMPLEMENTATION-CONTRACT.md` §6. Text is not a payload and is not governed by the promise-based custody model, which continues to govern media, PDFs, and uploaded sole-source files.

---

## D5 — Edition is a materialized entity.

`Edition` and `EditionEntry` are real tables. Edition was previously modeled only as per-ContentPiece state, which cannot deliver morning stability, cannot answer "what did I see Tuesday," and leaves nowhere to record why a piece was surfaced.

`EditionEntry.rationale` is the sanctioned durable record of a surfacing decision. It satisfies the explanation requirement without opening a general evidence graph.

---

## D6 — CloudKit posture.

Cockpit owns its container, schema, and `makeSyncEngine`. Syncable: Streams, InterestAreas, ContentPieces, Editions, EditionEntries, memberships, PersonalKnowledgeClaims, PendingFinds, DispositionPolicies.

Not synced: Artifacts and raw source text (device-local evidence; regenerable), `normalizedText` for non-Library pieces, `LocalAvailability` (per-device by definition), payload bytes pending the CloudKit Asset spike.

CloudKit record size limits are respected by keeping `normalizedText` in a child record rather than inline on ContentPiece.

---

## D7 — Gmail authorization is spiked in Phase 0, not Phase 3.

One day of work, before any Gmail feature exists:

1. Create the OAuth client, request `gmail.modify`.
2. Move the app from testing to production, unverified, under the personal-use exemption.
3. Complete the flow, store the refresh token.
4. **Check on day 8 whether the refresh token still works.**

Unverified apps expire OAuth tokens after seven days, and developers report refresh tokens continuing to expire after moving to production under the personal-use exemption. If that happens here, a morning-ritual app needs weekly re-authorization, which is a product problem, not an implementation detail.

If the token dies, evaluate IMAP with an app password as the transport before building Today. IMAP maps cleanly onto Leave / Archive / Trash through label manipulation and sidesteps restricted scopes entirely. Verify current app-password availability at that point.

Failing this spike changes Phase 3–5 substantially. Failing it in Phase 3 wastes a phase.

---

## Consequences

- Phase 0 now produces a schema and an OAuth answer, not only a set of distinctions.
- Composition cost and latency become measurable at Gate 1, which is when the server question can be reopened with evidence.
- Convergent identity removes a class of CloudKit race conditions before they can be written.

## Amends

`ARCHITECTURE.md` §3, §5. `docs/DECISIONS.md` §2, §5, §6. `docs/V1-SCOPE-AND-SEQUENCING.md` §2, §3.
