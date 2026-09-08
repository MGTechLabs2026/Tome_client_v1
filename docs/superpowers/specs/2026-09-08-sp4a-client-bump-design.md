# SP4a (client) — Staged `build_engine` bump `314f75a` → HEAD

**Date:** 2026-09-08
**Status:** design — pending review
**Repo:** `Tome_client` (Flutter), engine pin currently `314f75a` (2026-09-01)
**Engine spec (authoritative for contracts):**
`build_engine:docs/superpowers/specs/2026-09-08-sp4a-engine-bump-design.md` — its
§5 "consumed-contract register" is the frozen, per-stage list of engine public
surface this migration may rely on.
**Engine audit backing this doc:**
`build_engine:docs/superpowers/specs/2026-09-08-sp4a-engine-bump-notes.md`

---

## 1. Why this exists

`Tome_client` runs on `build_engine` `314f75a` — 139 commits and five engine
efforts behind engine HEAD `1dc7e5d`: **SP0a** (technique instancing) → **SP0b**
(technique inspiration/discovery) → **Almanac v1** → **SP1 game-run migration**
→ **SP1 tiered component effects** → **SP2** (per-active auras) → **SP3**
(per-fight consumables).

The parent SP4 sub-project ("`Tome_client` surfacing") cannot start until the
client is on engine HEAD. SP4 was split (engine notes §2):

- **SP4a** — this migration: drag the pin to HEAD, no new UX.
- **SP4b** — the surfacing (tiered reward affixes, tier-grouped detail sheet,
  `AuraBinder` / `ConsumableBinder` adoption, a client Almanac adapter). Starts
  **only** after SP4a is fully merged and green in both repos.

## 2. Scope

### 2.1 In scope

- Bump `pubspec.yaml`'s `build_engine` git `ref` from `314f75a` to engine HEAD,
  **in five sequential steps** (§4), one per engine stage.
- The compatibility work each step requires — in practice, **one hard compile
  break** in `lib/core/engine/combat_adapter.dart` at the SP1 step (§3), plus
  fixture re-baselines where the new engine legitimately shifts a fixed-seed
  result (§5).
- `pubspec.lock` regenerated at each step (`flutter pub get`).

### 2.2 Explicitly out of scope (SP4b, not SP4a)

- Tiered reward affixes / any reward-model change; the technique-affix one-shot
  boon path in `reward_adapter.dart` stays exactly as-is.
- `component_detail_sheet` changes.
- Adopting `AuraBinder` or `ConsumableBinder`; registering `ConsumablePlugin`;
  any consumable UI or reward-pool entry.
- Minting / hanging `TechniqueVariant` instances; calling
  `resolveTechniqueInspirationAfterTraining`; deriving real `ownedRefs` (a
  `const []` placeholder with a marker comment is the SP4a fix — §3).
- A `TomeClientAlmanacAdapter` / wiring the engine `AlmanacRecorder`.

If a step cannot go green without one of the above, **stop** — the SP4a/SP4b
boundary needs revisiting, not the scope.

### 2.3 Hard rule

**This spec must not assume an engine API that is not listed as merged in the
engine spec's §5 register for that stage.** Each PR targets a specific engine
commit; the client only touches surface frozen for that commit.

## 3. The one hard compile break — SP1 step, `combat_adapter.dart`

Three edits, all in `CombatAdapter.runFight` / around line 79:

1. **`final build = _ctx.tome.resolve(_me);`**
   → `final build = _ctx.tome.resolve(_me, ownedRefs: const []);`
   `TomeService.resolve` is now
   `resolve(EntityId owner, {required List<BuildComponentRef> ownedRefs}) →
   ResolvedBuild`. Passing `const []` is safe: `BuildResolver` unions every hung
   ref into `owned` by construction, and SP4a reads only the hung set. The
   `permanent` tier (owned-but-loose) contributes nothing — acceptable; the
   client has no loose-component combat concept and no tiered affixes yet.
   Leave `// SP4b: derive real ownedRefs (ref: build_engine game_run.dart
   ownedComponentRefs)`.

