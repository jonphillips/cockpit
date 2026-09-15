# Cockpit Orientation — how the pieces fit

**Status:** Orientation / map. Non-normative — the deeper docs it points at are the authority.
**Date:** 2026-09-15

A one-page mental model for when the thread slips: *what are the nouns, and how do they relate?*
Read this first, then follow the links for the real contracts.

---

## The whole app in one noun

**The `ContentPiece` is the atom.** Everything else is either a **source** that produces one, or a
**lens** that points at one. Nothing copies a piece; the lenses hold references.

```text
SOURCES                    THE ATOM                 LENSES  (all point at ContentPieces)
─────────                  ────────                 ────────────────────────────────────
RSS / Atom feed ─┐                             ┌──  Edition entry   today's finite package + "why"
                 ├─► Artifact ─► ContentPiece ─┼──  Later           you kept it to read
Gmail message  ──┘   (raw)       (the substance)  └──  Library         you kept it for good
   (M4)
                                               ▲
                                     Personal Knowledge steers which pieces
                                     are admitted and how they're explained
                                     (the judgment pass)

        ┌──────────────────────────────────────────────────────────┐
        │  The Reader renders ONE ContentPiece, whichever lens you   │
        │  arrived through. One Reader for the whole app.            │
        └──────────────────────────────────────────────────────────┘
```

---

## The nouns

- **Artifact** — the raw fetched thing (an RSS item, a web page, an email message). Device-local and
  regenerable; throwaway. See `docs/ADR-0001-PERSISTENCE-AND-EXECUTION.md`.
- **ContentPiece** — the normalized, deduplicated **unit of substance** derived from an Artifact (the
  actual essay/post/article). Its identity is *derived*, not random, so the same piece arriving two
  ways converges to one. This is the noun everything points at. See `docs/CONTENT-PIECE-MODEL.md`.
- **Stream** — a source you follow (a feed, and in M4 an email-delivered publication), with editorial
  **Handling** (why you follow it, whether it's Essential). See `docs/CONTENT-STREAM-MODEL.md`,
  `docs/STREAM-MANAGEMENT-EXPERIENCE.md`.
- **Edition / EditionEntry** — the finite daily package, **materialized once per day**. An
  `EditionEntry` is a *reference* to a ContentPiece plus editorial context: section, rank, the
  `rationale` ("why you're seeing this"), and its `entryState` (seen / dismissed / carried / aged).
  The Edition points at pieces; it does not own them. See `docs/EDITION-EXPERIENCE.md`,
  `docs/IMPLEMENTATION-CONTRACT.md` §3.
- **Later / Library** — explicit **memberships**: lists of pointers to ContentPieces you kept. Later =
  "read it soon"; Library = "keep it for good." See `docs/LATER-LIBRARY-EXPERIENCE.md`.
- **Personal Knowledge** — durable, explicit Facts / Tastes / Interests about you, built only from
  explicit intent (never passive clicks). It feeds the judgment pass so relevance reflects *you*. See
  `docs/PERSONAL-KNOWLEDGE-MODEL.md`.
- **Pending Find** — a useful opportunity (a restaurant, a wine, a product) extracted from a piece,
  parked until a specialist app can receive it. See `docs/PRODUCT-MODEL.md`, `docs/CONTENT-PIECE-MODEL.md`.

---

## Two surfaces people confuse: Today vs Edition

They are different **lenses** with different questions.

- **Today** — *"What happened, and what deserves my attention?"* Gmail-driven (arrives in M4). A
  personal or consequential message lives here and may **never** become a ContentPiece. Its action is
  **Clear**. See `docs/TODAY-EXPERIENCE.md`.
- **Edition** — *"What is worth spending time reading?"* The finite morning package of ContentPieces.
  Its action is **Dismiss**. See `docs/EDITION-EXPERIENCE.md`.

Different words for different operations, on purpose: **Clear** (Today) is not **Dismiss** (Edition).

---

## Mail is just another source

An **editorial** newsletter in Gmail becomes an Artifact → ContentPiece via a Stream, exactly like
RSS — same spine, same Reader, same Edition. **Personal / consequential** mail does *not* become a
ContentPiece; it stays a Today attention concern. That is the whole split, and M4 is where Today and
Edition finally sit side by side. See `docs/EMAIL-INTELLIGENCE-MODEL.md`.

---

## The shell (the five destinations)

`Today · Edition · Later · Library · Settings` — with Following / Interest Areas / You (Personal
Knowledge) / Pending Finds under **Settings**. iPad renders these as a sidebar, iPhone as a tab bar,
from one structure. Every list is **list ∥ detail** feeding the one Reader; no full-width rows that
push to a separate screen. See `docs/IPAD-FIRST-EXPERIENCE.md`, and `docs/milestones/M3-shell-and-personal-knowledge.md`
(S1) for how the current shell gets there.

---

## Where the build is

The plan of record is `docs/V1-SCOPE-AND-SEQUENCING.md` (Phases 0–8, with architecture gates).
Sliced build orders live in `docs/milestones/`:

- **M1** — persistence spine, Streams, destinations, sync (done).
- **M2** — real judgment, Edition, Reader, the first agreement number (the morning loop).
- **M3** — the iPad shell (one Reader over every lens) + Personal Knowledge deepens → Gate 2.
- **M4** (proposed) — Gmail read-only Today, then dispositions and the email-delivered Stream.

Ratified product decisions are logged in `docs/DECISIONS.md`.
