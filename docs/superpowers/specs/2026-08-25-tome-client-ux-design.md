# Tome: Martial Arts — Client UX Milestone Design

Status: approved by user in brainstorming session, pending final spec review
Scope: Flutter client UX shell only. No 2D combat, no 3D training, no new
`build_engine` gameplay rules beyond the two additive exports below.

## 1. Product concept (recap)

Tome: Martial Arts is a build-and-discovery martial arts roguelike. Core loop:

    BUILD TOME -> TRAIN/LEARN -> AUTO COMBAT -> CHOOSE LOOT -> MODIFY TOME -> ...

Three modes: **Tome** (strategic build management, the primary interactive
surface), **Training** (interactive skill development), **Combat** (automatic
simulation, observation only). The Tome grid is the visual center of the
game — this is not an action RPG, and combat is not the primary input.

## 2. Engine boundary

`build_engine` (repo `Tome:RougelikeGame`, package `build_engine`,
remote `git@github-built-engine:MGTechLabs2026/built_engine.git`) is the sole
gameplay authority. The client never computes combat, mastery, technique
learning/evolution, item combine odds, reward generation, or progression —
it only sequences calls into the engine's public plugin APIs and renders the
result.

### 2.1 What already exists (verified against the current engine)

- **Core ECS**: `EntityId`/`EntityRegistry`/`ComponentStore`/`EventBus`.
- **Tome/Build**: `TomeService` (`defineTome`/`createTome`/`tomeOf`/`validate`/
  `insert`/`remove`/`move`/`replace`/`inspect`/`resolve`), built on the
  generic `Container` abstraction. `Container.grid(w,h)` supports a true
  spatial NxN grid — the canonical `game_run.dart` run doesn't use it (it
  uses a flat 999-slot `namedSlots` list instead), so the client defines its
  **own** `TomeDefinition.grid(3,3)`.
- **Items**: `ItemDefinition` (`properties`, `requirement`, `trainingWeights`,
  now also `itemClass`/`maxClass`/`gradeEvolutionCandidates`/
  `classScalingPercent`). State is derived, not a single enum: `isItemOwned`,
  `discovery.stateOf` (unknown→discovered→unlocked), `isItemUsable`
  (discovered AND mastery requirement met), `isItemActive` (in Tome).
- **Item Combine** (new, `item_lifecycle.dart`): `combineItems(owner,
  instanceEntities, context)` — 2+ owned instances sharing `definitionId` +
  `itemClass` → one surviving upgraded copy, resolved via `CombineResolver`
  into `CombineOutcome.fail/classUpgrade/gradeUpgrade`, costing
  `ItemResources.upgradePoints` = `itemClass`. Throws
  `CombineMismatchException` (different definitionId/itemClass),
  `CombineNotAvailableException` (already at `maxClass` with no eligible
  grade-evolution path), or an ownership `ArgumentError`.
- **Techniques**: `TechniqueDefinition` (tier, `evolutionCandidates`).
  Lifecycle: `discoverTechnique` → `attemptToLearnTechnique` (via
  `ProgressionEngine`, returns `LearningAttemptResult`) → `isTechniqueLearned`
  → separate mastery axis (`trainTechniqueMastery`). Evolution:
  `evolveTechnique(character, technique, trainingProfile, context)` →
  `EvolutionResult`, publishes `TechniqueEvolved(fromId, toId)` — one-hop
  only, no stored lineage tree.
- **Training**: 5 generic `TrainingExercise`s (Timing/Precision/Reaction/
  Power/Combo). `TrainingSession(trainee, subject, exercise)` →
  `submitAttempt` (repeatable) → `complete()` → `TrainingResult(profile,
  attempts)`. No pass/fail baked in; the caller interprets the profile.
- **Combat**: `CombatSystem.startBattle`/`executeAction`;
  `AutoCombatController(context, combatSystem, battle, availableActions,
  policy)` with `.step()`/`.runUntilBattleEnds()`. No "run of N fights"
  primitive — `game_run.dart` hand-composes exactly 3 fights per cycle; the
  client does the same.
- **Loot**: `RewardKind { unlockSlot, itemOrTechnique, upgradePoint }` — this
  **is** the spec's 3-category loot screen, engine-side. Candidates must be
  knowable before the player chooses (no blind boxes).
