# Engine-Owned Affix Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Tome's affix system so `build_engine` is the sole canonical source of affix identity, mechanics, selection, and acquisition-event identity — the client only presents engine-owned affix data, forwards canonical acquisition results, and surfaces recorded affixes in the Almanac.

**Architecture:** `build_engine` gains an affix definition + registry + reward-selection + acquisition-event contract (companion spec). The client deletes `reward_affix.dart`, routes reward-affix rolling and application through the engine, wires an engine `AlmanacRecorder` over a `GameStore`-backed `AlmanacRepository` at the composition root (independent of `EngineSession` lifetime), records a taken affix through `recordAffixDiscovered` with the engine's `affixEventId`, and extends the existing `AlmanacAdapter` / Almanac screen with an `AFFIXES` group. No client canonical affix table survives; `CodexRepository` is untouched.

**Tech Stack:** Flutter (Dart ^3.7.0), `flutter_bloc`, `go_router`, `build_engine` (private git dep — `package:build_engine/*` importable ONLY under `lib/core/engine/`), `package:build_engine/almanac.dart` + `almanac_file.dart` (Almanac surface), `shared_preferences` (`GameStore`).

**Spec:** `docs/superpowers/specs/2026-09-10-engine-affix-identity-and-reward-api.md`

---

## GATE — this plan is blocked until the engine milestone ships

The spec status is **BLOCKED — engine API gap**. At `build_engine @ b43b4147` the Almanac can *record* affixes but the engine owns no affix definition, registry, reward-affix resolver, or acquisition-event identity contract.

**Do not start Task 1 until a `build_engine` revision exists that satisfies the spec's §13 acceptance criteria.** Task 0 pins that revision and reconciles every engine touchpoint below against the *actual* public surface. Every later task marks its engine calls `// SPEC §N — reconcile in Task 0`; those names are written against the spec's illustrative contract and are expected to be adjusted, not invented anew. If Task 0 finds the engine surface still insufficient, stop and report the residual gap — do not reintroduce a client affix table under any name.

---

## Global Constraints

Every task's requirements implicitly include this section.

- **Canonical ownership is the engine's.** The client never defines an affix, rolls an affix, constructs canonical mechanical values (`stat`/`value`/`category` or non-stat effect payloads — spec §8/§8.1), decides selection policy (rarity/affinity/context weighting/"no affix" chance — spec §5.1), or creates/substitutes an `affixEventId` (spec §9.1/§10). It forwards the engine's.
- **No client canonical affix vocabulary.** `lib/core/engine/reward_affix.dart` is deleted, not renamed or relocated. No parallel affix table, enum of effects, or affix-id list may exist in `lib/` after this plan.
- **Engine imports stay in `lib/core/engine/`.** Feature screens (`lib/features/**`) use plain client view models only — no `build_engine` type, including `AlmanacAffixRecord` / `AffixSnapshot` / any affix-definition type (spec §12).
- **`CodexRepository` is not modified.** Affix history is the engine Almanac path, not a 4th codex bucket (spec §12). `lib/core/persistence/codex_repository.dart` must not appear in any diff.
- **Almanac ownership stays in `build_engine`.** The client provides an `AlmanacRepository` implementation over `GameStore` and hydrates/persists `AlmanacState`; it does not reimplement recording, querying, identity, or serialization (spec §11).
- **Offer identity is stable.** The affix on a reward is resolved once at generation and is identical through preview and TAKE. Preview (`offerLoot`, any card render/inspect) has zero gameplay side effects: no RNG draw for a new affix, no Almanac write, no player-state mutation (spec §7).
- **One RNG.** Any engine affix selection uses the engine/session seeded RNG. No second RNG path is introduced (spec §14).
- **Almanac idempotency.** Recording is keyed `(affixId, affixEventId)`; re-processing the same canonical acquisition event must not duplicate history (spec §9/§13).
- **Locked-affix secrecy.** An undiscovered affix reveals no name, stat, value, or effect prose — in the visual UI *and* the semantics tree. Only an engine-provided structural category axis, if any, may show (spec §17-equivalent, §12 step 10).
- **Do not modify** `build_engine`, `ThresholdPage`, title routing, `RunBloc` (beyond reading run id/number), combat resolution, or unrelated reward mechanics (spec §14).
- **Do not weaken, skip, delete, or rebaseline unrelated existing tests.** `flutter pub get && flutter analyze && flutter test` must pass at every task boundary.
- **Commit trailer** (every commit):
  ```
  Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01Hu7eHfvoMZhDw7iPjkLHrn
  ```

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `lib/core/engine/reward_affix.dart` | client affix vocabulary + roll | **delete** |
| `lib/core/persistence/game_store_almanac_repository.dart` | `AlmanacRepository` over `GameStore` (`almanac.v1` key) | **create** |
| `lib/core/engine/almanac_session.dart` | owns the composition-root `AlmanacRecorder` + persistence, survives `EngineSession` rebuilds | **create** |
| `lib/core/engine/reward_adapter.dart` | reward offer + TAKE; engine affix selection, application, recording | modify |
| `lib/core/engine/item_adapter.dart` | drop `_affixByInstance` / `recordAffix`; derive name + bonus from engine state | modify |
| `lib/core/engine/almanac_adapter.dart` | add `AlmanacAffixView` + `affixes` on `AlmanacSnapshot` | modify |
| `lib/core/engine/engine_session.dart` | expose run id/number + the `AlmanacRecorder` handle for adapters | modify |
| `lib/core/models/loot_option_view.dart` | affix-name / effect-list fields sourced from engine data | modify |
| `lib/core/models/item_view.dart` | `affixBonus` / `displayName` doc + derivation | modify (minimal) |
| `lib/features/tome/widgets/component_detail_sheet.dart` | "AFFIXES while hung" row copy | modify (minimal) |
| `lib/features/title/almanac_screen.dart` | `AFFIXES` roster group + detail leaf + completion | modify |
| `lib/app/tome_app.dart` | provide `AlmanacSession` / repository at the root | modify |
| `test/core/engine/reward_affix_test.dart` | tests the deleted vocabulary | **delete** |
| `test/core/persistence/game_store_almanac_repository_test.dart` | round-trip persistence | **create** |
| `test/core/engine/almanac_affix_migration_test.dart` | spec §13 criteria (identity, selection, offer stability, recording, idempotency, restart) | **create** |
| `test/features/title/almanac_screen_test.dart` | `AFFIXES` group + locked secrecy | modify |
| `test/core/engine/reward_adapter_test.dart` | affix assertions retargeted to engine data | modify |

