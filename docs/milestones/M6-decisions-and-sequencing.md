# M6 — decisions, sequencing, and the deferred ledger

> **Read-first forward-carry doc.** Architect-recorded 2026-09-21 from the M6 design session. It exists
> so decisions that outlive a slice — especially the things we chose *not* to do yet — have a durable
> home instead of evaporating in chat or a PR comment. Companion to the slice/design notes:
> `M6-S1-series-trash-after-reading.md` (shipped, in review), `M6-gate5-find-handoff-design.md`
> (rationale), and `M6-gate5-find-handoff-slice-plan.md` (contract + decomposition).

## M6 shape

M6 has **two anchors**, each a real architectural test at a different seam. Everything else is
deferred, contingent, or a permanent boundary (see the ledger below). We deliberately did **not** pack
all the 2026-09-18 M6 candidates into M6 — that would tangle four risk types (model separation,
cross-app contract, quota-at-scale, prospective-policy authority) behind two gates in one milestone.

- **Anchor 1 — Email-delivered recurring Stream → Gate 4** (the separation test). Proves Transport /
  Artifact / ContentPiece / Stream Handling / source disposition / Edition state are genuinely
  separable, under real recurring newsletters (Yglesias, Puck, Sepinwall). **Product call: reachable-
  first is the default** (not promote-into-the-package); §24 inheritance holds for the email transport.
  Already partly de-risked: **M6 S1 + ADR-0002 D9** demonstrated the source-disposition-independent-of-
  custody axis (custody survives a trash). First check when slicing: **unify the recurring-email-series
  identity** — the `GmailSeriesKey`/`GmailStreamResolver.locatorKeys` normalizer is the same "this
  newsletter" identity an email-delivered Stream binds to; do not fork a parallel locator.
- **Anchor 2 — First specialist Find handoff → Gate 5** (the cross-app boundary test). Receiver = **Yes
  Chef (recipes)**, user-initiated, App Intent, raw text + provenance across the line, receiver owns all
  intelligence, set-valued verdict, custody per-app. Full design in `M6-gate5-find-handoff-design.md`.

Sequencing: **Gate 4 is the spine** (foundational; continuous with S1/D9). Gate 5 can proceed largely
in parallel (extraction exists; receiver work is mostly in `jon-platform`), but its *gate review*
trails Gate 4 because a Find's provenance/custody story rests on the ContentPiece/Stream separation
being settled.

---

## The ledger — three buckets, kept distinct on purpose

A deferred list fails when a by-design "never" gets re-litigated as a "not yet." So:

### A. Deferred but wanted — revisit when the dependency/trigger clears

| Item | Why deferred | Revisit when |
| --- | --- | --- |
| **Promote-into-the-package** for email Streams | reachable-first is the default to observe; promote is *additive* and is authority-on-the-keep-side | Gate 4 closed **and** real use shows reachable-first is insufficient. **Gate 4 closed 2026-09-25; Jon doesn't want it (DECISIONS §24, Gate 4 ratification). No trigger.** |
| **Auto-routing** of Finds to receivers | first handoff is user-initiated (agency); auto-routing is authority-flavored | after Gate 5 proves the manual boundary |
| **A second Find receiver / any generalized HandoffKit** | APP-FAMILY §7/§9 — one receiver end-to-end first | after Gate 5; a 2nd receiver is the earliest credible evidence for shared handoff infra |
| **Auto-Library policy (Phase 7)** | prospective keep-policy = authority on the keep side | after Library + custody trustworthy, i.e. after Gates 4 **and** 5. **Must NOT reuse `isSubstantivePrimary` as keep-criterion (DECISIONS §18)** — that conflates "attention today" with "keep forever" |
| **Promotions/Social at scale (#5)** | value (retail/wine Finds) only lands once a receiver exists; it's operational/quota hardening, no gate, own budget/cadence (ADR-0002 D2) | after Gate 5 (Finds need a home); tests whether the D2 quota budget holds at 16k/14k, not just 79 Primary |
| **S1 follow-ups** | out of the S1 slice on purpose | see `M6-S1-series-trash-after-reading.md`: propose-and-confirm nudge; per-message "keep before it trashes"; subject-template series-key fallback; global on/off + Settings management. **Plus review nit:** `RecentTrashRequest` is unbounded — add a `.limit`/window |
| **Yes Chef → Cockpit Current Context** (inbound projection) | separate direction from the Find handoff (APP-FAMILY §1/§2) | when a concrete Cockpit use for cooking context appears |

### B. Contingent — triggered by a measurement, not a date; do not schedule

| Item | Trigger | Gate |
| --- | --- | --- |
| **Type-call model swap** (M4-S1 PK-free classification → cheaper model) | S5's recorded on-device tail recompose stays well over the §7 60s budget **and** the progress affordance doesn't make it tolerable | capability-gated: the cheaper model must reliably emit the PK-free classification schema. Largely dissolved by §24 (curated mail skips the editorial pass; the §23 two-pass latency is tail-only). **De-listed from active M6 planning** — measure (S5) before scheduling |

### C. Permanent boundaries — by design "no", not "not yet". Do not re-open as deferrals.

- **Cockpit never learns specialist domain schema** (recipe, reservation, wine, product, …). It refers
  typed raw text + provenance; parsing/LLM/dedup/admission live in the receiver (APP-FAMILY §3/§4/§6).
- **No universal family ontology / `Thing`**, no Family Context Store, shared queue, universal envelope,
  entity graph, notification bus, App-Group acceleration, shared `FamilyContextKit`/`HandoffKit`, or
  two-way canonical cross-app sync — until repeated real consumers prove each (APP-FAMILY §9/§10).
- **No generalized disposition rules engine, learned auto-deletion, automatic unsubscribe, or
  `Delete Forever`** (ADR-0002 D5/D7; DECISIONS §7). Policies stay explicit and user-established;
  propose-and-confirm, if ever built, remains a *proposal* until accepted.

---

## Cross-references

- `docs/ADR-0002-…` D4 (barrier), D5 (label ops, no Delete Forever), D6 (Undo log), D7 (explicit
  authority), D8 (custody ≠ disposition), D9 (external-only departure reconciliation), D10 (read-
  triggered series-scoped disposition — M6 S1).
- `docs/APP-FAMILY-INTERACTION.md` — the normative cross-app boundary Gate 5 builds inside.
- `docs/DECISIONS.md` §7 (disposition), §18 (`isSubstantivePrimary` is not a durability signal), §23
  (two-pass latency), §24 (curated streams, reachable-first, dissolved promotion).
