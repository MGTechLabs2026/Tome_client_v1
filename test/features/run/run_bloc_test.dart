// test/features/run/run_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/models/game_phase.dart';
import 'package:tome_client/features/run/run_bloc.dart';
import 'package:tome_client/features/run/run_event.dart';
import 'package:tome_client/features/run/run_state.dart';

void main() {
  test('RunState defaults to the characterCreation phase', () {
    expect(const RunState().phase, GamePhase.characterCreation);
  });

  blocTest<RunBloc, RunState>(
    'advances to the phase carried by PhaseCompleted',
    build: RunBloc.new,
    act: (bloc) => bloc.add(const PhaseCompleted(GamePhase.tome)),
    expect: () => [const RunState(phase: GamePhase.tome)],
  );
}
