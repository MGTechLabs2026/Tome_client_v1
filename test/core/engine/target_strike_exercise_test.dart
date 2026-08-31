import 'package:build_engine/build_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/target_strike_exercise.dart';

TrainingAttempt _a({
  double off = 0.0,
  double latency = 200,
  double tolerance = 0.09,
  double maxAcceptable = 1200,
}) =>
    TrainingAttempt({
      'targetX': 0.5,
      'targetY': 0.5,
      'actionX': 0.5 + off,
      'actionY': 0.5,
      'tolerance': tolerance,
      'signalTimestamp': 0.0,
      'responseTimestamp': latency,
      'maxAcceptable': maxAcceptable,
    });

void main() {
  test('empty attempts -> empty profile', () {
    expect(const TargetStrikeExercise().evaluate([]).dimensions, isEmpty);
  });

  test('merges PrecisionExercise + ReactionExercise dimensions', () {
    final p = const TargetStrikeExercise().evaluate([
      _a(off: 0.01, latency: 150),
      _a(off: 0.02, latency: 180),
      _a(off: 0.0, latency: 120),
    ]).dimensions;

    // Precision half
    expect(p.keys, containsAll(<String>['accuracy', 'precision', 'control']));
    // Reaction half
    expect(p.keys, containsAll(<String>['reaction', 'speed', 'consistency']));
    for (final v in p.values) {
      expect(v, inInclusiveRange(0.0, 1.0));
    }
  });

  test('is a pure function of the attempts (deterministic)', () {
    final attempts = [_a(off: 0.03, latency: 210), _a(off: 0.0, latency: 90)];
    expect(
      const TargetStrikeExercise().evaluate(attempts).dimensions,
      equals(const TargetStrikeExercise().evaluate(attempts).dimensions),
    );
  });

  test('dead-centre fast strikes score higher than off-centre slow ones', () {
    final good = const TargetStrikeExercise().evaluate(
        [for (var i = 0; i < 4; i++) _a(off: 0.0, latency: 90)]).dimensions;
    final poor = const TargetStrikeExercise().evaluate(
        [for (var i = 0; i < 4; i++) _a(off: 0.9, latency: 1100)]).dimensions;
    expect(good['accuracy']!, greaterThan(poor['accuracy']!));
    expect(good['reaction']!, greaterThan(poor['reaction']!));
  });
}
