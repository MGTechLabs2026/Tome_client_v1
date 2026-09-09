# Engine Affix Identity and Reward API

## Status

**BLOCKED — engine API gap**

Target engine revision inspected:

`build_engine @ b43b4147bb9224b01ed5818ad0fea5b03408586b`

This specification records the minimum engine-side work required before Tome can migrate to **engine-owned affixes only**.

No client compatibility table or renamed copy of the current `reward_affix.dart` vocabulary should be introduced.

---

## 1. Problem

Tome currently has a client-owned affix system in:

`lib/core/engine/reward_affix.dart`

That system defines:

* affix identity
* labels
* lean/affinity
* mechanical effect
* numeric value
* reward rolling
* item/technique affix semantics

The engine already contains Almanac infrastructure capable of recording affix history, but it does not currently own the canonical affix vocabulary or reward-affix resolver.

Therefore the client cannot migrate cleanly to engine-owned affixes without an engine API addition.

---

## 2. Existing Engine Surface

The following APIs already exist and are usable:

### Almanac

Public through:

`package:build_engine/almanac.dart`

Available:

* `AlmanacRecorder.recordAffixDiscovered(...)`
* `AlmanacRecorder.recordAffixUsed(...)`
* `AffixObservation`
* `AffixSnapshot`
* `AlmanacAffixRecord`
* `AlmanacState.affixes`
* `AlmanacQueries.getAffixHistory(...)`
* `AlmanacQueries.mostUsedAffixes(...)`
* `AlmanacRepository`
* `InMemoryAlmanacRepository`
* `JsonFileAlmanacRepository`
* Almanac JSON serialization schema v1

Affix discovery idempotency is keyed by:

`(affixId, affixEventId)`

The engine test suite already verifies repeated events do not duplicate the record.

### Item mechanics

Public through:

`package:build_engine/item_plugin.dart`

Available:

* `ItemInstance.statBonuses`
* `addItemStatBonuses(...)`

The current Tome reward path already uses the item stat-bonus mechanism.

---

## 3. Missing Canonical Affix Identity

The engine currently has no equivalent of:

* `AffixDefinition`
* `AffixIds`
* `AffixCategory`
* canonical affix content definitions
* ContentRegistry `type: 'affix'`

`AffixSnapshot` is only a recorded observation:

* `affixId`
* `stat`
* `value`
* `category?`

It does not define what an affix is or how it should behave.

The engine therefore cannot currently answer:

> "What are the valid affixes in the game?"

without receiving those answers from the client.

That is the primary blocker.

---

## 4. Required Engine Affix Definition

Introduce an engine-owned canonical affix definition.

The exact class name may differ, but it should provide the equivalent of:

```dart
class AffixDefinition {
  final String id;
  final String label;
  final String category;
  final String stat;
  final num value;
  final Map<String, num> physiqueWeights;
}
```

The final schema should follow existing engine content conventions rather than duplicating client-only abstractions.

Requirements:

* stable opaque `id`
* deterministic label
* canonical mechanical data
* canonical category
* canonical numeric value
* canonical physique/reward weighting data
* immutable definition
* serializable/content-registry compatible

Do not derive identity from the display label.

---

## 5. Registry Integration

Affixes should be engine-owned enumerable content.

Preferred direction:

```text
ContentRegistry
    └── type: "affix"
          ├── plain
          ├── sturdy
          ├── keen
          └── ...
```

The engine must expose enumeration equivalent to the existing:

```dart
registry.allOfType('affix')
```

This is necessary for:

* reward generation
* Almanac enumeration
* validation
* future balancing tools
* deterministic testing
* content completeness checks

The client must not maintain a second canonical affix list.

---

## 6. Canonical Affix Rolling

The engine needs a deterministic public resolver.

Acceptable designs include either:

```dart
AffixDefinition rollAffix(
  ...
  RngService rng,
)
```

or integrating affixes into the existing reward-candidate pipeline.

The important contract is:

