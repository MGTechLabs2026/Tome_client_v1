// lib/core/platform/audioplayers_game_audio.dart
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'game_audio.dart';

/// The real [GameAudio] for the Flutter runtime. Constructed **only** at
/// the composition root (`lib/main.dart`); gameplay code sees the
/// interface. A small round-robin pool of players so an overlapping cue
/// doesn't cut off the previous one.
class AudioPlayersGameAudio implements GameAudio {
  static const _poolSize = 4;
  static const _ext = 'ogg'; // Task 2 commits .ogg when ffmpeg is present.

  /// Path is relative to the Flutter asset root; `AssetSource` prefixes
  /// `assets/` itself.
  @visibleForTesting
  final Map<SoundCue, String> assetPathFor = {
    for (final c in SoundCue.values) c: 'audio/${c.name}.$_ext',
  };

  final List<AudioPlayer> _pool = [];
  int _next = 0;

  bool _enabled = false;
  double _volume = 0;
  bool _unlocked = !kIsWeb; // native platforms need no gesture

  @override
  bool get enabled => _enabled;
  @override
  set enabled(bool value) {
    _enabled = value;
    if (!value) stopAll();
  }

  @override
  double get volume => _volume;
  @override
  set volume(double value) => _volume = value.clamp(0.0, 1.0).toDouble();

  @visibleForTesting
  bool get shouldPlay => _enabled && _volume > 0 && _unlocked;

  void _ensurePool() {
    if (_pool.isNotEmpty) return;
    for (var i = 0; i < _poolSize; i++) {
      final p = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      _pool.add(p);
    }
  }

  @override
  Future<void> unlock() async {
    if (_unlocked && _pool.isNotEmpty) return;
    _ensurePool();
    if (kIsWeb) {
      for (final p in _pool) {
        try {
          await p.play(AssetSource(assetPathFor[SoundCue.uiTap]!), volume: 0);
          await p.stop();
        } catch (_) {/* swallow */}
      }
    }
    _unlocked = true;
  }

  @override
  void play(SoundCue cue) {
    if (!shouldPlay) return;
    _ensurePool();
    final p = _pool[_next];
    _next = (_next + 1) % _pool.length;
    final path = assetPathFor[cue];
    if (path == null) return;
    unawaited(
      p.play(AssetSource(path), volume: _volume).catchError((_) {/* swallow */}),
    );
  }

  @override
  void stopAll() {
    for (final p in _pool) {
      try {
        unawaited(p.stop().catchError((_) {}));
      } catch (_) {/* swallow */}
    }
  }
}
