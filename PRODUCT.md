# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

Ships as a native Flutter app (iOS/Android/macOS/web build targets), but the approved design language is a fully custom game UI (Tome grid, combine tethers, hammer icons, custom card-state treatments) — not native HIG/Material component conformance. Recorded as `web` deliberately so future design work isn't held to native tab-bar/FAB/system-picker rules; only genuinely system-level chrome (safe areas, OS gestures) still follows platform convention.

## Stack

Flutter (Dart SDK `^3.7.0`), `flutter_bloc` for state management, `go_router` for phase-driven navigation, `build_engine` (private git package, sole gameplay-rules authority) as a git dependency with a local `dependency_overrides` path during development. No other state-management package. This was an existing decision recorded in `docs/superpowers/specs/2026-08-25-tome-client-ux-design.md` and `docs/superpowers/plans/2026-08-25-tome-client-ux-implementation.md`, not made during this init.

## Users

Players of a build-and-discovery martial arts roguelike. This is a solo/small-team indie game aiming for eventual public release (not currently a pure personal/portfolio exercise) — design and UX decisions should hold up for external players, not just the developer.

The player's core loop, in their own words: build a Tome (grid-based loadout), train/learn techniques, watch an automatic combat simulation play out, choose loot, modify the Tome, repeat. The Tome — not combat — is the primary interactive surface; combat is observation, not action-RPG input.

## Product Purpose

Tome: Martial Arts is a martial arts roguelike where the core skill expression is build-crafting (assembling and evolving a "Tome" of items/techniques on a spatial grid) rather than real-time combat execution. Success for the player is discovering synergies (martial tradition matches, item combines, technique evolutions) and seeing a stronger Tome survive progressively harder auto-resolved fights across a run.

The Tome_client repo is specifically the **Flutter UX shell** for this game: character creation through a full 3-fight run with real loot and Tome edits, driving every rule through the `build_engine` package, with Combat and Training rendered as swappable placeholders (real 2D/Flame combat and 3D training are explicitly future work, not this milestone).

## Positioning

The mechanism a neighboring roguelike-deckbuilder couldn't casually copy: every visible state (locked/mastered/combinable/upgradeable) is a materialization of real engine data — mastery requirements, `itemClass`/grade-evolution paths, technique evolution lineage, martial-tradition affinity multipliers (`×1.25` synergy / `×0.85` mismatch) — never decorative or client-invented. Loot is always shown with real identity (no blind boxes); combine/upgrade eligibility is queried from the engine (`canCombine`), not guessed client-side. The UI's job is to make real, engine-authoritative mechanical relationships (which items combine, which techniques evolved from what, which style matches this physique) legible at a glance via consistent visual language (tethers, borders, badges) rather than requiring the player to read stat sheets.

## Operating Context

- **Engine boundary is absolute**: `build_engine` (separate repo `Tome:RougelikeGame`) is the sole authority for combat, mastery, technique learning/evolution, item combine odds, and reward generation. The client only sequences calls into engine plugin APIs and renders results — it never computes gameplay rules itself. `package:build_engine/*` may only be imported inside `lib/core/engine/`.
- **Session model**: the client does not call the engine's blocking `runGame`; it runs its own async orchestration (`RunBloc` phase machine) calling the same low-level plugin functions the engine's reference run sequences, driven by Bloc events instead of a synchronous decision policy.
- **Phase-driven, illegal-navigation-proof routing**: `go_router` redirects off `RunBloc`'s current `GamePhase` (`CharacterCreation → Tome → TrainingPreparation → Training → TrainingResult → CombatPreparation → Combat → Loot → RunComplete`).
- **Presentation seams for future work**: `TrainingPresentation`/`CombatPresentation` are abstract interfaces with today's Flutter-widget placeholder implementations — the intended drop-in point for later Flame (2D) combat rendering and 3D training rendering, without touching `core/engine` or `RunBloc`.
- **Testing culture inherited from `build_engine`**: adapter tests hit the real engine package end-to-end — engine rules are never mocked. Feature Blocs are tested against a fake/in-memory adapter for fast deterministic phase-transition tests.
- **Cross-repo coordination**: this milestone requires exactly two additive, no-rule-change exports from `build_engine` (`martialTraditionOf(styleId)`, `canCombine(...)`) — no other engine change is in scope. The two repos currently develop in lockstep via local `dependency_overrides` worktrees.
- **No cross-run persistence or meta-progression** in this milestone — a completed run returns to Character Creation with nothing carried over.

