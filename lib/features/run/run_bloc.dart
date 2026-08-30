// lib/features/run/run_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import 'run_event.dart';
import 'run_state.dart';

class RunBloc extends Bloc<RunEvent, RunState> {
  RunBloc() : super(const RunState()) {
    on<PhaseCompleted>((event, emit) => emit(RunState(phase: event.next)));
  }
}
