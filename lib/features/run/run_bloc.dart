// lib/features/run/run_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/models/game_phase.dart';
import 'run_event.dart';
import 'run_state.dart';

export 'run_state.dart';

class RunBloc extends Bloc<RunEvent, RunState> {
  RunBloc() : super(const RunState()) {
    on<PhaseCompleted>((event, emit) {
      final advancingAfterLoot =
          event.next == GamePhase.tome && state.phase == GamePhase.loot;
      emit(state.copyWith(
        phase: event.next,
        fightIndex: advancingAfterLoot ? state.fightIndex + 1 : state.fightIndex,
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
