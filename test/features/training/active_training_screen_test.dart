import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/app/theme.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/tome_adapter.dart';
import 'package:tome_client/core/engine/training_adapter.dart';
import 'package:tome_client/core/models/game_phase.dart';
import 'package:tome_client/features/run/run_bloc.dart';
import 'package:tome_client/features/training/active_training_screen.dart';
import 'package:tome_client/features/training/exercise/target_strike_controller.dart';
import 'package:tome_client/features/training/presentation/target_field.dart';
import 'package:tome_client/features/training/training_bloc.dart';
import 'package:tome_client/features/training/training_event.dart';

void main() {
  late EngineSession session;
  late TrainingAdapter trainingAdapter;
  late CharacterAdapter characterAdapter;
  late RunBloc runBloc;
  late TrainingBloc trainingBloc;

  Future<void> pump(WidgetTester tester, {String style = 'polearming'}) async {
    session = EngineSession(2026);
    characterAdapter = CharacterAdapter(session)..createCharacter('Fighter');
    characterAdapter.chooseStyle(style);
    final tome = TomeAdapter(session)..createInitialTome();
    trainingAdapter = TrainingAdapter(session, tomeAdapter: tome);
    runBloc = RunBloc();
    trainingBloc = TrainingBloc(trainingAdapter)
      ..add(const TrainingSessionStarted('iron_sword', false));

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider.value(value: trainingAdapter),
          RepositoryProvider.value(value: characterAdapter),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: runBloc),
            BlocProvider.value(value: trainingBloc),
          ],
          child: MaterialApp(
            theme: tomeTheme(),
            home: const ActiveTrainingScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  tearDown(() {
    runBloc.close();
    trainingBloc.close();
  });

  testWidgets('opens with the subject and a wave counter', (tester) async {
    await pump(tester);
    expect(find.text('TRAINING'), findsOneWidget);
    expect(find.text('IRON SWORD'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('striking the field clears targets and finishing all 3 waves '
      'produces a result and returns toward the Tome', (tester) async {
    await pump(tester);
    final field = find.byType(TargetField);
    expect(field, findsOneWidget);

    for (var wave = 0; wave < TargetStrikeController.waveCount; wave++) {
      for (var i = 0; i < TargetStrikeController.perWave; i++) {
        await tester.tapAt(tester.getCenter(field));
        await tester.pump(const Duration(milliseconds: 30));
      }
      // let the wave-complete delay + advance settle
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));
    }

    expect(trainingBloc.state.result, isNotNull);
    expect(trainingBloc.state.summary, isNotNull);
    expect(trainingBloc.state.summary!.total, 9);
    expect(runBloc.state.phase, GamePhase.trainingResult);
  });

  testWidgets('an untouched wave times out into misses', (tester) async {
    await pump(tester);
    // Never tap; just let every target's window close (wave 1 lifetime
    // is the longest at 1400ms).
    for (var wave = 0; wave < TargetStrikeController.waveCount; wave++) {
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 350));
    }
    expect(trainingBloc.state.summary!.misses, 9);
    expect(trainingBloc.state.summary!.hits, 0);
  });
}
