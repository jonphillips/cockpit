# Cockpit Personal Knowledge Model

**Status:** Normative V1 product/domain decision  
**Date:** 2026-09-08

Personal Knowledge is Cockpit's durable explicit understanding of Jon.

It exists to make judgments materially better without turning Cockpit into a behavioral surveillance warehouse or a profile-maintenance chore.

Personal Knowledge is built in **Phase 1**, alongside the first Edition rather than after it. Judgment tuned against an empty profile is judgment that has to be tuned twice. How claims reach the model is specified in `docs/JUDGMENT-CONTRACT.md` §2.

---

## 1. Governing principle

> **Durable Personal Knowledge comes from explicit human intent, not passive clickstream inference.**

Jon may have decades of experience demonstrating that opens, clicks, dwell time, saves, and browsing frequency are ambiguous. Cockpit should respect that ambiguity.

Behavior may influence transient ranking or cause Cockpit to ask a useful question. It does not silently become durable truth.

Concretely, the judgment pass never receives clickstream, dwell time, or open history. Admitting them there would launder weak behavioral signal into ranking through the back door while the letter of this principle was preserved.

---

## 2. V1 knowledge kinds

Keep the initial durable model coarse.

### Fact

A truth-apt statement or constraint.

Examples:

- Home airport is RDU.
- A particular person has a dietary preference relevant to recommendations.

### Taste

A relatively durable preference or decision tendency.

Examples:

- Prefers smaller, characterful countryside luxury hotels over large corporate-feeling properties.
- For dry Riesling, generally prefers some fruit rather than severe austerity.

### Interest

A subject/domain Jon explicitly wants Cockpit to notice meaningfully.

Examples:

- Strong current interest in Burgundy travel and wine.
- Meaningful interest in kitchen design.

Do not add a large subtype taxonomy until real use proves it necessary.

---

## 3. Valid durable inputs

Personal Knowledge may become durable when Jon:

- directly teaches Cockpit something;
- corrects an existing understanding;
- explicitly explains why a ContentPiece mattered or what it reveals about him;
- confirms a hypothesis Cockpit asks about;
- bulk-imports explicit synthesized claims through the Jon Brain / Teach Cockpit workflow.

Ordinary annotation is not automatically teaching. The user intent to have Cockpit learn should be clear.

---

## 4. Behavior may trigger a question

Cockpit may notice patterns such as repeated Burgundy attention and ask:

> You seem to be spending meaningful attention on Burgundy. Is this something you want me to treat as an Interest?

Until Jon confirms, that remains a hypothesis/Notice-like observation rather than durable Personal Knowledge.

Conceptually:

```text
weak/behavioral evidence
→ possible hypothesis
→ ask Jon
→ confirmation
→ durable Personal Knowledge
```

Never:

```text
clickstream
→ durable Personal Knowledge
```

V1 does not need a rich Notice inbox to support this principle.

---

## 5. Teach from a ContentPiece

The Reader should eventually support an explicit teaching affordance such as:

- Tell Cockpit why this matters;
- Teach Cockpit;
- Correct this understanding.

This is higher-quality evidence than behavior because Jon supplies the reason.

Example:

> I am not especially interested in this specific hotel, but I care about this kind of adaptive reuse.

Cockpit may synthesize that into a scoped durable Taste/Interest claim while retaining provenance back to the explicit teaching event and relevant ContentPiece.

---

## 6. LLM synthesis is housekeeping, not authority expansion

Jon should not need to manage Personal Knowledge daily.

The LLM may autonomously:

- deduplicate overlapping explicit claims;
- consolidate compatible claims;
- roll up repeated explicit evidence;
- normalize wording;
- reorganize the representation for clarity.

It may do this without prompting Jon for every clerical rewrite **only when semantic meaning is preserved**.

Good synthesis:

```text
“I like smaller luxury hotels.”
“I prefer countryside locations.”
“I dislike corporate-feeling resorts.”

→

“Prefers smaller, characterful countryside luxury hotels
over large corporate-feeling properties.”
```

