import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/app/theme.dart';
import 'package:tome_client/core/models/game_phase.dart';
import 'package:tome_client/features/defeat/defeat_screen.dart';
import 'package:tome_client/features/run/run_bloc.dart';

void main() {
  testWidgets('shows how far the line got and returns to the Hall',
      (tester) async {
    final bloc = RunBloc();
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: tomeTheme(),
        home: BlocProvider<RunBloc>.value(
          value: bloc,
          child: const DefeatScreen(runNumber: 4, bout: 2),
        ),
      ),
    );

    expect(find.text('THE LINE ENDS'), findsOneWidget);
    expect(find.textContaining('run 4, bout 2'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Return to the Hall'));
    await tester.pump();

    expect(bloc.state.phase, GamePhase.title);
    expect(bloc.state.runNumber, 1);
  });
}
