// lib/core/persistence/training_pace_repository.dart
//
// A persisted per-player training-difficulty multiplier. It carries the
// adaptive target-strike pace *between* sessions (until local data is
// cleared), so a player who keeps performing well keeps a tighter
// window (more challenge, no reset to easy every visit) and a player on
// a slow device — who genuinely struggles — keeps a gentler one
// (never punished by a hard reset).
//
// 1.0 is the baseline. Below 1.0 = shorter windows (harder); above =
// longer (easier). Moves toward each session's result with heavy
// smoothing, so one unlucky or lucky run barely shifts it.
import 'game_store.dart';

const _kKey = 'training_pace.v1';

/// Clamp band, shared with `TargetStrikeController`.
const kPaceMin = 0.75;
const kPaceMax = 1.5;

/// How far toward a session's implied pace the stored value moves per
/// session (0..1). 0.4 ≈ two or three sessions to fully settle.
const _kSmoothing = 0.4;

class TrainingPaceRepository {
  TrainingPaceRepository(this._store)
      : _pace = _read(_store.read(_kKey));

  final GameStore _store;
  double _pace;

  /// The multiplier a new session starts from.
  double get pace => _pace;

  /// Fold one finished session's mean performance (`0` = all misses,
  /// `~1` = clean, centred, fast throughout) into the stored pace.
  Future<void> recordSession(double meanScore) {
    final implied = (1.55 - meanScore).clamp(kPaceMin, kPaceMax);
    final next = (_pace + (implied - _pace) * _kSmoothing)
        .clamp(kPaceMin, kPaceMax)
        .toDouble();
    _pace = next;
    return _store.write(_kKey, {'pace': next});
  }

  static double _read(Map<String, Object?> json) {
    final v = (json['pace'] as num?)?.toDouble() ?? 1.0;
    return v.clamp(kPaceMin, kPaceMax).toDouble();
  }
}
