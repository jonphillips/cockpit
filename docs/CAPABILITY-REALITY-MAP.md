# Cockpit Capability Reality Map

**Status:** Normative scope/reality map  
**Date:** 2026-09-08

This document prevents conceptual nouns from being mistaken for already-required infrastructure. It classifies current capabilities as **V1**, **Deferred**, or **Evidence required**.

Shapes live in `docs/IMPLEMENTATION-CONTRACT.md`; this map only says what is in and out.

---

## 1. Product shell

| Capability | Reality |
|---|---|
| Today | V1 |
| Edition | V1 |
| Later | V1, intentionally simple |
| Library | V1, intentionally simple |
| Settings | V1 |
| Following under Settings | V1 |
| Separate primary `Content` destination | Superseded by Edition |
| Separate primary `Following` destination | No |

---

## 2. Streams / Following

| Capability | Reality |
|---|---|
| Interest Areas | V1 |
| Streams | V1 |
| One primary Interest Area per Stream | V1 |
| Human-language Stream Handling | V1 |
| Essential Stream posture | V1 |
| Global Add Stream | V1 |
| RSS/Atom autodiscovery from known human URL | V1 |
| Narrow provider resolvers | V1 where justified |
| Pause / Stop Following | V1 |
| Basic abnormal health | V1 |
| Prospective auto-Library policy | V1 after manual Library works |
| Autonomous recommendations for new Streams | Deferred |
| Publisher-wide catalog/browser | Deferred |
| Historic YouTube/newsletter subscription cleanup | Deferred |
| Mailbox-wide automatic newsletter discovery | Deferred |

---

## 3. Content spine

| Capability | Reality |
|---|---|
| Artifact | V1 foundational concept |
| ContentPiece | V1 foundational concept |
| Derived (UUIDv5) ContentPiece identity | V1 architecture |
| `Edition` / `EditionEntry` as materialized entities | V1 architecture |
| `EditionEntry.rationale` as the why-surfaced record | V1 |
| Normalized text stored for every textual ContentPiece | V1 architecture |
| Edition/Later/Library memberships around same ContentPiece | V1 invariant |
| Conservative deterministic deduplication | V1 |
| Rich generic Artifact↔ContentPiece graph | Evidence required |
| Universal `Item` / `Thing` | Rejected |
| Universal cross-domain entity graph | Rejected |
| Canonical Restaurant/Product/Wine/Recipe models in Cockpit | Rejected |

---

## 4. Edition

