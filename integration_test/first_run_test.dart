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

  testWidgets('a run is a fixed 3 bouts, then the run-complete screen, then '
      'the Tome for the next run', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      return tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
        TomeApp(runBloc: RunBloc(), session: EngineSession(2026)));
    await tester.pumpAndSettle();

    // Character Creation.
    await tester.enterText(find.byType(TextField), 'Integration Fighter');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(InkWell).first); // first style card
    await tester.pumpAndSettle();

    expect(find.text('THE LOOSE RACK'), findsOneWidget);

    Future<void> fightThenLoot() async {
      await tester.pumpAndSettle(); // slide onto the Tome
      await tester.tap(find.byKey(const Key('startFightButton')));
      await tester.pumpAndSettle(); // Tome -> Combat Prep
      expect(find.text('Confirm & Fight'), findsOneWidget);
      await tester.tap(find.text('Confirm & Fight'));
      await _pumpUntil(
          tester, () => find.text('+1 Upgrade Point').evaluate().isNotEmpty);
      expect(find.text('+1 Upgrade Point'), findsOneWidget);
      await tester.pumpAndSettle();
      await tester.tap(find.text('+1 Upgrade Point'));
    }

    // Bouts 1 and 2 -> back to the Tome each time.
    for (var bout = 1; bout <= 2; bout++) {
      await fightThenLoot();
      await _pumpUntil(tester,
          () => find.byKey(const Key('startFightButton')).evaluate().isNotEmpty);
      expect(find.byKey(const Key('startFightButton')), findsOneWidget,
          reason: 'bout $bout returns to the Tome');
    }

    // Bout 3 is the hard fight; its loot leads to RUN COMPLETE, not the Tome.
    await fightThenLoot();
    await _pumpUntil(
        tester, () => find.text('RUN 1 CLEARED').evaluate().isNotEmpty);
    expect(find.text('RUN 1 CLEARED'), findsOneWidget);
    expect(find.byKey(const Key('startFightButton')), findsNothing);

    // Continue -> next run, back on the Tome.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('startFightButton')), findsOneWidget);
    expect(find.text('THE LOOSE RACK'), findsOneWidget);
  });
}
