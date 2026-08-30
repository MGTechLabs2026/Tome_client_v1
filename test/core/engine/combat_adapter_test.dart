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
