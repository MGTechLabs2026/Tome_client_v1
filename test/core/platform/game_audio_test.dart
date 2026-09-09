// test/core/platform/game_audio_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/platform/game_audio.dart';

import '../../support/fake_game_audio.dart';

void main() {
  test('SoundCue has the 13 named cues', () {
    expect(SoundCue.values, hasLength(13));
    expect(SoundCue.values.map((c) => c.name), containsAll(<String>[
      'uiTap', 'strikeDull', 'strikeWeapon', 'strikeTechnique',
      'strikePerfect', 'strikeMiss', 'guardHold', 'bodyBlow',
      'waveStart', 'sessionEnd', 'techniqueEvolved', 'fightWon', 'fightLost',
    ]));
  });

  test('SilentAudio stores enabled/volume and never throws', () async {
    final a = SilentAudio();
    expect(a.enabled, isFalse);
    expect(a.volume, 0);
    a
      ..enabled = true
      ..volume = 0.5;
    expect(a.enabled, isTrue);
    expect(a.volume, 0.5);
    await a.unlock();
    a.play(SoundCue.uiTap);
    a.stopAll();
  });

  test('FakeGameAudio records plays only while enabled and audible', () {
    final a = FakeGameAudio()
      ..enabled = true
      ..volume = 1;
    a.play(SoundCue.fightWon);
    a.enabled = false;
    a.play(SoundCue.fightLost);
    a.enabled = true;
    a.volume = 0;
    a.play(SoundCue.uiTap);
    expect(a.played, [SoundCue.fightWon]);
    expect(a.unlockCalls, 0);
    a.unlock();
    a.stopAll();
    expect(a.unlockCalls, 1);
    expect(a.stopAllCalls, 1);
  });
}
