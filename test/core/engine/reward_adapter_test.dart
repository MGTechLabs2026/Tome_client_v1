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
    final cha = CharacterAdapter(session)..createCharacter('Test Fighter');
    tomeAdapter = TomeAdapter(session)..createInitialTome();
    rewardAdapter = RewardAdapter(
      session,
      characterAdapter: cha,
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

  test('a stat-bump affix on a taken New Component reaches the sword', () {
    final s = EngineSession(13);
    final cha = CharacterAdapter(s)..createCharacter('F');
    final ra = RewardAdapter(
      s,
      characterAdapter: cha,
      tomeAdapter: TomeAdapter(s)..createInitialTome(),
      techniqueAdapter: TechniqueAdapter(s),
      itemPool: const [ItemIds.ironSword],
      techniquePool: const [],
    );

    // Roll until a card with a "bite +N" (statUp) affix comes up, take it.
    var took = false;
    for (var i = 0; i < 40 && !took; i++) {
      final card =
          ra.offerLoot().firstWhere((o) => o.kind == LootKind.newComponent);
      expect(card.badge, 'CLASS I');
      if (card.effects.any((e) => e.contains('bite +'))) {
        ra.applyLoot(LootKind.newComponent);
        took = true;
      } else {
        ra.applyLoot(LootKind.upgradePoints);
      }
    }
    expect(took, isTrue);

    // iron_sword isn't hung, so any 'blade' modifier now is the affix's.
    final mods = s.context.modifiers
        .activeModifiersFor(s.character, 'blade', s.context.components);
    expect(mods, isNotEmpty, reason: 'the roll bumps the sword\'s bite');
  });

  test('some New Component cards roll plain — no affix at all', () {
    final s = EngineSession(9);
    final cha = CharacterAdapter(s)..createCharacter('F');
    final ra = RewardAdapter(
      s,
      characterAdapter: cha,
      tomeAdapter: TomeAdapter(s)..createInitialTome(),
      techniqueAdapter: TechniqueAdapter(s),
      itemPool: const [ItemIds.ironSword],
      techniquePool: const [],
    );

    var sawPlain = false;
    for (var i = 0; i < 60 && !sawPlain; i++) {
      final card =
          ra.offerLoot().firstWhere((o) => o.kind == LootKind.newComponent);
      // plain = title is exactly the bare name, effects say so
      if (card.title == 'Iron Sword') {
        expect(card.effects, ['plain — no bonuses rolled']);
        sawPlain = true;
      }
      ra.applyLoot(LootKind.upgradePoints);
    }
    expect(sawPlain, isTrue,
        reason: 'an unadorned Iron Sword should turn up within 60 rolls');
  });

  test('the New Component draws with replacement — a duplicate can be '
      'farmed for Combine', () {
    final s = EngineSession(13);
    final cha = CharacterAdapter(s)..createCharacter('F');
    final item = ItemAdapter(s);
    final ra = RewardAdapter(
      s,
      characterAdapter: cha,
      tomeAdapter: TomeAdapter(s)..createInitialTome(),
      techniqueAdapter: TechniqueAdapter(s),
      itemPool: const [ItemIds.ironSword], // a one-item pool: every draw repeats
      techniquePool: const [],
    );

    for (var i = 0; i < 2; i++) {
      ra.offerLoot();
      ra.applyLoot(LootKind.newComponent);
    }

    final swords = item
        .ownedItems()
        .where((v) => v.definitionId == ItemIds.ironSword)
        .toList();
    expect(swords, hasLength(2), reason: 'two owned instances of the same id');
    expect(swords.first.combinableWith, isNotEmpty,
        reason: 'the pair is Combine-eligible');
  });

  test('techniques are in the New Component rotation from the start', () {
    final s = EngineSession(5);
    final cha = CharacterAdapter(s)..createCharacter('F');
    final ra = RewardAdapter(
      s,
      characterAdapter: cha,
      tomeAdapter: TomeAdapter(s)..createInitialTome(),
      techniqueAdapter: TechniqueAdapter(s),
      itemPool: const [ItemIds.ironSword, ItemIds.gloves],
      techniquePool: const ['basic_slash', 'basic_guard'],
    );

    final techniqueIds = {'basic_slash', 'basic_guard'};
    var sawTechnique = false;
    for (var screen = 0; screen < 30 && !sawTechnique; screen++) {
      final title = ra
          .offerLoot()
          .firstWhere((o) => o.kind == LootKind.newComponent)
          .title;
      // technique detail is the technique's display name, not an item id.
      sawTechnique = techniqueIds.any((id) =>
          title.toLowerCase().replaceAll(' ', '_').contains(id));
      ra.applyLoot(LootKind.upgradePoints);
    }
    expect(sawTechnique, isTrue,
        reason: 'a technique should surface within 30 loot screens');
  });

  test('a technique already on the roster is not offered again', () {
    final s = EngineSession(3);
    final cha = CharacterAdapter(s)..createCharacter('F');
    final techniques = TechniqueAdapter(s);
    final ra = RewardAdapter(
      s,
      characterAdapter: cha,
      tomeAdapter: TomeAdapter(s)..createInitialTome(),
      techniqueAdapter: techniques,
      itemPool: const [ItemIds.ironSword],
      techniquePool: const ['basic_slash'],
    );

    // Grant basic_slash once.
    var got = false;
    for (var i = 0; i < 50 && !got; i++) {
      final next = ra.offerLoot().firstWhere((o) => o.kind == LootKind.newComponent);
      if (next.title.toLowerCase().contains('slash')) {
        ra.applyLoot(LootKind.newComponent);
        got = true;
      } else {
        ra.applyLoot(LootKind.upgradePoints);
      }
    }
    expect(got, isTrue);
    expect(techniques.isOnRoster('basic_slash'), isTrue);

    // From here it should never be offered again — only the item comes up.
    for (var i = 0; i < 40; i++) {
      final d = ra.offerLoot().firstWhere((o) => o.kind == LootKind.newComponent)
          .title;
      expect(d.toLowerCase().contains('slash'), isFalse,
          reason: 'basic_slash must not be re-offered');
      ra.applyLoot(LootKind.upgradePoints);
    }
  });

  test('same seed -> same New Component sequence', () {
    List<String> seq(int seed) {
      final s = EngineSession(seed);
      final cha = CharacterAdapter(s)..createCharacter('F');
      final ra = RewardAdapter(
        s,
        characterAdapter: cha,
        tomeAdapter: TomeAdapter(s)..createInitialTome(),
        techniqueAdapter: TechniqueAdapter(s),
        itemPool: const [ItemIds.ironSword, ItemIds.gloves, ItemIds.trainingStaff],
        techniquePool: const ['basic_slash'],
      );
      return [
        for (var i = 0; i < 8; i++)
          () {
            final d = ra
                .offerLoot()
                .firstWhere((o) => o.kind == LootKind.newComponent)
          .title;
            ra.applyLoot(LootKind.upgradePoints);
            return d;
          }()
      ];
    }

    expect(seq(21), equals(seq(21)));
    final many = [for (var seed = 0; seed < 25; seed++) seq(seed).join('|')];
    expect(many.toSet().length, greaterThan(1),
        reason: 'different seeds diverge');
  });

  test('the New Component re-rolls every loot screen even when it is not '
      'taken', () {
    const pool = [
      ItemIds.ironSword,
      ItemIds.gloves,
      ItemIds.trainingStaff,
      ItemIds.clothArmor,
      ItemIds.trainingShoes,
    ];
    final s = EngineSession(4);
    final cha = CharacterAdapter(s)..createCharacter('F');
    final ra = RewardAdapter(
      s,
      characterAdapter: cha,
      tomeAdapter: TomeAdapter(s)..createInitialTome(),
      techniqueAdapter: TechniqueAdapter(s),
      itemPool: pool,
      techniquePool: const [],
    );

    final offered = <String>{};
    for (var screen = 0; screen < 12; screen++) {
      final component =
          ra.offerLoot().firstWhere((o) => o.kind == LootKind.newComponent);
      offered.add(component.title);
      // Bank a point instead of taking the component.
      ra.applyLoot(LootKind.upgradePoints);
    }

    expect(offered.length, greaterThan(1),
        reason: 'skipping the component must not freeze the offer');
    expect(
        offered.every((t) => pool.any(
            (id) => t.toLowerCase().replaceAll(' ', '_').contains(id))),
        isTrue);
  });
}
