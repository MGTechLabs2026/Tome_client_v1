// test/features/tome/widgets/component_detail_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/models/item_view.dart';
import 'package:tome_client/features/tome/widgets/component_detail_sheet.dart';

void main() {
  testWidgets('locked item shows the Locked banner and a Train action, no Equip', (tester) async {
    const item = ItemView(
      definitionId: 'cloth_armor', name: 'cloth_armor', category: 'armor',
      properties: {'defense': 2}, state: ItemDisplayState.locked,
      itemClass: 1, maxClass: 3, masteryLevel: 0, masteryProgress: 0,
      masteryThresholds: [8], instanceEntityValue: 1, combinableWith: [],
      eligibleToCombine: false,
    );

    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () => showComponentDetail(context, item: item, onTrain: () {}),
        child: const Text('open'),
      );
    })));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('LOCKED'), findsOneWidget);
    expect(find.text('TRAIN'), findsOneWidget);
    expect(find.text('EQUIP'), findsNothing);
    expect(find.text('UNHANG'), findsNothing,
        reason: 'no onRemove -> no Unhang');
  });

  testWidgets('a hung component shows an Unhang action that fires onRemove',
      (tester) async {
    const item = ItemView(
      definitionId: 'polearm', name: 'polearm', category: 'weapon',
      properties: {'attack': 3}, state: ItemDisplayState.equipped,
      itemClass: 1, maxClass: 3, masteryLevel: 0, masteryProgress: 0,
      masteryThresholds: [], instanceEntityValue: 4, combinableWith: [],
      eligibleToCombine: false,
    );

    var removed = false;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () => showComponentDetail(
          context,
          item: item,
          onTrain: () {},
          onRemove: () => removed = true,
        ),
        child: const Text('open'),
      );
    })));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('UNHANG'), findsOneWidget);
    await tester.tap(find.text('UNHANG'));
    expect(removed, isTrue);
  });
}
