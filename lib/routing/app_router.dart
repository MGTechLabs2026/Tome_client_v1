// lib/routing/app_router.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/engine/character_adapter.dart';
import '../core/engine/item_adapter.dart';
import '../core/engine/tome_adapter.dart';
import '../core/models/game_phase.dart';
import '../features/character_creation/character_creation_bloc.dart';
import '../features/character_creation/character_creation_screen.dart';
import '../features/run/run_bloc.dart';
import '../features/tome/tome_bloc.dart';
import '../features/tome/tome_screen.dart';

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
/// run advances a phase.
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

/// The real screen for [phase], or a name placeholder for phases whose
/// screen task hasn't landed yet. Each Phase 5 task swaps its phase's
/// arm from `_placeholderFor` to a `BlocProvider`-wrapped screen.
Widget _screenFor(GamePhase phase, BuildContext context) => switch (phase) {
      GamePhase.characterCreation => BlocProvider(
          create: (_) => CharacterCreationBloc(context.read<CharacterAdapter>()),
          child: const CharacterCreationScreen(),
        ),
      GamePhase.tome => BlocProvider(
          create: (_) => TomeBloc(
            tomeAdapter: context.read<TomeAdapter>(),
            itemAdapter: context.read<ItemAdapter>(),
          ),
          child: const TomeScreen(),
        ),
      _ => _placeholderFor(phase),
    };

GoRouter appRouter(RunBloc runBloc) => GoRouter(
      initialLocation: _pathFor(runBloc.state.phase),
      refreshListenable: _RunBlocListenable(runBloc),
      redirect: (context, state) => _pathFor(runBloc.state.phase),
      routes: [
        for (final phase in GamePhase.values)
          GoRoute(
            path: _pathFor(phase),
            builder: (context, state) => _screenFor(phase, context),
          ),
      ],
    );