```text
engine reward logic
        ↓
canonical affix definition
        ↓
stable affixId
        ↓
mechanical application
        ↓
Almanac observation
```

The roll must use the engine RNG abstraction.

The client must not continue to implement:

* affix probability
* affinity weighting
* prefix/suffix selection
* `no affix` probability
* affix selection pools

---

## 7. Mechanical Application

The selected `AffixDefinition` must be sufficient to apply its canonical mechanics.

For item rewards, the engine must be able to derive the resulting stat modification from the affix definition rather than requiring the client to reconstruct:

```text
label → effect → amount
```

For technique rewards, the engine must define the canonical semantics for one-shot effects such as healing or banking progression.

The engine-side design should avoid encoding UI concepts such as "prefix" or "suffix" as the fundamental identity model unless those concepts are genuinely part of the canonical game model.

---

## 8. Almanac Recording Contract

When an affix is actually taken, the composition layer may record:

```dart
almanacRecorder.recordAffixDiscovered(
  affixId: definition.id,
  observation: ...,
  snapshot: AffixSnapshot(
    affixId: definition.id,
    stat: definition.stat,
    value: definition.value,
    category: definition.category,
  ),
  timestamp: ...,
);
```

The client must not invent the `AffixSnapshot`.

The snapshot must be derived from the engine-owned `AffixDefinition`.

Discovery timing:

```text
reward preview
    → no discovery

player takes reward
    → apply canonical affix
    → record affix discovery
```

The existing Almanac idempotency contract should remain intact.

---

## 9. Producer / Bridge Requirement

One of the following must be provided:

### Preferred

The engine run/reward system emits a canonical affix-taken event/result containing the selected `AffixDefinition` or `affixId`.

### Acceptable

The composition layer receives the canonical `AffixDefinition` and is explicitly responsible for calling:

`recordAffixDiscovered(...)`

The contract must be documented.

What must not happen:

```text
client invents affix definition
        ↓
client constructs AffixSnapshot
        ↓
engine merely stores it
```

That leaves canonical game content in the client.

---

## 10. Tome Client Migration Unblocked by This Spec

Once the engine API exists, Tome should:

1. Delete `lib/core/engine/reward_affix.dart`.
2. Remove client-owned affix rolling.
3. Remove client-owned affix mechanical definitions.
4. Route reward selection through the engine affix API.
5. Record taken affixes through the engine Almanac.
6. Extend `AlmanacAdapter` with engine-derived affix views.
7. Add an `AFFIXES` Almanac group.
8. Enumerate the affix roster from engine content.
9. Display only discovered mechanical details for discovered affixes.
10. Keep locked affixes intentionally undisclosed.

`CodexRepository` should remain unchanged.

Affix discovery should belong to the engine Almanac path rather than becoming a fourth Codex bucket.

---

## 11. Acceptance Criteria

The engine work is complete only when all are true:

* canonical affix definitions exist in build_engine
* every canonical affix has a stable opaque ID
* affixes are enumerable without client tables
* reward resolution can select an affix through engine APIs
* affix selection uses `RngService`
* mechanical values come from engine-owned definitions
* the selected affix can be applied without client-owned canonical data
* a taken affix can be recorded using its engine definition
* Almanac serialization/hydration preserves the record
* duplicate `(affixId, affixEventId)` recording remains idempotent
* headless tests cover definition, roll, application, and recording
* public package exports expose the required API
* no client compatibility table is required

---

## 12. Explicit Non-Goals

This engine change does not require:

* redesigning the Almanac storage schema
* changing `CodexRepository`
* changing Tome visual design
* introducing client-side affix registries
* duplicating engine content into UI adapters
* changing unrelated reward mechanics
* redesigning item or technique systems beyond the minimum affix integration

---

## 13. Current Blocker

At `b43b4147`, the blocker is:

> **The engine can persist affix observations but cannot authoritatively define or produce an affix.**

Therefore the Tome migration is intentionally paused.

The correct next implementation target is an **engine affix identity + registry + reward-resolution API**, after which the client migration can proceed without architectural compromise.
