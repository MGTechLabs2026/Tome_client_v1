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
  TargetStrikeController(this._rng, {double initialPace = 1.0})
      : _initialPace = initialPace.clamp(_minPace, _maxPace).toDouble();

  final SeededRandom _rng;

  /// The multiplier this session starts from — the player's persisted
  /// skill (see `TrainingPaceRepository`). Wave 1 runs at exactly this;
  /// later waves blend it with how *this* session is going, so an
  /// experienced player stays challenged and a slow-device player who
  /// keeps struggling keeps their extra time.
  final double _initialPace;

  static const waveCount = 3;
  static const perWave = 3;
  static const totalTargets = waveCount * perWave;

  /// Per-wave baseline: target lifetime shortens, radius tightens. The
  /// lifetime is then scaled per wave by [_effectivePace].
  static const _baseLifetimeMs = [1750, 1313, 1025];
  static const _radius = [0.095, 0.085, 0.075];

  /// Adaptive lifetime is clamped to this band around the baseline.
  static const _minPace = 0.75; // sharpest: 25% shorter
  static const _maxPace = 1.5; // gentlest: 50% longer

  /// Targets kept this far in from every field edge (normalized).
  static const _inset = 0.13;

  final List<List<TrainingTarget>?> _waveCache =
      List<List<TrainingTarget>?>.filled(waveCount, null);
  final List<TargetResolution> _resolved = [];

  List<TargetResolution> get resolutions => List.unmodifiable(_resolved);
  bool get isComplete => _resolved.length >= totalTargets;

  void resolve(TargetResolution resolution) {
    if (isComplete) return;
    _resolved.add(resolution);
  }

  /// The [index]th wave, generated on first access so its lifetime can
  /// react to everything resolved before it. Cached — a wave's layout
  /// never changes once shown.
  List<TrainingTarget> wave(int index) =>
      _waveCache[index] ??= _wave(index, _lifetimeFor(index));

  /// All three waves. Forces generation; used where no adaptation has
  /// happened yet (tests, previews).
  List<List<TrainingTarget>> get waves =>
      [for (var i = 0; i < waveCount; i++) wave(i)];

  int _lifetimeFor(int wave) =>
      (_baseLifetimeMs[wave] * _effectivePace()).round();

  /// The pace this wave actually runs at: the persisted [_initialPace]
  /// blended toward *this session's* implied pace by how much of the
  /// run has been played — early waves lean on carried skill, later
  /// waves on the run in progress. > 1 = longer windows, < 1 = shorter.
  double _effectivePace() {
    if (_resolved.isEmpty) return _initialPace;
    final w = (_resolved.length / totalTargets).clamp(0.0, 1.0);
    final blended = _initialPace + (_sessionFactor() - _initialPace) * w;
    return blended.clamp(_minPace, _maxPace).toDouble();
  }

  /// This session's implied pace from the mean per-strike score so far:
  /// a clean centred fast hit ≈ 1.0, a weak slow one ≈ 0.5, a miss = 0.
  double _sessionFactor() {
    if (_resolved.isEmpty) return _initialPace;
    return (1.55 - sessionScore).clamp(_minPace, _maxPace).toDouble();
  }

  /// Mean per-strike score over everything resolved so far — misses
  /// count as 0. The number `TrainingPaceRepository` persists.
  double get sessionScore {
    if (_resolved.isEmpty) return 0;
    var sum = 0.0;
    for (final r in _resolved) {
      if (r.quality == StrikeQuality.miss) continue;
      final centre = (1 - r.offCentre).clamp(0.0, 1.0);
      final speed =
          (1 - r.latencyMs / r.target.lifetimeMs).clamp(0.0, 1.0);
      sum += 0.35 + 0.45 * centre + 0.20 * speed;
    }
    return sum / _resolved.length;
  }

  // ── layout ────────────────────────────────────────────────────────

  List<TrainingTarget> _wave(int w, int lifetimeMs) {
    final rng = _rng;
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
            index: w * perWave + i,
            x: p.x,
            y: p.y,
            radius: r,
            lifetimeMs: lifetimeMs,
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
