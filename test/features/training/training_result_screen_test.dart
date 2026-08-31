import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/app/theme.dart';
import 'package:tome_client/core/models/game_phase.dart';
import 'package:tome_client/core/models/training_result_view.dart';
import 'package:tome_client/features/run/run_bloc.dart';
import 'package:tome_client/features/training/exercise/target_strike_controller.dart';
import 'package:tome_client/features/training/training_bloc.dart';
import 'package:tome_client/features/training/training_event.dart';
import 'package:tome_client/features/training/training_result_screen.dart';

class _MockTrainingBloc extends MockBloc<TrainingEvent, TrainingState>
    implements TrainingBloc {}

const _summary = TrainingRunSummary(
  total: 9,
  hits: 8,
  perfect: 6,
  good: 1,
  weak: 1,
  misses: 1,
  avgReactionMs: 214,
  precision: 0.91,
);

void main() {
  late _MockTrainingBloc bloc;
  late RunBloc runBloc;

  setUp(() {
    bloc = _MockTrainingBloc();
    runBloc = RunBloc();
  });
  tearDown(() => runBloc.close());

  Future<void> pump(WidgetTester tester, TrainingState state) async {
    whenListen(bloc, const Stream<TrainingState>.empty(), initialState: state);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<TrainingBloc>.value(value: bloc),
          BlocProvider<RunBloc>.value(value: runBloc),
        ],
        child: MaterialApp(theme: tomeTheme(), home: const TrainingResultScreen()),
      ),
    );
  }

  testWidgets('item training shows the mastery consequence + the summary '
      'ledger, and returns to the Tome', (tester) async {
    await pump(
      tester,
      const TrainingState(
        subject: 'iron_sword',
        isTechnique: false,
        summary: _summary,
        result: TrainingResultView(
          subject: 'item:iron_sword',
          dimensions: {'accuracy': 0.9, 'reaction': 0.8},
          gain: 4.2,
          crossedIntoUsableOrLearned: false,
        ),
      ),
    );

    expect(find.text('TRAINING COMPLETE'), findsOneWidget);
    expect(find.text('ITEM MASTERY'), findsOneWidget);
    expect(find.text('+4.2'), findsOneWidget);
    expect(find.text('8 / 9'), findsOneWidget); // hits
    expect(find.text('214 ms'), findsOneWidget);
    expect(find.text('91%'), findsOneWidget);
    expect(find.text('NEW TECHNIQUE'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Back to the Tome'));
    await tester.pump();
    expect(runBloc.state.phase, GamePhase.tome);
  });

  testWidgets('engine-reported evolution is shown as the surprise discovery',
      (tester) async {
    await pump(
      tester,
      const TrainingState(
        subject: 'basic_punch',
        isTechnique: true,
        summary: _summary,
        result: TrainingResultView(
          subject: 'technique:basic_punch',
          dimensions: {'precision': 0.95, 'reaction': 0.9},
          gain: 6.1,
          crossedIntoUsableOrLearned: true,
          evolvedIntoDefinitionId: 'light_punch',
          evolvedFromDefinitionId: 'basic_punch',
        ),
      ),
    );

    expect(find.text('NEW TECHNIQUE'), findsOneWidget);
    expect(find.text('LIGHT PUNCH'), findsOneWidget);
    expect(find.text('EVOLVED FROM'), findsOneWidget);
    expect(find.text('basic punch'), findsOneWidget);
    // the plain mastery number is replaced by the discovery beat
    expect(find.text('+6.1'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Continue to the Tome'));
    await tester.pump();
    expect(runBloc.state.phase, GamePhase.tome);
  });

  testWidgets('no evolution -> no false discovery', (tester) async {
    await pump(
      tester,
      const TrainingState(
        subject: 'basic_slash',
        isTechnique: true,
        summary: _summary,
        result: TrainingResultView(
          subject: 'technique:basic_slash',
          dimensions: {'precision': 0.4},
          gain: 1.1,
          crossedIntoUsableOrLearned: false,
        ),
      ),
    );
    expect(find.text('NEW TECHNIQUE'), findsNothing);
    expect(find.text('TECHNIQUE LEARNING'), findsOneWidget);
  });
}
