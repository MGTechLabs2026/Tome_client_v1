import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/persistence/game_store.dart';
import 'package:tome_client/core/persistence/records_repository.dart';

void main() {
  test('starts empty', () {
    final r = RecordsRepository(GameStore.memory());
    expect(r.snapshot.isEmpty, isTrue);
  });

  test('clearing a run counts it and tracks furthest / longest', () async {
    final r = RecordsRepository(GameStore.memory());
    await r.recordRunCleared(runNumber: 1, bouts: 3);
    await r.recordRunCleared(runNumber: 2, bouts: 3);
    expect(r.snapshot.runsCleared, 2);
    expect(r.snapshot.furthestRun, 2);
    expect(r.snapshot.longestRunBouts, 3);
  });

  test('an ended run advances furthest without counting a clear', () async {
    final r = RecordsRepository(GameStore.memory());
    await r.recordRunEnded(runNumber: 5, bouts: 3);
    expect(r.snapshot.runsCleared, 0);
    expect(r.snapshot.furthestRun, 5);
  });

  test('heaviest blow only keeps the max', () async {
    final r = RecordsRepository(GameStore.memory());
    await r.recordBlow(7);
    await r.recordBlow(4);
    await r.recordBlow(11);
    expect(r.snapshot.heaviestBlow, 11);
  });

  test('persists through the store', () async {
    final store = GameStore.memory();
    await RecordsRepository(store).recordRunCleared(runNumber: 4, bouts: 5);
    final reloaded = RecordsRepository(store);
    expect(reloaded.snapshot.runsCleared, 1);
    expect(reloaded.snapshot.furthestRun, 4);
    expect(reloaded.snapshot.longestRunBouts, 5);
  });
}
