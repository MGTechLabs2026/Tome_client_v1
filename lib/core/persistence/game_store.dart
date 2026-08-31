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
//
// Each repository owns a single versioned key (`records.v1`, `codex.v1`,
// `settings.v1`) and tolerates missing fields on read, so a forward-
// compatible field add needs no migration. A breaking shape change would
// bump the suffix and add a one-time read of the old key — there is no
// such migration yet (nothing shipped a `v2`).
import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  Future<void> write(String key, Map<String, Object?> value) async {
    // Records / codex / settings writes are fire-and-forget from the
    // caller's side. A platform write failure must not surface as an
    // unhandled async error — degrade to "this change didn't persist".
    try {
      await _prefs.setString(key, jsonEncode(value));
    } catch (e, st) {
      debugPrint('GameStore: failed to persist "$key": $e\n$st');
    }
  }
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
