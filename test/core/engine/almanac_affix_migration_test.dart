import 'package:build_engine/almanac.dart';
import 'package:build_engine/item_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/almanac_session.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/item_adapter.dart';
import 'package:tome_client/core/engine/reward_adapter.dart';
import 'package:tome_client/core/engine/technique_adapter.dart';
import 'package:tome_client/core/engine/tome_adapter.dart';
import 'package:tome_client/core/models/loot_option_view.dart';
import 'package:tome_client/core/persistence/game_store.dart';
import 'package:tome_client/core/persistence/game_store_almanac_repository.dart';

AffixObservation _obs({String runId = 'run-1', int runNumber = 1}) =>
    AffixObservation(affixEventId: '$runId:affix:0:0', runId: runId, runNumber: runNumber);

const _snap = AffixSnapshot(
    affixId: 'af_keen', stat: 'weapon_stat_bonus', value: 3, category: 'item_prefix');

/// A real `RewardAdapter` over a real `AlmanacSession`, with an item-only
/// pool (`iron_sword` → every affix is a `WeaponStatBonus`) and a fixed
/// run identity, so acquisition ids are deterministic per run.
({RewardAdapter reward, AlmanacSession almanac, EngineSession session})
    _harness(int seed) {
  final session = EngineSession(seed);
  final cha = CharacterAdapter(session)..createCharacter('F');
  final almanac = AlmanacSession(GameStoreAlmanacRepository(GameStore.memory()));
  final reward = RewardAdapter(
    session,
    itemAdapter: ItemAdapter(session),
    characterAdapter: cha,
    tomeAdapter: TomeAdapter(session)..createInitialTome(),
    techniqueAdapter: TechniqueAdapter(session),
    itemPool: const [ItemIds.ironSword],
    techniquePool: const [],
    almanac: almanac,
    currentRun: () => (seed: 13, number: 1),
  );
  return (reward: reward, almanac: almanac, session: session);
}

LootOptionView _component(List<LootOptionView> offer) =>
    offer.firstWhere((o) => o.kind == LootKind.newComponent);

