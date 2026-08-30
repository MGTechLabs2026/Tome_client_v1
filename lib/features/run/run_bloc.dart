// lib/features/run/run_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/models/game_phase.dart';
import 'run_event.dart';
import 'run_state.dart';

export 'run_state.dart';

class RunBloc extends Bloc<RunEvent, RunState> {
  RunBloc() : super(const RunState()) {
    // Plain phase moves. Progression rules live in the LootResolved /
    // RunAdvanced handlers, not here.
    on<PhaseCompleted>((event, emit) {
      emit(state.copyWith(phase: event.next));
    });

    // Loot taken after a bout: advance to the next bout of this run, or
    // end the run if that was the final (hard) fight.
    on<LootResolved>((event, emit) {
      if (state.hasNextFight) {
        emit(state.copyWith(
          phase: GamePhase.tome,
          fightIndex: state.fightIndex + 1,
        ));
      } else {
        emit(state.copyWith(phase: GamePhase.runComplete));
      }
    });

    // Start the next run — character and build carry over.
    on<RunAdvanced>((event, emit) {
      final next = state.runNumber + 1;
      emit(state.copyWith(
        phase: GamePhase.tome,
        runNumber: next,
        fightIndex: 0,
        fightsInCurrentRun: fightsForRun(next),
      ));
    });

    on<TrainingRequested>((event, emit) {
      emit(state.copyWith(
        phase: GamePhase.trainingPreparation,
        trainingSubject: event.subject,
        trainingIsTechnique: event.isTechnique,
      ));
    });

    on<RunReset>((event, emit) => emit(const RunState()));
  }
}
