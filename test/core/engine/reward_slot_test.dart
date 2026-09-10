// Fixed three-slot reward rotation: progression / (tome slot ↔ consumable)
// / (item ↔ technique). See docs — this file covers the slot structure,
// Slot-2 rotation, and consumable TAKE. Affix behaviour lives in
// reward_adapter_test.dart / almanac_affix_migration_test.dart.
import 'package:build_engine/build_engine.dart';
import 'package:build_engine/consumable_plugin.dart';
import 'package:build_engine/item_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/item_adapter.dart';
import 'package:tome_client/core/engine/reward_adapter.dart';
import 'package:tome_client/core/engine/technique_adapter.dart';
import 'package:tome_client/core/engine/tome_adapter.dart';
import 'package:tome_client/core/models/loot_option_view.dart';

({RewardAdapter reward, TomeAdapter tome, EngineSession session}) _harness(
  int seed, {
  List<String> itemPool = const [ItemIds.ironSword],
  List<String> techniquePool = const ['basic_slash'],
}) {
  final session = EngineSession(seed);
  final cha = CharacterAdapter(session)..createCharacter('F');
  final tome = TomeAdapter(session)..createInitialTome();
  final reward = RewardAdapter(
    session,
    itemAdapter: ItemAdapter(session),
    characterAdapter: cha,
    tomeAdapter: tome,
    techniqueAdapter: TechniqueAdapter(session),
    itemPool: itemPool,
    techniquePool: techniquePool,
  );
  return (reward: reward, tome: tome, session: session);
}

List<BuildComponentRef> _tomeRefs(EngineSession s) => [
      for (final p in s.context.tome.inspect(s.character)) p.buildComponentRef,
    ];

