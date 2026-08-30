// test/core/engine/reward_adapter_test.dart
import 'package:build_engine/item_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/item_adapter.dart';
import 'package:tome_client/core/engine/reward_adapter.dart';
import 'package:tome_client/core/engine/technique_adapter.dart';
import 'package:tome_client/core/engine/tome_adapter.dart';
import 'package:tome_client/core/models/loot_option_view.dart';

void main() {
  late EngineSession session;
  late TomeAdapter tomeAdapter;
  late RewardAdapter rewardAdapter;

  setUp(() {
    session = EngineSession(13);
    CharacterAdapter(session).createCharacter('Test Fighter');
    tomeAdapter = TomeAdapter(session)..createInitialTome();
    rewardAdapter = RewardAdapter(
      session,
      tomeAdapter: tomeAdapter,
      techniqueAdapter: TechniqueAdapter(session),
      itemPool: const [ItemIds.ironSword],
      techniquePool: const [],
    );
  });

  test('offerLoot always returns exactly 3 real options', () {
    final options = rewardAdapter.offerLoot();
    expect(options.length, 3);
    expect(options.map((o) => o.kind).toSet(), {
      LootKind.upgradePoints, LootKind.gridExpansion, LootKind.newComponent,
    });
  });

  test('applyLoot(upgradePoints) banks a real upgrade point resource', () {
    rewardAdapter.offerLoot();
    rewardAdapter.applyLoot(LootKind.upgradePoints);
    expect(session.context.resources.currentOf(session.character, ItemResources.upgradePoints), 1);
  });

  test('applyLoot(gridExpansion) grows the Tome via TomeAdapter', () {
    rewardAdapter.offerLoot();
    rewardAdapter.applyLoot(LootKind.gridExpansion);
    expect(tomeAdapter.width, 4);
  });

  test('applyLoot(newComponent) grants and owns the next pooled item', () {
    rewardAdapter.offerLoot();
    rewardAdapter.applyLoot(LootKind.newComponent);
    expect(ItemAdapter(session).ownedItems().map((v) => v.definitionId), contains(ItemIds.ironSword));
  });
}
