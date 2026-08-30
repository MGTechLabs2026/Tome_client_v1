// test/features/tome/widgets/combine_confirmation_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/models/item_view.dart';
import 'package:tome_client/features/tome/widgets/combine_confirmation_sheet.dart';

const _knife = ItemView(
  definitionId: 'knife', name: 'knife', category: 'weapon', properties: {'attack': 2},
  state: ItemDisplayState.usable, itemClass: 1, maxClass: 3, masteryLevel: 0,
  masteryProgress: 0, masteryThresholds: [], instanceEntityValue: 1, combinableWith: [2],
  eligibleToCombine: true,
);

void main() {
  testWidgets('shows matched inputs and an Attempt Combine action', (tester) async {
    var confirmed = false;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () => showCombineConfirmation(context,
            matched: const [_knife, _knife], onConfirm: () => confirmed = true),
        child: const Text('open'),
      );
    })));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Attempt Combine'), findsOneWidget);
    await tester.tap(find.text('Attempt Combine'));
    expect(confirmed, isTrue);
  });
}
