# Engine Affix Identity and Reward API

## Status

**MIGRATED** — 2026-09-10. The engine milestone shipped as
`build_engine @ 35b8f2fb5e1ddde1948284957438a1e363bb6c85` (`AffixPlugin`,
`package:build_engine/affix_plugin.dart`), and the Tome client migration
against it landed on branch `worktree-affix-migration`, commits
`6fee90b..b75e025`:

- `reward_affix.dart` deleted; `RewardAdapter` calls `resolveRewardAffixes`
  (offer, pure) + `acquireAffixes` (TAKE) and records each acquired affix via
  `AlmanacRecorder.recordAffixDiscovered` with the engine-minted `affixEventId`.
- `GameStoreAlmanacRepository` + app-lifetime `AlmanacSession` persist the
  Almanac across `EngineSession` rebuilds.
- `AlmanacAdapter` + the Almanac screen gained an `AFFIXES` group
  (recorded / canonical, discovered effect leaf, locked category-only secrecy).
- `CodexRepository` unchanged; no client affix vocabulary remains.

Originally written as a forward request for the engine milestone. The
requirements below are preserved as the record of what was asked for; the
engine's own `docs/superpowers/specs/2026-09-10-engine-affix-plugin-design.md`
is the design that answered it.

---

## Original status (superseded)

**BLOCKED — engine API gap.** Target engine revision inspected:
`build_engine @ b43b4147bb9224b01ed5818ad0fea5b03408586b`.

This specification records the minimum engine-side work required before Tome can migrate to **engine-owned affixes only**.

It was written as a forward request for a future `build_engine` milestone. That milestone was *expected* to modify `build_engine`; what was out of scope was doing engine work, or a client workaround, as part of the current Tome client task. Until the milestone landed, the client migration stayed paused.

No client compatibility table, renamed copy, or relocated copy of the current `reward_affix.dart` vocabulary was to be introduced.

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

The engine already contains Almanac infrastructure capable of recording affix history, but it does not currently own the canonical affix vocabulary or the reward-affix resolver.

Therefore the client cannot migrate cleanly to engine-owned affixes without an engine API addition.

---

## 2. Existing Engine Surface

The following APIs already exist and are usable at `b43b4147`:

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

* an affix definition model
* stable affix ids
* an affix category vocabulary
* canonical affix content definitions
* `ContentRegistry` `type: 'affix'`

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

## 4. Required Engine Affix Semantics

Introduce an engine-owned canonical affix definition.

The following is an **illustrative shape only — not a mandated engine class**:

```dart
// ILLUSTRATIVE — semantics, not a prescribed definition.
class AffixDefinition {
  final String id;       // stable opaque identity
  final String label;    // deterministic display label
  final String category; // canonical category
  final String stat;     // canonical mechanical target
  final num value;       // canonical mechanical magnitude
}
```

> The exact model name, field layout, inheritance/composition strategy, and storage representation are implementation decisions for build_engine. The requirements below describe the semantics that must be available, not a prescribed class definition.

The final schema should follow existing engine content conventions rather than duplicating client-only abstractions.

### 4.1 Canonical identity requirements

* stable opaque `id`, never derived from the display label
* deterministic label (an id may map to a label without a lore/flavour table)
* canonical category
* immutable definition
* serializable / content-registry compatible

### 4.2 Canonical mechanical requirements

* enough structured mechanical data for the engine/application boundary to apply the affix's intended effect without the client reconstructing it (see §8)
* canonical numeric magnitude(s) owned by the engine

### 4.3 Reward-selection metadata is NOT intrinsic affix identity

Physique affinity, rarity, tradition/style affinity, reward-context weighting, and "no affix" probability are **reward-selection policy**, not properties of the affix's identity. They must be engine-owned, but they need not live as fields directly on the affix definition. See §5 and §6.

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

### 5.1 Affix identity vs reward-selection policy

Two distinct canonical concerns, both engine-owned, kept separate:

```text
Affix definition                 Reward-selection policy
────────────────                 ──────────────────────
canonical identity (stable id)   rarity / weight
canonical display metadata       physique affinity
canonical mechanical payload     tradition / style affinity
                                 reward-context weighting
                                 "no affix" probability
```

The engine must own whatever canonical selection metadata or policy is required to reproduce the intended reward behaviour. The client must not own that policy.

Do not over-design a new policy subsystem if existing engine reward infrastructure (`RewardDefinition` / `RewardCandidate` weights, `RewardResolver`) can cleanly carry it.

---

## 6. Canonical Affix Rolling

The engine needs a deterministic public resolver.

Acceptable designs include either:

```dart
// ILLUSTRATIVE
AffixDefinition rollAffix(/* pool, reward context */ RngService rng);
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

The roll must use the engine RNG abstraction (`RngService`). No second RNG path.

The client must not continue to implement:

* affix probability
* affinity weighting
* prefix/suffix selection
* "no affix" probability
* affix selection pools

---

## 7. Reward Offer Identity and TAKE Semantics

The affix on a reward is resolved **once**, at reward generation, and stays fixed through preview and acquisition.

Lifecycle:

```text
reward generation
    ↓
