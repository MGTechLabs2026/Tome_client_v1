// lib/core/persistence/settings_repository.dart
//
// The handful of player-set options. One real switch at v0.0.1 —
// reduce motion — persisted across launches and fed into MediaQuery so
// the whole surface's decorative animation collapses when it is on.
import 'package:flutter/foundation.dart';

import 'game_store.dart';

const _kKey = 'settings.v1';

class SettingsRepository {
  SettingsRepository(this._store) {
    final json = _store.read(_kKey);
    reduceMotion = ValueNotifier<bool>(json['reduceMotion'] == true);
  }

  final GameStore _store;

  /// When true, the app forces `MediaQuery.disableAnimations` on. Listen
  /// to it to rebuild; it never changes except from [setReduceMotion].
  late final ValueNotifier<bool> reduceMotion;

  Future<void> setReduceMotion(bool value) {
    reduceMotion.value = value;
    return _store.write(_kKey, {'reduceMotion': value});
  }
}
