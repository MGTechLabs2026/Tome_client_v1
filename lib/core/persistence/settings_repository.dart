// lib/core/persistence/settings_repository.dart
//
// The handful of player-set options, all persisted in one settings.v1
// blob: reduce motion (fed into MediaQuery), sound on/off, and volume.
import 'package:flutter/foundation.dart';

import 'game_store.dart';

const _kKey = 'settings.v1';
const _kDefaultVolume = 0.7;

class SettingsRepository {
  SettingsRepository(this._store) {
    final json = _store.read(_kKey);
    reduceMotion = ValueNotifier<bool>(json['reduceMotion'] == true);
    soundEnabled = ValueNotifier<bool>(json['soundEnabled'] != false);
    soundVolume = ValueNotifier<double>(
      ((json['soundVolume'] as num?)?.toDouble() ?? _kDefaultVolume)
          .clamp(0.0, 1.0)
          .toDouble(),
    );
  }

  final GameStore _store;

  /// When true, the app forces `MediaQuery.disableAnimations` on.
  late final ValueNotifier<bool> reduceMotion;

  /// Master switch for combat/training sound effects.
  late final ValueNotifier<bool> soundEnabled;

  /// 0.0..1.0. Applied to the live `GameAudio` by the composition root.
  late final ValueNotifier<double> soundVolume;

  Future<void> setReduceMotion(bool value) {
    reduceMotion.value = value;
    return _persist();
  }

  Future<void> setSoundEnabled(bool value) {
    soundEnabled.value = value;
    return _persist();
  }

  Future<void> setSoundVolume(double value) {
    soundVolume.value = value.clamp(0.0, 1.0).toDouble();
    return _persist();
  }

  Future<void> _persist() => _store.write(_kKey, {
        'reduceMotion': reduceMotion.value,
        'soundEnabled': soundEnabled.value,
        'soundVolume': soundVolume.value,
      });
}
