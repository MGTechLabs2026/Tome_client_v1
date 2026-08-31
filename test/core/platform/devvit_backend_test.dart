// Devvit persistence + identity transport (Platform Readiness V1).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tome_client/core/persistence/game_store.dart';
import 'package:tome_client/core/platform/devvit_backend.dart';

DevvitBackend _backend(MockClientHandler handler) =>
    DevvitBackend(client: MockClient(handler));

void main() {
  group('DevvitGameStoreTransport', () {
    test('loadAll GETs /api/state and shapes the response', () async {
      final t = DevvitGameStoreTransport(_backend((req) async {
        expect(req.method, 'GET');
        expect(req.url.path, '/api/state');
        return http.Response(
          jsonEncode({
            'records.v1': {'furthestRun': 4},
            'codex.v1': {'items': ['knife']},
          }),
          200,
        );
      }));

      expect(await t.loadAll(), {
        'records.v1': {'furthestRun': 4},
        'codex.v1': {'items': ['knife']},
      });
    });

    test('save POSTs /api/state with {key,value}', () async {
      Map<String, Object?>? sent;
      final t = DevvitGameStoreTransport(_backend((req) async {
        expect(req.method, 'POST');
        expect(req.url.path, '/api/state');
        sent = jsonDecode(req.body) as Map<String, Object?>;
        return http.Response(jsonEncode({'ok': true}), 200);
      }));

      await t.save('records.v1', {'furthestRun': 7});
      expect(sent, {
        'key': 'records.v1',
        'value': {'furthestRun': 7},
      });
    });

    test('a non-200 on save throws (so RemoteGameStore can swallow it)',
        () async {
      final t = DevvitGameStoreTransport(_backend(
          (req) async => http.Response('{"error":"nope"}', 400)));
      await expectLater(t.save('records.v1', {}), throwsException);
    });

    test('feeds RemoteGameStore end to end — hydrate then read from cache',
        () async {
      final store = RemoteGameStore(DevvitGameStoreTransport(_backend((req) async {
        if (req.method == 'GET') {
          return http.Response(jsonEncode({'settings.v1': {'muted': true}}), 200);
        }
        return http.Response(jsonEncode({'ok': true}), 200);
      })));
      await store.hydrate();
      expect(store.read('settings.v1'), {'muted': true});
      await store.write('records.v1', {'furthestRun': 1});
      expect(store.read('records.v1'), {'furthestRun': 1});
    });
  });

  group('DevvitIdentity', () {
    test('returns the server key', () async {
      final id = DevvitIdentity(_backend(
          (req) async => http.Response(jsonEncode({'key': 't2_abc'}), 200)));
      expect(await id.persistenceKey(), 't2_abc');
    });

    test('falls back to anon on error or an empty key', () async {
      final err = DevvitIdentity(_backend((req) async => http.Response('x', 500)));
      expect(await err.persistenceKey(), 'anon');

      final empty = DevvitIdentity(_backend(
          (req) async => http.Response(jsonEncode({'key': ''}), 200)));
      expect(await empty.persistenceKey(), 'anon');
    });
  });
}
