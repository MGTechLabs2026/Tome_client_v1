// lib/features/run/run_state.dart
import '../../core/models/game_phase.dart';

/// How many fights run [runNumber] (1-based) contains. The ramp is
/// driven by the run count, not by lifetime fight count:
///
/// * runs 1–10  -> 3 fights
/// * runs 11–20 -> 5 fights
/// * runs 21–30 -> 7 fights
/// * runs 31+   -> 9 fights
///
/// A run is client orchestration, not an engine primitive (spec §2.1),
/// so this progression lives here.
int fightsForRun(int runNumber) {
  if (runNumber <= 10) return 3;
  if (runNumber <= 20) return 5;
  if (runNumber <= 30) return 7;
  return 9;
}

class RunState {
  const RunState({
    this.phase = GamePhase.characterCreation,
    this.runNumber = 1,
    this.fightIndex = 0,
    this.fightsInCurrentRun = 3,
    this.trainingSubject,
    this.trainingIsTechnique = false,
  });

  final GamePhase phase;

  /// Which run this is (1-based). Increments only when the player starts
  /// the next run from the run-complete screen; the character, build and
  /// engine session all persist across runs.
  final int runNumber;

  /// Which bout of the current run is next (0-based) — also how many
  /// bouts of this run have been cleared. Reset to 0 at the start of
  /// every run; incremented on each return to the Tome after Loot.
  final int fightIndex;

  /// The total number of bouts in the current run (`fightsForRun`).
  final int fightsInCurrentRun;

  /// The item/technique definition id the player picked to train, set
  /// when leaving the Tome for the training flow; null outside it.
  final String? trainingSubject;
  final bool trainingIsTechnique;

  /// The last bout of the run — the hard fight.
  bool get isFinalFight => fightIndex >= fightsInCurrentRun - 1;

  /// The final bout of every run is the hard fight.
  bool get isHardFight => isFinalFight;

  /// Another bout remains in this run after the current one.
  bool get hasNextFight => fightIndex < fightsInCurrentRun - 1;

  RunState copyWith({
    GamePhase? phase,
    int? runNumber,
    int? fightIndex,
    int? fightsInCurrentRun,
    String? trainingSubject,
    bool? trainingIsTechnique,
  }) =>
      RunState(
        phase: phase ?? this.phase,
        runNumber: runNumber ?? this.runNumber,
        fightIndex: fightIndex ?? this.fightIndex,
        fightsInCurrentRun: fightsInCurrentRun ?? this.fightsInCurrentRun,
        trainingSubject: trainingSubject ?? this.trainingSubject,
        trainingIsTechnique: trainingIsTechnique ?? this.trainingIsTechnique,
      );

  @override
  bool operator ==(Object other) =>
      other is RunState &&
      other.phase == phase &&
      other.runNumber == runNumber &&
      other.fightIndex == fightIndex &&
      other.fightsInCurrentRun == fightsInCurrentRun &&
      other.trainingSubject == trainingSubject &&
      other.trainingIsTechnique == trainingIsTechnique;

  @override
  int get hashCode => Object.hash(phase, runNumber, fightIndex,
      fightsInCurrentRun, trainingSubject, trainingIsTechnique);
}