void main() {
  test('a recorded affix survives an AlmanacSession restart (persistence)', () {
    final store = GameStore.memory();

    final s1 = AlmanacSession(GameStoreAlmanacRepository(store));
    s1.recorder.recordAffixDiscovered(
      affixId: 'af_keen', observation: _obs(), snapshot: _snap,
      timestamp: DateTime.utc(2026),
    );
    s1.persist();

    final s2 = AlmanacSession(GameStoreAlmanacRepository(store));
    expect(s2.queries.getAffixHistory('af_keen'), isNotNull);
  });

  test('one AlmanacSession spans EngineSession rebuilds (service lifetime, '
      'NOT persistence)', () {
    // The same AlmanacSession object is reused while EngineSession is torn
    // down and rebuilt for the next run.
    final almanac = AlmanacSession(GameStoreAlmanacRepository(GameStore.memory()));

    var engine = EngineSession(1); // run 1
    almanac.recorder.recordAffixDiscovered(
      affixId: 'af_keen', observation: _obs(runId: 'run-1', runNumber: 1),
      snapshot: _snap, timestamp: DateTime.utc(2026),
    );
    engine.dispose();

    engine = EngineSession(2); // run 2 — fresh EngineSession
    addTearDown(engine.dispose);

    expect(almanac.queries.getAffixHistory('af_keen'), isNotNull,
        reason: 'run-1 history is still available after the EngineSession rebuild');
  });

  test('previewing an offer records nothing; TAKE records the acquired affix',
      () {
    final h = _harness(13);
    addTearDown(h.session.dispose);

    // Preview only — offerLoot + currentOffer are both pure w.r.t. the Almanac.
    for (var i = 0; i < 5; i++) {
      h.reward.offerLoot();
      h.reward.currentOffer();
      expect(h.almanac.recorder.state.affixes, isEmpty,
          reason: 'resolving an offer must never touch the Almanac');
    }

    // Now actually TAKE an affixed card.
    String? takenId;
    for (var i = 0; i < 40 && takenId == null; i++) {
      final card = _component(h.reward.offerLoot());
      final id = card.prefixAffixId ?? card.suffixAffixId;
      if (id != null) {
        takenId = id;
        h.reward.applyLoot(LootKind.newComponent);
      } else {
        h.reward.applyLoot(LootKind.upgradePoints);
      }
    }
    expect(takenId, isNotNull, reason: 'an affixed card within 40 offers');
    expect(h.almanac.queries.getAffixHistory(takenId!), isNotNull);
  });

  test('two genuine acquisitions of one affix -> one record, two distinct '
      'affixEventIds', () {
    final h = _harness(13);
    addTearDown(h.session.dispose);

    final takenCounts = <String, int>{};
    String? twice;
    for (var i = 0; i < 300 && twice == null; i++) {
      final card = _component(h.reward.offerLoot());
      final ids = [card.prefixAffixId, card.suffixAffixId].nonNulls.toList();
      if (ids.isEmpty) {
        h.reward.applyLoot(LootKind.upgradePoints);
        continue;
      }
      h.reward.applyLoot(LootKind.newComponent);
      for (final id in ids) {
        takenCounts[id] = (takenCounts[id] ?? 0) + 1;
        if (takenCounts[id] == 2) twice ??= id;
      }
    }
    expect(twice, isNotNull,
        reason: 'the same affix should recur across separate TAKE cycles');

    final records =
        h.almanac.recorder.state.affixes.where((a) => a.affixId == twice);
    expect(records, hasLength(1), reason: 'one canonical record per affixId');
    final observations = records.single.discoveryObservations;
    expect(observations, hasLength(2),
        reason: 'one discovery observation per genuine acquisition');
    expect(observations.map((o) => o.affixEventId).toSet(), hasLength(2),
        reason: 'the engine mints a distinct affixEventId per acquisition');
  });

  test('replaying an identical acquisition is idempotent', () {
    final h = _harness(13);
    addTearDown(h.session.dispose);

    String? takenId;
    for (var i = 0; i < 40 && takenId == null; i++) {
      final card = _component(h.reward.offerLoot());
      final id = card.prefixAffixId ?? card.suffixAffixId;
      if (id != null) {
        takenId = id;
        h.reward.applyLoot(LootKind.newComponent);
      } else {
        h.reward.applyLoot(LootKind.upgradePoints);
      }
    }
    expect(takenId, isNotNull);

    final record = h.almanac.queries.getAffixHistory(takenId!)!;
    final before = record.discoveryObservations.length;
    final last = record.discoveryObservations.last;
    final snapshot = record.snapshot;

    // Same (affixId, affixEventId) + the same snapshot: a replay, not a
    // second acquisition.
    h.almanac.recorder.recordAffixDiscovered(
      affixId: takenId,
      observation: AffixObservation(
        affixEventId: last.affixEventId,
        runId: last.runId,
        runNumber: last.runNumber,
      ),
      snapshot: snapshot,
      timestamp: DateTime.now(),
    );

    expect(h.almanac.queries.getAffixHistory(takenId)!.discoveryObservations,
        hasLength(before),
        reason: 'structural identity on (affixId, affixEventId) dedupes');
  });

  test('a card with both slots filled records both affixes', () {
    final h = _harness(7);
    addTearDown(h.session.dispose);

    String? prefixId;
    String? suffixId;
    for (var i = 0; i < 120 && prefixId == null; i++) {
      final card = _component(h.reward.offerLoot());
      if (card.prefixAffixId != null && card.suffixAffixId != null) {
        prefixId = card.prefixAffixId;
        suffixId = card.suffixAffixId;
        h.reward.applyLoot(LootKind.newComponent);
      } else {
        h.reward.applyLoot(LootKind.upgradePoints);
      }
    }
    expect(prefixId, isNotNull,
        reason: 'a prefix+suffix card should turn up within 120 offers');

    expect(h.almanac.queries.getAffixHistory(prefixId!), isNotNull);
    expect(h.almanac.queries.getAffixHistory(suffixId!), isNotNull);
  });
}
