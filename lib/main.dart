// lib/main.dart
import 'package:flutter/material.dart';

import 'app/tome_app.dart';
import 'core/persistence/game_store.dart';
import 'features/run/run_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GameStore store;
  try {
    store = await GameStore.open();
  } catch (_) {
    // No disk — records and the codex just won't persist this launch.
    store = GameStore.memory();
  }
  runApp(TomeApp(runBloc: RunBloc(), store: store));
}
