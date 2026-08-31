import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/models/seeded_random.dart';
import 'package:tome_client/features/training/exercise/target_strike_controller.dart';
import 'package:tome_client/features/training/exercise/training_target.dart';

/// A scripted, deterministic random — a fixed cycling sequence, so a
/// "seed" here is just this list.
class _ScriptedRandom implements SeededRandom {
  _ScriptedRandom(this._values);
  final List<double> _values;
  int _i = 0;
  double _next() => _values[_i++ % _values.length];
  @override
  double nextDouble() => _next();
  @override
  int nextInt(int max) => (_next() * max).floor() % max;
  @override
  double range(double min, double max) => min + _next() * (max - min);
}

List<double> _seq(int seed) {
  final r = math.Random(seed);
  return [for (var i = 0; i < 200; i++) r.nextDouble()];
}

TargetResolution _hit(TrainingTarget t, {double off = 0.0, int latency = 100}) =>
    TargetResolution(
      target: t,
      tapX: t.x + off * t.radius,
      tapY: t.y,
      latencyMs: latency,
      timedOut: false,
    );

void main() {
  test('lays out exactly 3 waves of 3 targets', () {
    final c = TargetStrikeController(_ScriptedRandom(_seq(1)));
    expect(c.waves.length, 3);
    expect(c.waves.every((w) => w.length == 3), isTrue);
    expect(c.waves.expand((w) => w).length, TargetStrikeController.totalTargets);
  });

  test('target sequence is deterministic under a fixed seed', () {
    List<List<double>> layout(SeededRandom r) => [
          for (final w in TargetStrikeController(r).waves)
            for (final t in w) [t.x, t.y, t.radius, t.lifetimeMs.toDouble()],
        ];
    expect(layout(_ScriptedRandom(_seq(7))), equals(layout(_ScriptedRandom(_seq(7)))));
    expect(layout(_ScriptedRandom(_seq(7))),
        isNot(equals(layout(_ScriptedRandom(_seq(8))))));
  });

  test('every target sits in a fair region — inset from edges, no overlap, '
      'lifetime tightens per wave', () {
    for (final seed in [1, 2, 3, 9, 42]) {
      final c = TargetStrikeController(_ScriptedRandom(_seq(seed)));
      for (final wave in c.waves) {
        for (final t in wave) {
          expect(t.x - t.radius, greaterThanOrEqualTo(0.05));
          expect(t.x + t.radius, lessThanOrEqualTo(0.95));
          expect(t.y - t.radius, greaterThanOrEqualTo(0.05));
          expect(t.y + t.radius, lessThanOrEqualTo(0.95));
        }
        for (var i = 0; i < wave.length; i++) {
          for (var j = i + 1; j < wave.length; j++) {
            final d = math.sqrt(math.pow(wave[i].x - wave[j].x, 2) +
                math.pow(wave[i].y - wave[j].y, 2));
            expect(d, greaterThan(wave[i].radius + wave[j].radius),
                reason: 'seed $seed rings must not overlap');
          }
        }
      }
      expect(c.waves[0].first.lifetimeMs, greaterThan(c.waves[2].first.lifetimeMs));
    }
  });

  test('counts hits, perfect hits and misses; precision is the mean '
      'centre-closeness of landed strikes', () {
    final c = TargetStrikeController(_ScriptedRandom(_seq(3)));
    final all = c.waves.expand((w) => w).toList();
    c.resolve(_hit(all[0], off: 0.0)); // perfect
    c.resolve(_hit(all[1], off: 0.5)); // good
    c.resolve(_hit(all[2], off: 0.9)); // weak
    c.resolve(TargetResolution(
        target: all[3], tapX: all[3].x, tapY: all[3].y, latencyMs: 0, timedOut: true));
    for (final t in all.skip(4)) {
      c.resolve(_hit(t, off: 0.0));
    }

    final s = c.summary;
    expect(s.total, 9);
    expect(s.misses, 1);
    expect(s.perfect, 6); // all[0] + the five clean ones
    expect(s.hits, 8);
    expect(s.precision, greaterThan(0.0));
    expect(s.precision, lessThanOrEqualTo(1.0));
  });

  test('a carried initialPace scales the first wave directly — below 1 '
      'shortens it, above 1 lengthens it', () {
    const base0 = 1750;
    int firstWave(double pace) => TargetStrikeController(
          _ScriptedRandom(_seq(13)),
          initialPace: pace,
        ).wave(0).first.lifetimeMs;

    expect(firstWave(1.0), base0);
    expect(firstWave(0.8), lessThan(base0));
    expect(firstWave(1.4), greaterThan(base0));
    // clamped
    expect(firstWave(0.2), (base0 * 0.75).round());
    expect(firstWave(9.0), (base0 * 1.5).round());
  });

  test('the next wave adapts to how the last one went — a clean, fast wave '
      'shortens it; a missed wave lengthens it past the baseline', () {
    const baseWave1 = 1313; // _baseLifetimeMs[1]

    int wave1LifetimeAfter(void Function(TargetStrikeController) playWave0) {
      final c = TargetStrikeController(_ScriptedRandom(_seq(11)));
      playWave0(c);
      return c.wave(1).first.lifetimeMs;
    }

    final afterClean = wave1LifetimeAfter((c) {
      for (final t in c.wave(0)) {
        c.resolve(_hit(t, off: 0.0, latency: 90));
      }
    });
    final afterMissed = wave1LifetimeAfter((c) {
      for (final t in c.wave(0)) {
        c.resolve(TargetResolution(
            target: t, tapX: t.x, tapY: t.y, latencyMs: 0, timedOut: true));
      }
    });

    expect(afterClean, lessThan(baseWave1), reason: 'reward -> tighter window');
    expect(afterMissed, greaterThan(baseWave1), reason: 'struggle -> more time');
    expect(afterMissed, greaterThan(afterClean));
  });

  test('one measurement bag per resolved target, carrying Precision + '
      'Reaction keys; a timeout writes a far miss', () {
    final c = TargetStrikeController(_ScriptedRandom(_seq(5)));
    final all = c.waves.expand((w) => w).toList();
    c.resolve(_hit(all[0], off: 0.1, latency: 140));
    c.resolve(TargetResolution(
        target: all[1], tapX: all[1].x, tapY: all[1].y, latencyMs: 0, timedOut: true));

    final bags = c.attemptMeasurements;
    expect(bags.length, 2);
    for (final b in bags) {
      expect(b.keys, containsAll(<String>[
        'targetX', 'targetY', 'actionX', 'actionY', 'tolerance',
        'signalTimestamp', 'responseTimestamp', 'maxAcceptable',
      ]));
    }
    // timeout bag: action far outside tolerance, response at the deadline
    final miss = bags[1];
    final dx = miss['actionX']! - miss['targetX']!;
    expect(dx.abs(), greaterThan(miss['tolerance']!));
    expect(miss['responseTimestamp'], miss['maxAcceptable']);
  });
}