---

## Task 0: Pin the engine revision and reconcile the affix API

**Files:**
- Modify: `pubspec.yaml` (build_engine ref), `pubspec.lock`
- Create: `docs/superpowers/plans/2026-09-10-engine-owned-affix-migration.resolved-api.md`

**Interfaces:**
- Produces: a "Resolved Engine API" note mapping every spec-illustrative name used below (`AffixDefinition`, `registry.allOfType('affix')`, `rollAffix`/reward-candidate integration, the taken-reward result carrying `affixId` + `affixEventId`, `AlmanacRecorder.recordAffixDiscovered`, `AlmanacRepository`, `AlmanacSerialization`) to the real public symbol, signature, and barrel. Later tasks consume this note.

- [ ] **Step 1: Bump the pin.** Set `build_engine` `ref:` in `pubspec.yaml` to the revision that ships the affix API; `flutter pub get`.
- [ ] **Step 2: Enumerate the real surface.** From `~/.pub-cache/git/built_engine-<rev>/lib/`, record for each spec touchpoint: the class/function name, its constructor/parameter list, which `package:build_engine/*.dart` barrel exports it, and whether `AffixObservation` needs a prior `recorder.beginRun(...)`. Write it all to the resolved-api note.
- [ ] **Step 3: Gate check.** Confirm against spec §13: canonical definitions exist and are enumerable without a client table; a public selector takes `RngService`/reward context; a taken-reward result exposes `affixId` + engine `affixEventId`; non-stat mechanics (heal/bank) are representable in canonical data. If any is absent → stop, write the residual gap into the resolved-api note, and report. Do **not** proceed.
- [ ] **Step 4: Run the suite unchanged.** `flutter analyze && flutter test` — the pin bump alone must not break anything (affix code still points at `reward_affix.dart` until Task 5). Fix only compile breaks the bump itself causes, minimally.
- [ ] **Step 5: Commit.**
```bash
git add pubspec.yaml pubspec.lock docs/superpowers/plans/2026-09-10-engine-owned-affix-migration.resolved-api.md
git commit -m "chore(engine): bump build_engine to the affix-API revision + resolved-API note"
```

---

## Task 1: `GameStoreAlmanacRepository` — persist `AlmanacState` over `GameStore`

**Files:**
- Create: `lib/core/persistence/game_store_almanac_repository.dart`
- Test: `test/core/persistence/game_store_almanac_repository_test.dart`

