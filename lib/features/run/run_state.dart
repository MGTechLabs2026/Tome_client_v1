// lib/features/run/run_state.dart
import '../../core/models/game_phase.dart';

class RunState {
  const RunState({
    this.phase = GamePhase.characterCreation,
    this.fightIndex = 0,
    this.trainingSubject,
    this.trainingIsTechnique = false,
  });

  final GamePhase phase;

  /// Which fight of the 3-fight run is next (0-based). The run of 3
  /// fights is client orchestration, not an engine primitive (spec
  /// §2.1) — incremented here on each return to the Tome after Loot.
  final int fightIndex;

  /// The item/technique definition id the player picked to train, set
  /// when leaving the Tome for the training flow; null outside it.
  final String? trainingSubject;
  final bool trainingIsTechnique;

  RunState copyWith({
    GamePhase? phase,
    int? fightIndex,
    String? trainingSubject,
    bool? trainingIsTechnique,
  }) =>
      RunState(
        phase: phase ?? this.phase,
        fightIndex: fightIndex ?? this.fightIndex,
        trainingSubject: trainingSubject ?? this.trainingSubject,
        trainingIsTechnique: trainingIsTechnique ?? this.trainingIsTechnique,
      );

  @override
  bool operator ==(Object other) =>
      other is RunState &&
      other.phase == phase &&
      other.fightIndex == fightIndex &&
      other.trainingSubject == trainingSubject &&
      other.trainingIsTechnique == trainingIsTechnique;

  @override
  int get hashCode => Object.hash(phase, fightIndex, trainingSubject, trainingIsTechnique);
}
