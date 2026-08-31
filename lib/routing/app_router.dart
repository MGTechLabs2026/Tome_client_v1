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
import '../core/models/enemy_roster.dart';
import '../core/models/game_phase.dart';
import '../core/persistence/codex_repository.dart';
import '../core/persistence/records_repository.dart';
import '../features/character_creation/character_creation_bloc.dart';
import '../features/character_creation/character_creation_screen.dart';
import '../features/combat/combat_bloc.dart';
import '../features/combat/combat_preparation_screen.dart';
import '../features/combat/combat_screen.dart';
import '../features/defeat/defeat_screen.dart';
import '../features/loot/loot_bloc.dart';
import '../features/loot/loot_screen.dart';
import '../features/run/run_bloc.dart';
import '../features/run/run_event.dart';
import '../features/title/title_screen.dart';
import '../features/tome/tome_bloc.dart';
import '../features/tome/tome_screen.dart';
import '../features/training/active_training_screen.dart';
import '../features/training/training_preparation_screen.dart';
import '../features/training/training_result_screen.dart';

String _pathFor(GamePhase phase) => switch (phase) {
      GamePhase.title => '/title',
      GamePhase.characterCreation => '/character-creation',
      GamePhase.tome => '/tome',
      GamePhase.trainingPreparation => '/training/prepare',
      GamePhase.training => '/training/exercise',
      GamePhase.trainingResult => '/training/result',
      GamePhase.combatPreparation => '/combat/prepare',
      GamePhase.combat => '/combat',
      GamePhase.loot => '/loot',
      GamePhase.defeat => '/defeat',
    };

/// "RUN 1 · BOUT 2 / 3" — the run/bout position for the prep screen.
String _boutLabel(RunState run) {
  final base = 'RUN ${run.runNumber}  ·  BOUT ${run.fightIndex + 1} / '
      '${run.fightsInCurrentRun}';
  return run.isHardFight ? '$base  ·  HARD FIGHT' : base;
}

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
Widget _screenFor(GamePhase phase, BuildContext context) {
  final run = context.read<RunBloc>();
  switch (phase) {
    case GamePhase.title:
      return const TitleScreen();
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
          // Records the fighter's style to the cross-run codex on the
          // first refresh (idempotent) — see TomeBloc.
          codex: context.read<CodexRepository>(),
        ),
        child: const TomeScreen(),
      );
    case GamePhase.trainingPreparation:
      return TrainingPreparationScreen(
        subject: run.state.trainingSubject ?? '',
        isTechnique: run.state.trainingIsTechnique,
      );
    case GamePhase.training:
      return const ActiveTrainingScreen();
    case GamePhase.trainingResult:
      return const TrainingResultScreen();
    case GamePhase.combatPreparation:
      return CombatPreparationScreen(
        enemy: enemyFor(run.state),
        isHardFight: run.state.isHardFight,
        boutLabel: _boutLabel(run.state),
      );
    case GamePhase.combat:
      return BlocProvider(
        create: (_) => CombatBloc(context.read<CombatAdapter>()),
        child: CombatScreen(
          enemy: enemyFor(run.state),
          playerName: context.read<CharacterAdapter>().currentView().name,
          isHardFight: run.state.isHardFight,
          // A won bout goes on to loot (RunBloc decides on LootResolved
          // whether another bout follows or the run is cleared). A lost
          // bout ends the run — the defeat beat, then the title screen.
          onFinished: (won) {
            if (won) {
              run.add(const PhaseCompleted(GamePhase.loot));
            } else {
              context.read<RecordsRepository>().recordRunEnded(
                    runNumber: run.state.runNumber,
                    bouts: run.state.fightIndex + 1,
                  );
              run.add(const RunEnded());
            }
          },
        ),
      );
    case GamePhase.loot:
      return BlocProvider(
        create: (_) => LootBloc(context.read<RewardAdapter>()),
        child: LootScreen(
          onApplied: () {
            // Clearing a run heals the fighter to full for the next one
            // and lands a mark on the RECORDS ledger.
            if (!run.state.hasNextFight) {
              context.read<CharacterAdapter>().restoreVitality();
              context.read<RecordsRepository>().recordRunCleared(
                    runNumber: run.state.runNumber,
                    bouts: run.state.fightsInCurrentRun,
                  );
            }
            run.add(const LootResolved());
          },
        ),
      );
    case GamePhase.defeat:
      return DefeatScreen(
        runNumber: run.state.runNumber,
        bout: run.state.fightIndex + 1,
      );
  }
}

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
