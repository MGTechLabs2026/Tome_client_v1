import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/app/theme.dart';
import 'package:tome_client/core/models/game_phase.dart';
import 'package:tome_client/features/run/run_bloc.dart';
import 'package:tome_client/features/title/title_screen.dart';

Widget _host(RunBloc bloc) => MaterialApp(
      theme: tomeTheme(),
      home: BlocProvider<RunBloc>.value(value: bloc, child: const TitleScreen()),
    );

void main() {
  testWidgets('shows the wordmark, edition line, version and the menu',
      (tester) async {
    final bloc = RunBloc();
    addTearDown(bloc.close);
    await tester.pumpWidget(_host(bloc));
    await tester.pumpAndSettle();

    expect(find.text('TOME'), findsOneWidget);
    expect(find.text('THE MARTIAL ART EDITION'), findsOneWidget);
    expect(find.text('v0.0.1'), findsOneWidget);

    for (final label in ['New Run', 'Almanac', 'Records', 'Settings', 'Quit']) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('New Run asks the RunBloc for a fresh run', (tester) async {
    final bloc = RunBloc();
    addTearDown(bloc.close);
    await tester.pumpWidget(_host(bloc));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('New Run'));
    await tester.pump();

    expect(bloc.state.phase, GamePhase.characterCreation);
    expect(bloc.state.sessionSeed, isNot(1));
  });
}
