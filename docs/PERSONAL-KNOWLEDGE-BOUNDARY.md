# Cockpit Personal Knowledge Boundary

**Status:** Normative boundary decision  
**Date:** 2026-09-08

This document defines what Personal Knowledge is not, and how it relates to Current Context, evidence, agency, and other Jon Universe apps.

---

## 1. Personal Knowledge is durable understanding

Personal Knowledge contains explicit durable claims about Jon that should continue to matter across individual sessions and ContentPieces.

V1 coarse kinds are Fact, Taste, and Interest.

It is not:

- conversation transcript history;
- clickstream;
- every observation Cockpit has ever made;
- a task list;
- a policy/permission store;
- Current Context;
- a universal domain graph.

---

## 2. Evidence is not knowledge

Cockpit may observe behavior, receive source material, or generate hypotheses without converting those into durable Personal Knowledge.

Evidence can support a question or explanation. Durable knowledge requires explicit teaching/correction/confirmation.

Preserve enough provenance to understand where a claim came from, but do not build a surveillance warehouse merely to justify future inferences.

---

## 3. Current Context is separate

Current Context is temporary situational information useful for relevance.

Examples:

- current/near-future travel;
- where Jon is staying this week;
- an imminent flight;
- a current planning horizon;
- a temporary project/research focus.

Current Context may come from Cockpit itself or from small projections published by specialist apps such as Galavant.

Temporary context may influence ranking strongly while active, then expire/refresh without becoming Personal Knowledge.

---

## 4. Knowledge does not grant agency

A durable claim about preference does not authorize an external action.

Examples:

```text
Knowledge:
Jon dislikes routine Amazon shipping notices.

Policy:
Trash Amazon shipping notices after processing.
```

These are separate records/responsibilities.

Likewise, interest in Burgundy does not authorize purchases, subscriptions, bookings, or notifications.

Any provider mutation or consequential action requires a separately established mandate/policy.

---

## 5. Personal Knowledge does not own specialist domain truth

Cockpit may know:

> Jon prefers characterful countryside hotels.

Galavant may own canonical truth about a particular hotel/idea/trip.

Personal Knowledge should describe Jon, not absorb the complete state of every specialist domain.

Similarly, a recipe, restaurant, wine, or product discovered through content does not become Personal Knowledge merely because it is relevant.

---

## 6. Cross-app long-term ownership

Long term, multiple Jon Universe apps may benefit from shared durable Personal Knowledge.

The current direction is:

- Cockpit is the primary stewardship UI;
- V1 implementation is Cockpit-local;
- specialist apps may consume narrow projections when a concrete need appears;
- physical/shared ownership may be extracted only after at least one additional real consumer proves the common semantics.

Do not prebuild a family-wide Personal Knowledge database/package merely because sharing is foreseeable.

---

## 7. Corrections and provenance

Explicit correction is high-authority evidence.

Cockpit should preserve enough supersession/provenance to avoid silently rewriting history while making the current understanding clear.

A receiver of Personal Knowledge context should normally receive a task-appropriate projection of current claims rather than the entire historical evidence trail.

---

## 8. LLM-readable projections

Canonical Personal Knowledge remains structured application data.

For model tasks, Cockpit may generate concise prose/profile projections containing only relevant current knowledge and context.

Do not treat one generated profile paragraph as canonical truth.

This boundary keeps model prompts flexible while preserving deterministic ownership of durable knowledge.
