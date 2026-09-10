import 'dart:async';

import 'package:build_engine/almanac.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/persistence/game_store.dart';
import 'package:tome_client/core/persistence/game_store_almanac_repository.dart';

/// Mimics RemoteGameStore's shape: read() serves an in-memory cache
/// synchronously; write() copies into a shared "server" map through an
/// async transport and completes `lastWrite` so tests observe completion
/// deterministically — no Future.delayed, no sleeps, no polling. Does NOT
/// change the production GameStore contract; it only adds an observable
/// signal on this test double.
class _TestRemoteStore implements GameStore {
  _TestRemoteStore(this._server);
  final Map<String, Map<String, Object?>> _server;
  Completer<void> _last = Completer<void>()..complete();

  Future<void> get lastWrite => _last.future;

  @override
  Map<String, Object?> read(String key) =>
      _server[key] == null ? <String, Object?>{} : Map<String, Object?>.of(_server[key]!);

  @override
  Future<void> write(String key, Map<String, Object?> value) {
    _last = Completer<void>();
    Future<void>.microtask(() {
      _server[key] = Map<String, Object?>.of(value);
      _last.complete();
    });
    return _last.future;
  }
}

const _obs = AffixObservation(affixEventId: 'evt-1', runId: 'run-1', runNumber: 1);
const _snap = AffixSnapshot(affixId: 'af_keen', stat: 'weapon_stat_bonus', value: 3, category: 'item_prefix');

void main() {
  test('empty store loads AlmanacState.empty()', () {
    expect(GameStoreAlmanacRepository(GameStore.memory()).load(), AlmanacState.empty());
  });

  test('unparseable document degrades to AlmanacState.empty()', () async {
    final store = GameStore.memory();
    await store.write('almanac.v1', {'affixes': 'not-a-list'});
    expect(GameStoreAlmanacRepository(store).load(), AlmanacState.empty());
  });

  test('save then load round-trips an affix record through JSON', () {
    final store = GameStore.memory();
    final a = GameStoreAlmanacRepository(store);
    final recorder = AlmanacRecorder(a.load())
      ..recordAffixDiscovered(
        affixId: 'af_keen', observation: _obs, snapshot: _snap,
        timestamp: DateTime.utc(2026),
      );
    a.save(recorder.state);

    final reloaded = GameStoreAlmanacRepository(store).load();
    expect(reloaded.affixes.single.affixId, 'af_keen');
    expect(reloaded.affixes.single.snapshot.value, 3);
  });

  test('transport-agnostic: history survives across sessions over a '
      'remote-style store, waiting on an explicit write-completion signal', () async {
    final server = <String, Map<String, Object?>>{};
    final s1store = _TestRemoteStore(server);

    final s1 = GameStoreAlmanacRepository(s1store);
    final rec = AlmanacRecorder(s1.load())
      ..recordAffixDiscovered(
        affixId: 'af_keen', observation: _obs, snapshot: _snap,
        timestamp: DateTime.utc(2026),
      );
    s1.save(rec.state);
    await s1store.lastWrite; // deterministic completion — no timing tricks

    final s2 = GameStoreAlmanacRepository(_TestRemoteStore(server));
    expect(s2.load().affixes.map((x) => x.affixId), contains('af_keen'));
  });
}
