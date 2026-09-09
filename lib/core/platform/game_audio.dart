// lib/core/platform/game_audio.dart

/// Named sound events the game can request. Abstract — no asset paths
/// here; a real implementation maps these to bundled files.
enum SoundCue {
  uiTap,           // button / screen transition on a prep/result screen
  strikeDull,      // your bare-handed hit lands (muffled thud)
  strikeWeapon,    // your weapon hit lands (short, sharp)
  strikeTechnique, // your technique hit lands (longer, edged)
  strikePerfect,   // training: a perfectly-timed hit
  strikeMiss,      // any missed attack (wind / whoosh)
  guardHold,       // a guard holds / armour soaks a blow
  bodyBlow,        // an enemy blow lands on you (low thud)
  waveStart,       // training: a new target wave begins
  sessionEnd,      // training: the session finishes
  techniqueEvolved,
  fightWon,
  fightLost,
}

/// The client's audio seam. [SilentAudio] is the default and the only
/// implementation used in tests; the Flutter runtime swaps in a real
/// backend at the composition root.
///
/// Rules a real implementation MUST follow:
///   * no sound before the first user gesture — [unlock] is called from
///     the first pointer-down and nothing plays until it resolves (web);
///   * [enabled] / [volume] are honoured immediately; the caller persists
///     them;
///   * a play/decode error is swallowed, never thrown, never logged in a
///     loop;
///   * [stopAll] on backgrounding and on leaving a combat/training screen.
abstract interface class GameAudio {
  bool get enabled;
  set enabled(bool value);

  /// 0.0..1.0. Setter clamps.
  double get volume;
  set volume(double value);

  /// Call once from the first user gesture. Safe to call again.
  Future<void> unlock();

  void play(SoundCue cue);

  void stopAll();
}

/// The no-op default. Stores [enabled] / [volume] so wiring can be
/// asserted without a real backend; every method is safe any number of
/// times.
class SilentAudio implements GameAudio {
  @override
  bool enabled = false;

  @override
  double volume = 0;

  @override
  Future<void> unlock() async {}

  @override
  void play(SoundCue cue) {}

  @override
  void stopAll() {}
}
