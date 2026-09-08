# Cockpit Stream Management Experience

**Status:** Normative V1 product direction  
**Date:** 2026-09-08

Following is administration for Edition. It belongs under **Settings**, with contextual access from the Reader when useful.

The domain noun is `Stream`; the friendly management label is `Following`.

---

## 1. Settings position

Likely structure:

```text
SETTINGS

Following
Interest Areas
Personal Knowledge / You
Integrations
Other app settings
```

Following does not earn a sixth primary destination.

---

## 2. Interest-Area-first overview

The Following overview should organize Streams primarily by Interest Area.

Example:

```text
Travel & Places            11
Food & Wine                 9
Opinion & Commentary        6
Arts & Culture              7
Technology & Making         8
```

Counts are followed Streams, not unread ContentPieces.

An “Essentials” view may exist as a derived filter/group, but Essential is a Stream property, not an Interest Area.

---

## 3. One global Add Stream operation

There is one conceptual admission door.

```text
ADD STREAM
→ paste/enter something known
→ Cockpit resolves recurring transport
→ proposes Publisher/Creator
→ proposes Interest Area
→ proposes Handling
→ Essential on/off
→ Follow
```

A contextual Add action may pre-bias an Interest Area, but it must invoke the same global operation rather than create a second model.

---

## 4. V1 resolution ladder

Given a URL/known target:

### Direct feed

Validate RSS/Atom and derive title/publisher metadata where possible.

### Generic website autodiscovery

Inspect standard feed metadata and obvious linked feeds.

If one clear candidate exists, propose it. If several plausible feeds exist, show the small candidate set rather than silently guess.

### Narrow provider resolver

Use deterministic provider-specific resolution only where it is stable and worthwhile, such as YouTube channel/handle to stable channel/feed identity.

### Explicit failure

If unresolved:

> I couldn't find a recurring feed automatically. Paste its RSS/Atom URL instead.

Do not hide failure behind model confidence.

---

## 5. Confirmation emphasizes intent

Transport plumbing should not dominate setup.

Example:

```text
FOUND
NYT Travel
The New York Times

Interest Area
Travel & Places                  >

How Cockpit should handle this
Screen for distinctive destination, hotel, restaurant and
place reporting. Let major features hang around long enough
to register. Skip routine service-travel churn.

Essential                        Off

[ Follow ]
```

Raw feed URL and technical detail may live deeper for troubleshooting.

---

## 6. Normal Stream row

Keep rows/cards compact.

Likely visible:

- Stream name;
- Publisher/Creator identity/icon where useful;
- Essential indicator;
- concise Handling summary;
- cadence/last activity only as quiet metadata when useful;
- abnormal health only.

Do not routinely expose:

- raw feed URLs;
- channel IDs;
- sender-pattern internals;
- parser/enrichment strategy;
- deduplication state;
- model/ranking parameters;
- custody/file mechanics.

> **Healthy should be quiet. Broken should be visible.**

---

## 7. Stream detail

A Stream detail surface should answer:

- What is this?
- Why does Cockpit follow it?
- Where does it broadly belong?
- Is it Essential?
- Is it healthy?
- What should happen to qualifying future ContentPieces?
- For email transport, what should happen to the source message after processing?

Representative structure:

```text
MATTHEW YGLESIAS
Slow Boring

Interest Area
Opinion & Commentary             >

Essential
On

HOW COCKPIT HANDLES THIS
Always surface substantive primary posts. Give enough
orientation to decide whether to read. Never let them
silently age away.

[ Change… ]

LIBRARY
Automatically add future qualifying ContentPieces   Off

EMAIL SOURCE DISPOSITION
Archive after safe processing

Following                    On
Last received                Sep 8
Typical cadence              inferred

Pause
Stop Following
```

Not every inferred field needs visible V1 UI.

---

## 8. Editing Handling

`Change…` should allow natural-language correction rather than open a rules form.

Example:

> I care a lot about interesting new hotels, even expensive ones. I almost never care about generic airline or points-and-miles stories.

Cockpit may synthesize that into a concise durable Stream instruction and show the resulting interpretation.

Handling expresses editorial intent; implementation details remain Cockpit's job.

---

## 9. Contextual management from Reader

The best moment to correct Stream behavior may be when Cockpit makes a judgment the user disagrees with.

Reader may expose a lightweight path such as:

```text
From: Point-Free
Interest Area: Technology & Making

How Cockpit handles this Stream…
```

This should remain secondary to reading actions such as Dismiss, Later, Library, offline, Tell Cockpit, and Find/handoff.

---

## 10. Source disposition stays separate

For an email-delivered Stream:

- Handling/Essential determine editorial treatment;
- Gmail Source Disposition determines Leave / Archive / Trash after safe processing.

Do not expose this as one overloaded “Handling” field.

Archive is a natural default for valuable editorial material. Trash is allowed only under explicit disposable policy.

---

## 11. Automatic Library admission

A Stream detail may support an explicit prospective setting:

> Automatically add future qualifying ContentPieces to Library

This policy is independent of Edition selection and does not backfill history automatically.

Implement explicit Library first; then add one real Stream policy in V1.

---

## 12. V1 does not need

- publisher directory/catalog;
- autonomous “what else should I follow?” recommendations;
- giant subscription import/cleanup;
- universal email-publication discovery;
- advanced health dashboards;
- ranking sliders;
- generic rules engine;
- provider plumbing in primary UI.

The product goal is to express intent clearly while hiding mechanics.