2. **`build.components`** — two sites (the item loop, the technique loop).
   `ResolvedBuild` exposes `owner` / `active` / `owned` / `asActiveBuild`, **no
   `.components`**. Change both to `build.active` (identical membership to the
   old `ActiveBuild.components`).

3. **`_itemInterpreter.interpret(build: build, …)`** — signature is now
   `interpret({required ResolvedBuild build, …})`. Correct as written once
   `build` is the `ResolvedBuild` from (1); no edit beyond (1).

**Semantic continuity (verify, not a compile break):** the item interpreter's
per-stat `Modifier` source string changed to
`effectprofile:item:<actorValue>:<stat>` (was `build:<itemId>:<actorValue>` /
`affix:*`). The client calls `interpret` only for its side effect (register item
stat modifiers on `_me`); net damage math is unchanged. Grep client tests for
`affix:` / `build:` / `removeBySource(` source-string assertions — none
expected; confirm.

`ItemInstance.statBonuses` (field) and `addItemStatBonuses` (writer) are
**retained** by SP1 — they now feed the engine's `ItemEffectContributor`
supporting tier. `item_adapter.dart` / `reward_adapter.dart` reads and writes of
`statBonuses` stay valid and keep their effect; no edit needed.

## 4. The five PRs

Branch base: `main`. Each PR: bump the `ref`, `flutter pub get`, do only that
stage's compatibility work, green the gate, merge. **The next bump does not
begin until the previous PR is merged and green** — so every engine bump is
independently reviewable, bisectable, and revertable.

**Gate (every PR):** `flutter pub get && flutter analyze && flutter test`.
The final PR additionally runs `scripts/package_itch.sh` (web release build; in
CI).

**Determinism-property check (every PR):** re-run `combat_adapter_test.dart`,
`combat_mastery_test.dart`, `run_bloc_test.dart`, `training_adapter_test.dart`.
Property that must hold: *same `EngineSession(seed)` + same submitted
`TrainingAttempt`s / same combat inputs, run twice → identical outcome.* If a
specific seed's asserted number/pattern moved **but the property holds**, update
the inline expectation to the observed value (§5). If two identical runs
diverge, **stop — real bug.**

| PR | Engine stage | Pin ref | Compat work | Expected result |
|----|--------------|---------|-------------|-----------------|
| 1 | **SP0a** technique instancing | `cb32b02` | none anticipated | compile-clean; behaviour identical (client mints no variants; `instanceEntityId` stays null; `addTechniqueToTome` / bare-ref `tome.insert`+`replace` remain the documented legacy path) |
| 2 | **SP0b** inspiration/discovery | `ff8c7db` | none | compile-clean; inert (`resolveTechniqueInspirationAfterTraining` not called; no owned `TechniqueVariant`; no `context.rng` draw). `AttackAction`/`SelfEffectAction` gain an optional `sourceRef` param — existing constructions unaffected |
| 3 | **SP1** tiered effects (also crosses Almanac v1 + SP1 game-run, both inert) | `0663e8e` | **§3 — `combat_adapter.dart` ×3** | compiles after §3; re-baseline any drifted inline seed expectations in `combat_adapter_test.dart` / `combat_mastery_test.dart` (§5) |
| 4 | **SP2** per-active auras | `dc213d4` | none (see §4.1) | compile-clean; inert — the client binds no auras. A combat-number drift for a build hanging one of the 7 aura-tagged content ids means an aura path leaked in ⇒ **stop** |
| 5 | **SP3** per-fight consumables | `1dc7e5d` (engine HEAD) | none (see §4.2) | compile-clean; inert (`ConsumablePlugin` not registered; client combat pool has no consumable branch; `RuleContext.modifiers` default keeps `RuleEngine._fire` identical). Run `scripts/package_itch.sh` |

### 4.1 PR 4 — lock the plugin init order

`engine_session.dart` already initialises `CombatPlugin()..initialize(context)`
**before** `ItemPlugin` / `TechniquePlugin`. SP2's `hasTrigger`-gated
aura-content load requires Combat-first, permanently, for that `PluginContext`
(engine CHANGELOG: "the constraint any future composition root must honour").
No reorder needed — **add a comment** at the `CombatPlugin` init line marking it
load-bearing, so a future edit doesn't move it.

