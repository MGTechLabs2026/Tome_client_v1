// lib/app/tome_app.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/engine/character_adapter.dart';
import '../core/engine/engine_session.dart';
import '../features/run/run_bloc.dart';
import '../routing/app_router.dart';
import 'theme.dart';

class TomeApp extends StatelessWidget {
  const TomeApp({super.key, required this.runBloc, EngineSession? session})
      : _session = session;

  final RunBloc runBloc;
  final EngineSession? _session;

  @override
  Widget build(BuildContext context) {
    // One EngineSession for the whole app; every adapter shares it.
    // Constructed once here and exposed via RepositoryProviders so each
    // phase's feature Bloc reads the adapter it needs. Adapters that
    // depend on a Tome existing (Training/Combat/Reward) are added to
    // this list by their own Phase 5 tasks and stay lazy so they build
    // only after character + Tome creation has run.
    final session = _session ?? EngineSession(DateTime.now().millisecondsSinceEpoch);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<EngineSession>.value(value: session),
        RepositoryProvider<CharacterAdapter>(
          create: (_) => CharacterAdapter(session),
        ),
      ],
      child: BlocProvider.value(
        value: runBloc,
        child: MaterialApp.router(
          title: 'Tome: Martial Arts',
          theme: tomeTheme(),
          routerConfig: appRouter(runBloc),
        ),
      ),
    );
  }
}
