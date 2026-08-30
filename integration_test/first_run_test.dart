// integration_test/first_run_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tome_client/app/tome_app.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/features/run/run_bloc.dart';

/// Pumps in fixed real-time steps until [predicate] holds or [maxSteps]
/// elapse. The combat replay drives itself off a wall-clock Timer, so a
/// plain pumpAndSettle would either race it or (with a perpetual ticker
/// on screen) never return.
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() predicate, {
  int maxSteps = 80,
}) async {
  for (var i = 0; i < maxSteps; i++) {
    if (predicate()) return;
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('character creation through 3 fights to Run Complete', (tester) async {
    await tester.pumpWidget(TomeApp(runBloc: RunBloc(), session: EngineSession(2026)));
    await tester.pumpAndSettle();

    // Character Creation: name step.
    await tester.enterText(find.byType(TextField), 'Integration Fighter');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Style step: pick the first style card.
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(find.text('Your Tome'), findsOneWidget);

    // Fight 1 -> Loot -> Tome -> Fight 2 -> Loot -> Tome -> Fight 3 -> Loot -> Run Complete.
    for (var fight = 1; fight <= 3; fight++) {
      await tester.tap(find.text('Start Fight'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm & Fight'), findsOneWidget);
      await tester.tap(find.text('Confirm & Fight'));

      await _pumpUntil(tester, () => find.text('+1 Upgrade Point').evaluate().isNotEmpty);
      expect(find.text('+1 Upgrade Point'), findsOneWidget);

      await tester.tap(find.text('+1 Upgrade Point'));
      await _pumpUntil(
        tester,
        () =>
            find.text('Start Fight').evaluate().isNotEmpty ||
            find.text('Run Complete!').evaluate().isNotEmpty,
      );
    }

    expect(find.text('Run Complete!'), findsOneWidget);
  });
}
