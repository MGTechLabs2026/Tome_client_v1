// SP2 (per-active auras) inertness regression.
//
// PR 4 of the SP4a staged engine bump moves `build_engine` from SP1
// (`0663e8e`) to SP2 (`dc213d4`). SP2 adds a per-active *aura* system:
// `auras: [<ruleId>]` keys on 7 content ids (`cloth_armor`,
// `training_staff`, `training_shoes`, `warlords_iron_sword`,
// `crushing_gauntlets`, `basic_guard`, `basic_slash`), an `AuraBinder`
// that registers a hung ref's aura rules with the `RuleEngine` per fight,
// and `BuildActionInterpreter.auraRules({build, context})`.
//
// The client adopts NONE of it in SP4a: `CombatAdapter.runFight` builds
// its own action pool and runs its own turn loop, calls
// `ItemActionInterpreter().interpret(...)` for passive stat modifiers
// only, and never calls `auraRules()` or `AuraBinder`. So a hung
// aura-bearing component contributes NO aura in the client.
//
// This test pins that. The expected values below are the **SP1 baseline**
// — the complete observable result of a fixed scenario that hangs an
// aura-bearing item (`cloth_armor`, `aura.regen_weave`: unconditional
// `heal 1` on `TurnStarted`) and an aura-bearing technique (`basic_slash`,
// `aura.venom`: `50%` chance of `damage 2` to the opponent on
// `TurnStarted`) — captured while the engine dependency WAS SP1, then
// transcribed here as literals. The test runs against ONE engine version
// (SP2 by the time it runs) and asserts:
//   (a) SP2 reproduces the SP1 baseline result exactly — identical final
//       stats, every damage number, resolution order, tally, and the HP
//       snapshots the log carries; and
//   (b) two fresh `EngineSession(9)` instances agree with each other
//       (same-seed reproducibility).
//
// A drift in (a) where an aura rule fired (player HP trending up from a
// leaked `aura.regen_weave`, the enemy dropping faster from a leaked
// `aura.venom`) means an aura path leaked into the client — STOP, do not
// patch around it (see the task brief's Stage 4 "Inert-content check").

import 'package:build_engine/technique_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/combat_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/tome_adapter.dart';

/// One run of the fixed aura-bearing scenario, reduced to a fully
/// comparable value: win flag, the combat log serialised line by line
/// (kind, text, and both fighters' HP at that entry), and every tally
/// field.
({bool won, List<String> log, List<String> tally}) _runScenario() {
  final session = EngineSession(9);
  CharacterAdapter(session).createCharacter('Test Fighter');
  final tome = TomeAdapter(session)..createInitialTome();

  // Aura-bearing item: cloth_armor -> aura.regen_weave. Its `minimum: 1`
  // mastery gate has a single threshold [8]; push progress past it so the
  // piece can hang. (Deterministic, and applied identically pre/post bump.)
  session.context.mastery.increase(session.character, 'item:cloth_armor', 8);
  tome.insertItem('cloth_armor', '1,1');

  // Aura-bearing technique: basic_slash -> aura.venom. Damage-dealing, so
  // the scored policy throws it on every player turn (unlike a guard,
  // which the policy skips while the enemy is up).
  final slash = techniqueDefinition('basic_slash', session.context);
  discoverTechnique(session.character, slash, session.context);
  attemptToLearnTechnique(session.character, slash, 9999, session.context);
  tome.insertTechnique('basic_slash', '1,2');

  final out = CombatAdapter(session, tomeAdapter: tome).runFight(
    'rival_master',
    enemyHealth: 40,
    enemyDamage: 5,
    enemyDamageStat: 'fist',
  );

  final log = <String>[
    for (final e in out.log)
      '${e.kind.name}|${e.text}|p=${e.playerHp}/${e.playerHpMax}'
          '|e=${e.enemyHp}/${e.enemyHpMax}',
  ];
  final t = out.tally;
  final tally = <String>[
    'hitsByTechnique=${t.hitsByTechnique}',
    'missesByTechnique=${t.missesByTechnique}',
    'hitsByItem=${t.hitsByItem}',
    'missesByItem=${t.missesByItem}',
    'fistHits=${t.fistHits}',
    'fistMisses=${t.fistMisses}',
    'defenceHeld=${t.defenceHeld}',
    'defenceBroken=${t.defenceBroken}',
    'masteryAwarded=${t.masteryAwarded}',
    'hitsLanded=${t.hitsLanded}',
    'strikesMissed=${t.strikesMissed}',
  ];
  return (won: out.won, log: log, tally: tally);
}

/// The SP1 baseline — captured with `build_engine` at `0663e8e`, before
/// the SP2 bump. Every field of the complete observable result.
const _sp1BaselineWon = true;

const _sp1BaselineLog = <String>[
  'damage|You land Basic Slash — 8.0 damage.|p=100/100|e=32.0/40',
  'damage|Enemy hits for 5 — your Cloth Armor gives.|p=95/100|e=32.0/40',
  'damage|You land Basic Slash — 8.0 damage.|p=95/100|e=24.0/40',
  'heal|Enemy hits for 5 — your Cloth Armor soaks 1.|p=91/100|e=24.0/40',
  'actionResolved|Your Basic Slash goes wide.|p=91/100|e=24.0/40',
  'heal|Enemy hits for 5 — your Cloth Armor soaks 1.|p=87/100|e=24.0/40',
  'damage|You land Basic Slash — 8.0 damage.|p=87/100|e=16.0/40',
  'heal|Enemy hits for 5 — your Cloth Armor soaks 1.|p=83/100|e=16.0/40',
  'damage|You land Basic Slash — 8.0 damage.|p=83/100|e=8.0/40',
  'damage|Enemy hits for 5 — your Cloth Armor gives.|p=78/100|e=8.0/40',
  'damage|You land Basic Slash — 8.0 damage.|p=78/100|e=0.0/40',
  'actionResolved|Landed 5 · missed 1 · defence 3/5.|p=78/100|e=0.0/40',
  'victory|Victory!|p=78/100|e=0.0/40',
];

const _sp1BaselineTally = <String>[
  'hitsByTechnique={basic_slash: 5}',
  'missesByTechnique={basic_slash: 1}',
  'hitsByItem={}',
  'missesByItem={}',
  'fistHits=0',
  'fistMisses=0',
  'defenceHeld=3',
  'defenceBroken=2',
  'masteryAwarded=1.7000000000000002',
  'hitsLanded=5',
  'strikesMissed=1',
];

void main() {
  group('SP2 per-active auras are inert for the client', () {
    test('an aura-bearing build (cloth_armor + basic_slash) reproduces the '
        'SP1 baseline combat result exactly', () {
      final run = _runScenario();

      expect(run.won, _sp1BaselineWon);
      // Field-by-field: resolution order, every damage number, and the
      // HP snapshot each log entry carries.
      expect(run.log, _sp1BaselineLog);
      // Tally: hits/misses per component, defence held/broken, mastery.
      expect(run.tally, _sp1BaselineTally);
    });

    test('two fresh EngineSession(9) instances agree (same-seed '
        'reproducibility under SP2)', () {
      final a = _runScenario();
      final b = _runScenario();

      expect(b.won, a.won);
      expect(b.log, a.log);
      expect(b.tally, a.tally);
    });
  });
}