- **Character creation**: `CharacterService.create()`; `initializePhysique`
  (uniform-random over Sturdy/Power/Burst/Endurance, no player-choice API);
  `chooseMartialTradition`/`chooseStartingStyle`/`learnStyle` — **required**
  before the Tome exists, not just optional flavor.
- **Physique/tradition synergy** (real mechanic, `physique_content.dart`):
  each physique carries `western_affinity`/`eastern_affinity` tags and
  conditional `Modifier`s (`×1.25` matching tradition, `×0.85` mismatched)
  gated on the `western`/`eastern` tags `learnStyle` grants.
- **Session driver**: `game.dart`'s `runGame(seed, {policy}) -> RunResult` is
  a **synchronous, single-shot, blocking** function — `RunDecisionPolicy`
  methods return values immediately (even `ConsoleDecisionPolicy` blocks on
  `stdin.readLineSync()`). **Not usable directly by a Flutter UI.**

### 2.2 Required build_engine additions (both additive, no rule changes)

1. **Export the style→tradition mapping.** `martial_styles.dart` has a
   private `_traditionTagFor(styleId)` that `learnStyle` already uses
   internally. Add a public equivalent (e.g. `martialTraditionOf(String
   styleId) -> String?`) so the client can compute synergy borders *before*
   the player commits to a style, not just after `learnStyle` applies the
   tag. Approved.
2. **Expose a non-throwing combine eligibility query.** Add `bool
   canCombine(EntityId owner, List<EntityId> instanceEntities, PluginContext
   context)` mirroring `TomeService.validate`'s pure-preview pattern —
   internally reuses `combineItems`'s own eligibility checks (same
   definitionId/itemClass, ownership, `atMax && !hasGradePath`) without the
   RNG resolve or mutation. Needed because the max/grade-path check
   evaluates `EvolutionCandidate.conditions`, which is real domain logic the
   client must not reimplement. Approved.

No other engine changes are in scope for this milestone.

## 3. Client architecture

**Package**: `Tome_client` (Flutter) depends on `build_engine` via a git
dependency (existing deploy key), with a local `dependency_overrides` path
during development.

**Layers** (`lib/`):

- `core/engine/` — the only code that imports `package:build_engine/*`.
  `EngineSession` holds `PluginContext`, the character `EntityId`,
  `RngService`, `EventBus` subscriptions, and client-only bookkeeping the
  engine doesn't store (technique lineage map accumulated from
  `TechniqueEvolved` events, current fight index, character display name).
  One adapter per domain — `CharacterAdapter`, `TomeAdapter`, `ItemAdapter`,
  `TechniqueAdapter`, `TrainingAdapter`, `CombatAdapter`, `RewardAdapter` —
  exposing async, app-shaped methods that return immutable view models
  (`ItemView`, `TechniqueView`, `GridCellView`, `CombatLogEntryView`,
  `LootOptionView`, …). Raw engine types never cross this boundary.
- `core/models/` — those view models, plus the `GamePhase` sealed type.
- `features/<phase>/` — `character_creation/`, `tome/`, `training/`,
  `combat/`, `loot/`, `run_complete/`, each with `bloc/` + `view/`.
  `training/` and `combat/` additionally get `presentation/`, holding the
  `TrainingPresentation`/`CombatPresentation` abstract interfaces plus
  today's Flutter-widget placeholder implementation — the seam where
  Flame/3D drop in later without touching `core/engine` or `RunBloc`.
- `routing/` — `go_router` config, redirect-driven off `RunBloc`'s current
  `GamePhase` (illegal navigation is structurally impossible).
- `app/` — root widget, theme.

**Session orchestration**: the client does **not** call `runGame`. It writes
its own async orchestration that calls the same low-level plugin functions
`game_run.dart` already sequences (Tome/Item/Technique/Training/Combat/
Reward), driven by `flutter_bloc` events instead of a blocking
`RunDecisionPolicy`. `RunBloc` is the single source of truth for "which
phase, what session-scoped data does this phase need" and emits a sealed
`RunState`. Feature Blocs own in-phase interaction, call `core/engine`
adapters for reads/writes, and dispatch a "phase complete" event up to
`RunBloc` to advance. Widgets only ever consume their feature Bloc's state —
never `core/engine` directly — so gameplay rules cannot leak into a widget,
and swapping Combat/Training presentation later means new widgets against
the same Bloc contract.

