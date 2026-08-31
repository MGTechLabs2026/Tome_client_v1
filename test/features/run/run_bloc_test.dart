// test/features/run/run_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/models/game_phase.dart';
import 'package:tome_client/features/run/run_bloc.dart';
import 'package:tome_client/features/run/run_event.dart';

void main() {
  group('fightsForRun — run count drives the ramp', () {
    for (final (run, fights) in const [
      (1, 3),
      (10, 3),
      (11, 5),
      (20, 5),
      (21, 7),
      (30, 7),
      (31, 9),
      (99, 9),
    ]) {
      test('run $run => $fights fights', () {
        expect(fightsForRun(run), fights);
      });
    }
  });

  test('RunState defaults: title screen, run 1, bout 0, three fights', () {
    const s = RunState();
    expect(s.phase, GamePhase.title);
    expect(s.sessionSeed, 1);
    expect(s.runNumber, 1);
    expect(s.fightIndex, 0);
    expect(s.fightsInCurrentRun, 3);
  });

  group('derived flags', () {
    test('bout 0 of a 3-fight run: has next, not final/hard', () {
      const s = RunState(fightIndex: 0, fightsInCurrentRun: 3);
      expect(s.hasNextFight, isTrue);
      expect(s.isFinalFight, isFalse);
      expect(s.isHardFight, isFalse);
    });
    test('last bout of the run: final + hard, no next', () {
      const s = RunState(fightIndex: 2, fightsInCurrentRun: 3);
      expect(s.hasNextFight, isFalse);
      expect(s.isFinalFight, isTrue);
      expect(s.isHardFight, isTrue);
    });
    test('bout 4 of a 5-fight run is the hard fight', () {
      const s = RunState(fightIndex: 4, fightsInCurrentRun: 5);
      expect(s.isHardFight, isTrue);
    });
  });

  blocTest<RunBloc, RunState>(
    'PhaseCompleted just moves the phase',
    build: RunBloc.new,
    act: (bloc) => bloc.add(const PhaseCompleted(GamePhase.combatPreparation)),
    expect: () => [
      const RunState(phase: GamePhase.combatPreparation),
    ],
  );

  blocTest<RunBloc, RunState>(
    'LootResolved mid-run goes straight to the next bout — no Tome',
    build: RunBloc.new,
    seed: () => const RunState(
        phase: GamePhase.loot, fightIndex: 0, fightsInCurrentRun: 3),
    act: (bloc) => bloc.add(const LootResolved()),
    expect: () => [
      const RunState(
          phase: GamePhase.combatPreparation,
          fightIndex: 1,
          fightsInCurrentRun: 3),
    ],
  );

  blocTest<RunBloc, RunState>(
    'LootResolved after the final bout clears the run: next run + Tome',
    build: RunBloc.new,
    seed: () => const RunState(
        phase: GamePhase.loot,
        runNumber: 10,
        fightIndex: 2,
        fightsInCurrentRun: 3),
    act: (bloc) => bloc.add(const LootResolved()),
    expect: () => [
      const RunState(
          phase: GamePhase.tome,
          runNumber: 11,
          fightIndex: 0,
          fightsInCurrentRun: 5),
    ],
  );

  blocTest<RunBloc, RunState>(
    'RunReset returns to the title screen, run tracking wiped',
    build: RunBloc.new,
    seed: () => const RunState(
        phase: GamePhase.loot, runNumber: 4, fightIndex: 6),
    act: (bloc) => bloc.add(const RunReset()),
    expect: () => [const RunState()],
  );

  blocTest<RunBloc, RunState>(
    'NewRunRequested bumps the session seed and drops into creation',
    build: RunBloc.new,
    act: (bloc) => bloc.add(const NewRunRequested()),
    verify: (bloc) {
      expect(bloc.state.phase, GamePhase.characterCreation);
      expect(bloc.state.sessionSeed, isNot(1));
      expect(bloc.state.runNumber, 1);
      expect(bloc.state.fightIndex, 0);
    },
  );

  blocTest<RunBloc, RunState>(
    'RunEnded moves to the defeat beat, keeping the run position',
    build: RunBloc.new,
    seed: () => const RunState(
        phase: GamePhase.combat, runNumber: 3, fightIndex: 1),
    act: (bloc) => bloc.add(const RunEnded()),
    expect: () => [
      const RunState(
          phase: GamePhase.defeat, runNumber: 3, fightIndex: 1),
    ],
  );
}
