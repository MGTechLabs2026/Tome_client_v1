import 'package:build_engine/affix_plugin.dart';
import 'package:build_engine/almanac.dart';
import 'package:build_engine/build_engine.dart';
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

/// Like [_harness] but the reward pool is a single **technique**
/// (`basic_slash`) and no items, so every New Component offer resolves a
/// technique-domain affix — `heal` / `bank_progression`, never a
/// `WeaponStatBonus`. Lets a test drive the non-stat mechanic path.
({RewardAdapter reward, AlmanacSession almanac, EngineSession session})
    _techniqueHarness(int seed) {
  final session = EngineSession(seed);
  final cha = CharacterAdapter(session)..createCharacter('F');
  final almanac = AlmanacSession(GameStoreAlmanacRepository(GameStore.memory()));
  final reward = RewardAdapter(
    session,
    itemAdapter: ItemAdapter(session),
    characterAdapter: cha,
    tomeAdapter: TomeAdapter(session)..createInitialTome(),
    techniqueAdapter: TechniqueAdapter(session),
    itemPool: const [],
    techniquePool: const ['basic_slash'],
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

  // ---- spec §13 acceptance gap-fill ----

  test('same seed -> identical offered affix-slot ids; a different seed may '
      'differ', () {
    List<String?> offeredIds(int seed) {
      final h = _harness(seed);
      addTearDown(h.session.dispose);
      final out = <String?>[];
      for (var i = 0; i < 8; i++) {
        final card = _component(h.reward.offerLoot());
        out
          ..add(card.prefixAffixId)
          ..add(card.suffixAffixId);
        h.reward.applyLoot(LootKind.upgradePoints); // advance, don't take
      }
      return out;
    }

    expect(offeredIds(13), equals(offeredIds(13)),
        reason: 'engine affix selection is deterministic under RngService');
    expect(offeredIds(13), isNot(equals(offeredIds(999))),
        reason: 'the run seed actually drives the selection');
  });

  test('a technique reward heal affix restores vitality and is recorded', () {
    final h = _techniqueHarness(7);
    addTearDown(h.session.dispose);
    final ctx = h.session.context;
    // Wound the fighter so a heal is observable (harness starts 100/100).
    ctx.components.add(
      h.session.character,
      const HealthComponent(current: 40, max: 100),
    );

    String? healId;
    for (var i = 0; i < 60 && healId == null; i++) {
      final card = _component(h.reward.offerLoot());
      final ids = [card.prefixAffixId, card.suffixAffixId].whereType<String>();
      final heal = ids.firstWhere(
        (id) => affixDefinition(id, ctx).mechanic is ImmediateHeal,
        orElse: () => '',
      );
      if (heal.isNotEmpty) {
        h.reward.applyLoot(LootKind.newComponent);
        healId = heal;
      } else {
        h.reward.applyLoot(LootKind.upgradePoints);
      }
    }

    expect(healId, isNotNull,
        reason: 'a heal affix should turn up within 60 technique offers');
    expect(
      ctx.components.get<HealthComponent>(h.session.character)!.current,
      greaterThan(40),
      reason: 'the engine applied the heal on TAKE',
    );
    final rec = h.almanac.queries.getAffixHistory(healId!);
    expect(rec, isNotNull);
    expect(rec!.snapshot.stat, 'heal');
  });

  test('a technique reward bank affix adds upgrade points and is recorded', () {
    final h = _techniqueHarness(3);
    addTearDown(h.session.dispose);
    final ctx = h.session.context;
    final character = h.session.character;
    // Track the running total: every non-take iteration banks +1 via
    // applyLoot(upgradePoints), so the assertion stays exact whether the
    // taken card carries one bank slot or two.
    num expectedPoints =
        ctx.resources.currentOf(character, ItemResources.upgradePoints);

    String? bankId;
    for (var i = 0; i < 80 && bankId == null; i++) {
      final card = _component(h.reward.offerLoot());
      final ids =
          [card.prefixAffixId, card.suffixAffixId].whereType<String>().toList();
      final bankIds = ids
          .where((id) => affixDefinition(id, ctx).mechanic is BankProgression)
          .toList();
      if (bankIds.isNotEmpty) {
        for (final id in bankIds) {
          expectedPoints +=
              (affixDefinition(id, ctx).mechanic as BankProgression).amount;
        }
        bankId = bankIds.first;
        h.reward.applyLoot(LootKind.newComponent);
      } else {
        h.reward.applyLoot(LootKind.upgradePoints);
        expectedPoints += 1;
      }
    }

    expect(bankId, isNotNull,
        reason: 'a bank affix should turn up within 80 technique offers');
    expect(
      ctx.resources.currentOf(character, ItemResources.upgradePoints),
      expectedPoints,
      reason: 'upgrade points moved only via the bank affix + explicit banking',
    );
    expect(h.almanac.queries.getAffixHistory(bankId!)!.snapshot.stat,
        'bank_progression');
  });

  test('the recorded AffixSnapshot value equals the engine AffixDefinition '
      'amount', () {
    final h = _harness(13);
    addTearDown(h.session.dispose);
    final ctx = h.session.context;

    String? takenId;
    for (var i = 0; i < 40 && takenId == null; i++) {
      final card = _component(h.reward.offerLoot());
      final id = card.prefixAffixId ?? card.suffixAffixId;
      if (id != null) {
        h.reward.applyLoot(LootKind.newComponent);
        takenId = id;
      } else {
        h.reward.applyLoot(LootKind.upgradePoints);
      }
    }

    expect(takenId, isNotNull);
    final rec = h.almanac.queries.getAffixHistory(takenId!)!;
    expect(rec.snapshot.value, affixDefinition(takenId, ctx).mechanic.amount,
        reason: 'no client substitution — the value is the engine amount');
    expect(rec.snapshot.category, affixDefinition(takenId, ctx).category);
  });

  test('recorded affixEventId has the engine <runId>:affix:<pos>:<seq> shape',
      () {
    final h = _harness(13); // currentRun -> fixed (seed: 13, number: 1)
    addTearDown(h.session.dispose);

    String? takenId;
    for (var i = 0; i < 40 && takenId == null; i++) {
      final card = _component(h.reward.offerLoot());
      final id = card.prefixAffixId ?? card.suffixAffixId;
      if (id != null) {
        h.reward.applyLoot(LootKind.newComponent);
        takenId = id;
      } else {
        h.reward.applyLoot(LootKind.upgradePoints);
      }
    }

    expect(takenId, isNotNull);
    final obs = h.almanac.queries
        .getAffixHistory(takenId!)!
        .discoveryObservations
        .single;
    // engine format from AffixAcquisitionIdSource.next: '<runId>:affix:<pos>:<seq>'
    expect(obs.affixEventId, matches(RegExp(r'^13:1:affix:[01]:\d+$')));
    expect(obs.runId, '13:1');
    expect(obs.runNumber, 1);
    // not a client uuid / timestamp
    expect(obs.affixEventId, isNot(matches(RegExp(r'^[0-9a-f-]{36}$'))));
  });
}