**Phases** (`GamePhase`): `CharacterCreation`, `Tome`, `TrainingPreparation`,
`Training`, `TrainingResult`, `CombatPreparation`, `Combat`, `Loot`,
`RunComplete`.

## 4. Screen designs

### 4.1 Character Creation

1. **Name** — single text field.
2. **Choose Your Style** — one screen, 6 cards in two columns (Western:
   Boxing / Wrestling / Fencing | Eastern: Shaolin / Tai Chi / Wing Chun).
   A header shows the already-revealed physique ("Your physique: STURDY").
   Each card's border is **green** (synergy) or **red** (mismatch) computed
   from `martialTraditionOf(styleId)` vs. the physique's
   `western_affinity`/`eastern_affinity` tag — a real `×1.25`/`×0.85`
   mechanical effect, not decorative. Tapping a card commits tradition +
   style together in one action (no separate tradition-only step).
3. **Confirmation** — character card preview (name, physique, chosen
   style), `[Begin Journey]`.

Confirming drives `CharacterAdapter`: create → physique → tradition/style →
Tome creation, landing on Tome with a one-time dismissible callout on the
Knife and Cloth cells.

### 4.2 Tome (main screen)

Top to bottom, replacing the spec's original 4-block top area (redundant
with the grid itself) with a single compact strip:

- **Character strip** — portrait placeholder, name, physique/style tags.
  Tapping expands a secondary stat sheet (not the default view).
- **Tome Grid** (3×3, dominant) — drag-and-drop from tray or between cells.
  Live valid/invalid halo per cell during drag. Dropping onto an occupied
  cell offers replace, not silent overwrite.
- **Combine linking** — any two+ cards (grid or tray) sharing `definitionId`
  + `itemClass` get a connecting tether:
  - `canCombine == true` → bright/pulsing, tappable → opens **Combine
    Confirmation** (inputs shown, upgrade-point cost = `itemClass`,
    `[Attempt Combine]` → `combineItems` → reveals
    Fail/ClassUpgrade/GradeUpgrade outcome → Tome refreshes around the
    survivor).
  - `canCombine == false` (matched but maxed with no grade path) → dim/grey,
    not tappable — communicates "related but unavailable" rather than
    hiding the relationship.
  - 3+ matches render as a radial hub, not pairwise spaghetti; Combine sheet
    defaults to all matched instances selected, deselectable.
- **Component Tray** — horizontal scroll, filter tabs (All/Items/
  Techniques), each card badged with its state.
- **Bottom bar** — Train, Start Fight, Upgrade Points counter (tap to
  spend).

### 4.3 Component Detail (modal/bottom sheet, not full navigation)

