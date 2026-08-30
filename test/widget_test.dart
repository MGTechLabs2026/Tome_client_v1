// Smoke test for the app shell — the phase-driven router should land on
// the Character Creation route (its placeholder until Phase 5's screen
// replaces it).
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/app/tome_app.dart';
import 'package:tome_client/features/run/run_bloc.dart';

void main() {
  testWidgets('app shell boots into the characterCreation phase', (tester) async {
    await tester.pumpWidget(TomeApp(runBloc: RunBloc()));
    await tester.pumpAndSettle();

    expect(find.text('characterCreation'), findsOneWidget);
  });
}