resolved reward offer
    ↓
stable affix identity
    ↓
preview
    ↓
player TAKE
    ↓
apply canonical mechanics
    ↓
record discovery
```

### 7.1 Stable offer identity

Once an affix reward is presented, its selected affix must remain the same through preview and TAKE. Previewing the reward must not perform another affix roll.

### 7.2 Preview purity

Rendering or inspecting a reward candidate must have no gameplay side effects. Preview must not:

* consume RNG for a new affix roll
* record Almanac discovery
* mutate player state
* mark the affix as used

### 7.3 TAKE semantics

TAKE must operate on the already-resolved reward candidate:

```text
offer.affixId
    ↓
TAKE
    ↓
canonical engine definition
    ↓
mechanical application
    ↓
Almanac discovery
```

The following is forbidden:

```text
preview → roll A
take    → roll B
```

That makes displayed rewards unstable and breaks deterministic reward semantics.

---

## 8. Mechanical Application

The selected canonical affix must expose enough structured information for the engine / application boundary to apply its intended mechanics.

For item rewards, the engine must be able to derive the resulting stat modification from the canonical affix rather than requiring the client to reconstruct:

```text
label → effect → amount
```

For technique rewards, the engine must define the canonical semantics for one-shot effects such as healing or banking progression.

The client must not reconstruct semantics from:

```text
label
prefix/suffix name
hardcoded effect enum
hardcoded number
```

The engine-side design should avoid encoding UI concepts such as "prefix" or "suffix" as the fundamental identity model. Those may remain reward-presentation concepts if the engine design determines they are not fundamental domain identity.

### 8.1 Non-stat affix mechanics

> Canonical affix mechanics are not restricted to stat/value modifications. The engine model must represent every supported affix effect type, including non-stat effects such as immediate healing or progression banking, without requiring the client to infer semantics from labels, prefix/suffix names, or other presentation data.

Both of these families must be representable through engine-owned canonical mechanics:

```text
Attack +3
Defense +2
Initiative +3
```

```text
heal immediately
bank progression
other future non-stat effects
```

The implementation remains an engine design decision. Do **not** prescribe a new `AffixEffect` class or specific field layout unless the existing engine architecture requires it.

The invariant is:

```text
canonical engine affix data
        ↓
canonical engine / application mechanics
```

and never:

```text
client label / name
        ↓
client interprets meaning
```

---

## 9. Almanac Recording Contract

When an affix is actually taken, the composition layer may record:

```dart
almanacRecorder.recordAffixDiscovered(
  affixId: definition.id,
  observation: /* carries the canonical acquisition-event identity */,
  snapshot: AffixSnapshot(
    affixId: definition.id,
    stat: definition.stat,
    value: definition.value,
    category: definition.category,
  ),
  timestamp: ...,
);
```

The client must not invent the `AffixSnapshot`. The snapshot must be derived from the engine-owned canonical affix.

### 9.1 `affixEventId` ownership

> The engine defines the acquisition-event identity contract. The engine reward / run layer is authoritative for creation of the acquisition-event identity. The composition layer may transport or forward that identity to Almanac recording, but must not manufacture or replace it.

```text
Acquisition event identity
    → build_engine reward / run layer

Composition layer
    → receives event identity → forwards it

Tome client
    → must not generate substitute affixEventIds
```

Explicitly prohibited as a replacement for the engine acquisition-event identity:

```text
client-generated UUID
client-generated timestamp-based id
client counter
random id generated at TAKE
```

Why: the engine Almanac is idempotent on `(affixId, affixEventId)`. The event identity must therefore represent the actual canonical acquisition event, so it must be stable and authoritative. The contract must prevent this failure mode:

```text
same affix acquired
    ↓
client invents a new random event id each time
    ↓
Almanac sees different events
    ↓
duplicate history
```

### 9.2 Discovery timing

```text
reward preview
    → no discovery

player takes reward
    → apply canonical affix
    → record affix discovery
```

The existing Almanac idempotency contract must remain intact.

---

## 10. Producer / Bridge Requirement

One of the following must be provided.

### Preferred

The engine run / reward layer produces a canonical taken-reward result / event containing:

* stable reward / acquisition event identity
* selected affix identity
* the canonical affix definition, or an engine identity that resolves to it

### Acceptable

The composition layer receives the canonical engine affix result and performs the Almanac recording call. The contract must be documented.

### In either case

The engine reward / run layer is authoritative for the acquisition-event identity. The composition layer may only transport that identity to Almanac recording; it must not manufacture or replace it.

* the client does not define the affix
* the client does not roll the affix
* the client does not construct canonical mechanical values
* the client does not create or substitute `affixEventId` — it forwards the engine's

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

## 11. Implementation Boundary

Five distinct concerns, and where each is owned:

| Concern | Owner |
|---|---|
| **Affix definition** — stable id, display metadata, mechanical payload | build_engine (canonical content) |
| **Reward-selection policy** — rarity, affinity, context weighting, "no affix" chance | build_engine (canonical, may be separate content/config) |
| **Reward offer** — the resolved candidate shown to the player, fixed at generation | build_engine reward layer |
| **Acquisition event** — the canonical TAKE / acquisition event and its stable `affixEventId` | **build_engine reward / run layer** |
| **Almanac observation** — the recorded `(affixId, affixEventId)` history entry | build_engine Almanac, fed at the composition boundary |

> The composition boundary is responsible only for forwarding / recording the authoritative event; it is not the source of event identity. Almanac ownership stays in build_engine.

```text
                BUILD ENGINE
