// test/support/fake_game_audio.dart
import 'package:tome_client/core/platform/game_audio.dart';

/// A [GameAudio] that records calls instead of making sound. Widget and
/// wiring tests provide this in place of the real backend.
class FakeGameAudio implements GameAudio {
  @override
  bool enabled = true;

  @override
  double volume = 1;

  final List<SoundCue> played = [];
  int unlockCalls = 0;
  int stopAllCalls = 0;

  @override
  Future<void> unlock() async => unlockCalls++;

  @override
  void play(SoundCue cue) {
    if (enabled && volume > 0) played.add(cue);
  }

  @override
  void stopAll() => stopAllCalls++;
}