**Interfaces:**
- Consumes: `GameStore.read(String) → Map<String,Object?>`, `GameStore.write(String, Map<String,Object?>) → Future<void>`; engine `AlmanacRepository` (interface), `AlmanacState`, `AlmanacSerialization.stateToJson` / `.stateFromJson` (resolved-api note).
- Produces: `class GameStoreAlmanacRepository implements AlmanacRepository { GameStoreAlmanacRepository(GameStore); AlmanacState load(); void save(AlmanacState); }` — key `almanac.v1`.

- [ ] **Step 1: Write the failing test.**
```dart
// test/core/persistence/game_store_almanac_repository_test.dart
import 'package:build_engine/almanac.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/persistence/game_store.dart';
import 'package:tome_client/core/persistence/game_store_almanac_repository.dart';

void main() {
  test('empty store loads AlmanacState.empty()', () {
    final repo = GameStoreAlmanacRepository(GameStore.memory());
    expect(repo.load(), AlmanacState.empty());
  });

  test('save then load round-trips an affix record through JSON', () {
    final store = GameStore.memory();
    final a = GameStoreAlmanacRepository(store);
    final recorder = AlmanacRecorder(a.load())
      ..recordAffixDiscovered( // SPEC §9 — reconcile in Task 0
        affixId: 'af_keen',
        observation: const AffixObservation(
          affixEventId: 'evt-1', runId: 'run-1', runNumber: 1),
        snapshot: const AffixSnapshot(
          affixId: 'af_keen', stat: 'blade', value: 3, category: 'item_prefix'),
        timestamp: DateTime.utc(2026),
      );
    a.save(recorder.state);

    final reloaded = GameStoreAlmanacRepository(store).load();
    expect(reloaded.affixes.single.affixId, 'af_keen');
    expect(reloaded.affixes.single.snapshot.value, 3);
  });
}
```
- [ ] **Step 2: Run — expect FAIL** (`game_store_almanac_repository.dart` missing). `flutter test test/core/persistence/game_store_almanac_repository_test.dart`
- [ ] **Step 3: Implement.**
```dart
// lib/core/persistence/game_store_almanac_repository.dart
import 'package:build_engine/almanac.dart';
import 'game_store.dart';

const _kKey = 'almanac.v1';

/// The client's persistence backing for the engine Almanac. The engine
/// owns recording, querying, identity and serialization (spec §11); this
/// only moves a complete [AlmanacState] between [AlmanacSerialization]
/// JSON and one [GameStore] document. Tolerates a missing / unparseable
/// document by returning [AlmanacState.empty] — same forward-compat
/// contract as the other repositories.
class GameStoreAlmanacRepository implements AlmanacRepository {
  GameStoreAlmanacRepository(this._store);
  final GameStore _store;

  @override
  AlmanacState load() {
    final json = _store.read(_kKey);
    if (json.isEmpty) return AlmanacState.empty();
    try {
      return AlmanacSerialization.stateFromJson( // SPEC §11 — reconcile in Task 0
        Map<String, dynamic>.from(json),
      );
    } catch (_) {
      return AlmanacState.empty();
    }
  }

  @override
  void save(AlmanacState state) {
    _store.write(_kKey, AlmanacSerialization.stateToJson(state));
  }
}
```
- [ ] **Step 4: Run — expect PASS.**
- [ ] **Step 5: Commit.** `git add lib/core/persistence/game_store_almanac_repository.dart test/core/persistence/game_store_almanac_repository_test.dart && git commit -m "feat(almanac): GameStore-backed AlmanacRepository (almanac.v1)"`

---

## Task 2: `AlmanacSession` — composition-root recorder that outlives `EngineSession`

**Files:**
- Create: `lib/core/engine/almanac_session.dart`
- Modify: `lib/app/tome_app.dart` (construct + provide), `lib/core/engine/engine_session.dart` (accept an optional recorder handle)
- Test: `test/core/engine/almanac_affix_migration_test.dart` (create; "restart" case here)

**Interfaces:**
- Consumes: `GameStoreAlmanacRepository`, engine `AlmanacRecorder` (+ `beginRun` if the resolved-api note says so), `AlmanacQueries`.
- Produces:
  ```dart
  class AlmanacSession {
    AlmanacSession(AlmanacRepository repo);
    AlmanacRecorder get recorder;
    AlmanacQueries get queries;      // over recorder.state
    void beginRun({required String runId, required int runNumber});
    void persist();                  // repo.save(recorder.state)
  }
  ```
  Lifetime = the app, not a run. `tome_app.dart` builds one `AlmanacSession` from `_store` next to `_codex` (line ~92) and passes it into `EngineSession` / `RewardAdapter`.

