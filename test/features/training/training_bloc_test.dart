// test/features/training/training_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:build_engine/item_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/tome_adapter.dart';
import 'package:tome_client/core/engine/training_adapter.dart';
import 'package:tome_client/features/training/training_bloc.dart';
import 'package:tome_client/features/training/training_event.dart';

void main() {
  late EngineSession session;
  late TrainingAdapter trainingAdapter;

  setUp(() {
    session = EngineSession(41);
    CharacterAdapter(session).createCharacter('Test Fighter');
    final tomeAdapter = TomeAdapter(session)..createInitialTome();
    trainingAdapter = TrainingAdapter(session, tomeAdapter: tomeAdapter);
    ownItem(session.character, ItemIds.clothArmor, session.context);
    discoverItem(session.character, itemDefinition(ItemIds.clothArmor, session.context), session.context);
  });

  blocTest<TrainingBloc, TrainingState>(
    'three submitted attempts followed by TrainingCompleted produces a result',
    build: () => TrainingBloc(trainingAdapter),
    act: (bloc) {
      bloc.add(const TrainingSessionStarted(ItemIds.clothArmor, false));
      bloc.add(const AttemptSubmitted(150));
      bloc.add(const AttemptSubmitted(150));
      bloc.add(const AttemptSubmitted(150));
      bloc.add(const TrainingCompleted());
    },
    verify: (bloc) => expect(bloc.state.result, isNotNull),
  );
}
