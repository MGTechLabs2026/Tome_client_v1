// test/features/run_complete/run_complete_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/features/run_complete/run_complete_screen.dart';

void main() {
  testWidgets('shows a restart action', (tester) async {
    var restarted = false;
    await tester.pumpWidget(MaterialApp(home: RunCompleteScreen(onRestart: () => restarted = true)));
    await tester.tap(find.text('Start New Run'));
    expect(restarted, isTrue);
  });
}