void main() {
  group('reward structure', () {
    test('every offer is exactly 3 cards in the fixed slot order', () {
      final h = _harness(13);
      addTearDown(h.session.dispose);

      for (var i = 0; i < 12; i++) {
        final o = h.reward.offerLoot();
        expect(o, hasLength(3));

        // Slot 1 — always Upgrade Point.
        expect(o[0].kind, LootKind.upgradePoints);
        expect(o[0].contentKind, RewardContentKind.upgradePoint);

        // Slot 2 — Tome Slot OR Consumable, never a component.
        expect(o[1].kind, LootKind.gridExpansion);
        expect(
          o[1].contentKind,
          anyOf(RewardContentKind.tomeSlot, RewardContentKind.consumable),
        );
        expect(o[1].contentKind, isNot(RewardContentKind.item));
        expect(o[1].contentKind, isNot(RewardContentKind.technique));

        // Slot 3 — Item OR Technique, never a consumable.
        expect(o[2].kind, LootKind.newComponent);
        expect(
          o[2].contentKind,
          anyOf(RewardContentKind.item, RewardContentKind.technique),
        );
        expect(o[2].contentKind, isNot(RewardContentKind.consumable));

        h.reward.applyLoot(LootKind.upgradePoints); // advance the RNG
      }
    });
  });

  group('Slot 2 rotation (tome slot ↔ consumable)', () {
    List<RewardContentKind> slot2Sequence(int seed, {int n = 24}) {
      final h = _harness(seed);
      addTearDown(h.session.dispose);
      return [
        for (var i = 0; i < n; i++)
          () {
            final kind = h.reward.offerLoot()[1].contentKind;
            h.reward.applyLoot(LootKind.upgradePoints);
            return kind;
          }(),
      ];
    }

    test('both reward families occur across a deterministic run', () {
      final seq = slot2Sequence(13);
      expect(seq, contains(RewardContentKind.tomeSlot));
      expect(seq, contains(RewardContentKind.consumable));
    });

    test('same seed -> identical Slot-2 sequence; a different seed may differ',
        () {
      expect(slot2Sequence(13), equals(slot2Sequence(13)));
      expect(slot2Sequence(13), isNot(equals(slot2Sequence(999))));
    });

    test('currentOffer() re-reads Slot 2 without consuming RNG', () {
      final h = _harness(7);
      addTearDown(h.session.dispose);

      final first = h.reward.offerLoot();
      for (var i = 0; i < 5; i++) {
        final again = h.reward.currentOffer();
        expect(again[1].contentKind, first[1].contentKind);
        expect(again[1].contentId, first[1].contentId);
        expect(again[1].effects, first[1].effects);
      }

      // No RNG consumed by the peeks: a fresh run driven the same way,
      // with currentOffer() interleaved, yields the same Slot-2 sequence.
      List<RewardContentKind> drive({required bool peek}) {
        final g = _harness(7);
        addTearDown(g.session.dispose);
        return [
          for (var i = 0; i < 6; i++)
            () {
              final k = g.reward.offerLoot()[1].contentKind;
              if (peek) {
                g.reward.currentOffer();
                g.reward.currentOffer();
              }
              g.reward.applyLoot(LootKind.upgradePoints);
              return k;
            }(),
        ];
      }

      expect(drive(peek: true), equals(drive(peek: false)));
    });

    test('the utility card never carries affix ids', () {
      final h = _harness(13);
      addTearDown(h.session.dispose);
      for (var i = 0; i < 12; i++) {
        final card = h.reward.offerLoot()[1];
        expect(card.prefixAffixId, isNull);
        expect(card.suffixAffixId, isNull);
        h.reward.applyLoot(LootKind.upgradePoints);
      }
    });
  });

  group('Slot 3 rotation (item ↔ technique)', () {
    test('both an item and a technique are offered across the progression', () {
      final h = _harness(9,
          itemPool: const [ItemIds.ironSword], techniquePool: const ['basic_slash']);
      addTearDown(h.session.dispose);
      final seen = <RewardContentKind>{};
      for (var i = 0; i < 40 && seen.length < 2; i++) {
        seen.add(h.reward.offerLoot()[2].contentKind);
        h.reward.applyLoot(LootKind.upgradePoints);
      }
      expect(seen, containsAll([
        RewardContentKind.item,
        RewardContentKind.technique,
      ]));
    });
  });

  group('consumable TAKE hangs it in the Tome', () {
    for (final id in const [
      ConsumableIds.healPotion,
      ConsumableIds.firebomb,
      ConsumableIds.powerTonic,
      ConsumableIds.cleanseTonic,
    ]) {
      test('$id is placed via consumableReferenceType, effect does not fire',
          () {
        final h = _harness(13);
        addTearDown(h.session.dispose);
        final ctx = h.session.context;

        // Re-roll the offer (no TAKE — that only advances the RNG) until
        // Slot 2 holds exactly this consumable.
        var took = false;
        for (var i = 0; i < 400 && !took; i++) {
          final card = h.reward.offerLoot()[1];
          if (card.contentKind == RewardContentKind.consumable &&
              card.contentId == id) {
            // Snapshot right before the TAKE so unrelated RNG churn above
            // doesn't muddy the "effect did not fire" assertions.
            final hpBefore = ctx.components
                .get<HealthComponent>(h.session.character)!
                .current;
            final pointsBefore = ctx.resources
                .currentOf(h.session.character, ItemResources.upgradePoints);

            h.reward.applyLoot(LootKind.gridExpansion);
            took = true;

            expect(
              ctx.components
                  .get<HealthComponent>(h.session.character)!
                  .current,
              hpBefore,
              reason: 'heal / attack did not fire on TAKE',
            );
            expect(
              ctx.resources
                  .currentOf(h.session.character, ItemResources.upgradePoints),
              pointsBefore,
              reason: 'no charge spent, no grant applied on TAKE',
            );
          }
        }
        expect(took, isTrue, reason: '$id should turn up within 400 offers');

        final refs = _tomeRefs(h.session);
        final placed = refs.where((r) =>
            r.referenceType == consumableReferenceType && r.contentId == id);
        expect(placed, isNotEmpty,
            reason: 'the consumable is hung in the Tome on TAKE');
      });
    }
  });

  group('Tome regression', () {
    test('a taken consumable rides the normal Tome representation', () {
      final h = _harness(13);
      addTearDown(h.session.dispose);

      // take a consumable
      for (var i = 0; i < 400; i++) {
        final card = h.reward.offerLoot()[1];
        if (card.contentKind == RewardContentKind.consumable) {
          h.reward.applyLoot(LootKind.gridExpansion);
          break;
        }
        h.reward.applyLoot(LootKind.newComponent);
      }

      // it surfaces through TomeAdapter.inspect() as a consumable occupant,
      // not classified as an item.
      final consumableCells = h.tome
          .inspect()
          .where((c) => c.occupant != null)
          .map((c) => c.occupant!)
          .where((o) => o.kind.name == 'consumable')
          .toList();
      expect(consumableCells, isNotEmpty);
      expect(consumableCells.first.instanceEntityValue, isNull,
          reason: 'a consumable has no per-copy instanced entity');
    });
  });
}
