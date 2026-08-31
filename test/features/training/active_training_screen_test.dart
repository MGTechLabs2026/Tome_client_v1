import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/app/theme.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/tome_adapter.dart';
import 'package:tome_client/core/engine/training_adapter.dart';
import 'package:tome_client/core/models/game_phase.dart';
import 'package:tome_client/core/persistence/game_store.dart';
import 'package:tome_client/core/persistence/training_pace_repository.dart';
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
  late TrainingPaceRepository pace;

  Future<void> pump(WidgetTester tester,
      {String style = 'polearming', GameStore? store}) async {
    session = EngineSession(2026);
    characterAdapter = CharacterAdapter(session)..createCharacter('Fighter');
    characterAdapter.chooseStyle(style);
    final tome = TomeAdapter(session)..createInitialTome();
    trainingAdapter = TrainingAdapter(session, tomeAdapter: tome);
    runBloc = RunBloc();
    pace = TrainingPaceRepository(store ?? GameStore.memory());
    trainingBloc = TrainingBloc(trainingAdapter)
      ..add(const TrainingSessionStarted('iron_sword', false));

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider.value(value: trainingAdapter),
          RepositoryProvider.value(value: characterAdapter),
          RepositoryProvider.value(value: pace),
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

  testWidgets('striking each target dead-centre clears all 3 waves, produces '
      'a result, returns toward the Tome, and carries a tighter pace',
      (tester) async {
    await pump(tester);
    final field = find.byType(TargetField);
    expect(field, findsOneWidget);

    for (var wave = 0; wave < TargetStrikeController.waveCount; wave++) {
      final rect = tester.getRect(field);
      final targets = (tester.widget(field) as TargetField).wave;
      for (final t in targets) {
        await tester.tapAt(
          rect.topLeft + Offset(t.x * rect.width, t.y * rect.height),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));
    }

    expect(trainingBloc.state.result, isNotNull);
    expect(trainingBloc.state.summary!.total, 9);
    expect(trainingBloc.state.summary!.hits, 9);
    expect(runBloc.state.phase, GamePhase.trainingResult);
    // A clean run carries forward as a tighter pace.
    expect(pace.pace, lessThan(1.0));
  });

  testWidgets('an untouched wave times out into misses', (tester) async {
    await pump(tester);
    // Never tap; just let every target's window close. Pump in ~60fps
    // frames — the field's stall clamp caps a single frame at 200ms, so
    // the wave clock only advances with a realistic frame cadence (this
    // is exactly what protects a backgrounded browser tab; see
    // TargetField._maxFrameMs).
    for (var wave = 0; wave < TargetStrikeController.waveCount; wave++) {
      for (var ms = 0; ms < 3200; ms += 16) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 350));
    }
    expect(trainingBloc.state.summary!.misses, 9);
    expect(trainingBloc.state.summary!.hits, 0);
    // A blank run buys the next session more time (slow device isn't
    // punished on a hard reset).
    expect(pace.pace, greaterThan(1.0));
  });

  testWidgets('a backgrounded tab does not time out live targets — the wave '
      'clock rejects a stalled frame', (tester) async {
    await pump(tester);
    // One giant frame stands in for "tab hidden for 30 s, then resumed":
    // AnimationController.lastElapsedDuration jumps by the whole gap in a
    // single tick. The clamp must keep the wave alive.
    await tester.pump(const Duration(milliseconds: 30000));
    await tester.pump(const Duration(milliseconds: 16));
    expect(trainingBloc.state.result, isNull,
        reason: 'no wave should have resolved from hidden time');
    // A normal frame cadence afterwards still runs the session to its
    // end — the stall neither advanced nor broke the clock.
    for (var wave = 0; wave < TargetStrikeController.waveCount; wave++) {
      for (var ms = 0; ms < 3200; ms += 16) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 350));
    }
    expect(trainingBloc.state.summary!.misses, 9,
        reason: 'every target still times out on real frames, none on the stall');
  });

  testWidgets('a stored tighter pace makes the first wave shorter than the '
      'baseline', (tester) async {
    final store = GameStore.memory();
    await TrainingPaceRepository(store).recordSession(1.0); // clean history
    await pump(tester, store: store);
    // Baseline wave-1 lifetime is 1750ms; a carried pace < 1 shortens it.
    final t = tester.state(find.byType(TargetField));
    expect((t as dynamic).widget.wave.first.lifetimeMs, lessThan(1750));
  });
}
