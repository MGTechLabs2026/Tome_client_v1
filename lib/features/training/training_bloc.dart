// lib/features/training/training_bloc.dart
//
// This Bloc is the one file outside `lib/core/engine/` cleared to touch
// `package:build_engine` types: `TrainingAttempt` is a plain
// string-keyed measurement bag, and `TargetStrikeExercise` is a
// client-owned composition of the engine's own pure exercises — neither
// is an engine service or rule. Wrapping the exercise's raw measurement
// maps here keeps `TrainingAdapter`'s surface from needing a
// pass-through for every attempt shape a future exercise invents.
import 'package:build_engine/build_engine.dart' show TrainingAttempt;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/engine/target_strike_exercise.dart';
import '../../core/engine/training_adapter.dart';
import 'training_event.dart';
import 'training_state.dart';

export 'training_state.dart';

class TrainingBloc extends Bloc<TrainingEvent, TrainingState> {
  TrainingBloc(this._adapter) : super(const TrainingState()) {
    on<TrainingSessionStarted>((event, emit) {
      emit(TrainingState(
        subject: event.subject,
        isTechnique: event.isTechnique,
      ));
    });

    on<TrainingRunCompleted>((event, emit) {
      final attempts = [
        for (final m in event.attemptMeasurements) TrainingAttempt(m),
      ];
      const exercise = TargetStrikeExercise();
      final result = state.isTechnique
          ? _adapter.trainTechnique(state.subject!, attempts, base: exercise)
          : _adapter.trainItem(state.subject!, attempts, base: exercise);
      emit(state.copyWith(result: result, summary: event.summary));
    });
  }

  final TrainingAdapter _adapter;
}
