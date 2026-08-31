// test/features/training/training_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:build_engine/item_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/tome_adapter.dart';
import 'package:tome_client/core/engine/training_adapter.dart';
import 'package:tome_client/features/training/exercise/target_strike_controller.dart';
import 'package:tome_client/features/training/training_bloc.dart';
import 'package:tome_client/features/training/training_event.dart';

Map<String, double> _measure({double off = 0, double latency = 120}) => {
      'targetX': 0.5,
      'targetY': 0.5,
      'actionX': 0.5 + off,
      'actionY': 0.5,
      'tolerance': 0.09,
      'signalTimestamp': 0.0,
      'responseTimestamp': latency,
      'maxAcceptable': 1200.0,
    };

void main() {
  late EngineSession session;
  late TrainingAdapter trainingAdapter;

  setUp(() {
    session = EngineSession(41);
    CharacterAdapter(session).createCharacter('Test Fighter');
    final tome = TomeAdapter(session)..createInitialTome();
    trainingAdapter = TrainingAdapter(session, tomeAdapter: tome);
    ownItem(session.character, ItemIds.clothArmor, session.context);
    discoverItem(session.character,
        itemDefinition(ItemIds.clothArmor, session.context), session.context);
  });

  blocTest<TrainingBloc, TrainingState>(
    'TrainingRunCompleted runs the exercise through the adapter and keeps '
    'the engine result + client summary',
    build: () => TrainingBloc(trainingAdapter),
    act: (bloc) {
      bloc.add(const TrainingSessionStarted(ItemIds.clothArmor, false));
      bloc.add(TrainingRunCompleted(
        [for (var i = 0; i < 9; i++) _measure()],
        const TrainingRunSummary(
          total: 9,
          hits: 8,
          perfect: 5,
          good: 2,
          weak: 1,
          misses: 1,
          avgReactionMs: 180,
          precision: 0.87,
        ),
      ));
    },
    verify: (bloc) {
      expect(bloc.state.result, isNotNull);
      expect(bloc.state.summary?.perfect, 5);
    },
  );
}
