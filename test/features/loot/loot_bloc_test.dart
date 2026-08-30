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

void main() {
  blocTest<LootBloc, LootState>(
    'LootOffered then LootChosen applies the choice',
    build: () {
      final session = EngineSession(61);
      final cha = CharacterAdapter(session)..createCharacter('Test Fighter');
      final tomeAdapter = TomeAdapter(session)..createInitialTome();
      final rewardAdapter = RewardAdapter(
        session,
        characterAdapter: cha, tomeAdapter: tomeAdapter, techniqueAdapter: TechniqueAdapter(session),
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
