// lib/core/persistence/game_store.dart
//
// The one place the client keeps anything across runs. Deliberately
// small: a handful of scalar "records" and a set of discovered content
// ids, kept as JSON documents under two keys. The repositories
// ([RecordsRepository], [CodexRepository]) own the shape; this only
// reads and writes their maps.
//
// Implementations:
//   * [LocalGameStore]  — `shared_preferences` (localStorage on web,
//     NSUserDefaults / SharedPreferences natively). The default on
//     desktop and on itch.io HTML5.
//   * [RemoteGameStore] — hydrates once from and flushes writes through a
//     [GameStoreTransport], serving `read` from an in-memory cache. The
//     Devvit target uses this with a transport that talks to the Devvit
//     server endpoint (backed by Redis); see docs/devvit-integration.md.
//     localStorage is NOT durable on Devvit (the iframe URL changes on
//     app update), so it must not be the authoritative store there.
//   * `GameStore.memory()` — a throwaway map for tests and for any
//     launch that could not reach persistence.
//
// Each repository owns a single versioned key (`records.v1`, `codex.v1`,
// `settings.v1`, `training_pace.v1`) and tolerates missing fields on
// read, so a forward-compatible field add needs no migration.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class GameStore {
  /// Opens the default local store ([LocalGameStore]). Call once at
  /// startup. Throws if the platform's key/value store is unreachable —
  /// `main()` falls back to [GameStore.memory].
  static Future<GameStore> open() async =>
      LocalGameStore(await SharedPreferences.getInstance());

  /// A throwaway store that forgets everything — for tests and for any
  /// launch that could not reach disk.
  factory GameStore.memory() = _MemoryGameStore;

  /// The JSON document at [key], or an empty map if nothing is stored.
  /// Synchronous by contract — a network-backed implementation
  /// ([RemoteGameStore]) hydrates its cache once before this is called.
  Map<String, Object?> read(String key);

  /// Replaces the JSON document at [key]. Fire-and-forget from the
  /// caller's side: a persistence failure degrades to "this change
  /// didn't persist" and must never surface as an unhandled async error.
  Future<void> write(String key, Map<String, Object?> value);
}

/// The local key/value store — `shared_preferences`. On web this is
/// `window.localStorage`, which is fine for desktop browsers / itch.io
/// but **not durable on Devvit** (see [RemoteGameStore]).
class LocalGameStore implements GameStore {
  LocalGameStore(this._prefs);
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

/// Moves versioned JSON documents to/from a durable backend the client
/// cannot reach synchronously — the Devvit server endpoint (backed by
/// Redis), or any other host-provided store. This is the *contract* the
/// platform shell implements; the client never opens a socket itself.
///
/// Keep payloads small (compact ids + the repositories' own small docs —
/// never runtime objects, never the content catalogue). See
/// docs/devvit-integration.md.
abstract interface class GameStoreTransport {
  /// Every stored document, keyed by its versioned key. Called once, at
  /// startup, before the game reads anything.
  Future<Map<String, Map<String, Object?>>> loadAll();

  /// Persist one document. May be called often; the shell should debounce
  /// / coalesce if its backend has a write budget.
  Future<void> save(String key, Map<String, Object?> value);
}

/// A [GameStore] backed by a [GameStoreTransport]. [hydrate] must be
/// awaited once before the store is handed to any repository; after that
/// [read] serves from the in-memory cache (synchronous, per the
/// [GameStore] contract) and [write] updates the cache immediately and
/// flushes through the transport in the background.
///
/// This is what the Devvit build uses (with a transport that calls the
/// Devvit server endpoint). It carries no Devvit / Reddit / itch
/// vocabulary — only "load all, save one".
class RemoteGameStore implements GameStore {
  RemoteGameStore(this._transport);

  final GameStoreTransport _transport;
  final Map<String, Map<String, Object?>> _cache = {};
  bool _hydrated = false;

  /// Pull every document into the cache. Safe to call again (re-pulls).
  /// On failure the cache is left as-is and the error is swallowed —
  /// the game continues from whatever it has (possibly empty), and
  /// subsequent [write]s still try to flush.
  Future<void> hydrate() async {
    try {
      final all = await _transport.loadAll();
      _cache
        ..clear()
        ..addAll({
          for (final e in all.entries) e.key: Map<String, Object?>.from(e.value),
        });
    } catch (e, st) {
      debugPrint('RemoteGameStore: hydrate failed, starting from cache: $e\n$st');
    }
    _hydrated = true;
  }

  @override
  Map<String, Object?> read(String key) {
    assert(_hydrated, 'RemoteGameStore.read before hydrate()');
    return Map<String, Object?>.from(_cache[key] ?? const {});
  }

  @override
  Future<void> write(String key, Map<String, Object?> value) async {
    _cache[key] = Map<String, Object?>.from(value);
    try {
      await _transport.save(key, value);
    } catch (e, st) {
      debugPrint('RemoteGameStore: failed to persist "$key": $e\n$st');
    }
  }
}
