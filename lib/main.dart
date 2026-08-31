// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/tome_app.dart';
import 'core/persistence/game_store.dart';
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

  GameStore store;
  try {
    store = await GameStore.open();
  } catch (e, st) {
    // Storage unavailable (private-mode localStorage, blocked site data,
    // a locked-down webview): the game still runs, records / codex just
    // won't persist this launch.
    debugPrint('Tome: persistence unavailable, running unsaved: $e\n$st');
    store = GameStore.memory();
  }

  runApp(TomeApp(runBloc: RunBloc(), store: store));
}
