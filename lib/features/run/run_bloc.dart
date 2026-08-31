// lib/features/run/run_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/models/game_phase.dart';
import 'run_event.dart';
import 'run_state.dart';

export 'run_state.dart';

class RunBloc extends Bloc<RunEvent, RunState> {
  RunBloc() : super(const RunState()) {
    // Plain phase moves. Progression rules live in LootResolved.
    on<PhaseCompleted>((event, emit) {
      // Ignore a redundant move to the phase we're already in (e.g. the
      // combat replay re-announcing "-> loot" after navigation): churning
      // the router would rebuild the destination screen's Bloc.
      if (event.next == state.phase) return;
      emit(state.copyWith(phase: event.next));
    });

    // Loot taken after a bout.
    on<LootResolved>((event, emit) {
      if (state.hasNextFight) {
        // Straight into the next bout — the Tome does not open mid-run.
        emit(state.copyWith(
          phase: GamePhase.combatPreparation,
          fightIndex: state.fightIndex + 1,
        ));
      } else {
        // Run cleared: advance to the next, longer run and open the Tome
        // to strategise. Character and build carry over.
        final next = state.runNumber + 1;
        emit(state.copyWith(
          phase: GamePhase.tome,
          runNumber: next,
          fightIndex: 0,
          fightsInCurrentRun: fightsForRun(next),
        ));
      }
    });

    on<NewRunRequested>((event, emit) {
      emit(RunState(
        phase: GamePhase.characterCreation,
        sessionSeed: DateTime.now().millisecondsSinceEpoch,
      ));
    });

    on<RunEnded>((event, emit) {
      emit(state.copyWith(phase: GamePhase.defeat));
    });

    on<TrainingRequested>((event, emit) {
      emit(state.copyWith(
        phase: GamePhase.trainingPreparation,
        trainingSubject: event.subject,
        trainingIsTechnique: event.isTechnique,
      ));
    });

    // Back to the title screen. The seed is kept as-is so sitting on
    // the threshold doesn't churn the (now idle) engine session; the
    // next NEW RUN bumps it.
    on<RunReset>((event, emit) => emit(RunState(sessionSeed: state.sessionSeed)));
  }
}
