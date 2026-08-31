// test/features/tome/tome_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:build_engine/item_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/item_adapter.dart';
import 'package:tome_client/core/engine/technique_adapter.dart';
import 'package:tome_client/core/engine/tome_adapter.dart';
import 'package:tome_client/features/tome/tome_bloc.dart';
import 'package:tome_client/features/tome/tome_event.dart';

void main() {
  late EngineSession session;
  late CharacterAdapter characterAdapter;
  late TomeAdapter tomeAdapter;

  setUp(() {
    session = EngineSession(31);
    characterAdapter = CharacterAdapter(session);
    characterAdapter.createCharacter('Test Fighter');
    tomeAdapter = TomeAdapter(session)..createInitialTome();
    tomeAdapter.insertItem('knife', '0,0');
  });

  blocTest<TomeBloc, TomeState>(
    'TomeRefreshRequested loads the current grid',
    build: () => TomeBloc(
      tomeAdapter: tomeAdapter,
      itemAdapter: ItemAdapter(session),
      characterAdapter: characterAdapter,
      techniqueAdapter: TechniqueAdapter(session),
    ),
    act: (bloc) => bloc.add(const TomeRefreshRequested()),
    verify: (bloc) => expect(bloc.state.cells.where((c) => !c.isEmpty).length, 1),
  );

  blocTest<TomeBloc, TomeState>(
    'ComponentUpgraded spends a banked point',
    build: () {
      session.context.resources
          .add(session.character, ItemResources.upgradePoints, 3);
      return TomeBloc(
        tomeAdapter: tomeAdapter,
        itemAdapter: ItemAdapter(session),
        characterAdapter: characterAdapter,
        techniqueAdapter: TechniqueAdapter(session),
      );
    },
    act: (bloc) {
      bloc.add(const TomeRefreshRequested());
      final knifeValue =
          ItemAdapter(session).viewOf('knife').instanceEntityValue!;
      bloc.add(ComponentUpgraded(knifeValue));
    },
    verify: (bloc) => expect(bloc.state.upgradePoints, 2),
  );

  blocTest<TomeBloc, TomeState>(
    'ComponentRemoved takes the hung item off the board and back to the rack',
    build: () => TomeBloc(
      tomeAdapter: tomeAdapter,
      itemAdapter: ItemAdapter(session),
      characterAdapter: characterAdapter,
      techniqueAdapter: TechniqueAdapter(session),
    ),
    act: (bloc) {
      bloc.add(const TomeRefreshRequested());
      bloc.add(const ComponentRemoved('0,0'));
    },
    verify: (bloc) {
      expect(bloc.state.cells.every((c) => c.isEmpty), isTrue,
          reason: 'board is clear');
      expect(bloc.state.tray.map((v) => v.definitionId), contains('knife'),
          reason: 'knife is back in the loose rack, still owned');
    },
  );
}
