// lib/core/engine/target_strike_exercise.dart
import 'package:build_engine/build_engine.dart';

import '../models/seeded_random.dart';

/// The interactive target-strike exercise, expressed entirely as
/// composition of the engine's own pure exercises: it runs
/// [PrecisionExercise] (spatial — `actionX/Y` vs `targetX/Y` within
/// `tolerance`) and [ReactionExercise] (temporal — `responseTimestamp`
/// after `signalTimestamp` vs `maxAcceptable`) over the *same* attempt
/// list and unions their dimensions. No new evaluation maths, no
/// thresholds, no evolution logic — every `TrainingAttempt` this
/// receives simply carries both exercises' measurement keys.
///
/// Precision emits `accuracy` / `precision` / `control`; Reaction emits
/// `reaction` / `speed` / `consistency` — disjoint, so the merge is a
/// plain union.
class TargetStrikeExercise implements TrainingExercise {
  const TargetStrikeExercise();

  @override
  TrainingProfile evaluate(List<TrainingAttempt> attempts) {
    if (attempts.isEmpty) return const TrainingProfile({});
    const precision = PrecisionExercise();
    const reaction = ReactionExercise();
    return TrainingProfile({
      ...precision.evaluate(attempts).dimensions,
      ...reaction.evaluate(attempts).dimensions,
    });
  }
}

/// A [SeededRandom] backed by an engine [RngService] — the concrete
/// source the training exercise draws its wave layout from, so a run's
/// (or a test's) seed fixes the target sequence.
class EngineSeededRandom implements SeededRandom {
  const EngineSeededRandom(this._rng);

  final RngService _rng;

  @override
  double nextDouble() => _rng.nextDouble();

  @override
  int nextInt(int max) => _rng.nextInt(max);

  @override
  double range(double min, double max) => min + _rng.nextDouble() * (max - min);
}
