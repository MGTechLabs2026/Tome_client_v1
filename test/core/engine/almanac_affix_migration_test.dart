import 'package:build_engine/almanac.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/almanac_session.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/persistence/game_store.dart';
import 'package:tome_client/core/persistence/game_store_almanac_repository.dart';

AffixObservation _obs({String runId = 'run-1', int runNumber = 1}) =>
    AffixObservation(affixEventId: '$runId:affix:0:0', runId: runId, runNumber: runNumber);

const _snap = AffixSnapshot(
    affixId: 'af_keen', stat: 'weapon_stat_bonus', value: 3, category: 'item_prefix');

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
}
