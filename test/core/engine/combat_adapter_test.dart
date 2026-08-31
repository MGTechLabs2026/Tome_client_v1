// test/core/engine/combat_adapter_test.dart
import 'package:build_engine/technique_plugin.dart';
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

  test('a Tome holding only a defensive technique still lets the player attack',
      () {
    final session = EngineSession(9);
    CharacterAdapter(session).createCharacter('Test Fighter');
    final tomeAdapter = TomeAdapter(session)..createInitialTome();

    // Learn Basic Guard (purely defensive) and hang it — nothing else.
    final guard = techniqueDefinition('basic_guard', session.context);
    discoverTechnique(session.character, guard, session.context);
    attemptToLearnTechnique(session.character, guard, 9999, session.context);
    tomeAdapter.insertTechnique('basic_guard', '1,1');

    final outcome = CombatAdapter(session, tomeAdapter: tomeAdapter).runFight(
      'training_dummy',
      enemyHealth: 8,
      enemyDamage: 1,
      enemyDamageStat: 'fist',
    );

    expect(outcome.log.any((e) => e.text.contains('You land')), isTrue,
        reason: 'the player still hits back despite a defence-only Tome');
    expect(outcome.won, isTrue);
  });

  group('enemy archetype behaviour (Content Expansion V1)', () {
    CombatAdapter freshAdapter(int seed) {
      final session = EngineSession(seed);
      CharacterAdapter(session).createCharacter('Test Fighter');
      final tome = TomeAdapter(session)..createInitialTome();
      return CombatAdapter(session, tomeAdapter: tome);
    }

    test('armour makes the same loadout take longer to drop the same enemy', () {
      int turnsToClear({double armour = 0}) {
        final out = freshAdapter(7).runFight(
          'x',
          enemyHealth: 40,
          enemyDamage: 0, // isolate offence
          enemyDamageStat: 'fist',
          enemyArmour: armour,
        );
        return out.log.where((e) => e.text.contains('You land')).length;
      }

      // With 55% shrug, each landed hit does < half — more landed hits
      // are needed to clear the same 40 HP.
      expect(turnsToClear(armour: 0.55), greaterThan(turnsToClear()));
    });

    test('a regenerating enemy is harder to finish than a plain one', () {
      bool wonAgainst({num regen = 0}) => freshAdapter(3)
          .runFight('x',
              enemyHealth: 26,
              enemyDamage: 3,
              enemyDamageStat: 'fist',
              enemyRegen: regen)
          .won;

      expect(wonAgainst(), isTrue);
      // 6 HP/turn out-heals a bare-handed fist on this seed.
      expect(wonAgainst(regen: 6), isFalse);
    });

    test('missPunish adds a counter beat to the log on a whiffed action', () {
      final out = freshAdapter(2).runFight(
        'x',
        enemyHealth: 60,
        enemyDamage: 6,
        enemyDamageStat: 'fist',
        enemyMissPunish: 0.5,
      );
      // Bare-handed fist misses often enough on this seed to see at
      // least one counter line before the fight resolves.
      expect(out.log.any((e) => e.text.contains('reads the opening')), isTrue);
    });

    test('a multi-hit enemy lands more blows per turn', () {
      int enemyHitLines({int hits = 1}) => freshAdapter(5)
          .runFight('x',
              enemyHealth: 30,
              enemyDamage: 2,
              enemyDamageStat: 'fist',
              enemyHits: hits)
          .log
          .where((e) => e.text.startsWith('Enemy hits'))
          .length;

      expect(enemyHitLines(hits: 2), greaterThan(enemyHitLines()));
    });
  });
}
