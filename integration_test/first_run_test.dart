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

  testWidgets('a run is 3 back-to-back bouts (no Tome mid-run); the Tome only '
      'opens once the run is cleared', (tester) async {
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

    // Character Creation -> the Tome opens once, before the run starts.
    await tester.enterText(find.byType(TextField), 'Integration Fighter');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(InkWell).first); // first style card
    await tester.pumpAndSettle();
    expect(find.text('THE LOOSE RACK'), findsOneWidget);

    // Kick off bout 1 from the Tome.
    await tester.tap(find.byKey(const Key('startFightButton')));
    await tester.pumpAndSettle();

    Future<void> confirmFightAndTakeLoot() async {
      await _pumpUntil(
          tester, () => find.text('Confirm & Fight').evaluate().isNotEmpty);
      await tester.tap(find.text('Confirm & Fight'));
      // Wait for the combat replay to finish and the loot screen to be
      // fully in (a couple of extra frames past first appearance so the
      // route transition has settled before we tap).
      await _pumpUntil(
          tester, () => find.text('+1 Upgrade Point').evaluate().isNotEmpty);
      await tester.pump(const Duration(milliseconds: 600));
      await _pumpUntil(
          tester, () => find.text('+1 Upgrade Point').evaluate().isNotEmpty);
      await tester.tap(find.text('+1 Upgrade Point'));
    }

    // Bouts 1 and 2: loot leads straight into the next bout's prep — the
    // Tome must NOT appear.
    for (var bout = 1; bout <= 2; bout++) {
      await confirmFightAndTakeLoot();
      await _pumpUntil(
          tester, () => find.text('Confirm & Fight').evaluate().isNotEmpty);
      expect(find.text('Confirm & Fight'), findsOneWidget,
          reason: 'bout $bout loot goes straight to the next bout');
      expect(find.text('THE LOOSE RACK'), findsNothing,
          reason: 'no Tome mid-run');
    }

    // Bout 3 is the hard fight; its loot clears the run and opens the Tome
    // for run 2.
    await confirmFightAndTakeLoot();
    await _pumpUntil(
        tester, () => find.text('THE LOOSE RACK').evaluate().isNotEmpty);
    expect(find.text('THE LOOSE RACK'), findsOneWidget);
    expect(find.byKey(const Key('startFightButton')), findsOneWidget);
    // The foot bar now reads run 2.
    expect(find.textContaining('RUN 2'), findsWidgets);
    // Clearing the run healed the fighter to full for the next one.
    expect(find.text('100 / 100'), findsOneWidget);
  });
}
