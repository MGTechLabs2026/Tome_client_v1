// test/core/platform/audioplayers_game_audio_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/platform/audioplayers_game_audio.dart';
import 'package:tome_client/core/platform/game_audio.dart';

void main() {
  test('asset path map covers every SoundCue', () {
    final a = AudioPlayersGameAudio();
    for (final cue in SoundCue.values) {
      final p = a.assetPathFor[cue];
      expect(p, isNotNull, reason: 'no asset path for ${cue.name}');
      expect(p, startsWith('audio/'));
      expect(p, contains(cue.name));
    }
  });

  test('volume setter clamps to 0..1', () {
    final a = AudioPlayersGameAudio()..volume = 5;
    expect(a.volume, 1);
    a.volume = -1;
    expect(a.volume, 0);
    a.volume = 0.4;
    expect(a.volume, 0.4);
  });

  test('shouldPlay gates on enabled, volume, and (web) unlock', () {
    final a = AudioPlayersGameAudio();
    a
      ..enabled = false
      ..volume = 1;
    expect(a.shouldPlay, isFalse);
    a.enabled = true;
    a.volume = 0;
    expect(a.shouldPlay, isFalse);
    a.volume = 0.5;
    // On non-web the constructor is treated as unlocked; on web it is not
    // until unlock() resolves. The test runs on the VM (non-web).
    expect(a.shouldPlay, isTrue);
  });

  test('disabling calls stopAll (no throw without a pool)', () {
    final a = AudioPlayersGameAudio()..enabled = true;
    a.enabled = false; // must not throw even though no pool exists yet
  });
}
