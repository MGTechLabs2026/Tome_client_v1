// lib/routing/app_router.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/engine/character_adapter.dart';
import '../core/engine/combat_adapter.dart';
import '../core/engine/item_adapter.dart';
import '../core/engine/reward_adapter.dart';
import '../core/engine/technique_adapter.dart';
import '../core/engine/tome_adapter.dart';
import '../core/models/game_phase.dart';
import '../features/character_creation/character_creation_bloc.dart';
import '../features/character_creation/character_creation_screen.dart';
import '../features/combat/combat_bloc.dart';
import '../features/combat/combat_preparation_screen.dart';
import '../features/combat/combat_screen.dart';
import '../features/loot/loot_bloc.dart';
import '../features/loot/loot_screen.dart';
import '../features/run/run_bloc.dart';
import '../features/run/run_event.dart';
import '../features/run_complete/run_complete_screen.dart';
import '../features/tome/tome_bloc.dart';
import '../features/tome/tome_screen.dart';
import '../features/training/training_preparation_screen.dart';
import '../features/training/training_result_screen.dart';

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

/// Enemy stats for fight [fightIndex] (0-based). The run is endless: the
/// first three bouts are hand-set, then the recurring rival scales up
/// each fight so the gauntlet always eventually ends the player.
({String id, num health, num damage, String stat}) _enemyFor(int fightIndex) =>
    switch (fightIndex) {
      0 => (id: 'sparring_partner', health: 12, damage: 2, stat: 'fist'),
      1 => (id: 'street_brawler', health: 20, damage: 3, stat: 'fist'),
      2 => (id: 'rival_master', health: 32, damage: 4, stat: 'fist'),
      final n => (
          id: 'rival_master',
          health: 32 + (n - 2) * 10,
          damage: 4 + (n - 2),
          stat: 'fist',
        ),
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


/// The real screen for [phase]. Feature Blocs that outlive a single
/// screen (Training/Combat/Loot) are provided once in `TomeApp`; screens
/// only local to one route get their Bloc here.
Widget _screenFor(GamePhase phase, BuildContext context, VoidCallback onRestart) {
  final run = context.read<RunBloc>();
  switch (phase) {
    case GamePhase.characterCreation:
      return BlocProvider(
        create: (_) => CharacterCreationBloc(context.read<CharacterAdapter>()),
        child: const CharacterCreationScreen(),
      );
    case GamePhase.tome:
      return BlocProvider(
        create: (_) => TomeBloc(
          tomeAdapter: context.read<TomeAdapter>(),
          itemAdapter: context.read<ItemAdapter>(),
          characterAdapter: context.read<CharacterAdapter>(),
          techniqueAdapter: context.read<TechniqueAdapter>(),
        ),
        child: const TomeScreen(),
      );
    case GamePhase.trainingPreparation:
      return TrainingPreparationScreen(
        subject: run.state.trainingSubject ?? '',
        isTechnique: run.state.trainingIsTechnique,
      );
    case GamePhase.training:
      return const TrainingExerciseScreen();
    case GamePhase.trainingResult:
      return const TrainingResultScreen();
    case GamePhase.combatPreparation:
      final enemy = _enemyFor(run.state.fightIndex);
      return CombatPreparationScreen(enemyId: enemy.id, enemyHealth: enemy.health);
    case GamePhase.combat:
      final enemy = _enemyFor(run.state.fightIndex);
      return BlocProvider(
        create: (_) => CombatBloc(context.read<CombatAdapter>()),
        child: CombatScreen(
          enemyId: enemy.id,
          enemyHealth: enemy.health,
          enemyDamage: enemy.damage,
          enemyDamageStat: enemy.stat,
          playerName: context.read<CharacterAdapter>().currentView().name,
          // Win -> loot then back to the Tome for the next bout. Lose ->
          // the run is over. The run only ends when the player falls.
          onFinished: (won) => run.add(PhaseCompleted(
            won ? GamePhase.loot : GamePhase.runComplete,
          )),
        ),
      );
    case GamePhase.loot:
      return BlocProvider(
        create: (_) => LootBloc(context.read<RewardAdapter>()),
        child: LootScreen(
          onApplied: () => run.add(const PhaseCompleted(GamePhase.tome)),
        ),
      );
    case GamePhase.runComplete:
      return RunCompleteScreen(
        fightsWon: run.state.fightIndex,
        onRestart: onRestart,
      );
  }
}

GoRouter appRouter(RunBloc runBloc, {required VoidCallback onRestart}) => GoRouter(
      initialLocation: _pathFor(runBloc.state.phase),
      refreshListenable: _RunBlocListenable(runBloc),
      redirect: (context, state) => _pathFor(runBloc.state.phase),
      routes: [
        for (final phase in GamePhase.values)
          GoRoute(
            path: _pathFor(phase),
            builder: (context, state) => _screenFor(phase, context, onRestart),
          ),
      ],
    );
