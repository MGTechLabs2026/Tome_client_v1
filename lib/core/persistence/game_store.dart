// lib/core/persistence/game_store.dart
//
// The one place the client keeps anything across runs. Deliberately
// small: a handful of scalar "records" and a set of discovered content
// ids, kept as JSON documents under two keys. The repositories
// ([RecordsRepository], [CodexRepository]) own the shape; this only
// reads and writes their maps.
//
// Backed by `shared_preferences` in the app and by an in-memory map in
// tests. If this ever needs per-run history rows it can be swapped for
// SQLite behind the same two `Map<String, Object?>` accessors without
// touching a repository.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract class GameStore {
  /// Opens the real, disk-backed store. Call once at startup.
  static Future<GameStore> open() async =>
      _PrefsGameStore(await SharedPreferences.getInstance());

  /// A throwaway store that forgets everything — for tests and for any
  /// launch that could not reach disk.
  factory GameStore.memory() = _MemoryGameStore;

  /// The JSON document at [key], or an empty map if nothing is stored.
  Map<String, Object?> read(String key);

  /// Replaces the JSON document at [key].
  Future<void> write(String key, Map<String, Object?> value);
}

class _PrefsGameStore implements GameStore {
  _PrefsGameStore(this._prefs);
  final SharedPreferences _prefs;

  @override
  Map<String, Object?> read(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, Object?>
          ? decoded
          : Map<String, Object?>.from(decoded as Map);
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> write(String key, Map<String, Object?> value) =>
      _prefs.setString(key, jsonEncode(value));
}

class _MemoryGameStore implements GameStore {
  final Map<String, Map<String, Object?>> _docs = {};

  @override
  Map<String, Object?> read(String key) =>
      Map<String, Object?>.from(_docs[key] ?? const {});

  @override
  Future<void> write(String key, Map<String, Object?> value) async {
    _docs[key] = Map<String, Object?>.from(value);
  }
}
