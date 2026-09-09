// test/app/audio_wiring_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/app/tome_app.dart';
import 'package:tome_client/core/persistence/game_store.dart';
import 'package:tome_client/features/run/run_bloc.dart';

import '../support/fake_game_audio.dart';

void main() {
  testWidgets('settings drive the live GameAudio; first pointer unlocks',
      (tester) async {
    final store = GameStore.memory();
    final audio = FakeGameAudio()
      ..enabled = false
      ..volume = 0;

    await tester.pumpWidget(TomeApp(
      runBloc: RunBloc(),
      store: store,
      audio: audio,
    ));
    await tester.pump();

    // The composition root pushed the persisted defaults in (on: true, 0.7).
    expect(audio.enabled, isTrue);
    expect(audio.volume, 0.7);

    // Driving the app's own SettingsRepository from outside the tree is not
    // worth the ceremony here — Task 6's settings_screen_test covers
    // "toggle -> repo". This test covers "repo defaults -> audio" and the
    // lifecycle-critical "first gesture -> unlock".
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    expect(audio.unlockCalls, greaterThanOrEqualTo(1));
  });
}
