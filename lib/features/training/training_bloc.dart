// lib/features/training/training_bloc.dart
//
// This Bloc is the one deliberate exception to "package:build_engine
// imports live only in core/engine/": TrainingAttempt is a plain data
// payload (windowStart/windowEnd/actual timestamps), not an engine
// service or rule -- constructing one here from raw UI tap timing avoids
// adding a pass-through method to TrainingAdapter for every possible
// attempt shape a future richer exercise might need.
import 'package:build_engine/build_engine.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/engine/training_adapter.dart';
import 'training_event.dart';
import 'training_state.dart';

export 'training_state.dart';

const _windowStart = 100.0;
const _windowEnd = 200.0;

class TrainingBloc extends Bloc<TrainingEvent, TrainingState> {
  TrainingBloc(this._adapter) : super(const TrainingState()) {
    on<TrainingSessionStarted>((event, emit) {
      _attempts.clear();
      emit(TrainingState(subject: event.subject, isTechnique: event.isTechnique));
    });

    on<AttemptSubmitted>((event, emit) {
      _attempts.add(TrainingAttempt({
        'windowStart': _windowStart,
        'windowEnd': _windowEnd,
        'actual': event.timestampMs,
      }));
      emit(state.copyWith(attemptsSubmitted: _attempts.length));
    });

    on<TrainingCompleted>((event, emit) {
      final result = state.isTechnique
          ? _adapter.trainTechnique(state.subject!, _attempts)
          : _adapter.trainItem(state.subject!, _attempts);
      emit(state.copyWith(result: result));
    });
  }

  final TrainingAdapter _adapter;
  final List<TrainingAttempt> _attempts = [];
}