## Capabilities and Constraints

**Confirmed real mechanics the UI must faithfully represent (not decorative):**
- Grid-based Tome (client defines its own true `TomeDefinition.grid(3,3)`, distinct from the engine's own flat 999-slot reference-run Tome).
- Item state is derived, not a single enum: unknown → discovered → unlocked (`discovery.stateOf`), usable (discovered AND mastery met), active (in Tome).
- Item Combine: 2+ owned instances sharing `definitionId` + `itemClass` → one upgraded survivor, costs `upgradePoints = itemClass`, outcomes are `fail`/`classUpgrade`/`gradeUpgrade`.
- Techniques: discover → learn (via `ProgressionEngine`) → separate mastery axis → one-hop evolution (no stored lineage tree server-side; the client accumulates lineage itself from `TechniqueEvolved` events).
- Training: 5 generic exercise dimensions (Timing/Precision/Reaction/Power/Combo); this milestone ships one generic parameterized placeholder interaction (not 5 distinct minigames), but submits real attempts to a real training session — only the visual is a placeholder.
- Combat: fully auto-resolved (`runUntilBattleEnds()`); the client captures the real event log first, then replays it at a readable pace — playback is decoupled from computation and never contradicts the already-decided outcome.
- Loot: exactly 3 real `RewardKind`s (`unlockSlot`/`itemOrTechnique`/`upgradePoint`), always shown with real identity before the player chooses.
- Physique/tradition synergy is a real stat multiplier, not flavor text: physique is randomly assigned (no player-facing physique choice), but style choice and its tradition match/mismatch against that physique is real and player-facing.

**Explicitly out of scope this milestone:**
- Real 2D (Flame) combat rendering or real 3D training rendering.
- Distinct minigames per training exercise type.
- Player-facing physique choice.
- Cross-run persistence / meta-progression.
- Any `build_engine` change beyond the two additive exports above.

**Terminology**: "Tome" = the player's grid-based build/loadout (not a book/document UI, despite the name). "Run" = one full playthrough (character creation → 3 fights → run complete). "Martial tradition" = western/eastern axis, distinct from "style" (the 6 concrete styles: Boxing/Wrestling/Fencing/Shaolin/Tai Chi/Wing Chun) and from "physique" (Sturdy/Power/Burst/Endurance, randomly assigned).

## Evidence on Hand

- `docs/superpowers/specs/2026-08-25-tome-client-ux-design.md` — full approved UX design spec (screen-by-screen), source of truth for this milestone's product and interaction facts.
- `docs/superpowers/plans/2026-08-25-tome-client-ux-implementation.md` — task-by-task implementation plan with the same product facts operationalized.
- No visual assets, logos, or brand marks currently exist in this repo. No player-facing name/logo treatment has been confirmed yet — future visual work must not invent one without asking.
- No real player testimonials, store copy, or marketing evidence exists yet (pre-release indie game).

## Product Principles

1. **The engine is the only source of gameplay truth.** Every state the UI shows (locked, mastered, combinable, synergy border) must trace to a real engine query, never a client-invented heuristic or decorative approximation.
2. **The Tome, not combat, is the game.** Combat and training are observation/skill-check surfaces; the grid-based build is the sustained strategic surface and should read as visually dominant and get the most interaction affordance care.
3. **No blind boxes.** Loot, combine outcomes, and eligibility are always shown with real identity/odds-relevant info before a commit action, never hidden until after choosing.
4. **Relationships stay visible even when unavailable.** An ineligible combine (matched but maxed) is shown dim/grey, not hidden — "related but unavailable" is itself information the player needs.
5. **Presentation is swappable, rules are not.** Combat/Training placeholders must be replaceable by real 2D/3D rendering later without touching engine adapters or Bloc contracts — this shapes today's architecture even though today's visuals are intentionally placeholder-grade.

## Accessibility & Inclusion

No accessibility standard has been confirmed yet for this project. Not yet established — do not assume a specific WCAG/platform target without asking.
