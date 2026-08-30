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

  testWidgets('character creation through an endless gauntlet until the player falls',
      (tester) async {
    // A real desktop form factor — 800x600 is neither shipped target.
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      return tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(TomeApp(runBloc: RunBloc(), session: EngineSession(2026)));
    await tester.pumpAndSettle();

    // Character Creation: name step.
    await tester.enterText(find.byType(TextField), 'Integration Fighter');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Style step: pick the first style card.
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(find.text('THE LOOSE RACK'), findsOneWidget);

    // Endless: Tome -> Fight -> (win) Loot -> Tome -> ... until a bout is
    // lost and the run ends on the "YOU FELL" screen. Enemies scale each
    // bout, so this always terminates; the cap is just a safety net.
    var gameOver = false;
    for (var fight = 1; fight <= 30 && !gameOver; fight++) {
      await tester.pumpAndSettle(); // finish the slide-in onto the Tome
      await tester.tap(find.byKey(const Key('startFightButton')));
      await tester.pumpAndSettle(); // Tome -> Combat Prep (both static)
      expect(find.text('Confirm & Fight'), findsOneWidget);

      await tester.tap(find.text('Confirm & Fight'));
      await _pumpUntil(
        tester,
        () =>
            find.text('+1 Upgrade Point').evaluate().isNotEmpty ||
            find.text('YOU FELL').evaluate().isNotEmpty,
      );

      if (find.text('YOU FELL').evaluate().isNotEmpty) {
        gameOver = true;
        break;
      }

      // Won this bout — take the upgrade point and head back to the Tome.
      await tester.pumpAndSettle(); // settle the Loot screen
      await tester.tap(find.text('+1 Upgrade Point'));
      await _pumpUntil(
        tester,
        () =>
            find.byKey(const Key('startFightButton')).evaluate().isNotEmpty ||
            find.text('YOU FELL').evaluate().isNotEmpty,
      );
      gameOver = find.text('YOU FELL').evaluate().isNotEmpty;
    }

    expect(gameOver, isTrue, reason: 'the gauntlet should end the player');
    expect(find.text('YOU FELL'), findsOneWidget);
    expect(find.text('Start New Run'), findsOneWidget);
  });
}