- [ ] **Step 1: Write the failing test** ("an affix recorded in one session is visible after rehydration"):
```dart
// test/core/engine/almanac_affix_migration_test.dart  (new file — grows over Tasks 2,4)
import 'package:build_engine/almanac.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/almanac_session.dart';
import 'package:tome_client/core/persistence/game_store.dart';
import 'package:tome_client/core/persistence/game_store_almanac_repository.dart';

void main() {
  test('recorded affix survives an AlmanacSession restart', () {
    final store = GameStore.memory();

    final s1 = AlmanacSession(GameStoreAlmanacRepository(store))
      ..beginRun(runId: 'run-1', runNumber: 1);
    s1.recorder.recordAffixDiscovered( // SPEC §9 — reconcile in Task 0
      affixId: 'af_keen',
      observation: const AffixObservation(
        affixEventId: 'evt-1', runId: 'run-1', runNumber: 1),
      snapshot: const AffixSnapshot(
        affixId: 'af_keen', stat: 'blade', value: 3),
      timestamp: DateTime.utc(2026),
    );
    s1.persist();

    final s2 = AlmanacSession(GameStoreAlmanacRepository(store));
    expect(s2.queries.getAffixHistory('af_keen'), isNotNull);
  });
}
```
- [ ] **Step 2: Run — expect FAIL** (`almanac_session.dart` missing).
- [ ] **Step 3: Implement `AlmanacSession`** — hydrate `AlmanacRecorder(repo.load())`, expose `recorder` / `queries` (rebuild `AlmanacQueries(recorder.state)` per get), `beginRun` delegates to the recorder's run entry point (per resolved-api note), `persist()` calls `repo.save(recorder.state)`.
- [ ] **Step 4: Wire the root.** In `tome_app.dart`: `late final AlmanacSession _almanac = AlmanacSession(GameStoreAlmanacRepository(_store));` beside `_codex`; add `RepositoryProvider<AlmanacSession>.value(value: _almanac)` in the outer (session-independent) provider list; pass `_almanac` into `EngineSession` and `RewardAdapter` construction. `EngineSession` stores the handle for adapters; on NEW RUN (`_session = EngineSession(_seed)` line ~131) the same `_almanac` is reused (it must not be rebuilt).
- [ ] **Step 5: Run — expect PASS**, then `flutter analyze && flutter test`.
- [ ] **Step 6: Commit.** `git commit -m "feat(almanac): composition-root AlmanacSession (recorder + persistence, outlives EngineSession)"`

---

## Task 3: Engine-owned reward-affix selection (offer side)

**Files:**
- Modify: `lib/core/engine/reward_adapter.dart`, `lib/core/models/loot_option_view.dart`
- Test: `test/core/engine/reward_adapter_test.dart`

**Interfaces:**
- Consumes: the engine affix selector / reward-candidate integration + `AffixDefinition` (resolved-api note); `_session.rng`.
- Produces: `RewardAdapter._offered` now also carries the engine-resolved affix (`AffixDefinition?` or a resolved handle) plus the engine's offer/acquisition identity. `offerLoot()` performs the affix resolution exactly once; re-calling `offerLoot()` is a *new* offer (existing behaviour), but a given offer's affix never changes between `offerLoot` and `applyLoot`.

- [ ] **Step 1: Update the failing test.** Replace the two affix assertions in `reward_adapter_test.dart` (`'an affixed New Component binds its stat bonus to the taken copy'`, `'a taken affixed item carries its rolled name into ItemView'`) and `'some New Component cards roll plain'` so they assert against **engine** affix data:
```dart
test('the offered affix comes from engine canonical data and is stable '
    'through preview', () {
  final r = _adapter(seed: 7);
  final firstOffer = r.offerLoot();
  final peek = r.offerLoot.hashCode; // no-op guard
  // Re-render / inspect must not re-roll:
  final again = r.currentOffer(); // SPEC §7 — add a pure getter, no side effects
  expect(again.componentAffixId, firstOffer /* same id */ );
  // The id is an engine affix id, not a client label:
  expect(again.componentAffixId, isNot(startsWith('Keen'))); // not a label
});
```
  (Exact matchers finalised against the resolved-api note — the invariant is: engine id, stable across preview, no RNG consumed on inspect.)
