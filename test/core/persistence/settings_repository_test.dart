// test/core/persistence/settings_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/persistence/game_store.dart';
import 'package:tome_client/core/persistence/settings_repository.dart';

void main() {
  test('defaults: reduceMotion off, sound on, volume 0.7', () {
    final r = SettingsRepository(GameStore.memory());
    expect(r.reduceMotion.value, isFalse);
    expect(r.soundEnabled.value, isTrue);
    expect(r.soundVolume.value, 0.7);
  });

  test('setters persist and co-persist across a reload', () async {
    final store = GameStore.memory();
    final r = SettingsRepository(store);
    await r.setReduceMotion(true);
    await r.setSoundEnabled(false);
    await r.setSoundVolume(0.25);

    final reloaded = SettingsRepository(store);
    expect(reloaded.reduceMotion.value, isTrue);
    expect(reloaded.soundEnabled.value, isFalse);
    expect(reloaded.soundVolume.value, 0.25);
  });

  test('setSoundVolume clamps to 0..1', () async {
    final r = SettingsRepository(GameStore.memory());
    await r.setSoundVolume(9);
    expect(r.soundVolume.value, 1);
    await r.setSoundVolume(-3);
    expect(r.soundVolume.value, 0);
  });

  test('a legacy blob without the sound keys reads the defaults', () async {
    final store = GameStore.memory();
    await store.write('settings.v1', {'reduceMotion': true});
    final r = SettingsRepository(store);
    expect(r.reduceMotion.value, isTrue);
    expect(r.soundEnabled.value, isTrue);
    expect(r.soundVolume.value, 0.7);
  });
}