┌──────────────────────────────────────────────┐
│ canonical affix identity / definitions       │
│ reward-selection policy                       │
│ deterministic affix resolution               │
│ canonical reward acquisition identity         │
│ mechanical application                        │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
              composition boundary
                       │
          ┌────────────┴────────────┐
          ▼                         ▼
   Tome presentation          Almanac recording
   / reward UI                recordAffixDiscovered
```

> Tome may present engine-owned reward data, but it must not become the source of truth for affix identity, mechanics, selection, or acquisition identity.

---

## 12. Tome Client Migration Unblocked by This Spec

Once the engine API exists, Tome should:

1. Delete `lib/core/engine/reward_affix.dart`.
2. Remove client-owned affix rolling.
3. Remove client-owned affix mechanical definitions.
4. Route reward selection through the engine affix API.
5. Record taken affixes through the engine Almanac, forwarding the canonical `affixEventId`.
6. Extend `AlmanacAdapter` with engine-derived affix views.
7. Add an `AFFIXES` Almanac group.
8. Enumerate the affix roster from engine content.
9. Display only discovered mechanical details for discovered affixes.
10. Keep locked affixes intentionally undisclosed.

`CodexRepository` remains unchanged. Affix discovery belongs to the engine Almanac path, not a fourth Codex bucket.

---

## 13. Acceptance Criteria

The engine work is complete only when all are true:

* canonical affix definitions exist in build_engine
* every canonical affix has a stable opaque id
* affixes are enumerable without client tables
* reward resolution can select an affix through engine APIs
* affix selection uses `RngService`
* mechanical values come from engine-owned canonical data
* the selected affix can be applied without client-owned canonical data
* **every supported affix mechanic, including non-stat mechanics (immediate heal, progression banking, future non-stat effects), is representable through engine-owned canonical data**
* the client never infers affix mechanics from presentation labels, prefix/suffix names, or other display data
* **engine-owned reward-selection logic can deterministically select valid affixes using canonical engine data and the applicable reward context** — physique/affinity/rarity weighting is owned by that logic rather than required to be a field directly on the affix model
* affix reward offers have stable identity from generation through TAKE
* previewing an offer does not reroll or mutate state
* TAKE uses the already-resolved offered affix
* the engine reward / run layer defines the canonical acquisition-event identity
* the composition layer can forward that identity without creating a replacement
* no client-generated event id is required for Almanac correctness
* repeated processing of the same canonical acquisition event remains idempotent
* a taken affix can be recorded using its engine definition
* Almanac serialization / hydration preserves the record
* duplicate `(affixId, affixEventId)` recording remains idempotent
* headless tests cover definition, roll, offer stability, application, and recording
* public package exports expose the required API
* the client cannot reproduce the canonical affix roster by maintaining a parallel table

---

## 14. Explicit Non-Goals

This engine change does not require:

* redesigning the Almanac storage schema
* changing `CodexRepository`
* changing Tome visual design
* introducing client-side affix registries
* duplicating engine content into UI adapters
* changing unrelated reward mechanics
* redesigning item or technique systems beyond the minimum affix integration
* prescribing the exact engine affix-definition class shape
* prescribing the exact representation of non-stat affix mechanics
* forcing physique / reward weighting into the affix model
* requiring prefix / suffix to be fundamental affix-domain concepts
* creating a parallel client-side reward-selection policy
* allowing the composition layer to invent acquisition-event identities
* deriving mechanics from display labels or reward-presentation terminology
* introducing a second RNG path

---

## 15. Current Blocker — RESOLVED

At `b43b4147` this read:

> Almanac persistence is available, but canonical affix identity, canonical reward selection, canonical mechanical ownership, and authoritative taken-event identity are not available as a complete public engine contract.

All four landed at `build_engine @ 35b8f2fb` (`AffixPlugin`): `AffixDefinition`
+ `type:'affix'` content, `resolveRewardAffixes` (deterministic 2-slot,
`RngService`), `AffixMechanic` (stat + heal + bank), and
`AffixAcquisitionIdSource` / `acquireAffixes` (engine-minted `affixEventId`,
one `AffixAcquisition` per affix). The client migration in §12 was completed
against it — see the Status section at the top of this file.
