// Smoke test for the app shell — the phase-driven router boots into the
// title screen, and NEW RUN carries the player into character creation.
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/app/tome_app.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/features/run/run_bloc.dart';

void main() {
  testWidgets('app shell boots into the title screen', (tester) async {
    await tester.pumpWidget(
      TomeApp(runBloc: RunBloc(), session: EngineSession(1)),
    );
    await tester.pumpAndSettle();

    expect(find.text('TOME'), findsOneWidget);
    expect(find.text('THE MARTIAL ART EDITION'), findsOneWidget);
  });

  testWidgets('NEW RUN opens character creation', (tester) async {
    await tester.pumpWidget(
      TomeApp(runBloc: RunBloc(), session: EngineSession(1)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('New Run'));
    await tester.pumpAndSettle();

    expect(find.text('NAME YOUR FIGHTER'), findsOneWidget);
  });
}
