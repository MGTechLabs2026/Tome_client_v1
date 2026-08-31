// Persistence-seam contracts (Platform Readiness V1, Task 30).
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/persistence/game_store.dart';

class _FakeTransport implements GameStoreTransport {
  _FakeTransport({this.seed = const {}, this.failLoad = false, this.failSave = false});
  final Map<String, Map<String, Object?>> seed;
  bool failLoad;
  bool failSave;
  final saved = <String, Map<String, Object?>>{};

  @override
  Future<Map<String, Map<String, Object?>>> loadAll() async {
    if (failLoad) throw StateError('backend unavailable');
    return {for (final e in seed.entries) e.key: Map.of(e.value)};
  }

  @override
  Future<void> save(String key, Map<String, Object?> value) async {
    if (failSave) throw StateError('write rejected');
    saved[key] = Map.of(value);
  }
}

void main() {
  group('GameStore.memory', () {
    test('round-trips a document and isolates callers from internal state', () {
      final s = GameStore.memory();
      s.write('records.v1', {'furthestRun': 3});
      expect(s.read('records.v1'), {'furthestRun': 3});
      // read returns a copy — mutating it doesn't corrupt the store
      s.read('records.v1')['furthestRun'] = 99;
      expect(s.read('records.v1'), {'furthestRun': 3});
    });

    test('an unknown key reads as an empty map', () {
      expect(GameStore.memory().read('nope'), isEmpty);
    });
  });

  group('RemoteGameStore', () {
    test('hydrates from the transport, then serves reads from cache', () async {
      final t = _FakeTransport(seed: {
        'records.v1': {'furthestRun': 7},
        'codex.v1': {'items': ['knife']},
      });
      final s = RemoteGameStore(t);
      await s.hydrate();

      expect(s.read('records.v1'), {'furthestRun': 7});
      expect(s.read('codex.v1'), {'items': ['knife']});
      expect(s.read('settings.v1'), isEmpty);
    });

    test('write updates the cache immediately and flushes through the '
        'transport', () async {
      final t = _FakeTransport();
      final s = RemoteGameStore(t);
      await s.hydrate();

      await s.write('records.v1', {'furthestRun': 2});
      expect(s.read('records.v1'), {'furthestRun': 2}); // cache
      expect(t.saved['records.v1'], {'furthestRun': 2}); // flushed
    });

    test('a hydrate failure is swallowed — the game starts from an empty '
        'cache and writes still try', () async {
      final t = _FakeTransport(failLoad: true);
      final s = RemoteGameStore(t);
      await s.hydrate(); // must not throw
      expect(s.read('records.v1'), isEmpty);

      await s.write('records.v1', {'furthestRun': 1}); // must not throw
      expect(s.read('records.v1'), {'furthestRun': 1});
      expect(t.saved['records.v1'], {'furthestRun': 1});
    });

    test('a save failure is swallowed but the local cache still reflects '
        'the write', () async {
      final t = _FakeTransport(failSave: true);
      final s = RemoteGameStore(t);
      await s.hydrate();

      await s.write('records.v1', {'furthestRun': 5}); // must not throw
      expect(s.read('records.v1'), {'furthestRun': 5});
      expect(t.saved, isEmpty);
    });
  });
}
