# Resolved Engine API — affix migration (Task 0 output)

**Engine revision:** `build_engine @ 35b8f2fb5e1ddde1948284957438a1e363bb6c85`
(branch `design/engine-owned-affix-api` merged to `main`; was `b43b4147`).
**Public barrel:** `package:build_engine/affix_plugin.dart` — import this, never `src/plugins/affix/...`.
**Engine design doc (authoritative):** `built_engine/docs/superpowers/specs/2026-09-10-engine-affix-plugin-design.md`
— "when this milestone merges, the client's Task 0 … consumes **this file** as its Resolved Engine API note."

Every `// SPEC §N — reconcile in Task 0` marker in the plan maps to a real symbol below.

---

## 1. Plugin registration

`class AffixPlugin extends GamePlugin` — `AffixPlugin().initialize(context)`.
Engine `game_run.dart` order: `Combat → MartialArts → Physique → Item → Technique → Consumable → Affix`.
**Client `EngineSession`:** add `AffixPlugin().initialize(context);` **after** `TechniquePlugin().initialize(context);`.
`AffixPlugin` needs only the Item/Technique content domains present when the resolver runs — no hard `ConsumablePlugin` dependency. (Whether the `b43b4147→35b8f2f` bump obliges the client to also add `ConsumablePlugin` is a compile-check outcome, not an affix requirement.)

Idempotent: skips its content batch if `context.content.withTag('affix').isNotEmpty`. Full §9 validation runs at `initialize` (amount>0, exactly one `lean:*`, exactly one `affix_pool:*`, pool⇔category, pool⇔mechanic-family).

## 2. Canonical definition

```dart
class AffixDefinition {
  final String id;        // opaque 'af_*'
  final String label;     // the ONLY display string; deterministic
  final String category;  // one of AffixCategories.all
  final AffixLean lean;   // neutral | force | flow
  final AffixMechanic mechanic;
}
AffixDefinition affixDefinitionFromContent(ContentDefinition d);
AffixDefinition affixDefinition(String id, PluginContext context);
```

`enum AffixLean { neutral, force, flow }`
`enum AffixDomain { item, technique }`
`abstract final class AffixCategories { itemPrefix='item_prefix'; itemSuffix='item_suffix'; techniquePrefix='technique_prefix'; techniqueSuffix='technique_suffix'; static const all = [...]; }`
`abstract final class AffixPoolTags { ... static String forSlot(AffixDomain, String slotKind); }` — tags are `affix_pool:<category>`.

## 3. Mechanic (closed union — covers non-stat)

```dart
sealed class AffixMechanic { num get amount; factory AffixMechanic.fromJson(Map<String,dynamic>); }
class WeaponStatBonus  extends AffixMechanic { const WeaponStatBonus(this.amount);  } // item pools
class ImmediateHeal    extends AffixMechanic { const ImmediateHeal(this.amount);    } // technique pools
class BankProgression  extends AffixMechanic { const BankProgression(this.amount);  } // technique pools
```

## 4. Content roster

`final List<Map<String,dynamic>> affixContentDefinitions` — **33** affixes, `type: 'affix'`,
tags `['affix', 'affix_pool:<cat>', 'lean:<lean>']`, extra `{label, category, mechanic:{kind,amount}}`.
Ported verbatim (label/magnitude/lean) from the client's `reward_affix.dart`.
Counts: item_prefix 11, item_suffix 9, technique_prefix 7, technique_suffix 6.
- **Canonical roster for the Almanac:** `context.content.withTag('affix')` → 33 → `affixDefinitionFromContent`.
- **One pool for the resolver:** `context.content.withTag('affix_pool:item_prefix')` etc.
- Two cross-pool labels reuse a display string under distinct ids:
  `af_flowing` / `af_flowing_technique` ("Flowing"), `af_of_still_water` / `af_of_still_water_technique` ("of Still Water").

## 5. Deterministic 2-slot selection (pure — RNG only)

```dart
class AffixRewardContext { const AffixRewardContext({required AffixDomain domain, required String? physiqueTradition}); }
class AffixResolvedSlot  { final int position; final String slotKind /* 'prefix'|'suffix' */; final AffixDefinition? affix; /* value-equal on (position, slotKind, affix?.id) */ }
class AffixResolution    { final List<AffixResolvedSlot> slots; /* unmodifiable, ALWAYS length 2 [prefix,suffix]; value-equal element-wise */ }

AffixResolution resolveRewardAffixes({
  required AffixRewardContext ctx,
  required RngService rng,
  required ContentRegistry content,
});
```

- Draws ONLY from `rng`, normative order: per slot in position order — 1 `nextDouble()` no-affix check
  (`kNoAffixChance = 0.34`, exported), then if kept 1 weighted pick (`weightedPick`, 1 more `nextDouble()`).
- Weighting: `neutral → 2`; matching favoured lean → 3; opposite → 1; `physiqueTradition` null/other → flat 2.
  `western → force` favoured, `eastern → flow` favoured.
- **No apply, no Almanac, no component reads.** `AffixResolution` is carried by value through preview → TAKE.
- The four states — `no affix` / `prefix only` / `suffix only` / `prefix + suffix` — are exactly the pre-existing `reward_affix.dart` semantics.

## 6. Mechanical application

