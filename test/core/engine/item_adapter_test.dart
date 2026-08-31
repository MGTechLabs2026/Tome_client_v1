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

  test('spendUpgradePoint consumes a banked point and buffs that copy', () {
    final knife = ownItem(session.character, ItemIds.knife, session.context);
    discoverItem(session.character,
        itemDefinition(ItemIds.knife, session.context), session.context);

    // Nothing banked yet.
    expect(itemAdapter.spendUpgradePoint(knife.value), isFalse);
    expect(itemAdapter.upgradePoints(), 0);

    session.context.resources
        .add(session.character, ItemResources.upgradePoints, 2);

    expect(itemAdapter.spendUpgradePoint(knife.value), isTrue);
    expect(itemAdapter.upgradePoints(), 1, reason: 'one point spent');
    expect(itemAdapter.viewOf(ItemIds.knife).upgradeCount, 1);

    // The +2 is bound to this copy (bites while hung), not a loose
    // character modifier.
    final bonuses =
        session.context.components.get<ItemInstance>(knife)!.statBonuses;
    expect(bonuses.values.fold<num>(0, (a, b) => a + b), 2,
        reason: '+2 on this copy');
  });

  test('a class-1 copy upgrades to +3, then hits its cap', () {
    final knife = ownItem(session.character, ItemIds.knife, session.context);
    discoverItem(session.character,
        itemDefinition(ItemIds.knife, session.context), session.context);
    session.context.resources
        .add(session.character, ItemResources.upgradePoints, 10);

    expect(itemAdapter.viewOf(ItemIds.knife).upgradeCap, 3,
        reason: 'class 1 -> 2*1 + 1');

    expect(itemAdapter.spendUpgradePoint(knife.value), isTrue); // +1
    expect(itemAdapter.spendUpgradePoint(knife.value), isTrue); // +2
    expect(itemAdapter.spendUpgradePoint(knife.value), isTrue); // +3
    expect(itemAdapter.spendUpgradePoint(knife.value), isFalse,
        reason: 'at the class cap');

    final view = itemAdapter.viewOf(ItemIds.knife);
    expect(view.upgradeCount, 3);
    expect(view.canUpgrade, isFalse);
    expect(itemAdapter.upgradePoints(), 7, reason: 'only 3 points spent');
  });

  test('upgrades are per copy — a second knife starts at +0 with its own cap',
      () {
    final a = ownItem(session.character, ItemIds.knife, session.context);
    final b = ownItem(session.character, ItemIds.knife, session.context);
    discoverItem(session.character,
        itemDefinition(ItemIds.knife, session.context), session.context);
    session.context.resources
        .add(session.character, ItemResources.upgradePoints, 10);

    expect(itemAdapter.spendUpgradePoint(a.value), isTrue);
    expect(itemAdapter.spendUpgradePoint(a.value), isTrue); // copy A at +2

    final views = itemAdapter.ownedItems();
    final viewA = views.firstWhere((v) => v.instanceEntityValue == a.value);
    final viewB = views.firstWhere((v) => v.instanceEntityValue == b.value);
    expect(viewA.upgradeCount, 2);
    expect(viewB.upgradeCount, 0, reason: 'the fresh copy is untouched');
    expect(viewB.canUpgrade, isTrue);
    expect(
        session.context.components
            .get<ItemInstance>(b)!
            .statBonuses
            .values
            .fold<num>(0, (x, y) => x + y),
        0,
        reason: "copy B carries none of A's upgrade");
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
