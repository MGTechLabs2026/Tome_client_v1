// SP2 (per-active auras) inertness regression.
//
// PR 4 of the SP4a staged engine bump moved `build_engine` from SP1
// (`0663e8e`) to SP2 (`dc213d4`). SP2 added a per-active *aura* system:
// `auras: [<ruleId>]` keys on 7 content ids (`cloth_armor`,
// `training_staff`, `training_shoes`, `warlords_iron_sword`,
// `crushing_gauntlets`, `basic_guard`, `basic_slash`), plus, on the engine
// side, NOT-ADOPTED: `AuraBinder` and NOT-ADOPTED: `auraRules` on the
// build-action interpreter. (The `NOT-ADOPTED:` prefixes let an
// adoption-detection grep over lib/ + test/ skip these doc mentions.)
//
// The client adopts none of it in SP4a: `CombatAdapter.runFight` builds
// its own action pool and turn loop and calls `ItemActionInterpreter`
// for passive stat modifiers only. A hung aura-bearing component therefore
// contributes no aura in the client.
//
// This test pins that. `_sp1Structural` and the tally expectations below
// are the SP1 baseline — the observable result of a fixed scenario,
// captured while `build_engine` WAS at `0663e8e`, then transcribed as
// literals. `cloth_armor` carries `aura.regen_weave` (unconditional heal 1
// on turn start, self); `basic_slash` carries `aura.venom` (chance of
// damage 2 on turn start, opponent). A leaked aura necessarily moves a
// per-entry HP snapshot — player HP trends up from a leaked regen, the
// enemy drops faster from leaked venom — so the STRUCTURAL assertion
// (entry kind + both HP snapshots) plus the numeric tally is the real
// inertness check. The player-facing combat-log copy is asserted
// separately: a wording change fails only that assertion and is a
// re-baseline, NOT an aura leak.
//
// If the structural or tally assertion drifts, do not patch around it —
// see the engine spec §5 Stage 4 "Inert-content check".
//
// SP4b note: when the client adopts the aura system, keep this file but
// invert it — same scenario, expectations that now DO reflect the auras.

import 'package:build_engine/technique_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/combat_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/tome_adapter.dart';

typedef _Run = ({
  bool won,
  List<String> structural, // entry kind + both fighters' HP — aura-sensitive
  List<String> text, // player-facing copy — not aura-sensitive
  Map<String, int> hitsByTechnique,
  Map<String, int> missesByTechnique,
  Map<String, int> hitsByItem,
  Map<String, int> missesByItem,
  int fistHits,
  int fistMisses,
  int defenceHeld,
  int defenceBroken,
  double masteryAwarded,
  int hitsLanded,
  int strikesMissed,
});

/// One run of the fixed aura-bearing scenario.
_Run _runScenario() {
  final session = EngineSession(9);
  CharacterAdapter(session).createCharacter('Test Fighter');
  final tome = TomeAdapter(session)..createInitialTome();

  // Aura-bearing item: cloth_armor -> aura.regen_weave. Its `minimum: 1`
  // mastery gate has a single threshold [8]; push progress past it so the
  // piece can hang. Deterministic; identical pre/post bump.
  session.context.mastery.increase(session.character, 'item:cloth_armor', 8);
  tome.insertItem('cloth_armor', '1,1');

  // Aura-bearing technique: basic_slash -> aura.venom. Damage-dealing, so
  // the scored policy throws it on every player turn.
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

  final t = out.tally;
  return (
    won: out.won,
    structural: [
      for (final e in out.log)
        '${e.kind.name}|p=${e.playerHp}/${e.playerHpMax}'
            '|e=${e.enemyHp}/${e.enemyHpMax}',
    ],
    text: [for (final e in out.log) e.text],
    hitsByTechnique: t.hitsByTechnique,
    missesByTechnique: t.missesByTechnique,
    hitsByItem: t.hitsByItem,
    missesByItem: t.missesByItem,
    fistHits: t.fistHits,
    fistMisses: t.fistMisses,
    defenceHeld: t.defenceHeld,
    defenceBroken: t.defenceBroken,
    masteryAwarded: t.masteryAwarded,
    hitsLanded: t.hitsLanded,
    strikesMissed: t.strikesMissed,
  );
}

// --- SP1 baseline (build_engine @ 0663e8e), transcribed as literals. ---

const _sp1Structural = <String>[
  'damage|p=100/100|e=32.0/40',
  'damage|p=95/100|e=32.0/40',
  'damage|p=95/100|e=24.0/40',
  'heal|p=91/100|e=24.0/40',
  'actionResolved|p=91/100|e=24.0/40',
  'heal|p=87/100|e=24.0/40',
  'damage|p=87/100|e=16.0/40',
  'heal|p=83/100|e=16.0/40',
  'damage|p=83/100|e=8.0/40',
  'damage|p=78/100|e=8.0/40',
  'damage|p=78/100|e=0.0/40',
  'actionResolved|p=78/100|e=0.0/40',
  'victory|p=78/100|e=0.0/40',
];

const _sp1Text = <String>[
  'You land Basic Slash — 8.0 damage.',
  'Enemy hits for 5 — your Cloth Armor gives.',
  'You land Basic Slash — 8.0 damage.',
  'Enemy hits for 5 — your Cloth Armor soaks 1.',
  'Your Basic Slash goes wide.',
  'Enemy hits for 5 — your Cloth Armor soaks 1.',
  'You land Basic Slash — 8.0 damage.',
  'Enemy hits for 5 — your Cloth Armor soaks 1.',
  'You land Basic Slash — 8.0 damage.',
  'Enemy hits for 5 — your Cloth Armor gives.',
  'You land Basic Slash — 8.0 damage.',
  'Landed 5 · missed 1 · defence 3/5.',
  'Victory!',
];

void main() {
  group('SP2 per-active auras are inert for the client', () {
    test('structural result matches the SP1 baseline '
        '(a leaked aura would move an HP snapshot or the tally)', () {
      final run = _runScenario();

      expect(run.won, isTrue);
      expect(
        run.structural,
        _sp1Structural,
        reason: 'entry kind + per-entry HP drifted from the SP1 baseline — '
            'that is a leaked aura.regen_weave / aura.venom tick, not a copy '
            'edit. STOP; do not re-baseline.',
      );

      expect(run.hitsByTechnique, {'basic_slash': 5});
      expect(run.missesByTechnique, {'basic_slash': 1});
      expect(run.hitsByItem, isEmpty);
      expect(run.missesByItem, isEmpty);
      expect(run.fistHits, 0);
      expect(run.fistMisses, 0);
      expect(run.defenceHeld, 3);
      expect(run.defenceBroken, 2);
      expect(run.hitsLanded, 5);
      expect(run.strikesMissed, 1);
      expect(run.masteryAwarded, closeTo(1.7, 1e-9));
    });

    test('combat-log copy matches the SP1 baseline '
        '(a mismatch here alone is a wording change — re-baseline, not a leak)',
        () {
      expect(_runScenario().text, _sp1Text);
    });

    test('two fresh EngineSession(9) instances agree under SP2', () {
      final a = _runScenario();
      final b = _runScenario();

      expect(b.won, a.won);
      expect(b.structural, a.structural);
      expect(b.text, a.text);
      expect(b.hitsByTechnique, a.hitsByTechnique);
      expect(b.masteryAwarded, a.masteryAwarded);
      expect(b.defenceHeld, a.defenceHeld);
      expect(b.defenceBroken, a.defenceBroken);
    });
  });
}
