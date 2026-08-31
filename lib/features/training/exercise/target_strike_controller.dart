// lib/features/training/exercise/target_strike_controller.dart
import 'dart:math' as math;

import '../../../core/models/seeded_random.dart';
import 'training_target.dart';

/// A compact read of how a whole session went — the numbers the result
/// screen shows. Derived purely from the resolutions; the engine's
/// returned gain / evolution stay the source of truth for progression.
class TrainingRunSummary {
  const TrainingRunSummary({
    required this.total,
    required this.hits,
    required this.perfect,
    required this.good,
    required this.weak,
    required this.misses,
    required this.avgReactionMs,
    required this.precision,
  });

  final int total;
  final int hits;
  final int perfect;
  final int good;
  final int weak;
  final int misses;

  /// Mean latency over landed strikes, ms (0 if none landed).
  final int avgReactionMs;

  /// Mean centre-closeness over landed strikes, 0..1.
  final double precision;

  static const empty = TrainingRunSummary(
    total: 0,
    hits: 0,
    perfect: 0,
    good: 0,
    weak: 0,
    misses: 0,
    avgReactionMs: 0,
    precision: 0,
  );
}

/// The pure exercise logic for V1 — timer-free and seed-deterministic.
///
/// * lays out 3 waves x 3 targets in a safe region of normalized field
///   space, drawn from [rng] (so a run/test seed fixes the sequence);
/// * accepts one [TargetResolution] per target (a real strike or a
///   timeout);
/// * builds the [TrainingAttempt] list carrying **both** the engine's
///   PrecisionExercise keys (`targetX/Y`, `actionX/Y`, `tolerance`) and
///   ReactionExercise keys (`signalTimestamp`, `responseTimestamp`,
///   `maxAcceptable`);
/// * computes a [TrainingRunSummary] for display.
///
/// The widget layer owns real timing, input and animation and feeds
/// resolutions in; nothing here touches a `Timer` or the clock.
class TargetStrikeController {
  TargetStrikeController(SeededRandom rng) : waves = _layout(rng);

  static const waveCount = 3;
  static const perWave = 3;
  static const totalTargets = waveCount * perWave;

  /// Per-wave difficulty: target lifetime shortens, radius tightens.
  static const _lifetimeMs = [1400, 1050, 820];
  static const _radius = [0.095, 0.085, 0.075];

  /// Targets kept this far in from every field edge (normalized).
  static const _inset = 0.13;

  final List<List<TrainingTarget>> waves;
  final List<TargetResolution> _resolved = [];

  List<TargetResolution> get resolutions => List.unmodifiable(_resolved);
  bool get isComplete => _resolved.length >= totalTargets;

  void resolve(TargetResolution resolution) {
    if (isComplete) return;
    _resolved.add(resolution);
  }

  // ── layout ────────────────────────────────────────────────────────

  static List<List<TrainingTarget>> _layout(SeededRandom rng) {
    var index = 0;
    return [
      for (var w = 0; w < waveCount; w++)
        _wave(rng, w, () => index++),
    ];
  }

  static List<TrainingTarget> _wave(SeededRandom rng, int w, int Function() next) {
    final r = _radius[w];
    // Usable centre-box for this wave's radius.
    final lo = _inset + r;
    final hi = 1 - _inset - r;
    final minSep = r * 2.6; // no two rings crowd or overlap
    final placed = <math.Point<double>>[];

    math.Point<double> pick() {
      for (var attempt = 0; attempt < 40; attempt++) {
        final p = math.Point(rng.range(lo, hi), rng.range(lo, hi));
        if (placed.every((q) => _dist(p, q) >= minSep)) return p;
      }
      // Deterministic fallback: step around a ring until it clears.
      for (var k = 0; k < 12; k++) {
        final a = k * (math.pi / 6);
        final p = math.Point(
          (0.5 + math.cos(a) * (hi - lo) * 0.42).clamp(lo, hi),
          (0.5 + math.sin(a) * (hi - lo) * 0.42).clamp(lo, hi),
        );
        if (placed.every((q) => _dist(p, q) >= minSep * 0.85)) return p;
      }
      return math.Point(rng.range(lo, hi), rng.range(lo, hi));
    }

    return [
      for (var i = 0; i < perWave; i++)
        () {
          final p = pick();
          placed.add(p);
          return TrainingTarget(
            wave: w,
            index: next(),
            x: p.x,
            y: p.y,
            radius: r,
            lifetimeMs: _lifetimeMs[w],
          );
        }(),
    ];
  }

  static double _dist(math.Point<double> a, math.Point<double> b) {
    final dx = a.x - b.x, dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  // ── engine handoff ───────────────────────────────────────────────

  /// One measurement bag per resolved target, carrying every key the
  /// composed PrecisionExercise + ReactionExercise read. `TrainingBloc`
  /// (the one file cleared to touch `build_engine` types outside
  /// `core/engine/`) wraps each in a `TrainingAttempt`.
  List<Map<String, double>> get attemptMeasurements => [
        for (final res in _resolved)
          {
            // PrecisionExercise
            'targetX': res.target.x,
            'targetY': res.target.y,
            'actionX': res.timedOut
                ? res.target.x + res.target.radius * 3
                : res.tapX,
            'actionY': res.timedOut ? res.target.y : res.tapY,
            'tolerance': res.target.radius,
            // ReactionExercise
            'signalTimestamp': 0.0,
            'responseTimestamp': res.timedOut
                ? res.target.lifetimeMs.toDouble()
                : res.latencyMs.toDouble(),
            'maxAcceptable': res.target.lifetimeMs.toDouble(),
          },
      ];

  TrainingRunSummary get summary {
    if (_resolved.isEmpty) return TrainingRunSummary.empty;
    var perfect = 0, good = 0, weak = 0, misses = 0;
    final latencies = <int>[];
    final closeness = <double>[];
    for (final res in _resolved) {
      switch (res.quality) {
        case StrikeQuality.perfect:
          perfect++;
        case StrikeQuality.good:
          good++;
        case StrikeQuality.weak:
          weak++;
        case StrikeQuality.miss:
          misses++;
      }
      if (res.quality.isHit) {
        latencies.add(res.latencyMs);
        closeness.add((1 - res.offCentre).clamp(0.0, 1.0));
      }
    }
    final hits = perfect + good + weak;
    return TrainingRunSummary(
      total: _resolved.length,
      hits: hits,
      perfect: perfect,
      good: good,
      weak: weak,
      misses: misses,
      avgReactionMs: latencies.isEmpty
          ? 0
          : (latencies.reduce((a, b) => a + b) / latencies.length).round(),
      precision: closeness.isEmpty
          ? 0
          : closeness.reduce((a, b) => a + b) / closeness.length,
    );
  }
}
