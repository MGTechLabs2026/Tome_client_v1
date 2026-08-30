import 'package:build_engine/item_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/item_adapter.dart';
import 'package:tome_client/core/models/combine_result_view.dart';
import 'package:tome_client/core/models/item_view.dart';

void main() {
  late EngineSession session;
  late ItemAdapter itemAdapter;

  setUp(() {
    session = EngineSession(7);
    CharacterAdapter(session).createCharacter('Test Fighter');
    itemAdapter = ItemAdapter(session);
  });

  test('an unowned item is not returned by ownedItems', () {
    expect(itemAdapter.ownedItems(), isEmpty);
  });

  test('owning and discovering the knife makes it usable (no mastery requirement)', () {
    ownItem(session.character, ItemIds.knife, session.context);
    discoverItem(session.character, itemDefinition(ItemIds.knife, session.context), session.context);

    final view = itemAdapter.viewOf(ItemIds.knife);
    expect(view.state, ItemDisplayState.usable);
  });

  test('owning cloth armor without training leaves it locked', () {
    ownItem(session.character, ItemIds.clothArmor, session.context);
    discoverItem(session.character, itemDefinition(ItemIds.clothArmor, session.context), session.context);

    final view = itemAdapter.viewOf(ItemIds.clothArmor);
    expect(view.state, ItemDisplayState.locked);
  });

  test('two owned same-class knives report each other as combinable', () {
    ownItem(session.character, ItemIds.knife, session.context);
    ownItem(session.character, ItemIds.knife, session.context);
    discoverItem(session.character, itemDefinition(ItemIds.knife, session.context), session.context);

    final views = itemAdapter.ownedItems();
    expect(views.length, 2);
    expect(views[0].combinableWith, [views[1].instanceEntityValue]);
    expect(views[1].combinableWith, [views[0].instanceEntityValue]);
  });

  test('spendUpgradePoint consumes a banked point and buffs the item stat', () {
    ownItem(session.character, ItemIds.knife, session.context);
    discoverItem(session.character,
        itemDefinition(ItemIds.knife, session.context), session.context);

    // Nothing banked yet.
    expect(itemAdapter.spendUpgradePoint(ItemIds.knife), isFalse);
    expect(itemAdapter.upgradePoints(), 0);

    session.context.resources
        .add(session.character, ItemResources.upgradePoints, 2);

    expect(itemAdapter.spendUpgradePoint(ItemIds.knife), isTrue);
    expect(itemAdapter.upgradePoints(), 1, reason: 'one point spent');

    final mods = session.context.modifiers.activeModifiersFor(
        session.character, 'blade', session.context.components);
    expect(mods.where((m) => m.value == 2), isNotEmpty,
        reason: '+2 to the blade stat');
  });

  test('combining two owned knives consumes one and derives a real outcome kind', () {
    ownItem(session.character, ItemIds.knife, session.context);
    ownItem(session.character, ItemIds.knife, session.context);
    discoverItem(session.character, itemDefinition(ItemIds.knife, session.context), session.context);
    // combineItems costs upgradePoints flat = the shared itemClass (1 here).
    session.context.resources.add(session.character, ItemResources.upgradePoints, 10);

    final before = itemAdapter.ownedItems();
    final instanceValues = before.map((v) => v.instanceEntityValue!).toList();

    final result = itemAdapter.combine(instanceValues);

    switch (result.kind) {
      case CombineResultKind.fail:
        expect(result.resultingDefinitionId, ItemIds.knife);
        expect(result.resultingItemClass, 1);
      case CombineResultKind.classUpgraded:
        expect(result.resultingDefinitionId, ItemIds.knife);
        expect(result.resultingItemClass, 2);
      case CombineResultKind.evolvedIntoNewItem:
        expect(result.resultingDefinitionId, isNot(ItemIds.knife));
        expect(result.resultingItemClass, 1);
    }

    // Only one instance survives Combine regardless of outcome — the
    // other input entity is always destroyed (see combineItems' destroy
    // loop, which runs unconditionally before the outcome switch).
    final after = itemAdapter.ownedItems();
    expect(after.length, 1);
    expect(after.single.definitionId, result.resultingDefinitionId);
    expect(after.single.itemClass, result.resultingItemClass);
  });
}
