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
}