Bad synthesis:

```text
→ “Jon dislikes cities.”
```

The latter is a materially new claim and requires confirmation.

---

## 7. Scope beats numeric confidence

Cockpit should invest in appropriately scoped language rather than artificial precision such as `confidence = 0.83`.

Example:

Too broad:

> Likes fruity wines.

Better:

> When drinking dry Riesling, generally prefers some fruit/generosity rather than severe austerity.

The LLM can help propose appropriately scoped claims. It must not overgeneralize.

V1 does not require durable numeric confidence, salience, half-life, or trajectory fields.

---

## 8. Provenance

Cockpit should retain enough lineage to answer:

> Why do you think this?

Useful provenance may include:

- directly stated by Jon;
- corrected by Jon;
- explicitly taught from ContentPiece X;
- confirmed from a Cockpit hypothesis;
- imported through Jon Brain;
- synthesized from specific explicit claims.

This does not require a giant behavioral evidence graph.

Provenance exists to support trust, correction, resynthesis, and semantic fidelity.

---

## 9. Correction and supersession

Correction is more important than confidence scoring.

When Jon says an understanding is wrong/incomplete, establish the corrected current claim and preserve enough history to know the old understanding was superseded.

Conceptually:

```text
old claim
→ superseded by
new current claim
```

Do not silently erase all prior provenance, and do not require the user to resolve numerical confidence.

Some apparent contradictions may reflect changed taste or context. V1 does not need a generalized contradiction-resolution engine; ask Jon when synthesis cannot reconcile safely.

---

## 10. Current Context is separate

Temporary situational information must not pollute Personal Knowledge.

Examples of Current Context:

- staying at Forestis this week;
- flying to Munich tomorrow;
- planning a specific Burgundy trip;
- current project/research focus when clearly transient.

Current Context may strongly influence relevance while active, then disappear naturally.

A temporary context should become durable Interest/Taste only through explicit teaching/confirmation.

---

## 11. Knowledge does not grant agency

Personal Knowledge answers:

> What matters to Jon / what is true about Jon's preferences and interests?

Policy/mandate answers:

> What is Cockpit allowed to do?

Knowing that Jon dislikes routine Amazon shipment notices does not authorize Trash. That requires a separate explicit Gmail disposition policy.

Knowing that Jon likes Burgundy does not authorize buying wine, subscribing to newsletters, booking hotels, or notifying him constantly.

Keep knowledge and agency separate.

---

## 12. Stewardship UI

Personal Knowledge should not require daily maintenance.

Most teaching/correction should happen in context:

- direct instruction;
- Reader teaching;
- correction from an explanation;
- occasional confirmation of a useful hypothesis;
- Jon Brain bulk import.

A `You` / Personal Knowledge Settings surface should primarily support:

- inspection;
- deliberate teaching;
- correction;
- perhaps retirement/removal.

Monthly review, rich Notices, trajectories, and generalized contradiction review wait until real usage shows they would be useful rather than annoying.

---

## 13. Personal Knowledge must affect the product

V1 should not build a beautiful profile store that has no consequence.

The proof is behavioral:

```text
explicit Personal Knowledge
+
new ContentPiece
→ materially different ranking / surfacing / explanation
```

Example:

> Because you explicitly care about adaptive-reuse hotels, this opening appears unusually relevant.

The explanation should be correctable from the same interaction.

---

## 14. V1 persistence guidance

A minimal durable claim needs enough to represent:

- broad kind: Fact / Taste / Interest;
- semantic claim;
- scope/context where needed;
- provenance;
- current versus superseded/retired status;
- linkage to explicit evidence where useful.

Do not add numeric confidence, trajectory enums, universal entity graphs, or salience mathematics before demonstrated need.

---

## 15. Cross-app future

Long term, Personal Knowledge may become shared across Jon Universe apps, with Cockpit remaining the primary stewardship surface.

V1 should implement the real Cockpit requirement app-locally behind a movable seam.

Do not create `PersonalKnowledgeKit` before a second real application demonstrates which semantics are actually shared.
