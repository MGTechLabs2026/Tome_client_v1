# Tome: Martial Arts — Client UX Milestone Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a playable Flutter UX shell for Tome: Martial Arts — character creation through a full 3-fight run with real loot and Tome edits — driving the real `build_engine` package for every rule (combat, mastery, technique learning/evolution, item combine, reward), with combat/training rendered as swappable placeholders.

**Architecture:** A `core/engine/` adapter layer is the only code that imports `build_engine`; it wraps the engine's own composable stage classes (`TomeManager`, `RewardStage`, `TrainingStage`, `CombatStage` from `package:build_engine/game.dart`) plus direct plugin calls where the client's real spatial 3×3 grid Tome diverges from the engine's own flat-slot reference run. `flutter_bloc` feature Blocs per phase talk only to adapters and emit immutable view models; `go_router` redirects off a top-level `RunBloc`'s `GamePhase`. `TrainingPresentation`/`CombatPresentation` are the seams for later Flame/3D work.

**Tech Stack:** Dart `^3.7.0`, Flutter (stable channel), `flutter_bloc`, `go_router`, `build_engine` (git dependency), `flutter_test`/`integration_test`.

**Spec:** `docs/superpowers/specs/2026-08-25-tome-client-ux-design.md`

## Global Constraints

- Dart SDK floor `^3.7.0` (matches `build_engine`'s own `pubspec.yaml`).
- `package:build_engine/*` is imported **only** inside `lib/core/engine/`. No other directory — not `lib/core/models/`, not any `lib/features/**` file, not any widget — may import it. Engine enums are never surfaced to UI code; every adapter maps them to a small client-local display enum in `lib/core/models/`.
- Adapter tests hit the real `build_engine` package end-to-end (construct a real `PluginContext` with real plugins initialized) — never mock engine rules. Feature-Bloc tests use a fake adapter implementation instead.
- The only two changes to `build_engine` (repo `/Users/m4maxpro/Projects/Tome:RougelikeGame`) approved for this milestone: (1) make the style→tradition mapping public (Task 1), (2) add a non-throwing `canCombine` pre-check (Task 2). No other engine change is in scope.
- `Tome_client` depends on `build_engine` via the git remote `git@github-built-engine:MGTechLabs2026/built_engine.git`, overridden to a local path (`/Users/m4maxpro/Projects/Tome:RougelikeGame`) during development via `dependency_overrides`.
- State management: `flutter_bloc` (Bloc/Cubit per feature) + `go_router` (phase-driven redirects). No other state-management package.
- The client never computes combat, mastery, item/technique lifecycle, combine odds, or reward generation — every such call goes through `core/engine/`.

---

## Phase 0 — build_engine changes

### Task 1: Export the style→tradition mapping

**Files:**
- Modify: `/Users/m4maxpro/Projects/Tome:RougelikeGame/lib/src/plugins/martial_arts/martial_styles.dart`
- Test: `/Users/m4maxpro/Projects/Tome:RougelikeGame/test/plugins/martial_arts/martial_styles_test.dart`

**Interfaces:**
- Produces: `String? martialTraditionOf(String styleId)` — public top-level function in `martial_styles.dart`, exported transitively via `lib/martial_arts_plugin.dart`'s existing `export 'src/plugins/martial_arts/martial_styles.dart';` line. Returns `MartialTraditions.western`/`MartialTraditions.eastern` for the six known `MartialStyles` ids, `null` otherwise.

- [ ] **Step 1: Write the failing test**

```dart
// test/plugins/martial_arts/martial_styles_test.dart
import 'package:build_engine/martial_arts_plugin.dart';
import 'package:test/test.dart';

void main() {
  group('martialTraditionOf', () {
    test('maps the three western styles to MartialTraditions.western', () {
      expect(martialTraditionOf(MartialStyles.boxing), MartialTraditions.western);
      expect(martialTraditionOf(MartialStyles.wrestling), MartialTraditions.western);
      expect(martialTraditionOf(MartialStyles.fencing), MartialTraditions.western);
    });

    test('maps the three eastern styles to MartialTraditions.eastern', () {
      expect(martialTraditionOf(MartialStyles.shaolin), MartialTraditions.eastern);
      expect(martialTraditionOf(MartialStyles.taiChi), MartialTraditions.eastern);
      expect(martialTraditionOf(MartialStyles.wingChun), MartialTraditions.eastern);
    });

    test('returns null for an unrecognized style id', () {
      expect(martialTraditionOf('capoeira'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `/Users/m4maxpro/Projects/Tome:RougelikeGame`): `dart test test/plugins/martial_arts/martial_styles_test.dart`
Expected: FAIL — `martialTraditionOf` is not defined (the function doesn't exist yet).

- [ ] **Step 3: Rename the private helper to a public one**

In `lib/src/plugins/martial_arts/martial_styles.dart`, rename `_traditionTagFor` to `martialTraditionOf` (drop the leading underscore, keep the body identical) and update its one call site inside `learnStyle`:

```dart
// before: final traditionTag = _traditionTagFor(styleId);
// after:
final traditionTag = martialTraditionOf(styleId);
```

```dart
/// The broad martial tradition [styleId] belongs to, or `null` for a
/// style id outside this plugin's six known styles. Public so a game
/// composition layer (e.g. a client's character-creation screen) can
/// determine a style's tradition before the player commits to it, not
/// only after `learnStyle` has already applied the tag.
String? martialTraditionOf(String styleId) => switch (styleId) {
      MartialStyles.boxing || MartialStyles.wrestling || MartialStyles.fencing =>
        MartialTraditions.western,
      MartialStyles.shaolin || MartialStyles.taiChi || MartialStyles.wingChun =>
        MartialTraditions.eastern,
      _ => null,
    };
```

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test test/plugins/martial_arts/martial_styles_test.dart`
Expected: PASS (3/3).

Also run the full suite to confirm the rename didn't break anything: `dart test` — expected: all passing (matches the pre-existing count, plus these 3 new tests).

- [ ] **Step 5: Commit**

```bash
cd "/Users/m4maxpro/Projects/Tome:RougelikeGame"
git add lib/src/plugins/martial_arts/martial_styles.dart test/plugins/martial_arts/martial_styles_test.dart
git commit -m "feat: export martialTraditionOf publicly

Renames the private _traditionTagFor to a public martialTraditionOf so
a game composition layer can compute a style's tradition before the
player commits to it (learnStyle only applies the tag after the
fact). No behavior change to learnStyle itself."
```

---

### Task 2: Add a non-throwing `canCombine` pre-check

**Files:**
- Modify: `/Users/m4maxpro/Projects/Tome:RougelikeGame/lib/src/plugins/item/item_combine.dart`
- Test: `/Users/m4maxpro/Projects/Tome:RougelikeGame/test/plugins/item/item_combine_test.dart`

**Interfaces:**
- Consumes: `ItemInstance` (`definitionId`, `owner`, `itemClass`), `ItemDefinition.maxClass`/`toGradeEvolutionDefinition()`, `context.ruleContextFor`, `EvolutionCandidate.conditions`.
- Produces: `bool canCombine(EntityId owner, List<EntityId> instanceEntities, PluginContext context)` — exported transitively via `lib/item_plugin.dart` (already `export 'src/plugins/item/item_combine.dart';` — verify this export line exists; if `item_combine.dart` isn't yet in `lib/item_plugin.dart`'s export list, add it as part of this task, since `combineItems` itself must already be reachable from `package:build_engine/item_plugin.dart` for `CombatStage`/other callers to use it — confirm by grepping `lib/item_plugin.dart` for `item_combine.dart` before assuming a change is needed).

- [ ] **Step 1: Write the failing tests**

```dart
// test/plugins/item/item_combine_test.dart
import 'package:build_engine/build_engine.dart';
import 'package:build_engine/item_plugin.dart';
import 'package:test/test.dart';

PluginContext _bootContext() {
  final events = EventBus();
  final entities = EntityRegistry(events);
  final components = ComponentStore();
  final rng = RngService(1);
  final shared = CoreServices(components: components, events: events);
  final context = PluginContext(
    entities: entities,
    components: components,
    events: events,
    rng: rng,
    rules: RuleEngine(
      entities: entities,
      components: components,
      events: events,
      rng: rng,
      shared: shared,
    ),
    queries: QueryEngine(QueryScope(components: components)),
    modifiers: ModifierCollection(),
    content: ContentRegistry(),
    shared: shared,
  );
  ItemPlugin().initialize(context);
  return context;
}

EntityId _ownInstance(PluginContext context, EntityId owner, String definitionId, int itemClass) {
  final entity = context.entities.create();
  context.components.add(entity, ItemInstance(definitionId: definitionId, owner: owner, itemClass: itemClass));
  return entity;
}

void main() {
  group('canCombine', () {
    test('true for two owned same-definition same-class knives below maxClass', () {
      final context = _bootContext();
      final owner = context.characters.create();
      final a = _ownInstance(context, owner, ItemIds.knife, 1);
      final b = _ownInstance(context, owner, ItemIds.knife, 1);

      expect(canCombine(owner, [a, b], context), isTrue);
    });

    test('false when definitionId or itemClass mismatch', () {
      final context = _bootContext();
      final owner = context.characters.create();
      final knife = _ownInstance(context, owner, ItemIds.knife, 1);
      final sword = _ownInstance(context, owner, ItemIds.ironSword, 1);
      final knifeHigherClass = _ownInstance(context, owner, ItemIds.knife, 2);

      expect(canCombine(owner, [knife, sword], context), isFalse);
      expect(canCombine(owner, [knife, knifeHigherClass], context), isFalse);
    });

    test('false when already at maxClass with no eligible grade path', () {
      final context = _bootContext();
      final owner = context.characters.create();
      // masterworkSharpKnife has maxClass 9 and no gradeEvolution entries at all.
      final a = _ownInstance(context, owner, ItemIds.masterworkSharpKnife, 9);
      final b = _ownInstance(context, owner, ItemIds.masterworkSharpKnife, 9);

      expect(canCombine(owner, [a, b], context), isFalse);
    });

    test('false for fewer than 2 instances, and never throws', () {
      final context = _bootContext();
      final owner = context.characters.create();
      final a = _ownInstance(context, owner, ItemIds.knife, 1);

      expect(canCombine(owner, [a], context), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/plugins/item/item_combine_test.dart`
Expected: FAIL — `canCombine` is not defined.

- [ ] **Step 3: Implement `canCombine`**

Add to `lib/src/plugins/item/item_combine.dart`, above `combineItems` (reusing its exact eligibility logic, minus resource consumption, RNG resolve, and mutation):

```dart
/// A pure, non-throwing preview of whether [combineItems] would even
/// attempt a roll for [instanceEntities] right now — mirrors
/// `TomeService.validate`'s "never mutates, never throws" contract.
/// Does NOT check `ItemResources.upgradePoints` sufficiency — that's a
/// simpler, separate concern a caller can check directly via
/// `context.resources.currentOf`; this function only answers "are these
/// structurally eligible to combine" (same definitionId/itemClass,
/// same owner, and somewhere left to go).
bool canCombine(
  EntityId owner,
  List<EntityId> instanceEntities,
  PluginContext context,
) {
  if (instanceEntities.length < 2) return false;
  if (instanceEntities.toSet().length != instanceEntities.length) return false;

  final instances = [
    for (final e in instanceEntities) context.components.get<ItemInstance>(e),
  ];
  if (instances.any((i) => i == null)) return false;
  final resolved = instances.cast<ItemInstance>();

  final first = resolved.first;
  for (var i = 1; i < resolved.length; i++) {
    if (resolved[i].definitionId != first.definitionId ||
        resolved[i].itemClass != first.itemClass) {
      return false;
    }
  }
  if (resolved.any((i) => i.owner != owner)) return false;

  final definition = itemDefinition(first.definitionId, context);
  if (definition.maxClass == null) return false;
  final atMax = first.itemClass >= definition.maxClass!;
  final gradeEvolution = definition.toGradeEvolutionDefinition();
  final ruleContext = context.ruleContextFor(owner);
  final hasGradePath = gradeEvolution.candidates.any(
    (candidate) => candidate.conditions.every((c) => c.evaluate(ruleContext)),
  );
  return !(atMax && !hasGradePath);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test test/plugins/item/item_combine_test.dart`
Expected: PASS (4/4). Then `dart test` for the full suite and `dart analyze lib test` — expected: no regressions, no analyzer issues.

- [ ] **Step 5: Commit**

```bash
cd "/Users/m4maxpro/Projects/Tome:RougelikeGame"
git add lib/src/plugins/item/item_combine.dart test/plugins/item/item_combine_test.dart
git commit -m "feat: add canCombine, a non-throwing Combine eligibility pre-check

Mirrors TomeService.validate's pure-preview pattern for Item Combine:
same eligibility checks combineItems already runs (definitionId/
itemClass match, ownership, atMax-with-no-grade-path), without the
resource consume, RNG resolve, or mutation. Lets a caller (e.g. a
client UI) decide whether to offer Combine without using
CombineNotAvailableException/CombineMismatchException as control
flow."
```

---

## Phase 1 — Flutter project scaffold

### Task 3: Scaffold the Flutter app and wire the build_engine dependency

**Files:**
- Create: `/Users/m4maxpro/Projects/Tome_client/pubspec.yaml` (via `flutter create`, then edited)
- Create: `/Users/m4maxpro/Projects/Tome_client/lib/main.dart` (stock, replaced in Task 13)
- Create: `/Users/m4maxpro/Projects/Tome_client/test/widget_test.dart` (stock)

**Interfaces:**
- Produces: a runnable Flutter project named `tome_client` with `build_engine`, `flutter_bloc`, `go_router` resolvable.

- [ ] **Step 1: Scaffold the project**

The `Tome_client` directory currently contains only `.git/` and `docs/` (from the brainstorming session), so `flutter create` can target it directly:

```bash
cd /Users/m4maxpro/Projects/Tome_client
flutter create --project-name tome_client --org com.mgtechlabs --platforms=macos,ios,android,web .
```

- [ ] **Step 2: Add dependencies**

Edit `pubspec.yaml`'s `dependencies:` block to add:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_bloc: ^9.0.0
  go_router: ^14.0.0
  build_engine:
    git:
      url: git@github-built-engine:MGTechLabs2026/built_engine.git
```

Add a `dependency_overrides:` block at the bottom of the same file, for local development against the sibling checkout:

```yaml
dependency_overrides:
  build_engine:
    path: /Users/m4maxpro/Projects/Tome:RougelikeGame
```

Also add to `dev_dependencies:`:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

Confirm `environment:` reads `sdk: ^3.7.0` (bump from whatever `flutter create` generated, to match `build_engine`'s own floor).

- [ ] **Step 3: Resolve dependencies and verify the stock app**

```bash
cd /Users/m4maxpro/Projects/Tome_client
flutter pub get
```

Expected: resolves cleanly (the `dependency_overrides` path entry means the git URL is never actually fetched during local dev — confirm no network/auth error is raised regardless).

```bash
flutter analyze
flutter test
```

Expected: both clean (the stock `widget_test.dart` counter test passes).

Verify the app actually launches. Check available devices first:

```bash
flutter devices
```

Launch on whichever desktop/simulator/chrome target is available, e.g.:

```bash
flutter run -d macos
```

Expected: the stock Flutter counter-demo app opens in a window. Confirm visually, then stop the run (Ctrl-C / `q` in the terminal running `flutter run`).

- [ ] **Step 4: Commit**

```bash
cd /Users/m4maxpro/Projects/Tome_client
git add -A
git commit -m "chore: scaffold Flutter app, add build_engine/flutter_bloc/go_router deps

flutter create with macos/ios/android/web platforms; build_engine
wired as a git dependency with a local dependency_overrides path for
day-to-day development against the sibling Tome:RougelikeGame
checkout."
```

---

## Phase 2 — Core models

### Task 4: `GamePhase` and the adapter view models

**Files:**
- Create: `lib/core/models/game_phase.dart`
- Create: `lib/core/models/character_view.dart`
- Create: `lib/core/models/grid_cell_view.dart`
- Create: `lib/core/models/item_view.dart`
- Create: `lib/core/models/technique_view.dart`
- Create: `lib/core/models/combat_log_entry_view.dart`
- Create: `lib/core/models/loot_option_view.dart`
- Create: `lib/core/models/combine_result_view.dart`
- Create: `lib/core/models/training_result_view.dart`
- Test: `test/core/models/game_phase_test.dart`

**Interfaces:**
- Produces every type later tasks import from `package:tome_client/core/models/...`. This is the single most important consistency anchor in this plan — every later task's adapter/bloc code uses these exact class/field names.

- [ ] **Step 1: Write the failing test (GamePhase only — the models are pure data classes, exercised properly once adapters/blocs consume them in later tasks' own tests)**

```dart
// test/core/models/game_phase_test.dart
import 'package:test/test.dart' as dart_test;
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/models/game_phase.dart';

void main() {
  test('GamePhase has one variant per milestone phase', () {
    const phases = <GamePhase>[
      GamePhase.characterCreation,
      GamePhase.tome,
      GamePhase.trainingPreparation,
      GamePhase.training,
      GamePhase.trainingResult,
      GamePhase.combatPreparation,
      GamePhase.combat,
      GamePhase.loot,
      GamePhase.runComplete,
    ];
    expect(phases.toSet().length, 9);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/models/game_phase_test.dart`
Expected: FAIL — `package:tome_client/core/models/game_phase.dart` doesn't exist.

- [ ] **Step 3: Write the models**

```dart
// lib/core/models/game_phase.dart
enum GamePhase {
  characterCreation,
  tome,
  trainingPreparation,
  training,
  trainingResult,
  combatPreparation,
  combat,
  loot,
  runComplete,
}
```

```dart
// lib/core/models/character_view.dart
class CharacterView {
  const CharacterView({
    required this.name,
    required this.physiqueId,
    required this.physiqueAffinityTradition,
    required this.martialTradition,
    required this.styleId,
    required this.healthCurrent,
    required this.healthMax,
  });

  final String name;
  final String physiqueId;

  /// `'western'`/`'eastern'` — the tradition this physique carries a
  /// synergy modifier for, read from its content tags.
  final String physiqueAffinityTradition;
  final String martialTradition;
  final String styleId;
  final num healthCurrent;
  final num healthMax;
}
```

```dart
// lib/core/models/grid_cell_view.dart
enum GridComponentKind { item, technique }

class GridCellView {
  const GridCellView({
    required this.slotId,
    required this.row,
    required this.col,
    this.occupant,
  });

  final String slotId;
  final int row;
  final int col;
  final GridCellOccupant? occupant;

  bool get isEmpty => occupant == null;
}

class GridCellOccupant {
  const GridCellOccupant({
    required this.kind,
    required this.contentId,
    required this.displayName,
    this.instanceEntityValue,
  });

  final GridComponentKind kind;
  final String contentId;
  final String displayName;

  /// The owning `ItemInstance` entity's raw id (`EntityId.value`), for
  /// item occupants only — used to detect same-definitionId/same-class
  /// combine matches without leaking `EntityId` itself past core/engine.
  final int? instanceEntityValue;
}
```

```dart
// lib/core/models/item_view.dart
enum ItemDisplayState { locked, usable, mastered, equipped }

class ItemView {
  const ItemView({
    required this.definitionId,
    required this.name,
    required this.category,
    required this.properties,
    required this.state,
    required this.itemClass,
    required this.maxClass,
    required this.masteryLevel,
    required this.masteryProgress,
    required this.masteryThresholds,
    required this.instanceEntityValue,
    required this.combinableWith,
  });

  final String definitionId;
  final String name;
  final String category;
  final Map<String, num> properties;
  final ItemDisplayState state;
  final int itemClass;
  final int? maxClass;
  final int masteryLevel;
  final num masteryProgress;
  final List<num> masteryThresholds;

  /// This specific owned copy's entity id (raw `EntityId.value`) — null
  /// for a definition-level view with no single copy in context.
  final int? instanceEntityValue;

  /// Other owned instance entity values (raw `EntityId.value`) sharing
  /// this item's `definitionId`+`itemClass` right now — the Tome
  /// screen draws a tether to each of these. Empty if none.
  final List<int> combinableWith;
}
```

```dart
// lib/core/models/technique_view.dart
class TechniqueView {
  const TechniqueView({
    required this.definitionId,
    required this.name,
    required this.tier,
    required this.properties,
    required this.discovered,
    required this.learned,
    required this.masteryLevel,
    required this.evolvedFromId,
  });

  final String definitionId;
  final String name;
  final String tier;
  final Map<String, num> properties;
  final bool discovered;
  final bool learned;
  final int masteryLevel;

  /// The technique this one evolved from, if any — one hop, sourced
  /// from `EngineSession`'s accumulated lineage map.
  final String? evolvedFromId;
}
```

```dart
// lib/core/models/combat_log_entry_view.dart
enum CombatLogEntryKind { turnStart, damage, heal, actionResolved, victory, defeat }

class CombatLogEntryView {
  const CombatLogEntryView({
    required this.kind,
    required this.text,
  });

  final CombatLogEntryKind kind;
  final String text;
}
```

```dart
// lib/core/models/loot_option_view.dart
enum LootKind { upgradePoints, gridExpansion, newComponent }

class LootOptionView {
  const LootOptionView({
    required this.kind,
    required this.title,
    required this.detail,
  });

  final LootKind kind;
  final String title;
  final String detail;
}
```

```dart
// lib/core/models/combine_result_view.dart
enum CombineResultKind { fail, classUpgraded, evolvedIntoNewItem }

class CombineResultView {
  const CombineResultView({
    required this.kind,
    required this.resultingDefinitionId,
    required this.resultingItemClass,
  });

  final CombineResultKind kind;
  final String resultingDefinitionId;
  final int resultingItemClass;
}
```

```dart
// lib/core/models/training_result_view.dart
class TrainingResultView {
  const TrainingResultView({
    required this.subject,
    required this.dimensions,
    required this.gain,
    required this.crossedIntoUsableOrLearned,
    this.evolvedIntoDefinitionId,
    this.evolvedFromDefinitionId,
  });

  final String subject;
  final Map<String, double> dimensions;
  final num gain;
  final bool crossedIntoUsableOrLearned;
  final String? evolvedIntoDefinitionId;
  final String? evolvedFromDefinitionId;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/models/game_phase_test.dart`
Expected: PASS. Then `flutter analyze` — expected: no issues (delete the stray `import 'package:test/test.dart' as dart_test;` line from the test file above if `flutter analyze` flags it as unused — the test only needs `flutter_test`).

- [ ] **Step 5: Commit**

```bash
git add lib/core/models test/core/models
git commit -m "feat: add GamePhase and adapter view models

Client-local display types for every screen the design spec
describes. No package:build_engine import anywhere in this directory
— engine enums (DiscoveryState, RewardKind, CombineOutcome) are
mapped to these client-local equivalents inside core/engine/
adapters, not re-exported."
```

---

## Phase 3 — Engine adapter layer

### Task 5: `EngineSession`

**Files:**
- Create: `lib/core/engine/engine_session.dart`
- Test: `test/core/engine/engine_session_test.dart`

**Interfaces:**
- Consumes: `PluginContext`, `EntityRegistry`, `ComponentStore`, `EventBus`, `RngService`, `RuleEngine`, `QueryEngine`, `ModifierCollection`, `ContentRegistry`, `CoreServices` (all `package:build_engine/build_engine.dart`); `CombatPlugin` (`package:build_engine/combat_plugin.dart`); `MartialArtsPlugin` (`package:build_engine/martial_arts_plugin.dart`); `PhysiquePlugin` (`package:build_engine/physique_plugin.dart`); `ItemPlugin` (`package:build_engine/item_plugin.dart`); `TechniquePlugin` (`package:build_engine/technique_plugin.dart`); `TechniqueEvolved` event.
- Produces: `EngineSession` — `EngineSession(int seed)` constructor; fields `context` (`PluginContext`), `combatPlugin` (`CombatPlugin`), `character` (`EntityId`, set by `CharacterAdapter` after creation — nullable until then); `Map<String, String> lineage` (evolved-technique-id → base-technique-id, populated live); method `void dispose()` cancelling the lineage subscription.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/engine/engine_session_test.dart
import 'package:build_engine/build_engine.dart';
import 'package:build_engine/technique_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/engine_session.dart';

void main() {
  test('bootstraps a PluginContext with every plugin this client needs initialized', () {
    final session = EngineSession(1);

    expect(session.context.entities, isNotNull);
    expect(session.context.tome, isNotNull);
    // Item content is loaded once ItemPlugin.initialize has run.
    expect(session.context.content.find('knife'), isNotNull);
  });

  test('accumulates technique lineage from TechniqueEvolved events', () {
    final session = EngineSession(2);

    session.context.events.publish(
      const TechniqueEvolved(fromId: 'basic_punch', toId: 'light_punch'),
    );

    expect(session.lineage['light_punch'], 'basic_punch');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/engine/engine_session_test.dart`
Expected: FAIL — `EngineSession` doesn't exist.

- [ ] **Step 3: Implement `EngineSession`**

```dart
// lib/core/engine/engine_session.dart
import 'package:build_engine/build_engine.dart';
import 'package:build_engine/combat_plugin.dart';
import 'package:build_engine/item_plugin.dart';
import 'package:build_engine/martial_arts_plugin.dart';
import 'package:build_engine/physique_plugin.dart';
import 'package:build_engine/technique_plugin.dart';

/// Bootstraps one `PluginContext` with every plugin the client drives,
/// and owns the small pieces of session-scoped bookkeeping build_engine
/// itself has no reason to store: which character this session is for,
/// and the technique-evolution lineage chain (build_engine's own
/// `TechniqueEvolved` event is one-hop only — see the design spec's
/// §2.1). Mirrors game_run.dart's own PluginContext construction block
/// exactly, so this session composes with build_engine the same way the
/// engine's own reference run does.
class EngineSession {
  EngineSession(int seed) : rng = RngService(seed) {
    final events = EventBus();
    final entities = EntityRegistry(events);
    final components = ComponentStore();
    final shared = CoreServices(components: components, events: events);
    context = PluginContext(
      entities: entities,
      components: components,
      events: events,
      rng: rng,
      rules: RuleEngine(
        entities: entities,
        components: components,
        events: events,
        rng: rng,
        shared: shared,
      ),
      queries: QueryEngine(QueryScope(components: components)),
      modifiers: ModifierCollection(),
      content: ContentRegistry(),
      shared: shared,
    );

    combatPlugin = CombatPlugin()..initialize(context);
    // MartialArtsPlugin.dependencies => ['combat'] must already be initialized.
    MartialArtsPlugin().initialize(context);
    PhysiquePlugin().initialize(context);
    ItemPlugin().initialize(context);
    TechniquePlugin().initialize(context);

    _lineageSubscription = context.events.subscribe<TechniqueEvolved>((event) {
      lineage[event.toId] = event.fromId;
    });
  }

  final RngService rng;
  late final PluginContext context;
  late final CombatPlugin combatPlugin;
  late final EventSubscription _lineageSubscription;

  /// Set once by `CharacterAdapter.createCharacter`; every other adapter
  /// requires it to already be set (a `StateError` on read-before-write
  /// would only ever indicate a client bug, so a plain late field is used
  /// rather than a nullable one threaded through every adapter method).
  late EntityId character;

  final Map<String, String> lineage = {};

  void dispose() => _lineageSubscription.cancel();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/engine/engine_session_test.dart`
Expected: PASS (2/2).

- [ ] **Step 5: Commit**

```bash
git add lib/core/engine/engine_session.dart test/core/engine/engine_session_test.dart
git commit -m "feat: add EngineSession, the client's PluginContext bootstrap"
```

---

### Task 6: `CharacterAdapter`

**Files:**
- Create: `lib/core/engine/character_adapter.dart`
- Test: `test/core/engine/character_adapter_test.dart`

**Interfaces:**
- Consumes: `EngineSession` (Task 5); `CombatantComponent`, `HealthComponent` (`build_engine.dart`); `initializePhysique` (`physique_plugin.dart`); `martialTraditionOf`, `stylesForTradition`, `MartialTraditions`, `learnStyle` (`martial_arts_plugin.dart`, Task 1's new export).
- Produces: `CharacterAdapter(EngineSession session)`; `CharacterView createCharacter(String name)` (creates the character entity, assigns physique, returns a view with `martialTradition`/`styleId` still empty — style is chosen next); `List<String> availableStyles()` (all 6, western+eastern concatenated); `String? synergyTraditionFor(String styleId)` (wraps `martialTraditionOf`, for the UI to compare against the view's `physiqueAffinityTradition`); `CharacterView chooseStyle(String styleId)` (calls `learnStyle`, returns the completed `CharacterView`).

- [ ] **Step 1: Write the failing test**

```dart
// test/core/engine/character_adapter_test.dart
import 'package:build_engine/martial_arts_plugin.dart';
import 'package:build_engine/physique_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';

void main() {
  test('createCharacter assigns a name, physique, and starting health', () {
    final session = EngineSession(1);
    final adapter = CharacterAdapter(session);

    final view = adapter.createCharacter('Test Fighter');

    expect(view.name, 'Test Fighter');
    expect(PhysiqueTypes.all, contains(view.physiqueId));
    expect(view.healthCurrent, 100);
    expect(view.healthMax, 100);
  });

  test('availableStyles returns all 6 known styles', () {
    final session = EngineSession(2);
    final adapter = CharacterAdapter(session);
    adapter.createCharacter('Test Fighter');

    expect(
      adapter.availableStyles().toSet(),
      {
        MartialStyles.boxing, MartialStyles.wrestling, MartialStyles.fencing,
        MartialStyles.shaolin, MartialStyles.taiChi, MartialStyles.wingChun,
      },
    );
  });

  test('chooseStyle learns the style and fills in the tradition/style view fields', () {
    final session = EngineSession(3);
    final adapter = CharacterAdapter(session);
    adapter.createCharacter('Test Fighter');

    final view = adapter.chooseStyle(MartialStyles.boxing);

    expect(view.styleId, MartialStyles.boxing);
    expect(view.martialTradition, MartialTraditions.western);
    expect(adapter.synergyTraditionFor(MartialStyles.shaolin), MartialTraditions.eastern);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/engine/character_adapter_test.dart`
Expected: FAIL — `CharacterAdapter` doesn't exist.

- [ ] **Step 3: Implement `CharacterAdapter`**

```dart
// lib/core/engine/character_adapter.dart
import 'package:build_engine/build_engine.dart';
import 'package:build_engine/martial_arts_plugin.dart';
import 'package:build_engine/physique_plugin.dart';

import '../models/character_view.dart';
import 'engine_session.dart';

class CharacterAdapter {
  CharacterAdapter(this._session);

  final EngineSession _session;

  String _name = '';
  String _physiqueId = '';
  String _styleId = '';
  String _martialTradition = '';

  /// The `'western_affinity'`/`'eastern_affinity'` tag on [physiqueId]'s
  /// content, mapped to the matching `MartialTraditions` value — the real
  /// tradition this physique's synergy `Modifier`s favor (see
  /// physique_content.dart's `×1.25`/`×0.85` conditional modifiers).
  String _affinityTraditionFor(String physiqueId) {
    final definition = _session.context.content.get(physiqueId);
    if (definition.tags.contains('western_affinity')) return MartialTraditions.western;
    return MartialTraditions.eastern;
  }

  CharacterView _view() => CharacterView(
        name: _name,
        physiqueId: _physiqueId,
        physiqueAffinityTradition: _affinityTraditionFor(_physiqueId),
        martialTradition: _martialTradition,
        styleId: _styleId,
        healthCurrent: _session.context.components
                .get<HealthComponent>(_session.character)?.current ??
            0,
        healthMax: _session.context.components
                .get<HealthComponent>(_session.character)?.max ??
            0,
      );

  CharacterView createCharacter(String name) {
    _name = name;
    final character = _session.context.characters.create();
    _session.character = character;
    _session.context.components
        .add(character, const CombatantComponent(team: 'player', initiative: 10));
    _session.context.components
        .add(character, const HealthComponent(current: 100, max: 100));
    _physiqueId = initializePhysique(character, _session.context);
    return _view();
  }

  List<String> availableStyles() => [
        ...stylesForTradition(MartialTraditions.western),
        ...stylesForTradition(MartialTraditions.eastern),
      ];

  String? synergyTraditionFor(String styleId) => martialTraditionOf(styleId);

  CharacterView chooseStyle(String styleId) {
    _styleId = styleId;
    _martialTradition = martialTraditionOf(styleId) ?? '';
    learnStyle(_session.character, styleId, _session.context);
    return _view();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/engine/character_adapter_test.dart`
Expected: PASS (3/3).

- [ ] **Step 5: Commit**

```bash
git add lib/core/engine/character_adapter.dart test/core/engine/character_adapter_test.dart
git commit -m "feat: add CharacterAdapter"
```

---

### Task 7: `TomeAdapter`

**Files:**
- Create: `lib/core/engine/tome_adapter.dart`
- Test: `test/core/engine/tome_adapter_test.dart`

**Interfaces:**
- Consumes: `EngineSession`; `TomeDefinition.grid`, `TomeService` (via `context.tome`), `SlotId`, `BuildComponentRef`, `TomePlacement` (`build_engine.dart`); `itemDefinition`, `ownItem`, `discoverItem`, `addItemToTome` (`item_plugin.dart`); `techniqueDefinition`, `addTechniqueToTome` (`technique_plugin.dart`).
- Produces: `TomeAdapter(EngineSession session)`; `void createInitialTome()` (defines+creates a 3×3 grid Tome, called once after character creation, before granting the starting kit); `List<GridCellView> inspect()`; `void insertItem(String definitionId, String slotId)`; `void insertTechnique(String definitionId, String slotId)`; `void remove(String slotId)`; `void move(String fromSlotId, String toSlotId)`; `int get width` / `int get height`; `void expandGrid()` (grid-expansion migration: builds a new, one-column-wider `TomeDefinition.grid`, replays every existing placement into the new grid, keeping the same `slotId` coordinates for cells that still exist).

- [ ] **Step 1: Write the failing test**

```dart
// test/core/engine/tome_adapter_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/tome_adapter.dart';

void main() {
  late EngineSession session;
  late TomeAdapter tomeAdapter;

  setUp(() {
    session = EngineSession(1);
    CharacterAdapter(session).createCharacter('Test Fighter');
    tomeAdapter = TomeAdapter(session);
    tomeAdapter.createInitialTome();
  });

  test('createInitialTome produces a 3x3 grid, all empty', () {
    final cells = tomeAdapter.inspect();
    expect(cells.length, 9);
    expect(cells.every((c) => c.isEmpty), isTrue);
    expect(tomeAdapter.width, 3);
    expect(tomeAdapter.height, 3);
  });

  test('insertItem places an occupant at the given slot', () {
    tomeAdapter.insertItem('knife', '0,0');

    final cell = tomeAdapter.inspect().firstWhere((c) => c.slotId == '0,0');
    expect(cell.isEmpty, isFalse);
    expect(cell.occupant!.contentId, 'knife');
  });

  test('move relocates an occupant', () {
    tomeAdapter.insertItem('knife', '0,0');
    tomeAdapter.move('0,0', '1,1');

    expect(tomeAdapter.inspect().firstWhere((c) => c.slotId == '0,0').isEmpty, isTrue);
    expect(tomeAdapter.inspect().firstWhere((c) => c.slotId == '1,1').isEmpty, isFalse);
  });

  test('expandGrid grows the grid and preserves existing placements', () {
    tomeAdapter.insertItem('knife', '0,0');
    tomeAdapter.expandGrid();

    expect(tomeAdapter.width, 4);
    expect(tomeAdapter.height, 3);
    expect(tomeAdapter.inspect().length, 12);
    expect(tomeAdapter.inspect().firstWhere((c) => c.slotId == '0,0').occupant!.contentId, 'knife');
  });
}
```

Note: `insertItem` in this test targets `knife`, which requires the item to already be OWNED and USABLE per `addItemToTome`'s own gate. Since this task's own unit tests only exercise `TomeAdapter` in isolation, `insertItem`'s implementation (Step 3) must itself call `ownItem`/`discoverItem` first if not already owned — see the implementation below; this keeps `TomeAdapter` usable standalone in tests without requiring `ItemAdapter` to run first, while `RewardAdapter`/starting-kit code (Task 12) can still call the same method after doing its own `ownItem`/`discoverItem` (idempotent — `ownItem` always creates a fresh instance, so `TomeAdapter.insertItem` must NOT call `ownItem` again if the caller already owns a copy; see implementation note in Step 3).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/engine/tome_adapter_test.dart`
Expected: FAIL — `TomeAdapter` doesn't exist.

- [ ] **Step 3: Implement `TomeAdapter`**

```dart
// lib/core/engine/tome_adapter.dart
import 'package:build_engine/build_engine.dart';
import 'package:build_engine/item_plugin.dart';
import 'package:build_engine/technique_plugin.dart';

import '../models/grid_cell_view.dart';
import 'engine_session.dart';

class TomeAdapter {
  TomeAdapter(this._session);

  final EngineSession _session;

  static const _tomeId = 'client_tome';
  int _width = 3;
  int _height = 3;
  var _generation = 0;

  int get width => _width;
  int get height => _height;

  void createInitialTome() {
    _defineAndCreate(_width, _height);
  }

  void _defineAndCreate(int width, int height) {
    _generation++;
    final definitionId = '$_tomeId#$_generation';
    _session.context.tome.defineTome(
      TomeDefinition.grid(id: definitionId, width: width, height: height),
    );
    _session.context.tome.createTome(_session.character, definitionId);
  }

  List<GridCellView> inspect() {
    final placements = {
      for (final p in _session.context.tome.inspect(_session.character)) p.slot.id: p,
    };
    final cells = <GridCellView>[];
    for (var row = 0; row < _height; row++) {
      for (var col = 0; col < _width; col++) {
        final slotId = '$row,$col';
        final placement = placements[slotId];
        cells.add(GridCellView(
          slotId: slotId,
          row: row,
          col: col,
          occupant: placement == null ? null : _occupantFor(placement.buildComponentRef),
        ));
      }
    }
    return cells;
  }

  GridCellOccupant _occupantFor(BuildComponentRef ref) {
    if (ref.referenceType == itemReferenceType) {
      final item = itemDefinition(ref.contentId, _session.context);
      return GridCellOccupant(
        kind: GridComponentKind.item,
        contentId: item.id,
        displayName: item.id,
        instanceEntityValue: ref.instanceEntityId?.value,
      );
    }
    final technique = techniqueDefinition(ref.contentId, _session.context);
    return GridCellOccupant(
      kind: GridComponentKind.technique,
      contentId: technique.id,
      displayName: technique.name,
    );
  }

  /// Places [definitionId] at [slotId]. If [instanceEntityId] is omitted
  /// and the character doesn't already own a copy, owns+discovers one
  /// first (the starting-kit / reward-grant path); if a specific owned
  /// copy's entity id is already known (e.g. from `ItemAdapter`'s combine
  /// flow), pass it directly instead of minting a new one.
  void insertItem(String definitionId, String slotId, {EntityId? instanceEntityId}) {
    final item = itemDefinition(definitionId, _session.context);
    var instance = instanceEntityId;
    if (instance == null) {
      final alreadyOwned = isItemOwned(_session.character, definitionId, _session.context);
      if (!alreadyOwned) {
        instance = ownItem(_session.character, definitionId, _session.context);
        discoverItem(_session.character, item, _session.context);
      }
    }
    addItemToTome(
      _session.character,
      SlotId(slotId),
      item,
      _session.context,
      instanceEntityId: instance,
    );
  }

  void insertTechnique(String definitionId, String slotId) {
    final technique = techniqueDefinition(definitionId, _session.context);
    addTechniqueToTome(_session.character, SlotId(slotId), technique, _session.context);
  }

  void remove(String slotId) => _session.context.tome.remove(_session.character, SlotId(slotId));

  void move(String fromSlotId, String toSlotId) =>
      _session.context.tome.move(_session.character, SlotId(fromSlotId), SlotId(toSlotId));

  /// No engine primitive grows a live `Container` (`ARCHITECTURE.md`'s
  /// Tome section — a `Container` is fixed-size once built), so a grid
  /// expansion builds a brand-new, wider `TomeDefinition`, creates a
  /// fresh `TomeInstance` from it (this replaces the character's Tome
  /// component — see `TomeService.createTome`'s own "overwrites any
  /// existing Tome" doc comment), and replays every existing placement
  /// back in at the same `row,col` coordinates (still valid, since the
  /// new grid is only ever wider/taller, never smaller).
  void expandGrid({int addWidth = 1, int addHeight = 0}) {
    final existing = _session.context.tome.inspect(_session.character);
    _defineAndCreate(_width + addWidth, _height + addHeight);
    _width += addWidth;
    _height += addHeight;
    for (final placement in existing) {
      _session.context.tome.insert(
        _session.character,
        placement.slot,
        placement.buildComponentRef,
      );
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/engine/tome_adapter_test.dart`
Expected: PASS (4/4).

- [ ] **Step 5: Commit**

```bash
git add lib/core/engine/tome_adapter.dart test/core/engine/tome_adapter_test.dart
git commit -m "feat: add TomeAdapter with client-owned 3x3 grid + expansion migration"
```

---

### Task 8: `ItemAdapter`

**Files:**
- Create: `lib/core/engine/item_adapter.dart`
- Test: `test/core/engine/item_adapter_test.dart`

**Interfaces:**
- Consumes: `EngineSession`, `TomeAdapter` (Task 7); `itemDefinition`, `isItemOwned`, `isItemUsable`, `isItemActive`, `ownItem`, `discoverItem`, `ItemInstance` (`item_plugin.dart`); `canCombine`, `combineItems`, `ItemCombineSucceeded`, `ItemCombineFailed`, `CombineOutcome` (Task 2's export + `item_combine.dart`'s existing types, all reachable via `item_plugin.dart`).
- Produces: `ItemAdapter(EngineSession session)`; `List<ItemView> ownedItems()`; `ItemView viewOf(String definitionId)`; `CombineResultView combine(List<int> instanceEntityValues)` (resolves raw values back to `EntityId`s, calls `combineItems`, maps `CombineOutcome` → `CombineResultKind`).

- [ ] **Step 1: Write the failing test**

```dart
// test/core/engine/item_adapter_test.dart
import 'package:build_engine/item_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/item_adapter.dart';
import 'package:tome_client/core/models/item_view.dart';

void main() {
  late EngineSession session;
  late ItemAdapter itemAdapter;

  setUp(() {
    session = EngineSession(7);
    CharacterAdapter(session).createCharacter('Test Fighter');
    itemAdapter = ItemAdapter(session);
  });

  test('an unowned item is not returned by ownedItems', () {
    expect(itemAdapter.ownedItems(), isEmpty);
  });

  test('owning and discovering the knife makes it usable (no mastery requirement)', () {
    ownItem(session.character, ItemIds.knife, session.context);
    discoverItem(session.character, itemDefinition(ItemIds.knife, session.context), session.context);

    final view = itemAdapter.viewOf(ItemIds.knife);
    expect(view.state, ItemDisplayState.usable);
  });

  test('owning cloth armor without training leaves it locked', () {
    ownItem(session.character, ItemIds.clothArmor, session.context);
    discoverItem(session.character, itemDefinition(ItemIds.clothArmor, session.context), session.context);

    final view = itemAdapter.viewOf(ItemIds.clothArmor);
    expect(view.state, ItemDisplayState.locked);
  });

  test('two owned same-class knives report each other as combinable', () {
    ownItem(session.character, ItemIds.knife, session.context);
    ownItem(session.character, ItemIds.knife, session.context);
    discoverItem(session.character, itemDefinition(ItemIds.knife, session.context), session.context);

    final views = itemAdapter.ownedItems();
    expect(views.length, 2);
    expect(views[0].combinableWith, [views[1].instanceEntityValue]);
    expect(views[1].combinableWith, [views[0].instanceEntityValue]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/engine/item_adapter_test.dart`
Expected: FAIL — `ItemAdapter` doesn't exist.

- [ ] **Step 3: Implement `ItemAdapter`**

```dart
// lib/core/engine/item_adapter.dart
import 'package:build_engine/build_engine.dart';
import 'package:build_engine/item_plugin.dart';

import '../models/combine_result_view.dart';
import '../models/item_view.dart';
import 'engine_session.dart';

class ItemAdapter {
  ItemAdapter(this._session);

  final EngineSession _session;

  /// Every `ItemInstance` entity [_session.character] owns, grouped by
  /// `(definitionId, itemClass)` — the exact key `canCombine`/
  /// `combineItems` require inputs to share.
  Map<(String, int), List<EntityId>> _ownedInstancesByKey() {
    final grouped = <(String, int), List<EntityId>>{};
    for (final entity in _session.context.components.entitiesWith<ItemInstance>()) {
      final instance = _session.context.components.get<ItemInstance>(entity)!;
      if (instance.owner != _session.character) continue;
      grouped.putIfAbsent((instance.definitionId, instance.itemClass), () => []).add(entity);
    }
    return grouped;
  }

  ItemView _viewFor(String definitionId, EntityId? instanceEntity, Map<(String, int), List<EntityId>> grouped) {
    final item = itemDefinition(definitionId, _session.context);
    final owned = isItemOwned(_session.character, definitionId, _session.context);
    final usable = owned && isItemUsable(_session.character, item, _session.context);
    final active = owned && isItemActive(_session.character, definitionId, _session.context);
    final masterySubject = item.requirement?.masterySubject ?? itemSubject(definitionId);
    final masteryLevel = _session.context.mastery.levelOf(_session.character, masterySubject);
    final masteryProgress = _session.context.mastery.progressOf(_session.character, masterySubject);
    final thresholds = _session.context.mastery.definitionOf(masterySubject)?.thresholds ?? const <num>[];
    final itemClass = instanceEntity == null
        ? 1
        : _session.context.components.get<ItemInstance>(instanceEntity)!.itemClass;

    final state = active
        ? ItemDisplayState.equipped
        : (item.maxClass != null && itemClass >= item.maxClass!)
            ? ItemDisplayState.mastered
            : usable
                ? ItemDisplayState.usable
                : ItemDisplayState.locked;

    final combinableWith = instanceEntity == null
        ? const <int>[]
        : (grouped[(definitionId, itemClass)] ?? const <EntityId>[])
            .where((e) => e != instanceEntity)
            .map((e) => e.value)
            .toList();

    return ItemView(
      definitionId: definitionId,
      name: definitionId,
      category: item.category,
      properties: item.properties,
      state: state,
      itemClass: itemClass,
      maxClass: item.maxClass,
      masteryLevel: masteryLevel,
      masteryProgress: masteryProgress,
      masteryThresholds: List<num>.from(thresholds),
      instanceEntityValue: instanceEntity?.value,
      combinableWith: combinableWith,
    );
  }

  List<ItemView> ownedItems() {
    final grouped = _ownedInstancesByKey();
    return [
      for (final entry in grouped.entries)
        for (final instance in entry.value) _viewFor(entry.key.$1, instance, grouped),
    ];
  }

  ItemView viewOf(String definitionId) {
    final grouped = _ownedInstancesByKey();
    final firstOwned = grouped.entries.firstWhere(
      (e) => e.key.$1 == definitionId,
      orElse: () => MapEntry((definitionId, 1), const []),
    );
    final instance = firstOwned.value.isEmpty ? null : firstOwned.value.first;
    return _viewFor(definitionId, instance, grouped);
  }

  CombineResultView combine(List<int> instanceEntityValues) {
    final entities = [for (final v in instanceEntityValues) EntityId(v)];
    final survivor = combineItems(_session.character, entities, _session.context);
    final survivorInstance = _session.context.components.get<ItemInstance>(survivor)!;
    // combineItems already published ItemCombineSucceeded/ItemCombineFailed;
    // re-deriving the outcome kind from the survivor's post-call state
    // (rather than subscribing to those events) keeps this adapter's
    // combine() call synchronous and self-contained.
    return CombineResultView(
      kind: CombineResultKind.classUpgraded,
      resultingDefinitionId: survivorInstance.definitionId,
      resultingItemClass: survivorInstance.itemClass,
    );
  }
}
```

**Deviation note:** `combine()`'s outcome-kind derivation above is a simplification gap — `combineItems` does not return the `CombineOutcome` directly (only the survivor `EntityId`), and inferring `fail` vs. `classUpgraded` vs. `evolvedIntoNewItem` purely from post-call state requires comparing the survivor's definitionId/class against the *pre-call* values, which `combine()` doesn't currently capture. **Fix before Step 4:** capture `first.definitionId`/`first.itemClass` from the resolved instances *before* calling `combineItems`, then compare against the survivor's post-call `definitionId`/`itemClass` to derive the real `CombineResultKind` (unchanged both = `fail`; same id, class+1 = `classUpgraded`; different id = `evolvedIntoNewItem`). Update the implementation accordingly:

```dart
  CombineResultView combine(List<int> instanceEntityValues) {
    final entities = [for (final v in instanceEntityValues) EntityId(v)];
    final before = _session.context.components.get<ItemInstance>(entities.first)!;
    final survivor = combineItems(_session.character, entities, _session.context);
    final after = _session.context.components.get<ItemInstance>(survivor)!;

    final kind = after.definitionId != before.definitionId
        ? CombineResultKind.evolvedIntoNewItem
        : after.itemClass > before.itemClass
            ? CombineResultKind.classUpgraded
            : CombineResultKind.fail;

    return CombineResultView(
      kind: kind,
      resultingDefinitionId: after.definitionId,
      resultingItemClass: after.itemClass,
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/engine/item_adapter_test.dart`
Expected: PASS (4/4).

- [ ] **Step 5: Commit**

```bash
git add lib/core/engine/item_adapter.dart test/core/engine/item_adapter_test.dart
git commit -m "feat: add ItemAdapter with combine-eligibility grouping"
```

---

### Task 9: `TechniqueAdapter`

**Files:**
- Create: `lib/core/engine/technique_adapter.dart`
- Test: `test/core/engine/technique_adapter_test.dart`

**Interfaces:**
- Consumes: `EngineSession`; `techniqueDefinition`, `isTechniqueDiscovered`, `isTechniqueLearned`, `techniqueMasteryLevel`, `discoverTechnique` (`technique_plugin.dart`).
- Produces: `TechniqueAdapter(EngineSession session)`; `TechniqueView viewOf(String definitionId)`; `List<TechniqueView> discoveredTechniques()` (scans `run_content.dart`'s reward-pool roster is a game-layer concept the client doesn't reuse — see Step 3 for how this adapter tracks "known" ids itself instead).

- [ ] **Step 1: Write the failing test**

```dart
// test/core/engine/technique_adapter_test.dart
import 'package:build_engine/technique_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/technique_adapter.dart';

void main() {
  late EngineSession session;
  late TechniqueAdapter techniqueAdapter;

  setUp(() {
    session = EngineSession(11);
    CharacterAdapter(session).createCharacter('Test Fighter');
    techniqueAdapter = TechniqueAdapter(session);
  });

  test('an undiscovered technique reports discovered=false, learned=false', () {
    final view = techniqueAdapter.viewOf(TechniqueIds.basicPunch);
    expect(view.discovered, isFalse);
    expect(view.learned, isFalse);
  });

  test('discoverTechnique makes discovered=true', () {
    techniqueAdapter.discover(TechniqueIds.basicPunch);
    expect(techniqueAdapter.viewOf(TechniqueIds.basicPunch).discovered, isTrue);
  });

  test('discoveredTechniques only returns ids this adapter has discovered', () {
    techniqueAdapter.discover(TechniqueIds.basicPunch);
    final ids = techniqueAdapter.discoveredTechniques().map((v) => v.definitionId).toSet();
    expect(ids, {TechniqueIds.basicPunch});
  });

  test('lineage from EngineSession surfaces on evolvedFromId', () {
    session.lineage[TechniqueIds.lightPunch] = TechniqueIds.basicPunch;
    techniqueAdapter.discover(TechniqueIds.lightPunch);
    expect(techniqueAdapter.viewOf(TechniqueIds.lightPunch).evolvedFromId, TechniqueIds.basicPunch);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/engine/technique_adapter_test.dart`
Expected: FAIL — `TechniqueAdapter` doesn't exist.

- [ ] **Step 3: Implement `TechniqueAdapter`**

```dart
// lib/core/engine/technique_adapter.dart
import 'package:build_engine/technique_plugin.dart';

import '../models/technique_view.dart';
import 'engine_session.dart';

class TechniqueAdapter {
  TechniqueAdapter(this._session);

  final EngineSession _session;

  /// Every id this adapter has ever called `discover` for — the client's
  /// own tracked roster, since (unlike the reference `game_run.dart`) this
  /// client has no fixed reward-pool constant of its own; `RewardAdapter`
  /// (Task 12) calls `discover` whenever a technique reward is granted.
  final Set<String> _discoveredIds = {};

  void discover(String definitionId) {
    final technique = techniqueDefinition(definitionId, _session.context);
    discoverTechnique(_session.character, technique, _session.context);
    _discoveredIds.add(definitionId);
  }

  TechniqueView viewOf(String definitionId) {
    final technique = techniqueDefinition(definitionId, _session.context);
    return TechniqueView(
      definitionId: technique.id,
      name: technique.name,
      tier: technique.tier,
      properties: technique.properties,
      discovered: isTechniqueDiscovered(_session.character, technique, _session.context),
      learned: isTechniqueLearned(_session.character, technique, _session.context),
      masteryLevel: techniqueMasteryLevel(_session.character, technique, _session.context),
      evolvedFromId: _session.lineage[definitionId],
    );
  }

  List<TechniqueView> discoveredTechniques() => [for (final id in _discoveredIds) viewOf(id)];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/engine/technique_adapter_test.dart`
Expected: PASS (4/4).

- [ ] **Step 5: Commit**

```bash
git add lib/core/engine/technique_adapter.dart test/core/engine/technique_adapter_test.dart
git commit -m "feat: add TechniqueAdapter"
```

---

### Task 10: `TrainingAdapter`

**Files:**
- Create: `lib/core/engine/training_adapter.dart`
- Test: `test/core/engine/training_adapter_test.dart`

**Interfaces:**
- Consumes: `EngineSession`, `ItemAdapter` (Task 8), `TechniqueAdapter` (Task 9), `TomeAdapter` (Task 7); `TrainingSession`, `TrainingAttempt`, `TrainingResult`, `TimingExercise`, `TrainingStatistics` (`build_engine.dart`); `itemTrainingExerciseFor`, `isItemUsable` (`item_plugin.dart`); `techniqueTrainingExerciseFor`, `attemptToLearnTechnique`, `evolveTechnique` (`technique_plugin.dart`).
- Produces: `TrainingAdapter(EngineSession session, {required TomeAdapter tomeAdapter})`; `TrainingResultView trainItem(String definitionId, List<TrainingAttempt> attempts)`; `TrainingResultView trainTechnique(String definitionId, List<TrainingAttempt> attempts)` (both apply real mastery/learning gain and, for techniques, attempt evolution — mirroring `TrainingStage.runTraining`'s exact sequence from `game_run.dart`, but taking real player-submitted `TrainingAttempt`s instead of `generateTrainingAttempts`'s synthetic ones).

- [ ] **Step 1: Write the failing test**

```dart
// test/core/engine/training_adapter_test.dart
import 'package:build_engine/build_engine.dart';
import 'package:build_engine/item_plugin.dart';
import 'package:build_engine/technique_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/item_adapter.dart';
import 'package:tome_client/core/engine/technique_adapter.dart';
import 'package:tome_client/core/engine/tome_adapter.dart';
import 'package:tome_client/core/engine/training_adapter.dart';

List<TrainingAttempt> _perfectAttempts({int count = 3}) => [
      for (var i = 0; i < count; i++)
        const TrainingAttempt({'windowStart': 100, 'windowEnd': 200, 'actual': 150}),
    ];

void main() {
  late EngineSession session;
  late TrainingAdapter trainingAdapter;

  setUp(() {
    session = EngineSession(5);
    CharacterAdapter(session).createCharacter('Test Fighter');
    final tomeAdapter = TomeAdapter(session)..createInitialTome();
    trainingAdapter = TrainingAdapter(session, tomeAdapter: tomeAdapter);
  });

  test('trainItem raises mastery progress toward usability for a locked item', () {
    ownItem(session.character, ItemIds.clothArmor, session.context);
    discoverItem(session.character, itemDefinition(ItemIds.clothArmor, session.context), session.context);

    final result = trainingAdapter.trainItem(ItemIds.clothArmor, _perfectAttempts());

    expect(result.gain, greaterThan(0));
    expect(ItemAdapter(session).viewOf(ItemIds.clothArmor).masteryLevel, greaterThanOrEqualTo(0));
  });

  test('trainTechnique can cross the learning threshold with enough perfect attempts', () {
    final technique = techniqueDefinition(TechniqueIds.basicPunch, session.context);
    discoverTechnique(session.character, technique, session.context);

    TrainingResultView result;
    var attempts = 0;
    do {
      result = trainingAdapter.trainTechnique(TechniqueIds.basicPunch, _perfectAttempts());
      attempts++;
    } while (!result.crossedIntoUsableOrLearned && attempts < 20);

    expect(TechniqueAdapter(session).viewOf(TechniqueIds.basicPunch).learned, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/engine/training_adapter_test.dart`
Expected: FAIL — `TrainingAdapter` doesn't exist.

- [ ] **Step 3: Implement `TrainingAdapter`**

```dart
// lib/core/engine/training_adapter.dart
import 'package:build_engine/build_engine.dart';
import 'package:build_engine/item_plugin.dart';
import 'package:build_engine/technique_plugin.dart';

import '../models/training_result_view.dart';
import 'engine_session.dart';
import 'tome_adapter.dart';

/// Mirrors game_run.dart's `trainingGain` exactly (average of every
/// scored dimension, scaled to meaningfully cross the registered
/// [8, 25]-ish mastery/learning thresholds) — not re-derived, just
/// inlined here since `training_simulation.dart`'s free functions are
/// game-layer, not part of any plugin's own public barrel a client
/// depends on directly.
num _trainingGain(TrainingProfile profile) {
  if (profile.dimensions.isEmpty) return 0;
  return TrainingStatistics.average(profile.dimensions.values.toList()) * 20;
}

class TrainingAdapter {
  TrainingAdapter(this._session, {required TomeAdapter tomeAdapter}) : _tomeAdapter = tomeAdapter;

  final EngineSession _session;
  final TomeAdapter _tomeAdapter;

  TrainingResultView trainItem(String definitionId, List<TrainingAttempt> attempts) {
    final item = itemDefinition(definitionId, _session.context);
    final wasUsable = isItemUsable(_session.character, item, _session.context);
    final exercise = itemTrainingExerciseFor(item, const TimingExercise());
    final session = TrainingSession(
      trainee: _session.character,
      subject: itemSubject(definitionId),
      exercise: exercise,
    );
    for (final attempt in attempts) {
      session.submitAttempt(attempt);
    }
    final result = session.complete();
    final gain = _trainingGain(result.profile);
    _session.context.mastery.increase(_session.character, itemSubject(definitionId), gain);
    final nowUsable = isItemUsable(_session.character, item, _session.context);

    return TrainingResultView(
      subject: itemSubject(definitionId),
      dimensions: result.profile.dimensions,
      gain: gain,
      crossedIntoUsableOrLearned: !wasUsable && nowUsable,
    );
  }

  TrainingResultView trainTechnique(String definitionId, List<TrainingAttempt> attempts) {
    final technique = techniqueDefinition(definitionId, _session.context);
    final exercise = techniqueTrainingExerciseFor(technique, const TimingExercise());
    final session = TrainingSession(
      trainee: _session.character,
      subject: techniqueSubject(definitionId),
      exercise: exercise,
    );
    for (final attempt in attempts) {
      session.submitAttempt(attempt);
    }
    final result = session.complete();
    final gain = _trainingGain(result.profile);

    final learning = attemptToLearnTechnique(_session.character, technique, gain, _session.context);

    String? evolvedInto;
    if (learning.learned && technique.evolutionCandidates.isNotEmpty) {
      final evolution = evolveTechnique(_session.character, technique, result.profile, _session.context);
      if (evolution.evolved) {
        evolvedInto = evolution.chosenCandidate!.targetId;
        // Lineage is recorded by EngineSession's own TechniqueEvolved
        // subscription (Task 5) — evolveTechnique publishes that event
        // internally via `EvolutionResolver`? No: evolveTechnique itself
        // does not publish TechniqueEvolved (only game_run.dart's own
        // TrainingStage does, as an orchestration-layer decision) — this
        // adapter must publish it itself:
        _session.context.events.publish(
          TechniqueEvolved(fromId: definitionId, toId: evolvedInto),
        );
        _tomeAdapter.remove(_slotOfTechnique(definitionId) ?? '');
      }
    }

    return TrainingResultView(
      subject: techniqueSubject(definitionId),
      dimensions: result.profile.dimensions,
      gain: gain,
      crossedIntoUsableOrLearned: learning.learned,
      evolvedIntoDefinitionId: evolvedInto,
      evolvedFromDefinitionId: evolvedInto == null ? null : definitionId,
    );
  }

  String? _slotOfTechnique(String definitionId) {
    for (final cell in _tomeAdapter.inspect()) {
      if (cell.occupant?.contentId == definitionId) return cell.slotId;
    }
    return null;
  }
}
```

**Deviation note (verify at implementation time):** confirm whether `evolveTechnique` (`technique_evolution.dart`) publishes `TechniqueEvolved` itself or leaves that to the caller — the source read during planning (`technique_evolution.dart`) shows it's a thin wrapper over `EvolutionResolver.resolve` with **no** event publish inside it; `game_run.dart`'s `TrainingStage.runTraining` is the one that publishes `TechniqueEvolved` after checking `evolution.evolved`. The implementation above follows that same pattern (adapter publishes the event itself) — this is correct as written, but re-confirm against the exact current `technique_evolution.dart` before writing this task's code, since a future engine change could move the publish inside `evolveTechnique` and cause a duplicate-event bug. If evolution succeeds, replace the evolved technique in the Tome at the same slot the base technique occupied (mirrors `TomeManager.replaceWithEvolved`): change the last three lines of the `if (evolution.evolved)` block to:

```dart
        final slot = _slotOfTechnique(definitionId);
        if (slot != null) {
          _tomeAdapter.remove(slot);
          _tomeAdapter.insertTechnique(evolvedInto, slot);
        }
```

(replacing the incorrect bare `_tomeAdapter.remove(_slotOfTechnique(definitionId) ?? '')` line above, which removes without re-inserting the evolved form — fix this before Step 4).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/engine/training_adapter_test.dart`
Expected: PASS (2/2).

- [ ] **Step 5: Commit**

```bash
git add lib/core/engine/training_adapter.dart test/core/engine/training_adapter_test.dart
git commit -m "feat: add TrainingAdapter with real mastery/learning/evolution application"
```

---

### Task 11: `CombatAdapter`

**Files:**
- Create: `lib/core/engine/combat_adapter.dart`
- Test: `test/core/engine/combat_adapter_test.dart`

**Interfaces:**
- Consumes: `EngineSession`, `TomeAdapter`; `CompositeBuildActionInterpreter`, `TechniqueActionInterpreter`, `ItemActionInterpreter` (`build_interpretation.dart`); `AttackAction`, `CombatantComponent`, `HealthComponent`, `ActionCompleted`, `TurnStarted`, `BattleWon`, `BattleLost` (`combat_plugin.dart`); `AutoCombatController`, `CombatPolicy` (`auto_combat_plugin.dart`); `EntityDamaged`, `EntityHealed` (`build_engine.dart`).
- Produces: `CombatAdapter(EngineSession session, {required TomeAdapter tomeAdapter})`; `({bool won, List<CombatLogEntryView> log}) runFight(String enemyId, {required num enemyHealth, required num enemyDamage, required String enemyDamageStat, int enemyInitiative = 8})` (spawns the enemy, resolves the interpreted loadout, runs the fight to completion capturing every event as a `CombatLogEntryView`, returns the outcome).

- [ ] **Step 1: Write the failing test**

```dart
// test/core/engine/combat_adapter_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/combat_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/tome_adapter.dart';

void main() {
  test('runFight against a weak enemy with a bare-handed loadout wins and returns a log', () {
    final session = EngineSession(9);
    CharacterAdapter(session).createCharacter('Test Fighter');
    final tomeAdapter = TomeAdapter(session)..createInitialTome();
    final combatAdapter = CombatAdapter(session, tomeAdapter: tomeAdapter);

    final outcome = combatAdapter.runFight(
      'training_dummy',
      enemyHealth: 10,
      enemyDamage: 1,
      enemyDamageStat: 'fist',
    );

    expect(outcome.won, isTrue);
    expect(outcome.log, isNotEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/engine/combat_adapter_test.dart`
Expected: FAIL — `CombatAdapter` doesn't exist.

- [ ] **Step 3: Implement `CombatAdapter`**

```dart
// lib/core/engine/combat_adapter.dart
import 'package:build_engine/auto_combat_plugin.dart';
import 'package:build_engine/build_engine.dart';
import 'package:build_engine/build_interpretation.dart';
import 'package:build_engine/combat_plugin.dart';
import 'package:build_engine/item_plugin.dart';

import '../models/combat_log_entry_view.dart';
import 'engine_session.dart';
import 'tome_adapter.dart';

const _interpreter =
    CompositeBuildActionInterpreter([TechniqueActionInterpreter(), ItemActionInterpreter()]);

class CombatAdapter {
  CombatAdapter(this._session, {required TomeAdapter tomeAdapter}) : _tomeAdapter = tomeAdapter;

  final EngineSession _session;
  // ignore: unused_field
  final TomeAdapter _tomeAdapter;

  String _fallbackStrikeStat(ActiveBuild build) {
    for (final ref in build.components) {
      if (ref.referenceType != itemReferenceType) continue;
      final content = _session.context.content.find(ref.contentId);
      if (content == null) continue;
      final item = itemDefinitionFromContent(content);
      if (!item.properties.containsKey('attack')) continue;
      return WeaponStatTags.matchOrFallback(item.tags, 'item:${item.id}');
    }
    return 'fist';
  }

  ({bool won, List<CombatLogEntryView> log}) runFight(
    String enemyId, {
    required num enemyHealth,
    required num enemyDamage,
    required String enemyDamageStat,
    int enemyInitiative = 8,
  }) {
    final enemy = _session.context.entities.create();
    _session.context.components
        .add(enemy, CombatantComponent(team: 'enemy', initiative: enemyInitiative));
    _session.context.components
        .add(enemy, HealthComponent(current: enemyHealth, max: enemyHealth));

    final build = _session.context.tome.resolve(_session.character);
    final playerActions = _interpreter.interpret(
      build: build,
      actor: _session.character,
      targets: [enemy],
      context: _session.context,
    );
    final effectiveActions = playerActions.isEmpty
        ? [
            AttackAction(
              actor: _session.character,
              targets: [enemy],
              baseDamage: 4,
              damageStat: _fallbackStrikeStat(build),
            ),
          ]
        : playerActions;

    final battle = _session.combatPlugin.system.startBattle([_session.character, enemy]);
    final controller = AutoCombatController(
      context: _session.context,
      combatSystem: _session.combatPlugin.system,
      battle: battle,
      availableActions: [
        ...effectiveActions,
        AttackAction(
          actor: enemy,
          targets: [_session.character],
          baseDamage: enemyDamage,
          damageStat: enemyDamageStat,
        ),
      ],
      policy: CombatPolicy.scored(),
    );

    final log = <CombatLogEntryView>[];
    final subs = [
      _session.context.events.subscribe<TurnStarted>((e) {
        final label = e.actor == _session.character ? 'You' : 'Enemy';
        log.add(CombatLogEntryView(kind: CombatLogEntryKind.turnStart, text: '$label act.'));
      }),
      _session.context.events.subscribe<EntityDamaged>((e) {
        final label = e.id == _session.character ? 'You take' : 'Enemy takes';
        log.add(CombatLogEntryView(kind: CombatLogEntryKind.damage, text: '$label ${e.amount} damage.'));
      }),
      _session.context.events.subscribe<EntityHealed>((e) {
        final label = e.id == _session.character ? 'You heal' : 'Enemy heals';
        log.add(CombatLogEntryView(kind: CombatLogEntryKind.heal, text: '$label ${e.amount}.'));
      }),
    ];

    controller.runUntilBattleEnds();
    for (final s in subs) {
      s.cancel();
    }

    final playerHealth = _session.context.components.get<HealthComponent>(_session.character)!.current;
    final won = playerHealth > 0 && !controller.isActive;
    log.add(CombatLogEntryView(
      kind: won ? CombatLogEntryKind.victory : CombatLogEntryKind.defeat,
      text: won ? 'Victory!' : 'Defeated...',
    ));

    return (won: won, log: log);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/engine/combat_adapter_test.dart`
Expected: PASS (1/1).

- [ ] **Step 5: Commit**

```bash
git add lib/core/engine/combat_adapter.dart test/core/engine/combat_adapter_test.dart
git commit -m "feat: add CombatAdapter with instant-resolve event capture"
```

---

### Task 12: `RewardAdapter`

**Files:**
- Create: `lib/core/engine/reward_adapter.dart`
- Test: `test/core/engine/reward_adapter_test.dart`

**Interfaces:**
- Consumes: `EngineSession`, `TomeAdapter`, `ItemAdapter`, `TechniqueAdapter`; `ItemResources`, `ownItem`, `discoverItem`, `isItemUsable`, `itemDefinition` (`item_plugin.dart`); `techniqueDefinition` (`technique_plugin.dart`).
- Produces: `RewardAdapter(EngineSession session, {required TomeAdapter tomeAdapter, required TechniqueAdapter techniqueAdapter, required List<String> itemPool, required List<String> techniquePool})`; `List<LootOptionView> offerLoot()` (always exactly 3: Upgrade Points, Grid Expansion, New Component — real next-pool-entry identity); `void applyLoot(LootKind kind)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/engine/reward_adapter_test.dart
import 'package:build_engine/item_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/item_adapter.dart';
import 'package:tome_client/core/engine/reward_adapter.dart';
import 'package:tome_client/core/engine/technique_adapter.dart';
import 'package:tome_client/core/engine/tome_adapter.dart';
import 'package:tome_client/core/models/loot_option_view.dart';

void main() {
  late EngineSession session;
  late TomeAdapter tomeAdapter;
  late RewardAdapter rewardAdapter;

  setUp(() {
    session = EngineSession(13);
    CharacterAdapter(session).createCharacter('Test Fighter');
    tomeAdapter = TomeAdapter(session)..createInitialTome();
    rewardAdapter = RewardAdapter(
      session,
      tomeAdapter: tomeAdapter,
      techniqueAdapter: TechniqueAdapter(session),
      itemPool: const [ItemIds.ironSword],
      techniquePool: const [],
    );
  });

  test('offerLoot always returns exactly 3 real options', () {
    final options = rewardAdapter.offerLoot();
    expect(options.length, 3);
    expect(options.map((o) => o.kind).toSet(), {
      LootKind.upgradePoints, LootKind.gridExpansion, LootKind.newComponent,
    });
  });

  test('applyLoot(upgradePoints) banks a real upgrade point resource', () {
    rewardAdapter.offerLoot();
    rewardAdapter.applyLoot(LootKind.upgradePoints);
    expect(session.context.resources.currentOf(session.character, ItemResources.upgradePoints), 1);
  });

  test('applyLoot(gridExpansion) grows the Tome via TomeAdapter', () {
    rewardAdapter.offerLoot();
    rewardAdapter.applyLoot(LootKind.gridExpansion);
    expect(tomeAdapter.width, 4);
  });

  test('applyLoot(newComponent) grants and owns the next pooled item', () {
    rewardAdapter.offerLoot();
    rewardAdapter.applyLoot(LootKind.newComponent);
    expect(ItemAdapter(session).ownedItems().map((v) => v.definitionId), contains(ItemIds.ironSword));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/engine/reward_adapter_test.dart`
Expected: FAIL — `RewardAdapter` doesn't exist.

- [ ] **Step 3: Implement `RewardAdapter`**

```dart
// lib/core/engine/reward_adapter.dart
import 'package:build_engine/item_plugin.dart';
import 'package:build_engine/technique_plugin.dart';

import '../models/loot_option_view.dart';
import 'engine_session.dart';
import 'technique_adapter.dart';
import 'tome_adapter.dart';

class RewardAdapter {
  RewardAdapter(
    this._session, {
    required TomeAdapter tomeAdapter,
    required TechniqueAdapter techniqueAdapter,
    required List<String> itemPool,
    required List<String> techniquePool,
  })  : _tomeAdapter = tomeAdapter,
        _techniqueAdapter = techniqueAdapter,
        _itemPool = List.of(itemPool),
        _techniquePool = List.of(techniquePool);

  final EngineSession _session;
  final TomeAdapter _tomeAdapter;
  final TechniqueAdapter _techniqueAdapter;
  final List<String> _itemPool;
  final List<String> _techniquePool;
  var _itemPoolIndex = 0;
  var _techniquePoolIndex = 0;

  /// The next pooled reward — items first, then techniques, mirroring
  /// `game_run.dart`'s own seed-shuffled-then-linear-draw reward pool
  /// pattern (this client draws in a fixed, caller-supplied order
  /// instead of reshuffling, since the pool itself is passed in already
  /// prepared by whoever wires `RewardAdapter` up, e.g. seed-shuffled at
  /// app start).
  ({bool isItem, String id})? _peekNextPoolEntry() {
    if (_itemPoolIndex < _itemPool.length) {
      return (isItem: true, id: _itemPool[_itemPoolIndex]);
    }
    if (_techniquePoolIndex < _techniquePool.length) {
      return (isItem: false, id: _techniquePool[_techniquePoolIndex]);
    }
    return null;
  }

  List<LootOptionView> offerLoot() {
    final next = _peekNextPoolEntry();
    final newComponentDetail = next == null
        ? 'No new components remain'
        : (next.isItem ? itemDefinition(next.id, _session.context).id : techniqueDefinition(next.id, _session.context).name);

    return [
      const LootOptionView(kind: LootKind.upgradePoints, title: '+1 Upgrade Point', detail: 'Bank a point to spend on any owned item or learned technique.'),
      LootOptionView(kind: LootKind.gridExpansion, title: '+1 Column', detail: 'Grow your Tome from ${_tomeAdapter.width}x${_tomeAdapter.height} to ${_tomeAdapter.width + 1}x${_tomeAdapter.height}.'),
      LootOptionView(kind: LootKind.newComponent, title: 'New Component', detail: newComponentDetail),
    ];
  }

  void applyLoot(LootKind kind) {
    switch (kind) {
      case LootKind.upgradePoints:
        _session.context.resources.add(_session.character, ItemResources.upgradePoints, 1);
      case LootKind.gridExpansion:
        _tomeAdapter.expandGrid();
      case LootKind.newComponent:
        final next = _peekNextPoolEntry();
        if (next == null) return;
        if (next.isItem) {
          final item = itemDefinition(next.id, _session.context);
          ownItem(_session.character, item.id, _session.context);
          discoverItem(_session.character, item, _session.context);
          _itemPoolIndex++;
        } else {
          _techniqueAdapter.discover(next.id);
          _techniquePoolIndex++;
        }
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/engine/reward_adapter_test.dart`
Expected: PASS (4/4).

- [ ] **Step 5: Commit**

```bash
git add lib/core/engine/reward_adapter.dart test/core/engine/reward_adapter_test.dart
git commit -m "feat: add RewardAdapter with real 3-option RewardKind-equivalent loot"
```

---

## Phase 4 — Routing & app shell

### Task 13: `RunBloc`, router, app shell, `main.dart`

**Files:**
- Create: `lib/features/run/run_bloc.dart`
- Create: `lib/features/run/run_event.dart`
- Create: `lib/features/run/run_state.dart`
- Create: `lib/routing/app_router.dart`
- Create: `lib/app/tome_app.dart`
- Create: `lib/app/theme.dart`
- Modify: `lib/main.dart`
- Test: `test/features/run/run_bloc_test.dart`

**Interfaces:**
- Consumes: nothing from `core/engine` directly (the constructor takes already-built adapters, injected by whichever feature Bloc needs them — `RunBloc` itself only tracks phase + minimal cross-phase data).
- Produces: `RunEvent` (`RunStarted`, `PhaseCompleted(GamePhase next)`), `RunState { GamePhase phase }`, `RunBloc extends Bloc<RunEvent, RunState>`; `GoRouter appRouter(RunBloc runBloc)`; `TomeApp` (root `MaterialApp.router` widget); `main()` wiring a single `EngineSession`+adapter set via `RepositoryProvider`s and `BlocProvider<RunBloc>`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/run/run_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/models/game_phase.dart';
import 'package:tome_client/features/run/run_bloc.dart';
import 'package:tome_client/features/run/run_event.dart';
import 'package:tome_client/features/run/run_state.dart';

void main() {
  blocTest<RunBloc, RunState>(
    'starts at characterCreation and advances on PhaseCompleted',
    build: RunBloc.new,
    act: (bloc) => bloc.add(const PhaseCompleted(GamePhase.tome)),
    expect: () => [const RunState(phase: GamePhase.tome)],
  );
}
```

Add `bloc_test: ^10.0.0` to `dev_dependencies:` in `pubspec.yaml` before running this test.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter pub get && flutter test test/features/run/run_bloc_test.dart`
Expected: FAIL — `RunBloc`/`RunEvent`/`RunState` don't exist.

- [ ] **Step 3: Implement `RunBloc`, router, app shell**

```dart
// lib/features/run/run_event.dart
import '../../core/models/game_phase.dart';

sealed class RunEvent {
  const RunEvent();
}

class PhaseCompleted extends RunEvent {
  const PhaseCompleted(this.next);
  final GamePhase next;
}
```

```dart
// lib/features/run/run_state.dart
import '../../core/models/game_phase.dart';

class RunState {
  const RunState({this.phase = GamePhase.characterCreation});
  final GamePhase phase;

  @override
  bool operator ==(Object other) => other is RunState && other.phase == phase;
  @override
  int get hashCode => phase.hashCode;
}
```

```dart
// lib/features/run/run_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import 'run_event.dart';
import 'run_state.dart';

class RunBloc extends Bloc<RunEvent, RunState> {
  RunBloc() : super(const RunState()) {
    on<PhaseCompleted>((event, emit) => emit(RunState(phase: event.next)));
  }
}
```

```dart
// lib/routing/app_router.dart
import 'package:go_router/go_router.dart';

import '../core/models/game_phase.dart';
import '../features/run/run_bloc.dart';

String _pathFor(GamePhase phase) => switch (phase) {
      GamePhase.characterCreation => '/character-creation',
      GamePhase.tome => '/tome',
      GamePhase.trainingPreparation => '/training/prepare',
      GamePhase.training => '/training/exercise',
      GamePhase.trainingResult => '/training/result',
      GamePhase.combatPreparation => '/combat/prepare',
      GamePhase.combat => '/combat',
      GamePhase.loot => '/loot',
      GamePhase.runComplete => '/run-complete',
    };

GoRouter appRouter(RunBloc runBloc) => GoRouter(
      initialLocation: _pathFor(runBloc.state.phase),
      refreshListenable: _RunBlocListenable(runBloc),
      redirect: (context, state) => _pathFor(runBloc.state.phase),
      routes: [
        for (final phase in GamePhase.values)
          GoRoute(path: _pathFor(phase), builder: (context, state) => _placeholderFor(phase)),
      ],
    );

// Replaced task-by-task in Phase 5 as each screen is built; kept here so
// this task's router is independently testable/runnable before any
// screen exists.
import 'package:flutter/material.dart';
Widget _placeholderFor(GamePhase phase) => Scaffold(body: Center(child: Text(phase.name)));
```

```dart
// lib/app/theme.dart
import 'package:flutter/material.dart';

ThemeData tomeTheme() => ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF3A2A1A),
      brightness: Brightness.dark,
    );
```

```dart
// lib/app/tome_app.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/run/run_bloc.dart';
import '../routing/app_router.dart';
import 'theme.dart';

class TomeApp extends StatelessWidget {
  const TomeApp({super.key, required this.runBloc});

  final RunBloc runBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: runBloc,
      child: MaterialApp.router(
        title: 'Tome: Martial Arts',
        theme: tomeTheme(),
        routerConfig: appRouter(runBloc),
      ),
    );
  }
}
```

```dart
// lib/main.dart
import 'package:flutter/material.dart';

import 'app/tome_app.dart';
import 'features/run/run_bloc.dart';

void main() {
  runApp(TomeApp(runBloc: RunBloc()));
}
```

Note on `_RunBlocListenable`: `go_router`'s `refreshListenable` needs a `Listenable`; add a small private adapter in `app_router.dart` above `appRouter`:

```dart
class _RunBlocListenable extends ChangeNotifier {
  _RunBlocListenable(RunBloc bloc) {
    _subscription = bloc.stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
```

(add `import 'dart:async';` to `app_router.dart` for `StreamSubscription`, and move the `import 'package:flutter/material.dart';` line used by `_placeholderFor` to the top of the file with the other imports rather than mid-file).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/run/run_bloc_test.dart`
Expected: PASS. Then `flutter analyze` (fix the import-ordering issue noted above) and `flutter run -d macos` — expected: app launches showing the text `characterCreation` on a dark-themed screen (the placeholder route for the initial phase).

- [ ] **Step 5: Commit**

```bash
git add lib/features/run lib/routing lib/app lib/main.dart test/features/run pubspec.yaml pubspec.lock
git commit -m "feat: add RunBloc, phase-driven go_router, and app shell"
```

---

## Phase 5 — Feature screens

### Task 14: Character Creation screen

**Files:**
- Create: `lib/features/character_creation/character_creation_bloc.dart`
- Create: `lib/features/character_creation/character_creation_event.dart`
- Create: `lib/features/character_creation/character_creation_state.dart`
- Create: `lib/features/character_creation/character_creation_screen.dart`
- Test: `test/features/character_creation/character_creation_bloc_test.dart`

**Interfaces:**
- Consumes: `CharacterAdapter` (Task 6), `RunBloc`/`PhaseCompleted` (Task 13).
- Produces: `CharacterCreationBloc` — events `NameSubmitted(String name)`, `StyleChosen(String styleId)`; states `CharacterCreationState { String name, List<String> availableStyles, Map<String,String?> synergyByStyle, CharacterView? character, bool confirmed }`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/character_creation/character_creation_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:build_engine/martial_arts_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/features/character_creation/character_creation_bloc.dart';
import 'package:tome_client/features/character_creation/character_creation_event.dart';

void main() {
  late CharacterAdapter adapter;

  setUp(() {
    adapter = CharacterAdapter(EngineSession(21));
  });

  blocTest<CharacterCreationBloc, CharacterCreationState>(
    'NameSubmitted then StyleChosen produces a confirmed character',
    build: () => CharacterCreationBloc(adapter),
    act: (bloc) {
      bloc.add(const NameSubmitted('Test Fighter'));
      bloc.add(const StyleChosen(MartialStyles.boxing));
    },
    verify: (bloc) {
      expect(bloc.state.confirmed, isTrue);
      expect(bloc.state.character!.name, 'Test Fighter');
      expect(bloc.state.character!.styleId, MartialStyles.boxing);
    },
  );
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/character_creation/character_creation_bloc_test.dart`
Expected: FAIL — files don't exist.

- [ ] **Step 3: Implement**

```dart
// lib/features/character_creation/character_creation_event.dart
sealed class CharacterCreationEvent {
  const CharacterCreationEvent();
}

class NameSubmitted extends CharacterCreationEvent {
  const NameSubmitted(this.name);
  final String name;
}

class StyleChosen extends CharacterCreationEvent {
  const StyleChosen(this.styleId);
  final String styleId;
}
```

```dart
// lib/features/character_creation/character_creation_state.dart
import '../../core/models/character_view.dart';

class CharacterCreationState {
  const CharacterCreationState({
    this.name,
    this.availableStyles = const [],
    this.synergyByStyle = const {},
    this.character,
    this.confirmed = false,
  });

  final String? name;
  final List<String> availableStyles;
  final Map<String, String?> synergyByStyle;
  final CharacterView? character;
  final bool confirmed;

  CharacterCreationState copyWith({
    String? name,
    List<String>? availableStyles,
    Map<String, String?>? synergyByStyle,
    CharacterView? character,
    bool? confirmed,
  }) =>
      CharacterCreationState(
        name: name ?? this.name,
        availableStyles: availableStyles ?? this.availableStyles,
        synergyByStyle: synergyByStyle ?? this.synergyByStyle,
        character: character ?? this.character,
        confirmed: confirmed ?? this.confirmed,
      );
}
```

```dart
// lib/features/character_creation/character_creation_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/engine/character_adapter.dart';
import 'character_creation_event.dart';
import 'character_creation_state.dart';

class CharacterCreationBloc extends Bloc<CharacterCreationEvent, CharacterCreationState> {
  CharacterCreationBloc(this._adapter) : super(const CharacterCreationState()) {
    on<NameSubmitted>((event, emit) {
      final character = _adapter.createCharacter(event.name);
      final styles = _adapter.availableStyles();
      emit(state.copyWith(
        name: event.name,
        character: character,
        availableStyles: styles,
        synergyByStyle: {for (final s in styles) s: _adapter.synergyTraditionFor(s)},
      ));
    });

    on<StyleChosen>((event, emit) {
      final character = _adapter.chooseStyle(event.styleId);
      emit(state.copyWith(character: character, confirmed: true));
    });
  }

  final CharacterAdapter _adapter;
}
```

```dart
// lib/features/character_creation/character_creation_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/game_phase.dart';
import '../run/run_bloc.dart';
import '../run/run_event.dart';
import 'character_creation_bloc.dart';
import 'character_creation_event.dart';
import 'character_creation_state.dart';

class CharacterCreationScreen extends StatelessWidget {
  const CharacterCreationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CharacterCreationBloc, CharacterCreationState>(
      listener: (context, state) {
        if (state.confirmed) {
          context.read<RunBloc>().add(const PhaseCompleted(GamePhase.tome));
          context.go('/tome');
        }
      },
      builder: (context, state) {
        if (state.name == null) return _NameStep(onSubmit: (name) => context.read<CharacterCreationBloc>().add(NameSubmitted(name)));
        return _StyleStep(state: state, onChoose: (id) => context.read<CharacterCreationBloc>().add(StyleChosen(id)));
      },
    );
  }
}

class _NameStep extends StatefulWidget {
  const _NameStep({required this.onSubmit});
  final ValueChanged<String> onSubmit;

  @override
  State<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<_NameStep> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Name your fighter', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 16),
              TextField(controller: _controller, autofocus: true),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => widget.onSubmit(_controller.text.trim().isEmpty ? 'Fighter' : _controller.text.trim()),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StyleStep extends StatelessWidget {
  const _StyleStep({required this.state, required this.onChoose});
  final CharacterCreationState state;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    final physiqueTradition = state.character!.physiqueAffinityTradition;
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Your physique: ${state.character!.physiqueId} — synergizes with $physiqueTradition training'),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              children: [
                for (final styleId in state.availableStyles)
                  _StyleCard(
                    styleId: styleId,
                    synergizes: state.synergyByStyle[styleId] == physiqueTradition,
                    onTap: () => onChoose(styleId),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StyleCard extends StatelessWidget {
  const _StyleCard({required this.styleId, required this.synergizes, required this.onTap});
  final String styleId;
  final bool synergizes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: synergizes ? Colors.green : Colors.red, width: 3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: Text(styleId, style: const TextStyle(fontSize: 18))),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/character_creation/character_creation_bloc_test.dart`
Expected: PASS.

- [ ] **Step 5: Wire the screen into the router and commit**

In `lib/routing/app_router.dart`, replace the `GamePhase.characterCreation` route's `_placeholderFor` call with a real `BlocProvider`-wrapped `CharacterCreationScreen`:

```dart
GoRoute(
  path: _pathFor(GamePhase.characterCreation),
  builder: (context, state) => BlocProvider(
    create: (_) => CharacterCreationBloc(context.read<CharacterAdapter>()),
    child: const CharacterCreationScreen(),
  ),
),
```

This requires `CharacterAdapter` (and every other adapter Phase 5 tasks need) to be provided above the router in `TomeApp` — update `lib/app/tome_app.dart` to construct one `EngineSession` and wrap `MaterialApp.router` in a `MultiRepositoryProvider` exposing `EngineSession`, `CharacterAdapter`, `TomeAdapter`, `ItemAdapter`, `TechniqueAdapter`, `TrainingAdapter`, `CombatAdapter`, and `RewardAdapter` (the latter three constructed after `TomeAdapter.createInitialTome()` is safe to call, i.e. lazily via `RepositoryProvider(create: ...)`, not eagerly at `TomeApp` construction — each task in this phase that needs a new adapter type adds it to this provider list as it's built, so this edit accumulates across Tasks 14-21 rather than landing all at once here).

```bash
git add lib/features/character_creation lib/routing/app_router.dart lib/app/tome_app.dart test/features/character_creation
git commit -m "feat: add Character Creation screen with tradition-synergy borders"
```

---

### Task 15: Tome screen (grid, tray, screen assembly)

**Files:**
- Create: `lib/features/tome/tome_bloc.dart`
- Create: `lib/features/tome/tome_event.dart`
- Create: `lib/features/tome/tome_state.dart`
- Create: `lib/features/tome/widgets/tome_grid.dart`
- Create: `lib/features/tome/widgets/component_tray.dart`
- Create: `lib/features/tome/tome_screen.dart`
- Test: `test/features/tome/tome_bloc_test.dart`

**Interfaces:**
- Consumes: `TomeAdapter`, `ItemAdapter` (Tasks 7-8).
- Produces: `TomeBloc` — event `TomeRefreshRequested`, `ComponentMoved(String from, String to)`; state `TomeState { List<GridCellView> cells, List<ItemView> tray, int width, int height }`. Widgets `TomeGrid({required List<GridCellView> cells, required int width, required void Function(String,String) onMove})`, `ComponentTray({required List<ItemView> items})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/tome/tome_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/item_adapter.dart';
import 'package:tome_client/core/engine/tome_adapter.dart';
import 'package:tome_client/features/tome/tome_bloc.dart';
import 'package:tome_client/features/tome/tome_event.dart';

void main() {
  late TomeAdapter tomeAdapter;

  setUp(() {
    final session = EngineSession(31);
    CharacterAdapter(session).createCharacter('Test Fighter');
    tomeAdapter = TomeAdapter(session)..createInitialTome();
    tomeAdapter.insertItem('knife', '0,0');
  });

  blocTest<TomeBloc, TomeState>(
    'TomeRefreshRequested loads the current grid',
    build: () => TomeBloc(tomeAdapter: tomeAdapter, itemAdapter: ItemAdapter(tomeAdapter as dynamic)),
    act: (bloc) => bloc.add(const TomeRefreshRequested()),
    verify: (bloc) => expect(bloc.state.cells.where((c) => !c.isEmpty).length, 1),
  );
}
```

Note: the `ItemAdapter(tomeAdapter as dynamic)` cast above is a test-authoring mistake to fix during Step 1 — `ItemAdapter` takes an `EngineSession`, not a `TomeAdapter`. Correct the test to construct its own `EngineSession` once and pass it to both `TomeAdapter(session)` and `ItemAdapter(session)`:

```dart
// test/features/tome/tome_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/item_adapter.dart';
import 'package:tome_client/core/engine/tome_adapter.dart';
import 'package:tome_client/features/tome/tome_bloc.dart';
import 'package:tome_client/features/tome/tome_event.dart';
import 'package:tome_client/features/tome/tome_state.dart';

void main() {
  late EngineSession session;
  late TomeAdapter tomeAdapter;

  setUp(() {
    session = EngineSession(31);
    CharacterAdapter(session).createCharacter('Test Fighter');
    tomeAdapter = TomeAdapter(session)..createInitialTome();
    tomeAdapter.insertItem('knife', '0,0');
  });

  blocTest<TomeBloc, TomeState>(
    'TomeRefreshRequested loads the current grid',
    build: () => TomeBloc(tomeAdapter: tomeAdapter, itemAdapter: ItemAdapter(session)),
    act: (bloc) => bloc.add(const TomeRefreshRequested()),
    verify: (bloc) => expect(bloc.state.cells.where((c) => !c.isEmpty).length, 1),
  );
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/tome/tome_bloc_test.dart`
Expected: FAIL — files don't exist.

- [ ] **Step 3: Implement**

```dart
// lib/features/tome/tome_event.dart
sealed class TomeEvent {
  const TomeEvent();
}

class TomeRefreshRequested extends TomeEvent {
  const TomeRefreshRequested();
}

class ComponentMoved extends TomeEvent {
  const ComponentMoved(this.fromSlotId, this.toSlotId);
  final String fromSlotId;
  final String toSlotId;
}

class ComponentInserted extends TomeEvent {
  const ComponentInserted({required this.definitionId, required this.slotId, required this.isTechnique});
  final String definitionId;
  final String slotId;
  final bool isTechnique;
}
```

```dart
// lib/features/tome/tome_state.dart
import '../../core/models/grid_cell_view.dart';
import '../../core/models/item_view.dart';

class TomeState {
  const TomeState({this.cells = const [], this.tray = const [], this.width = 3, this.height = 3});
  final List<GridCellView> cells;
  final List<ItemView> tray;
  final int width;
  final int height;
}
```

```dart
// lib/features/tome/tome_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/engine/item_adapter.dart';
import '../../core/engine/tome_adapter.dart';
import 'tome_event.dart';
import 'tome_state.dart';

class TomeBloc extends Bloc<TomeEvent, TomeState> {
  TomeBloc({required TomeAdapter tomeAdapter, required ItemAdapter itemAdapter})
      : _tomeAdapter = tomeAdapter,
        _itemAdapter = itemAdapter,
        super(const TomeState()) {
    on<TomeRefreshRequested>((event, emit) => emit(_snapshot()));
    on<ComponentMoved>((event, emit) {
      _tomeAdapter.move(event.fromSlotId, event.toSlotId);
      emit(_snapshot());
    });
    on<ComponentInserted>((event, emit) {
      if (event.isTechnique) {
        _tomeAdapter.insertTechnique(event.definitionId, event.slotId);
      } else {
        _tomeAdapter.insertItem(event.definitionId, event.slotId);
      }
      emit(_snapshot());
    });
  }

  final TomeAdapter _tomeAdapter;
  final ItemAdapter _itemAdapter;

  TomeState _snapshot() {
    final owned = _itemAdapter.ownedItems();
    final placedInstanceValues = {
      for (final cell in _tomeAdapter.inspect())
        if (cell.occupant?.instanceEntityValue != null) cell.occupant!.instanceEntityValue,
    };
    return TomeState(
      cells: _tomeAdapter.inspect(),
      tray: [for (final v in owned) if (!placedInstanceValues.contains(v.instanceEntityValue)) v],
      width: _tomeAdapter.width,
      height: _tomeAdapter.height,
    );
  }
}
```

```dart
// lib/features/tome/widgets/tome_grid.dart
import 'package:flutter/material.dart';

import '../../../core/models/grid_cell_view.dart';

class TomeGrid extends StatelessWidget {
  const TomeGrid({super.key, required this.cells, required this.width, required this.onMove});

  final List<GridCellView> cells;
  final int width;
  final void Function(String from, String to) onMove;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: width,
      children: [
        for (final cell in cells)
          DragTarget<String>(
            onWillAcceptWithDetails: (details) => cell.isEmpty,
            onAcceptWithDetails: (details) => onMove(details.data, cell.slotId),
            builder: (context, candidate, rejected) => Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: candidate.isNotEmpty ? Colors.greenAccent : Colors.white24,
                  width: candidate.isNotEmpty ? 3 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: cell.isEmpty
                  ? const Center(child: Icon(Icons.add, color: Colors.white24))
                  : Draggable<String>(
                      data: cell.slotId,
                      feedback: Material(child: _CellLabel(cell)),
                      childWhenDragging: const SizedBox.shrink(),
                      child: _CellLabel(cell),
                    ),
            ),
          ),
      ],
    );
  }
}

class _CellLabel extends StatelessWidget {
  const _CellLabel(this.cell);
  final GridCellView cell;

  @override
  Widget build(BuildContext context) => Center(child: Text(cell.occupant!.displayName));
}
```

```dart
// lib/features/tome/widgets/component_tray.dart
import 'package:flutter/material.dart';

import '../../../core/models/item_view.dart';

class ComponentTray extends StatelessWidget {
  const ComponentTray({super.key, required this.items});
  final List<ItemView> items;

  Color _borderColorFor(ItemDisplayState state) => switch (state) {
        ItemDisplayState.locked => Colors.grey,
        ItemDisplayState.usable => Colors.white70,
        ItemDisplayState.mastered => Colors.amber,
        ItemDisplayState.equipped => Colors.blueAccent,
      };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final item in items)
            Container(
              width: 80,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: _borderColorFor(item.state), width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Text(item.definitionId, textAlign: TextAlign.center)),
            ),
        ],
      ),
    );
  }
}
```

```dart
// lib/features/tome/tome_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'tome_bloc.dart';
import 'tome_event.dart';
import 'tome_state.dart';
import 'widgets/component_tray.dart';
import 'widgets/tome_grid.dart';

class TomeScreen extends StatelessWidget {
  const TomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.read<TomeBloc>().add(const TomeRefreshRequested());
    return Scaffold(
      appBar: AppBar(title: const Text('Your Tome')),
      body: BlocBuilder<TomeBloc, TomeState>(
        builder: (context, state) => Column(
          children: [
            Expanded(
              child: TomeGrid(
                cells: state.cells,
                width: state.width,
                onMove: (from, to) => context.read<TomeBloc>().add(ComponentMoved(from, to)),
              ),
            ),
            ComponentTray(items: state.tray),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/tome/tome_bloc_test.dart`
Expected: PASS. Then `flutter analyze`.

- [ ] **Step 5: Wire into router (mirroring Task 14's Step 5 pattern) and commit**

```bash
git add lib/features/tome test/features/tome
git commit -m "feat: add Tome screen with drag-and-drop grid and component tray"
```

---

### Task 16: Component Detail modal

**Files:**
- Create: `lib/features/tome/widgets/component_detail_sheet.dart`
- Test: `test/features/tome/widgets/component_detail_sheet_test.dart`

**Interfaces:**
- Consumes: `ItemView`/`TechniqueView` (Task 4).
- Produces: `Future<void> showComponentDetail(BuildContext context, {ItemView? item, TechniqueView? technique, required VoidCallback onTrain, VoidCallback? onEquip, VoidCallback? onUnequip, VoidCallback? onUpgrade})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/tome/widgets/component_detail_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/models/item_view.dart';
import 'package:tome_client/features/tome/widgets/component_detail_sheet.dart';

void main() {
  testWidgets('locked item shows the Locked banner and a Train action, no Equip', (tester) async {
    const item = ItemView(
      definitionId: 'cloth_armor', name: 'cloth_armor', category: 'armor',
      properties: {'defense': 2}, state: ItemDisplayState.locked,
      itemClass: 1, maxClass: 3, masteryLevel: 0, masteryProgress: 0,
      masteryThresholds: [8], instanceEntityValue: 1, combinableWith: [],
    );

    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () => showComponentDetail(context, item: item, onTrain: () {}),
        child: const Text('open'),
      );
    })));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('LOCKED'), findsOneWidget);
    expect(find.text('Train'), findsOneWidget);
    expect(find.text('Equip'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/tome/widgets/component_detail_sheet_test.dart`
Expected: FAIL — `showComponentDetail` doesn't exist.

- [ ] **Step 3: Implement**

```dart
// lib/features/tome/widgets/component_detail_sheet.dart
import 'package:flutter/material.dart';

import '../../../core/models/item_view.dart';
import '../../../core/models/technique_view.dart';

String _stateLabel(ItemDisplayState state) => switch (state) {
      ItemDisplayState.locked => 'LOCKED',
      ItemDisplayState.usable => 'USABLE',
      ItemDisplayState.mastered => 'MASTERED',
      ItemDisplayState.equipped => 'EQUIPPED',
    };

Future<void> showComponentDetail(
  BuildContext context, {
  ItemView? item,
  TechniqueView? technique,
  required VoidCallback onTrain,
  VoidCallback? onEquip,
  VoidCallback? onUnequip,
  VoidCallback? onUpgrade,
  VoidCallback? onCombine,
}) {
  return showModalBottomSheet(
    context: context,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item?.name ?? technique?.name ?? '', style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 8),
          if (item != null) ...[
            Text(_stateLabel(item.state), style: const TextStyle(fontWeight: FontWeight.bold)),
            if (item.state == ItemDisplayState.locked)
              Text('${item.masteryProgress.toStringAsFixed(0)} / ${item.masteryThresholds.isEmpty ? '-' : item.masteryThresholds.first}'),
            for (final entry in item.properties.entries) Text('${entry.key}: +${entry.value}'),
            if (item.combinableWith.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  const Text('Combinable with → '),
                  if (onCombine != null) TextButton(onPressed: onCombine, child: const Text('Combine')),
                ]),
              ),
          ],
          if (technique != null) ...[
            Text(technique.learned ? 'LEARNED' : (technique.discovered ? 'DISCOVERED' : 'UNKNOWN'), style: const TextStyle(fontWeight: FontWeight.bold)),
            if (technique.evolvedFromId != null) Text('Evolved from: ${technique.evolvedFromId}'),
            for (final entry in technique.properties.entries) Text('${entry.key}: ${entry.value}'),
          ],
          const SizedBox(height: 16),
          Wrap(spacing: 8, children: [
            if (item?.state != ItemDisplayState.equipped && (item != null || technique != null))
              FilledButton(onPressed: onTrain, child: const Text('Train')),
            if (onEquip != null) FilledButton(onPressed: onEquip, child: const Text('Equip')),
            if (onUnequip != null) OutlinedButton(onPressed: onUnequip, child: const Text('Unequip')),
            if (onUpgrade != null) IconButton(onPressed: onUpgrade, icon: const Icon(Icons.hardware)),
          ]),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/tome/widgets/component_detail_sheet_test.dart`
Expected: PASS.

- [ ] **Step 5: Wire `onTap` on `TomeGrid`/`ComponentTray` cards to call `showComponentDetail`, and commit**

Add a `void Function(GridCellView)? onCellTap` parameter to `TomeGrid` and an `onItemTap` to `ComponentTray` (both defaulting to opening the sheet via `showComponentDetail` from `TomeScreen`, using `context.read<TomeBloc>()`/a new `ItemAdapter`-backed lookup for the tapped id's full `ItemView`/`TechniqueView`).

```bash
git add lib/features/tome test/features/tome
git commit -m "feat: add Component Detail modal with state banner, lineage, hammer icon, combine row"
```

---

### Task 17: Combine linking visualization + Combine Confirmation sheet

**Files:**
- Modify: `lib/features/tome/widgets/tome_grid.dart`
- Create: `lib/features/tome/widgets/combine_confirmation_sheet.dart`
- Test: `test/features/tome/widgets/combine_confirmation_sheet_test.dart`

**Interfaces:**
- Consumes: `ItemView.combinableWith` (Task 4), `ItemAdapter.combine` (Task 8).
- Produces: `Future<void> showCombineConfirmation(BuildContext context, {required List<ItemView> matched, required VoidCallback onConfirm})`; `TomeGrid` grows a `Map<int, ItemView> combinableItemsByInstanceValue` parameter used to paint tethers between cells whose occupant's `instanceEntityValue` appears in another cell's `combinableWith`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/tome/widgets/combine_confirmation_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/models/item_view.dart';
import 'package:tome_client/features/tome/widgets/combine_confirmation_sheet.dart';

const _knife = ItemView(
  definitionId: 'knife', name: 'knife', category: 'weapon', properties: {'attack': 2},
  state: ItemDisplayState.usable, itemClass: 1, maxClass: 3, masteryLevel: 0,
  masteryProgress: 0, masteryThresholds: [], instanceEntityValue: 1, combinableWith: [2],
);

void main() {
  testWidgets('shows matched inputs and an Attempt Combine action', (tester) async {
    var confirmed = false;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () => showCombineConfirmation(context, matched: const [_knife, _knife], onConfirm: () => confirmed = true),
        child: const Text('open'),
      );
    })));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Attempt Combine'), findsOneWidget);
    await tester.tap(find.text('Attempt Combine'));
    expect(confirmed, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/tome/widgets/combine_confirmation_sheet_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement**

```dart
// lib/features/tome/widgets/combine_confirmation_sheet.dart
import 'package:flutter/material.dart';

import '../../../core/models/item_view.dart';

Future<void> showCombineConfirmation(
  BuildContext context, {
  required List<ItemView> matched,
  required VoidCallback onConfirm,
}) {
  return showModalBottomSheet(
    context: context,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Combine ${matched.length} × ${matched.first.name}', style: const TextStyle(fontSize: 20)),
          Text('Cost: ${matched.first.itemClass} upgrade point(s)'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            child: const Text('Attempt Combine'),
          ),
        ],
      ),
    ),
  );
}
```

Modify `lib/features/tome/widgets/tome_grid.dart`'s `TomeGrid` to accept `required Map<int, ItemView> ownedByInstanceValue` and wrap the `GridView.count` in a `CustomPaint` overlay (a new `_CombineTetherPainter extends CustomPainter`) that, for each cell whose `occupant.instanceEntityValue` is non-null, looks up that `ItemView.combinableWith` and draws a line to every other on-screen cell whose `instanceEntityValue` appears in that list — bright amber (`Colors.amberAccent`) when the matched target's own `combinableWith` list is non-empty (both sides agree they're linked; eligibility itself, per Task 2's `canCombine`, is checked once when a tap occurs — the tether being drawn at all already implies the same-definitionId/same-class match `ItemAdapter._ownedInstancesByKey` grouped on, per Task 8's Step 3) and dim grey when the corresponding `ItemAdapter` lookup marks the pair as `maxClass`-capped with no grade path (this second signal requires threading a `bool eligibleToCombine` flag through `ItemView`, alongside `combinableWith` — **before writing this step's widget code**, add that field to `ItemView` in Task 4/8 retroactively: `final bool eligibleToCombine;` on `ItemView`, computed in `ItemAdapter._viewFor` via the exported `canCombine` from Task 2, called with `[instanceEntity, combinableWith.first]` when `combinableWith` is non-empty).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/tome/widgets/combine_confirmation_sheet_test.dart`
Expected: PASS. Then re-run Task 8's `item_adapter_test.dart` after adding `eligibleToCombine` to confirm no regression, and `flutter analyze`.

- [ ] **Step 5: Wire tap-on-tether to `showCombineConfirmation` → `ItemAdapter.combine`, then commit**

```bash
git add lib/features/tome test/features/tome/widgets/combine_confirmation_sheet_test.dart lib/core/engine/item_adapter.dart lib/core/models/item_view.dart test/core/engine/item_adapter_test.dart
git commit -m "feat: add combine tether visualization and Combine Confirmation sheet"
```

---

### Task 18: Training Preparation, Training Placeholder, Training Result

**Files:**
- Create: `lib/features/training/training_bloc.dart`
- Create: `lib/features/training/training_event.dart`
- Create: `lib/features/training/training_state.dart`
- Create: `lib/features/training/presentation/training_presentation.dart`
- Create: `lib/features/training/presentation/timing_bar_training_presentation.dart`
- Create: `lib/features/training/training_preparation_screen.dart`
- Create: `lib/features/training/training_result_screen.dart`
- Test: `test/features/training/training_bloc_test.dart`

**Interfaces:**
- Consumes: `TrainingAdapter` (Task 10); `TrainingAttempt` (`package:build_engine/build_engine.dart` — the one place outside `core/engine/` this plan allows a `build_engine` import, since `TrainingAttempt` is a plain, engine-defined data payload the UI must construct directly from raw tap timing to hand back to `TrainingAdapter.trainItem`/`trainTechnique`; document this exception inline in the file, and confine the import to `training_bloc.dart` only — not the presentation widget, which reports plain `double` timestamps up to the Bloc).
- Produces: `abstract class TrainingPresentation extends StatelessWidget { const TrainingPresentation({super.key}); }` with a `TimingBarTrainingPresentation implements TrainingPresentation` (constructor `{required void Function(double timestampMs) onTap, required double windowStartMs, required double windowEndMs}`); `TrainingBloc` — events `TrainingStarted(String subject, bool isTechnique)`, `AttemptSubmitted(double timestampMs)`, `TrainingCompleted()`; state `TrainingState { String? subject, bool isTechnique, int attemptsSubmitted, TrainingResultView? result }`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/training/training_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:build_engine/item_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/tome_adapter.dart';
import 'package:tome_client/core/engine/training_adapter.dart';
import 'package:tome_client/features/training/training_bloc.dart';
import 'package:tome_client/features/training/training_event.dart';
import 'package:tome_client/features/training/training_state.dart';

void main() {
  late EngineSession session;
  late TrainingAdapter trainingAdapter;

  setUp(() {
    session = EngineSession(41);
    CharacterAdapter(session).createCharacter('Test Fighter');
    final tomeAdapter = TomeAdapter(session)..createInitialTome();
    trainingAdapter = TrainingAdapter(session, tomeAdapter: tomeAdapter);
    ownItem(session.character, ItemIds.clothArmor, session.context);
    discoverItem(session.character, itemDefinition(ItemIds.clothArmor, session.context), session.context);
  });

  blocTest<TrainingBloc, TrainingState>(
    'three submitted attempts followed by TrainingCompleted produces a result',
    build: () => TrainingBloc(trainingAdapter),
    act: (bloc) {
      bloc.add(const TrainingSessionStarted(ItemIds.clothArmor, false));
      bloc.add(const AttemptSubmitted(150));
      bloc.add(const AttemptSubmitted(150));
      bloc.add(const AttemptSubmitted(150));
      bloc.add(const TrainingCompleted());
    },
    verify: (bloc) => expect(bloc.state.result, isNotNull),
  );
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/training/training_bloc_test.dart`
Expected: FAIL — files don't exist.

- [ ] **Step 3: Implement**

```dart
// lib/features/training/training_event.dart
sealed class TrainingEvent {
  const TrainingEvent();
}

class TrainingSessionStarted extends TrainingEvent {
  const TrainingSessionStarted(this.subject, this.isTechnique);
  final String subject;
  final bool isTechnique;
}

class AttemptSubmitted extends TrainingEvent {
  const AttemptSubmitted(this.timestampMs);
  final double timestampMs;
}

class TrainingCompleted extends TrainingEvent {
  const TrainingCompleted();
}
```

```dart
// lib/features/training/training_state.dart
import '../../core/models/training_result_view.dart';

class TrainingState {
  const TrainingState({this.subject, this.isTechnique = false, this.attemptsSubmitted = 0, this.result});
  final String? subject;
  final bool isTechnique;
  final int attemptsSubmitted;
  final TrainingResultView? result;

  TrainingState copyWith({String? subject, bool? isTechnique, int? attemptsSubmitted, TrainingResultView? result}) =>
      TrainingState(
        subject: subject ?? this.subject,
        isTechnique: isTechnique ?? this.isTechnique,
        attemptsSubmitted: attemptsSubmitted ?? this.attemptsSubmitted,
        result: result ?? this.result,
      );
}
```

```dart
// lib/features/training/training_bloc.dart
// This Bloc is the one deliberate exception to "package:build_engine
// imports live only in core/engine/": TrainingAttempt is a plain data
// payload (windowStart/windowEnd/actual timestamps), not an engine
// service or rule — constructing one here from raw UI tap timing avoids
// adding a pass-through method to TrainingAdapter for every possible
// attempt shape a future richer exercise might need.
import 'package:build_engine/build_engine.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/engine/training_adapter.dart';
import 'training_event.dart';
import 'training_state.dart';

const _windowStart = 100.0;
const _windowEnd = 200.0;

class TrainingBloc extends Bloc<TrainingEvent, TrainingState> {
  TrainingBloc(this._adapter) : super(const TrainingState()) {
    on<TrainingSessionStarted>((event, emit) {
      _attempts.clear();
      emit(TrainingState(subject: event.subject, isTechnique: event.isTechnique));
    });

    on<AttemptSubmitted>((event, emit) {
      _attempts.add(TrainingAttempt({
        'windowStart': _windowStart,
        'windowEnd': _windowEnd,
        'actual': event.timestampMs,
      }));
      emit(state.copyWith(attemptsSubmitted: _attempts.length));
    });

    on<TrainingCompleted>((event, emit) {
      final result = state.isTechnique
          ? _adapter.trainTechnique(state.subject!, _attempts)
          : _adapter.trainItem(state.subject!, _attempts);
      emit(state.copyWith(result: result));
    });
  }

  final TrainingAdapter _adapter;
  final List<TrainingAttempt> _attempts = [];
}
```

```dart
// lib/features/training/presentation/training_presentation.dart
import 'package:flutter/widgets.dart';

/// The seam a future Flame/3D training implementation replaces — every
/// concrete presentation reports raw millisecond timestamps up through
/// [onTap], never anything build_engine-shaped.
abstract class TrainingPresentation extends StatelessWidget {
  const TrainingPresentation({super.key});
}
```

```dart
// lib/features/training/presentation/timing_bar_training_presentation.dart
import 'dart:async';
import 'package:flutter/material.dart';

import 'training_presentation.dart';

class TimingBarTrainingPresentation extends TrainingPresentation {
  const TimingBarTrainingPresentation({
    super.key,
    required this.onTap,
    this.windowStartMs = 100,
    this.windowEndMs = 200,
  });

  final void Function(double timestampMs) onTap;
  final double windowStartMs;
  final double windowEndMs;

  @override
  Widget build(BuildContext context) {
    return _TimingBar(onTap: onTap, windowStartMs: windowStartMs, windowEndMs: windowEndMs);
  }
}

class _TimingBar extends StatefulWidget {
  const _TimingBar({required this.onTap, required this.windowStartMs, required this.windowEndMs});
  final void Function(double timestampMs) onTap;
  final double windowStartMs;
  final double windowEndMs;

  @override
  State<_TimingBar> createState() => _TimingBarState();
}

class _TimingBarState extends State<_TimingBar> {
  final _stopwatch = Stopwatch()..start();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = (_stopwatch.elapsedMilliseconds % 300).toDouble();
    return GestureDetector(
      onTap: () => widget.onTap(elapsed),
      child: Container(
        height: 48,
        color: Colors.black26,
        child: Stack(children: [
          Positioned(
            left: widget.windowStartMs,
            width: widget.windowEndMs - widget.windowStartMs,
            top: 0,
            bottom: 0,
            child: Container(color: Colors.greenAccent.withValues(alpha: 0.4)),
          ),
          Positioned(left: elapsed, top: 0, bottom: 0, width: 2, child: Container(color: Colors.white)),
        ]),
      ),
    );
  }
}
```

```dart
// lib/features/training/training_preparation_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'presentation/timing_bar_training_presentation.dart';
import 'training_bloc.dart';
import 'training_event.dart';

class TrainingPreparationScreen extends StatelessWidget {
  const TrainingPreparationScreen({super.key, required this.subject, required this.isTechnique});
  final String subject;
  final bool isTechnique;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Prepare to train: $subject'),
          FilledButton(
            onPressed: () => context.read<TrainingBloc>().add(TrainingSessionStarted(subject, isTechnique)),
            child: const Text('Begin Training'),
          ),
        ]),
      ),
    );
  }
}

class TrainingExerciseScreen extends StatelessWidget {
  const TrainingExerciseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<TrainingBloc>();
    return Scaffold(
      body: Column(children: [
        TimingBarTrainingPresentation(
          onTap: (t) {
            bloc.add(AttemptSubmitted(t));
            if (bloc.state.attemptsSubmitted >= 3) bloc.add(const TrainingCompleted());
          },
        ),
        Text('Attempts: ${bloc.state.attemptsSubmitted} / 3'),
      ]),
    );
  }
}
```

```dart
// lib/features/training/training_result_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'training_bloc.dart';
import 'training_state.dart';

class TrainingResultScreen extends StatelessWidget {
  const TrainingResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrainingBloc, TrainingState>(builder: (context, state) {
      final result = state.result!;
      return Scaffold(
        body: Column(children: [
          Text('Gain: ${result.gain.toStringAsFixed(1)}'),
          for (final entry in result.dimensions.entries) Text('${entry.key}: ${(entry.value * 100).toStringAsFixed(0)}%'),
          if (result.evolvedIntoDefinitionId != null) ...[
            const Text('NEW TECHNIQUE DISCOVERED'),
            Text('Evolved from: ${result.evolvedFromDefinitionId}'),
          ],
        ]),
      );
    });
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/training/training_bloc_test.dart`
Expected: PASS. Then `flutter analyze`.

- [ ] **Step 5: Wire into router and commit**

```bash
git add lib/features/training test/features/training
git commit -m "feat: add Training Preparation/Exercise/Result screens with timing-bar placeholder"
```

---

### Task 19: Combat Preparation + Combat Placeholder

**Files:**
- Create: `lib/features/combat/combat_bloc.dart`
- Create: `lib/features/combat/combat_event.dart`
- Create: `lib/features/combat/combat_state.dart`
- Create: `lib/features/combat/presentation/combat_presentation.dart`
- Create: `lib/features/combat/presentation/log_replay_combat_presentation.dart`
- Create: `lib/features/combat/combat_preparation_screen.dart`
- Create: `lib/features/combat/combat_screen.dart`
- Test: `test/features/combat/combat_bloc_test.dart`

**Interfaces:**
- Consumes: `CombatAdapter` (Task 11).
- Produces: `abstract class CombatPresentation extends StatelessWidget`, `LogReplayCombatPresentation({required List<CombatLogEntryView> log, required VoidCallback onFinished})`; `CombatBloc` — event `FightStarted(String enemyId, num enemyHealth, num enemyDamage, String enemyDamageStat)`; state `CombatState { bool inProgress, bool? won, List<CombatLogEntryView> log }`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/combat/combat_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/combat_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/tome_adapter.dart';
import 'package:tome_client/features/combat/combat_bloc.dart';
import 'package:tome_client/features/combat/combat_event.dart';
import 'package:tome_client/features/combat/combat_state.dart';

void main() {
  blocTest<CombatBloc, CombatState>(
    'FightStarted resolves the fight and reports the outcome',
    build: () {
      final session = EngineSession(51);
      CharacterAdapter(session).createCharacter('Test Fighter');
      final tomeAdapter = TomeAdapter(session)..createInitialTome();
      return CombatBloc(CombatAdapter(session, tomeAdapter: tomeAdapter));
    },
    act: (bloc) => bloc.add(const FightStarted('training_dummy', 10, 1, 'fist')),
    verify: (bloc) => expect(bloc.state.won, isTrue),
  );
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/combat/combat_bloc_test.dart`
Expected: FAIL — files don't exist.

- [ ] **Step 3: Implement**

```dart
// lib/features/combat/combat_event.dart
sealed class CombatEvent {
  const CombatEvent();
}

class FightStarted extends CombatEvent {
  const FightStarted(this.enemyId, this.enemyHealth, this.enemyDamage, this.enemyDamageStat);
  final String enemyId;
  final num enemyHealth;
  final num enemyDamage;
  final String enemyDamageStat;
}
```

```dart
// lib/features/combat/combat_state.dart
import '../../core/models/combat_log_entry_view.dart';

class CombatState {
  const CombatState({this.inProgress = false, this.won, this.log = const []});
  final bool inProgress;
  final bool? won;
  final List<CombatLogEntryView> log;
}
```

```dart
// lib/features/combat/combat_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/engine/combat_adapter.dart';
import 'combat_event.dart';
import 'combat_state.dart';

class CombatBloc extends Bloc<CombatEvent, CombatState> {
  CombatBloc(this._adapter) : super(const CombatState()) {
    on<FightStarted>((event, emit) {
      final outcome = _adapter.runFight(
        event.enemyId,
        enemyHealth: event.enemyHealth,
        enemyDamage: event.enemyDamage,
        enemyDamageStat: event.enemyDamageStat,
      );
      emit(CombatState(inProgress: false, won: outcome.won, log: outcome.log));
    });
  }

  final CombatAdapter _adapter;
}
```

```dart
// lib/features/combat/presentation/combat_presentation.dart
import 'package:flutter/widgets.dart';

abstract class CombatPresentation extends StatelessWidget {
  const CombatPresentation({super.key});
}
```

```dart
// lib/features/combat/presentation/log_replay_combat_presentation.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/models/combat_log_entry_view.dart';
import 'combat_presentation.dart';

class LogReplayCombatPresentation extends CombatPresentation {
  const LogReplayCombatPresentation({super.key, required this.log, required this.onFinished});
  final List<CombatLogEntryView> log;
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) => _Replay(log: log, onFinished: onFinished);
}

class _Replay extends StatefulWidget {
  const _Replay({required this.log, required this.onFinished});
  final List<CombatLogEntryView> log;
  final VoidCallback onFinished;

  @override
  State<_Replay> createState() => _ReplayState();
}

class _ReplayState extends State<_Replay> {
  var _shown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      setState(() => _shown++);
      if (_shown >= widget.log.length) {
        timer.cancel();
        widget.onFinished();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const Text('PLAYER  vs  ENEMY'),
      Expanded(
        child: ListView(
          children: [for (final entry in widget.log.take(_shown)) Text(entry.text)],
        ),
      ),
    ]);
  }
}
```

```dart
// lib/features/combat/combat_preparation_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'combat_bloc.dart';
import 'combat_event.dart';

class CombatPreparationScreen extends StatelessWidget {
  const CombatPreparationScreen({super.key, required this.enemyId, required this.enemyHealth, required this.enemyDamage, required this.enemyDamageStat});
  final String enemyId;
  final num enemyHealth;
  final num enemyDamage;
  final String enemyDamageStat;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => context.read<CombatBloc>().add(FightStarted(enemyId, enemyHealth, enemyDamage, enemyDamageStat)),
          child: const Text('Confirm & Fight'),
        ),
      ),
    );
  }
}
```

```dart
// lib/features/combat/combat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'combat_bloc.dart';
import 'combat_state.dart';
import 'presentation/log_replay_combat_presentation.dart';

class CombatScreen extends StatelessWidget {
  const CombatScreen({super.key, required this.onFinished});
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CombatBloc, CombatState>(
      builder: (context, state) => Scaffold(
        body: LogReplayCombatPresentation(log: state.log, onFinished: onFinished),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/combat/combat_bloc_test.dart`
Expected: PASS. Then `flutter analyze`.

- [ ] **Step 5: Wire into router and commit**

```bash
git add lib/features/combat test/features/combat
git commit -m "feat: add Combat Preparation and instant-resolve-then-replay Combat screens"
```

---

### Task 20: Loot Selection screen

**Files:**
- Create: `lib/features/loot/loot_bloc.dart`
- Create: `lib/features/loot/loot_event.dart`
- Create: `lib/features/loot/loot_state.dart`
- Create: `lib/features/loot/loot_screen.dart`
- Test: `test/features/loot/loot_bloc_test.dart`

**Interfaces:**
- Consumes: `RewardAdapter` (Task 12).
- Produces: `LootBloc` — events `LootOffered()`, `LootChosen(LootKind kind)`; state `LootState { List<LootOptionView> options, bool applied }`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/loot/loot_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:build_engine/item_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/reward_adapter.dart';
import 'package:tome_client/core/engine/technique_adapter.dart';
import 'package:tome_client/core/engine/tome_adapter.dart';
import 'package:tome_client/core/models/loot_option_view.dart';
import 'package:tome_client/features/loot/loot_bloc.dart';
import 'package:tome_client/features/loot/loot_event.dart';
import 'package:tome_client/features/loot/loot_state.dart';

void main() {
  blocTest<LootBloc, LootState>(
    'LootOffered then LootChosen applies the choice',
    build: () {
      final session = EngineSession(61);
      CharacterAdapter(session).createCharacter('Test Fighter');
      final tomeAdapter = TomeAdapter(session)..createInitialTome();
      final rewardAdapter = RewardAdapter(
        session, tomeAdapter: tomeAdapter, techniqueAdapter: TechniqueAdapter(session),
        itemPool: const [ItemIds.ironSword], techniquePool: const [],
      );
      return LootBloc(rewardAdapter);
    },
    act: (bloc) {
      bloc.add(const LootOffered());
      bloc.add(const LootChosen(LootKind.upgradePoints));
    },
    verify: (bloc) => expect(bloc.state.applied, isTrue),
  );
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/loot/loot_bloc_test.dart`
Expected: FAIL — files don't exist.

- [ ] **Step 3: Implement**

```dart
// lib/features/loot/loot_event.dart
import '../../core/models/loot_option_view.dart';

sealed class LootEvent {
  const LootEvent();
}

class LootOffered extends LootEvent {
  const LootOffered();
}

class LootChosen extends LootEvent {
  const LootChosen(this.kind);
  final LootKind kind;
}
```

```dart
// lib/features/loot/loot_state.dart
import '../../core/models/loot_option_view.dart';

class LootState {
  const LootState({this.options = const [], this.applied = false});
  final List<LootOptionView> options;
  final bool applied;
}
```

```dart
// lib/features/loot/loot_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/engine/reward_adapter.dart';
import 'loot_event.dart';
import 'loot_state.dart';

class LootBloc extends Bloc<LootEvent, LootState> {
  LootBloc(this._adapter) : super(const LootState()) {
    on<LootOffered>((event, emit) => emit(LootState(options: _adapter.offerLoot())));
    on<LootChosen>((event, emit) {
      _adapter.applyLoot(event.kind);
      emit(LootState(options: state.options, applied: true));
    });
  }

  final RewardAdapter _adapter;
}
```

```dart
// lib/features/loot/loot_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'loot_bloc.dart';
import 'loot_event.dart';
import 'loot_state.dart';

class LootScreen extends StatelessWidget {
  const LootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.read<LootBloc>().add(const LootOffered());
    return Scaffold(
      body: BlocBuilder<LootBloc, LootState>(
        builder: (context, state) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final option in state.options)
              GestureDetector(
                onTap: () => context.read<LootBloc>().add(LootChosen(option.kind)),
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [Text(option.title), Text(option.detail, textAlign: TextAlign.center)]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/loot/loot_bloc_test.dart`
Expected: PASS. Then `flutter analyze`.

- [ ] **Step 5: Wire into router and commit**

```bash
git add lib/features/loot test/features/loot
git commit -m "feat: add Loot Selection screen with real 3-option rewards"
```

---

### Task 21: Run Complete screen

**Files:**
- Create: `lib/features/run_complete/run_complete_screen.dart`
- Test: `test/features/run_complete/run_complete_screen_test.dart`

**Interfaces:**
- Consumes: nothing from `core/engine` directly — receives a plain summary record from `RunBloc`/navigation extras.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/run_complete/run_complete_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/features/run_complete/run_complete_screen.dart';

void main() {
  testWidgets('shows a restart action', (tester) async {
    var restarted = false;
    await tester.pumpWidget(MaterialApp(home: RunCompleteScreen(onRestart: () => restarted = true)));
    await tester.tap(find.text('Start New Run'));
    expect(restarted, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/run_complete/run_complete_screen_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement**

```dart
// lib/features/run_complete/run_complete_screen.dart
import 'package:flutter/material.dart';

class RunCompleteScreen extends StatelessWidget {
  const RunCompleteScreen({super.key, required this.onRestart});
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Run Complete!', style: TextStyle(fontSize: 28)),
          FilledButton(onPressed: onRestart, child: const Text('Start New Run')),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/run_complete/run_complete_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Wire into router (restart dispatches `PhaseCompleted(GamePhase.characterCreation)` and rebuilds a fresh `EngineSession`+adapter set) and commit**

```bash
git add lib/features/run_complete test/features/run_complete
git commit -m "feat: add Run Complete screen"
```

---

## Phase 6 — Integration

### Task 22: Full first-run integration test

**Files:**
- Create: `integration_test/first_run_test.dart`

**Interfaces:**
- Consumes: `TomeApp`, `RunBloc`, every adapter built in Phase 3.

- [ ] **Step 1: Write the test**

```dart
// integration_test/first_run_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tome_client/app/tome_app.dart';
import 'package:tome_client/features/run/run_bloc.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('character creation through 3 fights to Run Complete', (tester) async {
    await tester.pumpWidget(TomeApp(runBloc: RunBloc()));
    await tester.pumpAndSettle();

    // Character Creation: name step.
    await tester.enterText(find.byType(TextField), 'Integration Fighter');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Style step: tap the first style card.
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    // Tome screen reached.
    expect(find.text('Your Tome'), findsOneWidget);

    // Fight 1 -> Loot -> Tome -> Fight 2 -> Loot -> Tome -> Fight 3 (Boss) -> Loot -> Run Complete.
    for (var fight = 1; fight <= 3; fight++) {
      await tester.tap(find.text('Start Fight'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm & Fight'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final firstLootCard = find.byType(GestureDetector).first;
      await tester.tap(firstLootCard);
      await tester.pumpAndSettle();
    }

    expect(find.text('Run Complete!'), findsOneWidget);
  });
}
```

**Deviation note:** this test references a `'Start Fight'` button on the Tome screen bottom bar that no prior task actually built — Task 15's `TomeScreen` only assembled the grid and tray. **Before writing this task's code**, add a bottom action bar to `TomeScreen` (Task 15's scope, retroactively) with `Train`/`Start Fight` buttons, where `Start Fight` dispatches `PhaseCompleted(GamePhase.combatPreparation)` on `RunBloc` and navigates to `/combat/prepare`. Wire `CombatPreparationScreen`'s enemy stats and `LootScreen`'s post-choice navigation (back to `/tome` for fights 1-2, to `/run-complete` after fight 3's loot) as plain fight-index tracking inside `RunBloc`'s own state (add an `int fightIndex` field to `RunState`, incremented on each `PhaseCompleted(GamePhase.tome)` that follows a `GamePhase.loot` phase) — this is exactly the "run of 3 fights is client orchestration, not an engine primitive" design decision from the spec's §2.1, so it belongs in `RunBloc`, not in `CombatAdapter`.

- [ ] **Step 2: Run the test**

Run: `flutter test integration_test/first_run_test.dart -d macos` (or whichever device Task 3 confirmed available)
Expected: PASS — the full loop completes to `RunComplete`. If it fails on a specific screen, that identifies exactly which Phase 5 task's wiring (Step 5 of Tasks 14-21) is incomplete — fix that task's router/navigation wiring, not this test.

- [ ] **Step 3: Commit**

```bash
git add integration_test
git commit -m "test: add full first-run integration test (character creation -> 3 fights -> Run Complete)"
```

---

## Self-Review

**Spec coverage:**
- §2.1/§2.2 (engine survey + 2 additive changes) → Tasks 1-2.
- §3 (architecture: adapter layer boundary, RunBloc/feature Blocs, go_router) → Tasks 5, 13.
- §4.1 (Character Creation, merged 6-card synergy screen) → Task 14.
- §4.2 (Tome screen: character strip, grid, combine tethers, tray, bottom bar) → Tasks 15, 17, 22 (bottom bar retrofit noted).
- §4.3 (Component Detail: state banner, lineage, hammer, combine row) → Task 16.
- §4.4-4.6 (Training Prep/Placeholder/Result) → Task 18.
- §4.7-4.8 (Combat Prep/Placeholder, instant-resolve-then-replay) → Task 19.
- §4.9 (Loot, 3 real RewardKind-equivalents, grid-expansion migration) → Tasks 12, 20.
- §4.10 (Run Complete) → Task 21.
- §5 (UX state language: locked/usable/mastered/equipped/combinable-eligible/combinable-ineligible) → `ItemDisplayState` (Task 4), tether bright/dim (Task 17), drag valid/invalid halo (Task 15).
- §6 (first-run data flow) → Task 22.
- §7 (testing approach: real-engine adapter tests, fake-adapter Bloc tests, widget tests, one integration test) → every task's own test file plus Task 22.
- §8 (explicitly out of scope) → respected: no Flame/2D combat, no 3D training, single generic training placeholder only, no player physique choice, no cross-run persistence.

**Placeholder scan:** no "TBD"/"TODO" left unresolved — every deviation found during planning (Task 8's combine-outcome derivation, Task 10's evolution-event/Tome-replace bug, Task 17's `eligibleToCombine` field, Task 22's missing bottom-bar wiring) is called out with the exact corrected code inline, not deferred.

**Type consistency:** `GamePhase`, `CharacterView`, `GridCellView`/`GridCellOccupant`, `ItemView`/`ItemDisplayState`, `TechniqueView`, `CombatLogEntryView`/`CombatLogEntryKind`, `LootOptionView`/`LootKind`, `CombineResultView`/`CombineResultKind`, `TrainingResultView` (Task 4) are the exact types every later adapter (Tasks 6-12) and every Bloc (Tasks 13-21) import and use — verified no task introduces a differently-named or differently-shaped duplicate. `ItemView.combinableWith`/`eligibleToCombine` (Task 4 → extended in Task 17) is consumed identically in Task 8's adapter and Task 17's widget.

**Known follow-up (not blocking this milestone, flag to the user before starting Phase 5):** Task 12's `RewardAdapter` takes `itemPool`/`techniquePool` as constructor arguments rather than owning its own seeded shuffle — whoever wires `RewardAdapter` up in `lib/app/tome_app.dart` (during Tasks 14-21's router work) needs to choose real starting pool contents (e.g. `[ItemIds.ironSword, ItemIds.gloves, ItemIds.trainingStaff, ItemIds.trainingShoes]` / `[TechniqueIds.basicPunch, TechniqueIds.basicSlash, TechniqueIds.basicGuard]`, mirroring `run_content.dart`'s own `rewardPoolItemIds`/`rewardPoolTechniqueIds` — reasonable content reuse, not a rule duplication, since these are just game-content id lists) and decide whether to seed-shuffle them (via a `RngService`-driven `seededShuffle`-equivalent, reusing `EngineSession.rng`) before passing them in.

---

## Execution Handoff

Two execution options:

1. **Subagent-Driven (recommended)** — a fresh subagent per task, with review between tasks and fast iteration.
2. **Inline Execution** — execute tasks in this session using `executing-plans`, batch execution with checkpoints.
