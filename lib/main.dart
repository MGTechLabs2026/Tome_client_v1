// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/tome_app.dart';
import 'core/persistence/game_store.dart';
import 'core/platform/platform.dart';
import 'features/run/run_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A browser can fail in ways a desktop app does not. Keep the game
  // running: log the error, don't white-screen the tab.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Tome: uncaught framework error: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Tome: uncaught error: $error\n$stack');
    return true; // handled — do not crash the isolate
  };

  runApp(TomeApp(runBloc: RunBloc(), store: await _openStore()));
}

/// Picks the persistence backend for the current platform. Any failure
/// degrades to an in-memory store — the game runs, this launch just
/// doesn't persist.
Future<GameStore> _openStore() async {
  try {
    if (PlatformCapabilities.current.id == 'devvit') {
      // Durable state lives on the Devvit server (Redis), not
      // localStorage (which the webview drops on app update). Hydrate
      // once, then read is synchronous.
      final remote = RemoteGameStore(DevvitGameStoreTransport(DevvitBackend()));
      await remote.hydrate();
      return remote;
    }
    return await GameStore.open();
  } catch (e, st) {
    debugPrint('Tome: persistence unavailable, running unsaved: $e\n$st');
    return GameStore.memory();
  }
}
