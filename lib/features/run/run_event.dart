// lib/features/run/run_event.dart
import '../../core/models/game_phase.dart';

sealed class RunEvent {
  const RunEvent();
}

class RunStarted extends RunEvent {
  const RunStarted();
}

/// A plain phase move — combat -> loot, tome -> combatPreparation, and
/// every step of the training flow. Progression decisions (does another
/// bout follow? is the run over?) are NOT expressed this way; see
/// [LootResolved].
class PhaseCompleted extends RunEvent {
  const PhaseCompleted(this.next);
  final GamePhase next;
}

/// The player has taken their loot after a bout. The run orchestrates
/// what comes next: the Tome for the next bout, or the run-complete
/// screen if that was the final (hard) fight.
class LootResolved extends RunEvent {
  const LootResolved();
}

/// The player chose to start the next run from the run-complete screen.
/// Bumps `runNumber`, resets `fightIndex`, and recomputes
/// `fightsInCurrentRun`; the character and build carry over.
class RunAdvanced extends RunEvent {
  const RunAdvanced();
}

/// Player picked a component to train from the Tome; carries the choice
/// into the training flow and advances to trainingPreparation.
class TrainingRequested extends RunEvent {
  const TrainingRequested(this.subject, {required this.isTechnique});
  final String subject;
  final bool isTechnique;
}

/// "Start Over" — a fresh character. Resets all run tracking to the
/// beginning; the app rebuilds the engine session around it.
class RunReset extends RunEvent {
  const RunReset();
}
