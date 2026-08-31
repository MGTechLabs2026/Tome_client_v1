// test/features/combat/combat_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/combat_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/tome_adapter.dart';
import 'package:tome_client/core/models/enemy_view.dart';
import 'package:tome_client/features/combat/combat_bloc.dart';
import 'package:tome_client/features/combat/combat_event.dart';

void main() {
  blocTest<CombatBloc, CombatState>(
    'FightStarted resolves the fight and reports the outcome',
    build: () {
      final session = EngineSession(51);
      CharacterAdapter(session).createCharacter('Test Fighter');
      final tomeAdapter = TomeAdapter(session)..createInitialTome();
      return CombatBloc(CombatAdapter(session, tomeAdapter: tomeAdapter));
    },
    act: (bloc) => bloc.add(const FightStarted(EnemyView(
      id: 'training_dummy',
      archetype: EnemyArchetype.brute,
      health: 10,
      damage: 1,
      damageStat: 'fist',
    ))),
    verify: (bloc) => expect(bloc.state.won, isTrue),
  );
}
