// test/core/engine/combat_adapter_test.dart
import 'package:build_engine/martial_arts_plugin.dart'
    show BurstChainState, StyleCombatRules, offSpecialtyDamageFactor;
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

  group('style specialties in combat (Content Expansion V1, §E)', () {
    CombatAdapter styled(int seed, String style, String hangTechnique) {
      final session = EngineSession(seed);
      CharacterAdapter(session)
        ..createCharacter('Test Fighter')
        ..chooseStyle(style);
      final tome = TomeAdapter(session)..createInitialTome();
      final tech = techniqueDefinition(hangTechnique, session.context);
      discoverTechnique(session.character, tech, session.context);
      attemptToLearnTechnique(session.character, tech, 9999, session.context);
      tome.insertTechnique(hangTechnique, '1,1');
      return CombatAdapter(session, tomeAdapter: tome);
    }

    /// Total damage the player dealt across the whole fight, read off the
    /// "You land … — N damage." lines (N may be fractional).
    double totalPlayerDamage(String style, String tech) {
      final out = styled(4, style, tech).runFight(
        'x',
        enemyHealth: 100000, // never dies — the loop caps at maxSteps
        enemyDamage: 0,
        enemyDamageStat: 'fist',
      );
      var sum = 0.0;
      for (final e in out.log) {
        final m = RegExp(r'— ([\d.]+) damage').firstMatch(e.text);
        if (m != null) sum += double.parse(m.group(1)!);
      }
      return sum;
    }

    test('a blade technique lands softer for shaolin (off-lane) than for '
        'kunlun (in-lane) — the off-specialty penalty', () {
      final shaolin = totalPlayerDamage('shaolin', 'basic_slash');
      final kunlun = totalPlayerDamage('kunlun', 'basic_slash');
      expect(shaolin, greaterThan(0));
      expect(kunlun, greaterThan(0));
      // same seed -> same hit/miss pattern -> only the 0.85 factor differs
      expect(shaolin, closeTo(kunlun * 0.85, 0.001));
    });

    test('A2 parity: the ratio the adapter applies is exactly the engine '
        "StyleCombatRules' factor — one implementation, not two", () {
      double factor(String style, String tag) => StyleCombatRules(
        {'martial', 'style:$style'},
      ).outgoingDamageFactor(['technique', tag]);

      // The adapter multiplies AttackAction.baseDamage by this same call.
      expect(factor('shaolin', 'blade'), offSpecialtyDamageFactor);
      expect(factor('kunlun', 'blade'), 1.0);
      expect(factor('shaolin', 'fist'), 1.0);
      // Burst Chain state machine is the engine's too.
      final rules = StyleCombatRules({'martial', 'style:kunlun', 'spec:burst_chain'});
      var s = BurstChainState.broken;
      s = rules.burstChainOnHit(s, true).state;
      expect(rules.burstChainOnHit(s, true).bonus, 2);
    });

    test('a fist technique is unpenalised for shaolin (fist is in its lane)', () {
      final shaolin = totalPlayerDamage('shaolin', 'basic_punch');
      final kunlun = totalPlayerDamage('kunlun', 'basic_punch');
      expect(shaolin, closeTo(kunlun, 0.001));
    });

    test('shaolin Conditioning leaves the fighter with more HP than an '
        'otherwise identical run', () {
      final withCond = styled(2, 'shaolin', 'basic_punch').runFight(
          'x', enemyHealth: 500, enemyDamage: 6, enemyDamageStat: 'fist');
      final without = styled(2, 'kunlun', 'basic_punch').runFight(
          'x', enemyHealth: 500, enemyDamage: 6, enemyDamageStat: 'fist');
      int lastHp(List<dynamic> log) =>
          log.reversed.map((e) => e.playerHp).whereType<num>().first.round();
      expect(lastHp(withCond.log), greaterThan(lastHp(without.log)),
          reason: 'the -1/hit conditioning floor adds up over a fight');
    });
  });
}
