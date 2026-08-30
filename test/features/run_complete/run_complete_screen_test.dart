// test/features/run_complete/run_complete_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/features/run_complete/run_complete_screen.dart';

void main() {
  testWidgets('offers Continue (next run) and Start Over (fresh fighter)',
      (tester) async {
    var continued = false;
    var restarted = false;
    await tester.pumpWidget(MaterialApp(
      home: RunCompleteScreen(
        runNumber: 1,
        fightsCleared: 3,
        nextRunFights: 3,
        onContinue: () => continued = true,
        onRestart: () => restarted = true,
      ),
    ));

    await tester.tap(find.text('Continue'));
    expect(continued, isTrue);
    expect(restarted, isFalse);

    await tester.tap(find.text('Start Over'));
    expect(restarted, isTrue);
  });
}
