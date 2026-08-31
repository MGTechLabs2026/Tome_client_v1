// lib/features/training/exercise/training_target.dart
import 'dart:math' as math;

/// How well a strike landed, by tap distance from the ring centre as a
/// fraction of the target radius. Shape (not colour) carries this in the
/// UI — a clean stamp, a collapse, a dent, a struck-through ring.
enum StrikeQuality { perfect, good, weak, miss }

extension StrikeQualityX on StrikeQuality {
  bool get isHit => this != StrikeQuality.miss;
}

/// One target the player must strike, in **normalized field space**:
/// [x], [y] and [radius] are fractions of the field's shorter side, so
/// the same wave renders correctly at any aspect ratio.
class TrainingTarget {
  const TrainingTarget({
    required this.wave,
    required this.index,
    required this.x,
    required this.y,
    required this.radius,
    required this.lifetimeMs,
  });

  final int wave; // 0..2
  final int index; // 0..8 across the whole session
  final double x;
  final double y;
  final double radius;
  final int lifetimeMs;
}

/// The player's answer to one target — where and when they struck. A
/// timeout is a resolution too ([timedOut] true), so every target
/// yields exactly one attempt to the engine.
class TargetResolution {
  const TargetResolution({
    required this.target,
    required this.tapX,
    required this.tapY,
    required this.latencyMs,
    required this.timedOut,
  });

  final TrainingTarget target;
  final double tapX;
  final double tapY;
  final int latencyMs;
  final bool timedOut;

  double get distance {
    final dx = tapX - target.x;
    final dy = tapY - target.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// 0 at dead centre, 1 at the rim, >1 outside.
  double get offCentre => target.radius <= 0 ? 1 : distance / target.radius;

  StrikeQuality get quality {
    if (timedOut || offCentre > 1) return StrikeQuality.miss;
    if (offCentre <= 0.30) return StrikeQuality.perfect;
    if (offCentre <= 0.65) return StrikeQuality.good;
    return StrikeQuality.weak;
  }
}
