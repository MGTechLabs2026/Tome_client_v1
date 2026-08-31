// lib/core/platform/game_audio.dart

/// Named sound events the game can request. Deliberately abstract — no
/// asset paths here; a real implementation maps these to files it ships.
enum SoundCue {
  uiTap,
  strikeHit,
  strikePerfect,
  strikeMiss,
  techniqueEvolved,
  fightWon,
  fightLost,
}

/// The client's audio seam. There are no audio assets in the project
/// yet, so [SilentAudio] is the only implementation and the default —
/// this exists so gameplay code can call `audio.play(...)` today and a
/// real backend can be dropped in later without touching call sites.
///
/// Web rules a real implementation MUST follow (Task 11):
///   * no sound before the first user gesture — [unlock] is called from
///     the first tap/click and nothing plays until it resolves;
///   * [muted] is honoured immediately and persisted by the caller;
///   * a play/decode error is swallowed, never thrown;
///   * [stopAll] on backgrounding / screen change.
abstract interface class GameAudio {
  bool get muted;
  set muted(bool value);

  /// Call once from the first user gesture. Safe to call again.
  Future<void> unlock();

  void play(SoundCue cue);

  void stopAll();
}

/// The no-op default. Every method is safe to call any number of times.
class SilentAudio implements GameAudio {
  @override
  bool muted = true;

  @override
  Future<void> unlock() async {}

  @override
  void play(SoundCue cue) {}

  @override
  void stopAll() {}
}