SP2's `BuildActionInterpreter.auraRules(...)` abstract addition does not break
the client: it implements/subclasses no `BuildActionInterpreter` or
`CompositeBuildActionInterpreter`, has no interface test double, and builds no
interpreter list. `const ItemActionInterpreter()` gains a method the client
never calls.

### 4.2 PR 5 — do not register `ConsumablePlugin`

`ConsumablePlugin` stays out of `engine_session.dart` in SP4a. Registering it,
wiring `ConsumableBinder`, or adding consumables to any reward pool is SP4b.

## 5. Fixture / golden policy

Client determinism comes from the pinned engine `ref` + `pubspec.lock` (CI
comment), not the Flutter version. Four cases:

1. **Expected seed-output drift** — a seed's asserted combat number / hit-miss
   pattern / mastery total changes because the new engine legitimately computes
   a value differently (SP1: two hung copies of one item each contribute scaled
   `attack` — the old `build:<itemId>` source collapsed duplicates; item
   modifier source is now per-actor). **Action:** update the inline expectation
   in `combat_adapter_test.dart` / `combat_mastery_test.dart` to the observed
   value; note it in the PR.
2. **Unexpected nondeterminism** — the same `EngineSession(seed)` + same inputs,
   run twice, diverge. **Action:** STOP. Real bug — do not touch the fixture, do
   not weaken the assertion, diagnose.
3. **Compile / API migration** — a signature/type change breaks the build
   (§3 is the only one). **Action:** minimal mechanical fix per the engine
   spec's §5 register; no behaviour change intended.
4. **Actual gameplay regression** — a run ends differently in a way that is not
   a legitimate calculation change (wrong winner, crash, a plugin path firing
   that SP4a says is inert — e.g. an aura contributing in PR 4). **Action:**
   STOP, surface it; likely SP4b work leaked in or a real engine bug.

`tome_visual_capture_test.dart` is a structural capture (no PNG golden) — it
should not move; if it does, inspect before re-baselining.

**Never weaken a determinism assertion to make a bump green. Never delete a
"same seed twice → identical" test.**

## 6. Files expected to change

- `pubspec.yaml` — the `build_engine` `ref` (5 times, once per PR).
- `pubspec.lock` — regenerated each PR.
- `lib/core/engine/combat_adapter.dart` — §3 (PR 3).
- `lib/core/engine/engine_session.dart` — one comment (PR 4).
- `test/core/engine/combat_adapter_test.dart`,
  `test/core/engine/combat_mastery_test.dart` — inline seed re-baselines if
  drift occurs (PR 3, possibly PR 4/5 — expected none).

Not expected to change: `item_adapter.dart`, `reward_adapter.dart`,
`technique_adapter.dart`, `training_adapter.dart`, `tome_adapter.dart`,
`character_adapter.dart`, any `features/` code, any widget/bloc test.

## 7. Verification each stage

- `flutter analyze` clean.
- `flutter test` green (with §5-case-1 re-baselines only).
- Determinism property holds (§4).
- A manual read-through: for PRs 1/2/4/5, confirm no new engine code path is
  reachable from the client (no variant minting, no aura bind, no consumable
  registration).
- PR 5: `scripts/package_itch.sh` succeeds.

## 8. After PR 5

Client is on engine HEAD, gate green, web build green. With engine-repo SP4a
(Part A) also merged, **SP4a is complete** and SP4b may begin — targeting engine
HEAD and this fully migrated client.

## 9. Self-review

- **Placeholders:** none.
- **Consistency:** §3's `const []` choice matches §2.2's "no real `ownedRefs`
  in SP4a"; the PR table's "inert" claims match the engine spec's §5
  present-but-not-relied-on lists.
- **Scope:** one `pubspec` field moved five times + three lines in one adapter +
  one comment + possible fixture re-baselines. Deliberately minimal.
- **Ambiguity:** "green gate" and "determinism property" are defined once (§4)
  and referenced; each PR's compat work is enumerated, not left to discovery
  (except fixture drift, which is bounded by §5).

## 10. Next step

Review alongside the engine spec → `superpowers:writing-plans` for the five-PR
implementation plan.
