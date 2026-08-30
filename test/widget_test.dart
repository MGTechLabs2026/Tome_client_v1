// Smoke test for the app shell — the phase-driven router boots into the
// Character Creation phase, whose screen opens on the name step.
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/app/tome_app.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/features/run/run_bloc.dart';

void main() {
  testWidgets('app shell boots into Character Creation', (tester) async {
    await tester.pumpWidget(TomeApp(runBloc: RunBloc(), session: EngineSession(1)));
    await tester.pumpAndSettle();

    expect(find.text('Name your fighter'), findsOneWidget);
  });
}
