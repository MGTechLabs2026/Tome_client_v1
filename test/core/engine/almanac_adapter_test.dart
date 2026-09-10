// AlmanacAdapter — the Almanac's engine boundary.
//
// These pin the redesign's core promise: the roster is *enumerated from
// the live engine content registry*, never a hand-maintained catalogue,
// and a style view carries only what the engine actually models (no
// archetype, no reconstructed specialty modifier).
import 'package:build_engine/almanac.dart';
import 'package:build_engine/martial_arts_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/almanac_adapter.dart';
import 'package:tome_client/core/engine/almanac_session.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/persistence/game_store.dart';
import 'package:tome_client/core/persistence/game_store_almanac_repository.dart';

void main() {
  late EngineSession session;
  setUp(() => session = EngineSession(1));

  AlmanacSnapshot snap() => AlmanacAdapter(session).snapshot();

  group('roster is enumerated from the engine, not hand-listed', () {
    test('items = every ContentDefinition tagged `item`', () {
      final engineIds =
          session.context.content.withTag('item').map((d) => d.id).toSet();
      final rosterIds = snap().items.map((i) => i.id).toSet();

      expect(rosterIds, engineIds);
      expect(rosterIds.length, greaterThan(20),
          reason: 'base forms + Combine grades should all be present');
    });

    test('techniques = every ContentDefinition tagged `technique`', () {
      final engineIds = session.context.content
          .withTag('technique')
          .map((d) => d.id)
          .toSet();
      final rosterIds = snap().techniques.map((t) => t.id).toSet();

      expect(rosterIds, engineIds);
      // evolved branches are in the roster now (were withheld before)
      expect(rosterIds, contains('light_punch'));
      expect(rosterIds, contains('heavy_punch'));
    });

    test('newly registered engine content appears with no adapter change',
        () {
      final before = snap().items.map((i) => i.id).toSet();
      expect(before, isNot(contains('almanac_probe_blade')));

      session.context.content.load(const {
        'id': 'almanac_probe_blade',
        'type': 'weapon',
        'tags': ['item', 'weapon', 'blade', 'aff:burst', 'rarity:common'],
        'properties': {'attack': 3},
      });

      final after = AlmanacAdapter(session).snapshot();
      expect(after.items.map((i) => i.id), contains('almanac_probe_blade'));
      final probe =
          after.items.firstWhere((i) => i.id == 'almanac_probe_blade');
      expect(probe.category, 'weapon');
      expect(probe.family, 'blade');
      expect(probe.properties, {'attack': 3});
    });
  });

  group('styles come from MartialArts vocabulary', () {
    test('exactly the six known style ids, western first', () {
      final ids = snap().styles.map((s) => s.id).toList();
      expect(ids, [
        ...stylesForTradition(MartialTraditions.western),
        ...stylesForTradition(MartialTraditions.eastern),
      ]);
    });

    test('tradition / specialties / aligned families are the engine values',
        () {
      for (final s in snap().styles) {
        expect(s.tradition, martialTraditionOf(s.id));
        expect(s.specialtyTags, MartialSpecs.byStyle[s.id] ?? const []);
        expect(
          s.alignedFamilies,
          (styleAlignedFamilies[s.id] ?? const <String>{}).toList()..sort(),
        );
      }
    });

    test('style honesty: every specialty is a raw `spec:*` engine tag, '
        'nothing numeric is reconstructed', () {
      for (final s in snap().styles) {
        for (final tag in s.specialtyTags) {
          expect(tag, startsWith('spec:'));
          expect(MartialSpecs.byStyle[s.id], contains(tag));
        }
      }
      // The view has no archetype and no modifier field — a style is
      // id + label + tradition + spec tags + aligned families, full stop.
      final polearming = snap().styles.firstWhere((s) => s.id == 'polearming');
      expect(polearming.label, 'Polearming');
      expect(polearming.tradition, 'western');
    });

    test('deterministic label handles camel-case ids', () {
      final taiChi = snap().styles.firstWhere((s) => s.id == 'taiChi');
      expect(taiChi.label, 'Tai Chi');
    });
  });

  group('known content detail is exposed faithfully', () {
    test('knife: category, properties, and Combine grade graph', () {
      final knife = snap().items.firstWhere((i) => i.id == 'knife');

      expect(knife.category, 'weapon');
      expect(knife.label, 'Knife');
      expect(knife.properties, {'attack': 2});
      expect(knife.maxClass, 3);
      expect(knife.classScalingPercent, 15);
      expect(
        knife.evolutionCandidates.map((e) => e.targetId).toSet(),
        {'sharp_knife', 'fast_knife'},
      );
      final precise = knife.evolutionCandidates
          .firstWhere((e) => e.targetId == 'sharp_knife');
      expect(precise.trainingTags, contains('precision'));
      expect(precise.targetLabel, 'Sharp Knife');
    });

    test('basic_punch: tier badge, damage property, evolution branches', () {
      final punch =
          snap().techniques.firstWhere((t) => t.id == 'basic_punch');

      expect(punch.label, 'Basic Punch');
      expect(punch.tier, 'basic');
      expect(punch.properties, {'damage': 6});
      expect(
        punch.evolutionCandidates.map((e) => e.targetId).toSet(),
        {'light_punch', 'heavy_punch', 'fast_punch', 'counter_punch'},
      );
    });

    test('every evolution target resolves to another roster entry '
        '(so the screen graph can recurse)', () {
      final s = snap();
      final itemIds = s.items.map((i) => i.id).toSet();
      for (final i in s.items) {
        for (final e in i.evolutionCandidates) {
          expect(itemIds, contains(e.targetId));
        }
      }
      final techIds = s.techniques.map((t) => t.id).toSet();
      for (final t in s.techniques) {
        for (final e in t.evolutionCandidates) {
          expect(techIds, contains(e.targetId));
        }
      }
    });

    test('reward-weighter / rarity tags are stripped from structural tags',
        () {
      for (final i in snap().items) {
        expect(i.tags, isNot(contains(anyElement(startsWith('aff:')))));
        expect(i.tags, isNot(contains(anyElement(startsWith('rarity:')))));
        expect(i.tags, isNot(contains('item')));
      }
    });
  });

  group('affixes: engine roster + Almanac discovery', () {
    test('roster is exactly the engine `affix`-tagged content (33)', () {
      final engineIds = session.context.content
          .withTag('affix').map((d) => d.id).toSet();
      final rosterIds = snap().affixes.map((a) => a.id).toSet();
      expect(rosterIds, engineIds);
      expect(rosterIds.length, 33);
    });

    test('with no AlmanacSession every affix reads locked, no stat/value', () {
      for (final a in snap().affixes) {
        expect(a.discovered, isFalse);
        expect(a.stat, isNull);
        expect(a.value, isNull);
        expect(a.category, isNotEmpty); // structural axis always present
      }
    });

    test('a recorded affix reads discovered with its snapshot stat/value', () {
      final almanac = AlmanacSession(GameStoreAlmanacRepository(GameStore.memory()));
      almanac.recorder.recordAffixDiscovered(
        affixId: 'af_keen',
        observation: const AffixObservation(
            affixEventId: '13:1:affix:0:0', runId: '13:1', runNumber: 1),
        snapshot: const AffixSnapshot(
            affixId: 'af_keen', stat: 'weapon_stat_bonus', value: 3,
            category: 'item_prefix'),
        timestamp: DateTime.utc(2026),
      );

      final affixes = AlmanacAdapter(session, almanac: almanac).snapshot().affixes;
      final keen = affixes.firstWhere((a) => a.id == 'af_keen');
      expect(keen.discovered, isTrue);
      expect(keen.label, 'Keen');
      expect(keen.category, 'item_prefix');
      expect(keen.stat, 'weapon_stat_bonus');
      expect(keen.value, 3);

      // a sibling affix that was not recorded stays locked
      final other = affixes.firstWhere((a) => a.id != 'af_keen' && !a.discovered);
      expect(other.stat, isNull);
    });

    test('snapshot.total includes the affix roster', () {
      final s = snap();
      expect(s.total,
          s.styles.length + s.items.length + s.techniques.length + s.affixes.length);
    });
  });
}