| Capability | Reality |
|---|---|
| Finite morning-oriented Edition, composed once daily | V1 |
| Reader | V1 |
| Seen | V1 |
| Dismiss (Edition resolution; `Clear` is Today's) | V1 |
| Essential protection | V1 |
| Essential backlog relief valve | V1 |
| Batched judgment pass per `docs/JUDGMENT-CONTRACT.md` | V1 |
| Judgment evaluation harness + labelled fixture set | V1 from Phase 1 |
| Save for Later | V1 |
| Add to Library | V1 |
| Personal Knowledge affects relevance/explanation | V1 proof |
| Exact aging windows | Evidence required |
| Rich section taxonomy | Evidence required |
| Midday refresh system | Deferred/evidence required |
| Hero/card optimization | Evidence required |

---

## 5. Later

| Capability | Reality |
|---|---|
| Explicit Save for Later | V1 |
| No silent expiry | V1 law |
| Simple browse/open/remove | V1 |
| Add to Library | V1 |
| Offline controls | V1 |
| Cleanup assistant | Deferred until backlog exists |
| Sophisticated filters/facets | Deferred |
| Backlog analytics/reminders | Rejected for V1 |

---

## 6. Library

| Capability | Reality |
|---|---|
| ContentPieces only | V1 law |
| Explicit Add to Library | V1 |
| Metadata/provenance/summary | V1 |
| Ordinary text search | V1 |
| Lightweight Subjects | V1 if useful |
| Removal | V1 |
| Offline controls | V1 |
| Uploaded-payload custody | V1 |
| One prospective Stream auto-Library policy | V1 after manual flow |
| Vector/embedding retrieval | Evidence required |
| Folders/collections | Deferred |
| Rich facets | Evidence required |
| Universal entity graph | Rejected |

---

## 7. Custody / offline

| Capability | Reality |
|---|---|
| Reliable upstream source may remain authoritative | V1 architecture |
| Gmail Archive as authoritative source for ordinary Gmail-backed material | V1 architecture |
| Lightweight Cockpit understanding separate from payload | V1 |
| Uploaded sole-source payload preservation | V1 |
| Automatic local cache | V1 implementation concern |
| Offline until [date] | V1 |
| Keep Offline | V1 |
| Trip-aware offline package | Deferred |
| Bulk Edition/Later offline | Deferred |
| Stream-wide offline rules | Deferred |
| Exact CloudKit Asset design | Evidence/spike required |

---

## 8. Gmail / Today

| Capability | Reality |
|---|---|
| Gmail OAuth viability spike (`gmail.modify`, production-published client) | V1, Phase 0 — done 2026-09-11 |
| IMAP + app password as fallback transport | Evidence required — only if the spike fails |
| Read current Inbox | V1 |
| Summarize/classify | V1 |
| Worth Seeing / personal-consequential attention | V1 |
| Leave / Archive / Trash | V1 after read-only spike + ADR |
| Stream-specific email disposition | V1 |
| Small explicit non-Stream policies | V1 where useful |
| Processing/disposition barrier | V1 correctness law |
| Recent dispositions / Undo | V1 |
| Read/unread as Cockpit attention state | Rejected |
| Learned silent deletion | Rejected for V1 |
| AI policy suggestions | Deferred |
| Generic rules engine | Deferred/rejected absent evidence |
| Delete Forever | Not V1 |
| Auto-unsubscribe | Not V1 |
| General compose/reply | Not V1 |

---

## 9. Personal Knowledge

| Capability | Reality |
|---|---|
| Fact / Taste / Interest | V1 from Phase 1 |
| Direct teaching | V1 from Phase 1 |
| Jon Brain import before the first Edition | V1, Phase 1 |
| Teach from ContentPiece / why it matters | V1 |
| Correction/supersession | V1 |
| Provenance | V1 |
| Confirm hypothesis before durable inference | V1 |
| Jon Brain natural-language bulk import | V1 |
| LLM dedupe/consolidation/rollup of explicit claims | V1 |
| PK demonstrably affects relevance | V1 proof |
| Clickstream becomes durable PK | Rejected |
| Numeric confidence model | Deferred/likely unnecessary |
| Interest trajectories | Deferred |
| Monthly review | Deferred |
| Rich Notices inbox | Deferred |
| General contradiction engine | Deferred |
| Shared PersonalKnowledgeKit | Evidence required from second app |

---

## 10. Finds / Jon Universe

| Capability | Reality |
|---|---|
| Find as outbound product concept | V1 |
| Find extraction sharing the judgment call | V1 from Phase 1 |
| Lightweight Pending Find | V1 from Phase 1 |
| Broad descriptive kind/hints | V1 |
| One real receiver handoff | V1, Phase 6 |
| Receiver-owned canonical identity/validation | V1 law |
| Universal Find schema hierarchy | Rejected |
| Product/restaurant/wine canonical models in Cockpit | Rejected |
| Second receiver | Post-V1/evidence |
| Generic family queue/handoff kit | Evidence required from repeated consumers |
| New Shopping/Consumption/Cellar app | Wait for orphan Find evidence |

---

## 11. Cross-app context

| Capability | Reality |
|---|---|
| Small read-only Current Context projection from specialist app | V1 only when needed by a concrete slice |
| Galavant/current travel context affecting relevance | Strong future/near-V1 candidate |
| Family-wide context store | Deferred |
| Shared universal envelope | Deferred |
| Cross-app canonical entity graph | Rejected |

---

## 12. jon-platform

| Capability | Reality |
|---|---|
| House Swift architecture | Adopt |
| SQLiteData conventions | Adopt |
| CloudKit / CloudSyncKit | Adopt |
| Point-Free Dependencies | Adopt |
| LLMClientKit | Adopt |
| Semantic-fidelity doctrine | Adopt |
| Actionable-AI doctrine | Adopt |
| WebExtractorKit | Only when concrete web workflow earns it |
| LLMHandoffKit full session/persistence model | Do not adopt current Galavant-shaped form |
| New ContentStreamKit / PersonalKnowledgeKit / FamilyContextKit / JonLibraryKit | Do not create from first Cockpit use |

---

## 13. Execution and processing

| Capability | Reality |
|---|---|
| On-device ingestion, judgment, enrichment | V1 architecture |
| Edition materialized at first launch after day boundary | V1 |
| `BGProcessingTask` opportunistic pre-warm | V1, never relied upon |
| Designated ingesting device | V1 |
| Server / hosted worker / ingest service | Rejected for V1; reopenable at Gate 1 on cost and latency evidence |
| Composition cost and latency recorded on `Edition` | V1 |

---

## 14. Implementation rule

A `Deferred` or `Evidence required` capability must not quietly enter V1 because it looks architecturally elegant.

Promote it only when a real vertical slice demonstrates a concrete requirement, then update `docs/DECISIONS.md` and the relevant focused document.