- [ ] **Step 2: Run — expect FAIL.**
- [ ] **Step 3: Implement.** In `reward_adapter.dart`: delete `import 'reward_affix.dart';`; remove `Affix? _prefix; Affix? _suffix;`; add `_OfferedAffix? _offeredAffix` (a tiny private record holding the engine `affixId`, the canonical snapshot fields, and the engine acquisition/`affixEventId` handle). In `offerLoot()` replace the two `rollAffixOrNone(...)` calls with **one** engine affix resolution for `next` (item vs technique context passed through), storing the result in `_offeredAffix`. Build the card title/effect list from `_offeredAffix` canonical fields (label + a descriptor composed from `stat`/`value` or the canonical non-stat effect — spec §16), not from a client blurb. Add a pure `LootOptionView currentOffer()` / equivalent getter that returns the already-resolved offer with no RNG or state touch.
- [ ] **Step 4: Update `loot_option_view.dart`** — rename/repoint the affix fields: `componentAffixId` (engine id, nullable), `componentAffixLabel`, `componentAffixDescriptor` (composed from engine fields). Drop "prefix/suffix blurbs" wording.
- [ ] **Step 5: Run — expect PASS**, `flutter analyze` (will still fail to compile until Task 5 removes the file; keep `reward_affix.dart` importable but unused here — OR sequence Task 5 immediately after. If analyze must stay green per task boundary, fold Task 5's deletion into this commit).
- [ ] **Step 6: Commit.** `git commit -m "feat(reward): resolve the reward affix from engine canonical data; stable offer identity"`

---

## Task 4: TAKE — apply canonical mechanics + record discovery

**Files:**
- Modify: `lib/core/engine/reward_adapter.dart`
- Test: `test/core/engine/almanac_affix_migration_test.dart`

**Interfaces:**
- Consumes: `AlmanacSession` (via `EngineSession`), engine mechanical-application entry point for an `AffixDefinition` on an `ItemInstance` and for the technique one-shot effects (resolved-api note), engine acquisition/`affixEventId`.
- Produces: `applyLoot(LootKind.newComponent)` applies the engine affix and, only on a real TAKE, calls `almanac.recorder.recordAffixDiscovered(affixId:, observation: AffixObservation(affixEventId: <engine's>, runId:, runNumber:, lineageId?:), snapshot: <from AffixDefinition>, timestamp:)` then `almanac.persist()`. Cancel / re-roll / not-taken records nothing.

- [ ] **Step 1: Write the failing tests** ("take records", "preview does not record", "idempotent", "multiple item copies → one canonical record"):
```dart
test('taking an affixed reward records it in the Almanac; previewing does not', () {
  final h = _harness(seed: 3);
  h.reward.offerLoot();                     // preview only
  expect(h.almanac.queries.getAffixHistory(anyAffix), isNull); // SPEC §7

  final offeredId = h.reward.currentOffer().componentAffixId!;
  h.reward.applyLoot(LootKind.newComponent); // TAKE
  expect(h.almanac.queries.getAffixHistory(offeredId), isNotNull);
});

test('replaying the same acquisition event does not duplicate history', () {
  final h = _harness(seed: 3);
  h.reward.offerLoot();
  h.reward.applyLoot(LootKind.newComponent);
  final rec = h.almanac.queries.getAffixHistory(h.lastAffixId)!;
  // feed the identical (affixId, affixEventId) again:
  h.almanac.recorder.recordAffixDiscovered(/* same as RewardAdapter used */);
  expect(h.almanac.queries.getAffixHistory(h.lastAffixId)!.timesDiscovered,
      rec.timesDiscovered);
});

test('the same canonical affix on two item copies is one Almanac record', () {
  final h = _harness(seed: 11);
  h.takeUntilAffix('af_keen'); h.takeUntilAffix('af_keen');
  expect(h.almanac.recorder.state.affixes.where((a) => a.affixId == 'af_keen'),
      hasLength(1));
});
```
- [ ] **Step 2: Run — expect FAIL.**
- [ ] **Step 3: Implement.** In `applyLoot`'s `newComponent` branch: after `ownItem(...)` / `_techniqueAdapter.discover(...)`, hand the engine the `_offeredAffix` to apply its canonical mechanics (item → engine binds to the `ItemInstance`; technique → engine resolves the one-shot effect — no client `_applyTechniqueAffix` switch). Then, iff `_offeredAffix != null`, build the `AffixObservation` from `_session.runId` / `_session.runNumber` and the engine's `affixEventId`, and call `recordAffixDiscovered` + `almanac.persist()`. Delete `_applyTechniqueAffix` and the `math` import if now unused. `_codex?.discover` for item/technique id stays (that is the item/technique codex, not affixes).
- [ ] **Step 4: Delete the client one-shot switch paths** and confirm no `AffixEffect` reference remains in `reward_adapter.dart`.
- [ ] **Step 5: Run — expect PASS**, `flutter analyze && flutter test`.
- [ ] **Step 6: Commit.** `git commit -m "feat(reward): apply canonical affix mechanics and record discovery on TAKE"`

---

## Task 5: Delete `reward_affix.dart` and its test; sweep references

**Files:**
- Delete: `lib/core/engine/reward_affix.dart`, `test/core/engine/reward_affix_test.dart`
- Modify: any remaining importer surfaced by the sweep

- [ ] **Step 1: Sweep.** `grep -rn -E "reward_affix|Affix\(|AffixLean|AffixEffect|itemPrefixes|itemSuffixes|techniquePrefixes|techniqueSuffixes|rollAffix" lib/ test/` — every hit outside a doc comment must be gone or retargeted.
- [ ] **Step 2: Delete the two files.**
- [ ] **Step 3: Run — expect compile errors only at real remaining importers**; fix each to use engine data / the new view fields.
- [ ] **Step 4: `flutter analyze && flutter test` — expect PASS.**
- [ ] **Step 5: Commit.** `git commit -m "chore(reward): delete the client-owned affix vocabulary (reward_affix.dart)"`

---

## Task 6: `ItemAdapter` — engine-derived name + bonus; drop `_affixByInstance`

**Files:**
- Modify: `lib/core/engine/item_adapter.dart`, `lib/core/models/item_view.dart`, `lib/features/tome/widgets/component_detail_sheet.dart`
- Test: `test/core/engine/reward_adapter_test.dart` (the "carries its rolled name into ItemView" case)

**Interfaces:**
- Consumes: `ItemInstance.statBonuses` (engine per-copy state — unchanged), engine affix-definition lookup by `affixId` for the display label (resolved-api note), and — if the engine exposes which affix is bound to a copy — that lookup; otherwise `AlmanacQueries` / the reward result at TAKE time supplies the label to `ItemAdapter` through an engine-owned handle, never a client map keyed by guesswork.
- Produces: `_affixByInstance` and `recordAffix(...)` removed. `_displayName` composes `<engine affix label> <base>` from engine data. `affixBonus` still = `statBonuses` total minus the upgrade-point portion (that logic is unchanged and unrelated to affix identity).

- [ ] **Step 1: Update the failing test** — "a taken affixed item's `ItemView.displayName` shows the engine affix label" (not a client `Affix.label`).
- [ ] **Step 2: Run — expect FAIL.**
- [ ] **Step 3: Implement.** Remove `_affixByInstance` + `recordAffix`. If the engine binds an `affixId` to the `ItemInstance` (resolved-api note), read it there and resolve the label via the engine affix registry; else accept the engine affix handle from `RewardAdapter` at own-time through an explicit `ItemAdapter` method that stores only the engine `affixId` (not a label), keyed by the instance entity value, and resolves the label on read. Update `combine()` cleanup to drop only what it still owns (`_upgradesByInstance`), removing the `_affixByInstance.remove(v)` line.
- [ ] **Step 4: Trim `item_view.dart` / `component_detail_sheet.dart`** doc comments that say "rolled prefix/suffix" → "engine affix"; the `affixBonus` row copy ("+N while hung") stays.
- [ ] **Step 5: Run — expect PASS**, `flutter analyze && flutter test`.
- [ ] **Step 6: Commit.** `git commit -m "refactor(item): derive affix display from engine state; remove _affixByInstance"`

---

## Task 7: `AlmanacAdapter` — expose the affix roster + history as plain views

**Files:**
- Modify: `lib/core/engine/almanac_adapter.dart`
- Test: `test/core/engine/almanac_adapter_test.dart`

**Interfaces:**
- Consumes: engine affix registry enumeration (`registry.allOfType('affix')` or resolved equivalent) for the canonical roster; `AlmanacSession.queries.getAffixHistory(affixId)` for discovered state; `AlmanacQueries` for a "discovered ids" set.
- Produces:
  ```dart
  class AlmanacAffixView {
    final String id;
    final String label;
    final String? category;     // structural axis; may be null
    final String? stat;         // discovered only
    final num? value;           // discovered only
    final bool discovered;
  }
  ```
  `AlmanacSnapshot` gains `final List<AlmanacAffixView> affixes;` and `total` includes it. `AlmanacAdapter` takes the `AlmanacSession` (or its `AlmanacQueries`) alongside the `EngineSession` it already holds.

- [ ] **Step 1: Write failing tests** (roster = engine enumeration; discovered overlay = Almanac history; locked view carries no `stat`/`value`):
```dart
test('affix roster is the engine canonical set; history marks discovered', () {
  final h = _adapterHarness();
  final ids = h.snapshot().affixes.map((a) => a.id).toSet();
  expect(ids, h.session.context.content.allOfType('affix').map((d) => d.id).toSet());
  expect(h.snapshot().affixes.every((a) => !a.discovered), isTrue); // empty almanac

  h.almanac.recorder.recordAffixDiscovered(affixId: ids.first, /* … */);
  final v = h.snapshot().affixes.firstWhere((a) => a.id == ids.first);
  expect(v.discovered, isTrue);
});

test('an undiscovered affix view exposes no stat or value', () {
  final v = _adapterHarness().snapshot().affixes.firstWhere((a) => !a.discovered);
  expect(v.stat, isNull); expect(v.value, isNull);
});
```
- [ ] **Step 2: Run — expect FAIL.**
- [ ] **Step 3: Implement.** Add `_affixes()` to `AlmanacAdapter`: enumerate the engine affix registry → for each, look up `queries.getAffixHistory(id)`; if present set `discovered: true`, `stat`/`value` from `record.snapshot`; else `discovered: false` with `stat`/`value` null and `category` only if the engine definition provides a safe structural category. Add `affixes` to `AlmanacSnapshot` + its `total`. Thread the `AlmanacSession` in via the constructor (update `tome_app.dart` provider for `AlmanacAdapter` if one exists, else the screen constructs it — keep consistent with the current wiring).
- [ ] **Step 4: Run — expect PASS**, `flutter analyze && flutter test`.
- [ ] **Step 5: Commit.** `git commit -m "feat(almanac): AlmanacAdapter exposes the affix roster + discovery as plain views"`

---

## Task 8: Almanac screen — `AFFIXES` group

**Files:**
- Modify: `lib/features/title/almanac_screen.dart`
- Test: `test/features/title/almanac_screen_test.dart`

**Interfaces:**
- Consumes: `AlmanacSnapshot.affixes` (`List<AlmanacAffixView>`), the existing `_Kind` enum + roster/detail scaffolding.
- Produces: a 4th roster group `AFFIXES` with `recorded / canonical` completion; discovered plate = bone + chop + label + `category · stat +value` descriptor; locked plate = slate wash + blotted placeholder + category axis only (or nothing); detail leaf for a discovered affix = category badge + effect row(s) composed from `stat`/`value` / canonical non-stat effect; locked selection = "not yet met" + axis. No `build_engine` import added.

- [ ] **Step 1: Write failing tests:**
```dart
testWidgets('AFFIXES group shows recorded / canonical completion', (t) async {
  await _pump(t, GameStore.memory()); // empty almanac
  expect(find.text('AFFIXES'), findsOneWidget);
  // canonical count N, recorded 0:
  expect(find.textContaining('0 / '), findsWidgets);
});

testWidgets('a locked affix leaks no name / stat / value in UI or semantics',
    (t) async {
  await _pump(t, GameStore.memory(), size: const Size(560, 900));
  await tester.tap(find.text('AFFIXES'));            // reach the group
  // tap a locked affix plate, then:
  expect(find.textContaining('Keen'), findsNothing);
  expect(find.textContaining('+3'), findsNothing);
  final sem = tester.getSemantics(find.byType(/* locked plate */));
  expect(sem.label, isNot(contains('Keen')));
});
```
- [ ] **Step 2: Run — expect FAIL.**
- [ ] **Step 3: Implement.** Extend `_Kind` with `affix`; add the group to `_Roster` (roster built from `snapshot.affixes`); reuse `_EntryPlate` (discovered/locked already branch on a bool); add `_AffixLeaf` mirroring `_StyleLeaf` (badge = category, rows = effect from `stat`/`value`); locked path reuses `_LockedLeaf` with `kind: _Kind.affix`, axis = `view.category ?? 'affix'`. Completion bar denominator now includes affixes.
- [ ] **Step 4: Run — expect PASS**, `flutter analyze && flutter test`, then `node ~/.claude/skills/impeccable/scripts/detect.mjs --json lib/features/title/almanac_screen.dart`.
- [ ] **Step 5: Commit.** `git commit -m "feat(almanac-ui): AFFIXES group — recorded/canonical, discovered detail, locked secrecy"`

---

## Task 9: Spec §13 acceptance test sweep + migration cleanup grep

**Files:**
- Modify: `test/core/engine/almanac_affix_migration_test.dart`
- Test: itself + a repo grep gate

- [ ] **Step 1: Fill the remaining §13 cases** not already covered by Tasks 2/4/7/8:
  - affix selection uses `RngService` (same seed → same offered affix id; different seed can differ)
  - mechanical values come from engine data (the recorded `AffixSnapshot` equals the engine `AffixDefinition`'s fields, not any client constant)
  - non-stat mechanic path: taking a heal/bank affix produces the engine-defined effect (HP / upgrade points move) *and* records the affix
  - `TAKE` uses the already-resolved offered affix (offered id == recorded id)
  - no client-generated event id: the `affixEventId` in the record equals the engine's, asserted via the engine handle
- [ ] **Step 2: Cleanup grep gate.** `grep -rn -E "Affix\(|itemPrefixes|itemSuffixes|techniquePrefixes|techniqueSuffixes|AffixEffect|AffixLean|_affixByInstance|recordAffix\b" lib/` → **zero** hits. Add this as a shell check in the task notes (not a Dart test).
- [ ] **Step 3: Run the full suite** `flutter analyze && flutter test` — all green, no unrelated test touched.
- [ ] **Step 4: Commit.** `git commit -m "test(affix): spec §13 acceptance sweep + client-vocabulary cleanup gate"`

---

## Task 10: Full verification + desktop check

**Files:** none (verification only) — plus `pubspec.lock` if `pub get` normalises it.

- [ ] **Step 1:** `flutter pub get && flutter analyze && flutter test` — capture the pass counts; confirm no unrelated test was weakened, skipped, deleted, or rebaselined vs. the pre-plan baseline.
- [ ] **Step 2:** `node ~/.claude/skills/impeccable/scripts/detect.mjs --json lib/features/title/almanac_screen.dart lib/core/engine/almanac_adapter.dart` — clean.
- [ ] **Step 3:** `flutter build macos --release`; launch; open Almanac; screenshot the `AFFIXES` group discovered + locked, and one affix detail leaf; eyeball against the Lineage Hall language and locked-secrecy rule.
- [ ] **Step 4:** Update the spec's Status from **BLOCKED** to **MIGRATED** with the landing commit range; note the engine revision used.
- [ ] **Step 5: Commit.** `git commit -m "docs(affix): mark the migration complete; engine rev + commit range"`

---

## Self-Review

**Spec coverage:** §4/§5 canonical identity + registry → Task 7 (enumeration) + Task 0 (verification). §5.1/§6 selection policy + roll → Task 3. §7 offer identity / preview purity → Task 3 (pure getter, one resolution) + Task 4 (preview-does-not-record test). §8/§8.1 mechanical application incl. non-stat → Task 4 + Task 9. §9/§9.1 recording + `affixEventId` ownership → Task 4 + Task 9. §10 producer/bridge → Task 4 (engine result carries id) + Task 0 (which shape). §11 boundary / Almanac ownership in engine → Task 1 + Task 2. §12 client migration steps 1-10 → Tasks 3-8. §13 acceptance criteria → Task 9 sweep. §14 non-goals respected (no schema redesign, no `CodexRepository` change, no second RNG, no client registry).

**Placeholder scan:** engine calls are concrete against the spec's illustrative contract, each tagged `// SPEC §N — reconcile in Task 0`; Task 0 produces the real names before any of them is executed. No "TBD"/"handle edge cases"/"similar to Task N".

**Type consistency:** `AlmanacAffixView` fields (Task 7) are consumed unchanged by the screen (Task 8). `_OfferedAffix` (Task 3) is the only producer of the recording arguments (Task 4). `GameStoreAlmanacRepository` (Task 1) is the only `AlmanacRepository` impl, consumed by `AlmanacSession` (Task 2), consumed by `AlmanacAdapter` (Task 7) and `RewardAdapter` (Task 4).

**Known risk:** if Task 0 finds the engine still lacks a taken-reward result exposing `affixId` + `affixEventId`, Tasks 3-4 cannot proceed as written — stop at Task 0 per the GATE and report the residual gap; do not fabricate an event id or a client affix table.

---

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-09-10-engine-owned-affix-migration.md`.

**This plan does not start until the `build_engine` affix milestone (companion spec) ships.** When it does:

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks. REQUIRED SUB-SKILL: `superpowers:subagent-driven-development`.
2. **Inline Execution** — `superpowers:executing-plans`, batch with checkpoints.

Task 0 is the gate: it pins the revision and reconciles every `// SPEC §N` touchpoint. If Task 0's gate check fails, the plan halts there.
