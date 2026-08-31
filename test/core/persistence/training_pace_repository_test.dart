import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/persistence/game_store.dart';
import 'package:tome_client/core/persistence/training_pace_repository.dart';

void main() {
  test('starts at the neutral baseline', () {
    expect(TrainingPaceRepository(GameStore.memory()).pace, 1.0);
  });

  test('a strong session drifts the pace down (toward challenge); a poor '
      'one drifts it up (toward mercy) — heavily smoothed', () {
    final r = TrainingPaceRepository(GameStore.memory());

    r.recordSession(1.0); // clean, fast, centred throughout
    final afterOneGood = r.pace;
    expect(afterOneGood, lessThan(1.0));
    expect(afterOneGood, greaterThan(kPaceMin));
    // one session can't slam it to the floor
    expect(afterOneGood, greaterThan(0.85));

    r.recordSession(0.0); // all misses
    expect(r.pace, greaterThan(afterOneGood));
  });

  test('clamped to the band even under a run of extreme sessions', () async {
    final r = TrainingPaceRepository(GameStore.memory());
    for (var i = 0; i < 20; i++) {
      await r.recordSession(1.0);
    }
    expect(r.pace, greaterThanOrEqualTo(kPaceMin));
    for (var i = 0; i < 20; i++) {
      await r.recordSession(0.0);
    }
    expect(r.pace, lessThanOrEqualTo(kPaceMax));
  });

  test('persists across a fresh repository over the same store', () async {
    final store = GameStore.memory();
    await TrainingPaceRepository(store).recordSession(0.95);
    final reloaded = TrainingPaceRepository(store);
    expect(reloaded.pace, lessThan(1.0));
  });
}
