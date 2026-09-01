// lib/core/platform/devvit_backend.dart
//
// The Devvit implementations of the persistence + identity contracts.
// A Devvit webview may only reach its own app's server endpoint, so
// these hit the Devvit Hono server's plain REST routes with relative
// paths (`/api/...`) — the webview is served from the app origin.
//
// Server side: devvit/src/server/routes/state.ts
//   GET  /api/state             -> { "<key>": <doc>, ... }
//   POST /api/state {key,value} -> { ok: true }
//   GET  /api/identity          -> { key: "<opaque player id>" }
//
// The engine never sees any of this. Used only when
// PlatformCapabilities.current.id == 'devvit' (see main.dart), wrapped
// in RemoteGameStore so read stays synchronous after one hydrate().
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../persistence/game_store.dart';
import 'platform_identity.dart';

/// Shared client + base path for the Devvit REST endpoints.
class DevvitBackend {
  DevvitBackend({http.Client? client, this.basePath = '/api'})
      : client = client ?? http.Client();

  final http.Client client;
  final String basePath;

  Uri uri(String path) => Uri.parse('$basePath$path');
}

/// [GameStoreTransport] over `GET`/`POST /api/state`. Per-player scoping
/// is enforced *server-side* (Redis key `state:<userId>`), so the client
/// sends only the document key + value.
class DevvitGameStoreTransport implements GameStoreTransport {
  DevvitGameStoreTransport(this._backend);

  final DevvitBackend _backend;

  @override
  Future<Map<String, Map<String, Object?>>> loadAll() async {
    final res = await _backend.client.get(_backend.uri('/state'));
    if (res.statusCode != 200) {
      throw Exception('GET /api/state -> ${res.statusCode}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) return const {};
    return {
      for (final e in decoded.entries)
        e.key as String: Map<String, Object?>.from(e.value as Map),
    };
  }

  @override
  Future<void> save(String key, Map<String, Object?> value) async {
    final res = await _backend.client.post(
      _backend.uri('/state'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'key': key, 'value': value}),
    );
    if (res.statusCode != 200) {
      throw Exception('POST /api/state -> ${res.statusCode}: ${res.body}');
    }
  }
}

/// [PlatformIdentity] over `GET /api/identity`. Returns the server's
/// opaque player key, or `'anon'` if the call fails / the viewer is
/// logged out. The game keys off the string only — never Reddit data.
class DevvitIdentity implements PlatformIdentity {
  DevvitIdentity(this._backend);

  final DevvitBackend _backend;

  @override
  Future<String> persistenceKey() async {
    try {
      final res = await _backend.client.get(_backend.uri('/identity'));
      if (res.statusCode != 200) return 'anon';
      final decoded = jsonDecode(res.body);
      final key = decoded is Map ? decoded['key'] : null;
      return (key is String && key.isNotEmpty) ? key : 'anon';
    } catch (_) {
      return 'anon';
    }
  }
}
