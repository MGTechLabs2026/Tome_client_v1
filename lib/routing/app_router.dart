// lib/routing/app_router.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/models/game_phase.dart';
import '../features/run/run_bloc.dart';

String _pathFor(GamePhase phase) => switch (phase) {
      GamePhase.characterCreation => '/character-creation',
      GamePhase.tome => '/tome',
      GamePhase.trainingPreparation => '/training/prepare',
      GamePhase.training => '/training/exercise',
      GamePhase.trainingResult => '/training/result',
      GamePhase.combatPreparation => '/combat/prepare',
      GamePhase.combat => '/combat',
      GamePhase.loot => '/loot',
      GamePhase.runComplete => '/run-complete',
    };

/// Bridges [RunBloc]'s state stream to a [Listenable] so `go_router`'s
/// [GoRouter.refreshListenable] re-runs the phase redirect whenever the
/// run advances a phase. Replaced screen-by-screen in Phase 5; until
/// then every route renders a name placeholder so the router is
/// independently runnable.
class _RunBlocListenable extends ChangeNotifier {
  _RunBlocListenable(RunBloc bloc) {
    _subscription = bloc.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

Widget _placeholderFor(GamePhase phase) =>
    Scaffold(body: Center(child: Text(phase.name)));

GoRouter appRouter(RunBloc runBloc) => GoRouter(
      initialLocation: _pathFor(runBloc.state.phase),
      refreshListenable: _RunBlocListenable(runBloc),
      redirect: (context, state) => _pathFor(runBloc.state.phase),
      routes: [
        for (final phase in GamePhase.values)
          GoRoute(
            path: _pathFor(phase),
            builder: (context, state) => _placeholderFor(phase),
          ),
      ],
    );