Art, name, category/tier, properties, color-coded state banner (Discovered /
Locked with mastery progress bar + reason / Usable / Mastered / Equipped).
Techniques: evolution chip ("Evolved from: Light Punch") with `[View
Lineage]` expanding the client's accumulated lineage chain. Items eligible
for combine: "Combinable with →" row + `[Combine]`. **Hammer icon** appears
on any owned item or learned technique card whenever `upgrade_points > 0`
(mirrors `manageTome`'s `item:$id`/`technique:$id` candidates); tapping
spends one point via the same upgrade path. Contextual actions: Equip /
Unequip / Train / Remove.

### 4.4 Training Preparation

Subject picker (preselected if entered via Component Detail's Train
button), shows which exercise dimensions this session weights (icon tags:
Timing/Precision/Reaction/Power/Combo, from `trainingWeights`),
`[Begin Training]`.

### 4.5 Training Placeholder

One generic, parameterized interactive exercise — a timing-bar tap
interaction (moving marker, hit window sized/positioned by the subject's
`trainingWeights`) — rather than 5 distinct minigames. Submits real
`TrainingAttempt`s to a real `TrainingSession`, so progress is genuine; only
the visual is a placeholder. Single swap point for `TrainingPresentation`
later.

### 4.6 Training Result

Before/after bars for trained dimensions, mastery/learning delta. If
`evolveTechnique` fired: "NEW TECHNIQUE DISCOVERED / Evolved from X" panel,
`[View Lineage]` `[Use in Tome]`.

### 4.7 Combat Preparation

Interpreted loadout (from `CompositeBuildActionInterpreter`), next opponent
(name, "Fight 2"/"BOSS" tag), `[Confirm & Fight]` — the actual lock point;
Tome edits unavailable from here until Loot.

### 4.8 Combat Placeholder

PLAYER vs ENEMY, HP bars, current-action caption, scrolling event log,
progress indicator, WIN/LOSS banner. `CombatAdapter` runs the whole battle
instantly via `runUntilBattleEnds()`, captures the full event list, then the
presentation layer replays that fixed list at a readable pace with
pause/skip controls — decouples playback pacing from computation speed and
guarantees the log matches the already-decided outcome.

### 4.9 Loot Selection

Three cards matching real `RewardKind`s, shown with actual identity (no
blind boxes): Upgrade Points / Grid Expansion (client-side grid migration —
build a new larger `TomeDefinition.grid`, new `TomeInstance`, reinsert
existing placements, since the engine's own `unlockSlot` targets the
flat-list Tome we're not using) / New Component (real name+icon). Choosing
applies it, returns to Tome with confirmation + tray spotlight on new items.

### 4.10 Run Complete

After the boss fight's loot is chosen: recap (fights won, final Tome
snapshot, techniques discovered/evolved, total upgrade points),
`[Start New Run]` → back to Character Creation. No cross-run persistence
this milestone.

## 5. UX state language (applied consistently to every card/cell)

| State | Treatment |
|---|---|
| Empty | Dashed outline, subtle "+" hint |
| Valid drop target (dragging) | Green glow |
| Invalid drop target | Red glow, shake + toast reason on rejected drop |
| Locked | Desaturated, lock icon, tap → reason in Component Detail |
| Mastered | Gold border |
| Newly discovered | "NEW" ribbon, one-time pulse |
| Selected (move/combine) | Blue outline, valid targets highlighted |
| Upgraded | Shimmer + delta pop on the changed stat |
| Combinable (eligible) | Bright pulsing tether to matched card(s) |
| Combinable (ineligible) | Dim grey tether |

## 6. First-run data flow (illustrative call sequence)

1. Character Creation confirm → `CharacterAdapter.create()` →
   `initializePhysique` → player picks style → `learnStyle` +
   `chooseMartialTradition`/`chooseStartingStyle` equivalents →
   `TomeAdapter.createTome` with a client-defined `TomeDefinition.grid(3,3)`
   → insert starting Knife + Cloth refs.
2. Tome screen renders via `TomeAdapter.inspect` + `ItemAdapter` state
   queries. Player starts Fight 1 → Combat Preparation resolves loadout via
   `CompositeBuildActionInterpreter` → `[Confirm & Fight]` locks Tome.
3. `CombatAdapter.runFight()` → `CombatSystem.startBattle` +
   `AutoCombatController.runUntilBattleEnds()` → captured event list →
   Combat Placeholder replays it → WIN.
4. Loot: `RewardAdapter` surfaces 3 real `RewardKind` candidates → player
   picks one → applied → back to Tome.
5. Player modifies Tome (equip/train/combine as eligible) → Fight 2 → Loot →
   Tome → Fight 3 (Boss) → Loot → Run Complete.

## 7. Testing approach

- `core/engine/` adapters: unit-tested against the real `build_engine`
  package (no mocking of engine rules — mirrors the project's existing
  "hit the real thing" testing culture visible in `build_engine`'s own
  integration tests).
- Feature Blocs: unit-tested with a fake/in-memory adapter layer for
  fast, deterministic phase-transition tests.
- Widgets: `flutter_test` widget tests per screen for the UX states table
  (empty/locked/valid/invalid/selected/upgraded/newly-discovered/combinable)
  — each state must be independently renderable and visually distinct.
- End-to-end: one `integration_test` walking the full first-run loop
  (Section 6) against a fixed seed, asserting phase transitions occur in
  order and the run reaches `RunComplete`.

## 8. Explicitly out of scope this milestone

- Real 2D (Flame) combat rendering, real 3D training rendering.
- Distinct minigames per training exercise type (deferred beyond the single
  generic placeholder).
- Player-facing physique choice (engine only supports random assignment).
- Cross-run persistence / meta-progression.
- Any `build_engine` change beyond the two additive exports in §2.2.