```dart
sealed class AffixApplicationTarget {}
class ItemInstanceTarget extends AffixApplicationTarget { const ItemInstanceTarget({required EntityId instance, required String itemId}); }
class CharacterTarget    extends AffixApplicationTarget { const CharacterTarget({required EntityId character}); }

({String stat}) applyAffixMechanic(AffixDefinition def, AffixApplicationTarget target, PluginContext context);
```

- Returns `stat` = the mechanic **kind** string (`'weapon_stat_bonus'` / `'heal'` / `'bank_progression'`),
  **target-independent** (one canonical `AffixSnapshot` per `affixId`).
- `WeaponStatBonus` → resolves `WeaponStatTags.matchOrFallback(itemDef.tags, 'item:<id>')` and calls
  `addItemStatBonuses(instance, {resolvedStat: amount}, context)` internally — client does not.
- `ImmediateHeal` → clamps `HealthComponent`; **throws `ArgumentError` when the target has no `HealthComponent`**
  (a failed apply never yields a `(stat:)` result, so `acquireAffixes` never mints an id for it).
- `BankProgression` → `context.resources.add(character, ItemResources.upgradePoints, amount)`.
- Mechanic/target mismatch throws `ArgumentError` (unreachable from validated content — the pool tag fixes the domain).

## 7. Acquisition — engine-owned event identity

```dart
class RunRef { const RunRef({required String runId, required int runNumber}); }

class AffixAcquisitionIdSource {           // ONE per logical run; engine-owned; monotonic; no RNG
  String next({required RunRef run, required int slotPosition}); // '<runId>:affix:<slotPos>:<seq>'
}

class AffixAcquisition {                    // plain record — NO Almanac type
  final String affixId, affixEventId, runId;
  final int runNumber;
  final String stat;      // mechanic kind
  final num value;         // == AffixMechanic.amount
  final String category;   // affix definition's category, verbatim
}

List<AffixAcquisition> acquireAffixes({
  required AffixResolution resolution,
  required AffixApplicationTarget target,
  required AffixAcquisitionIdSource idSource,
  required RunRef run,
  required PluginContext context,
}); // applies each non-null slot in position order; mints ONE affixEventId per acquired affix;
    // returns one AffixAcquisition per acquired affix. Consumes NO RNG, touches NO Almanac.
    // No-affix slot yields nothing.
```

**Multi-affix model → resolved:** one `AffixAcquisition` **per acquired affix**, each with its own `affixEventId`
(`<runId>:affix:0:<seq>` for prefix, `<runId>:affix:1:<seq>` for suffix). The client records each in a loop.

## 8. Almanac recording — mirror `almanac_bridge._onAffixAcquired`

```dart
for (final a in acquisitions) {
  recorder.recordAffixDiscovered(
    affixId: a.affixId,
    observation: AffixObservation(affixEventId: a.affixEventId, runId: a.runId, runNumber: a.runNumber),
    snapshot:    AffixSnapshot(affixId: a.affixId, stat: a.stat, value: a.value, category: a.category),
    timestamp:   DateTime.now(),
  );
}
```
`AffixObservation` / `AffixSnapshot` / `AlmanacRecorder` from `package:build_engine/almanac.dart` (unchanged since `b43b4147`). No `beginRun` precondition for `recordAffixDiscovered` (the engine bridge calls it directly); `AlmanacSession.beginRun` remains a client convenience.

## 9. Reference wiring (engine `RewardStage._acquireRewardAffixes`) — client `RewardAdapter` mirrors this, SPLIT across two phases

| Phase | Engine (atomic, at reward-resolve) | Client `RewardAdapter` |
|---|---|---|
| generation / `offerLoot()` | `resolveRewardAffixes(ctx, rng: context.rng, content: context.content)` → `AffixResolution` | store `AffixResolution` on the offer; compose the card name/effects from `slot.affix` labels + `mechanic`; **`currentOffer()` (new, pure) re-reads it — no RNG** |
| TAKE / `applyLoot()` | `acquireAffixes(resolution, target, idSource, run, context)` → publish `AffixAcquired` per acquisition | `acquireAffixes(...)` with an `AffixAcquisitionIdSource` owned per-run + `RunRef(runId: <session seed/run key>, runNumber: <run #>)`; then the §8 record loop + `almanac.persist()` |

`target` = `ItemInstanceTarget(instance: <owned copy>, itemId: <id>)` for items, `CharacterTarget(character: <fighter>)` for techniques.
`physiqueTradition` = `_characterAdapter.currentView().physiqueAffinityTradition`.

## 10. Bump blast radius (SP1 + SP4a rode along)

- **SP1 Tiered Component Effects:** `ItemActionInterpreter` internals rewritten off `affix:*`/`build:*` → `effectprofile:item:*` ("same combat numbers, one path"). Client call site: `lib/core/engine/combat_adapter.dart:19` `const _itemInterpreter = ItemActionInterpreter();` and `:87` `.resolve(build:, actor:, targets:, context:)`. Verify signature + combat tests.
- **SP4a consumable build-DNA:** `buildDna(...)` gained a required `consumableIds` param — **client never calls `buildDna`**, no impact.
- No client use of `RewardStage` / `runGame` / `HeadlessGameAlmanacBridge` / `EffectProfile` directly.
- Fix bump fallout minimally in Task 0; a larger-than-mechanical break is a controller ruling.
