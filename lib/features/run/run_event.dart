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
/// what comes next:
///
/// * more bouts remain -> straight into the next bout's preparation
///   (there is no Tome mid-run);
/// * that was the final (hard) bout -> the run is cleared: advance to
///   the next, longer run and open the Tome to strategise. The
///   character and build carry over.
class LootResolved extends RunEvent {
  const LootResolved();
}

/// Player picked a component to train from the Tome; carries the choice
/// into the training flow and advances to trainingPreparation.
class TrainingRequested extends RunEvent {
  const TrainingRequested(this.subject, {required this.isTechnique});
  final String subject;
  final bool isTechnique;
}

/// Reset all run tracking to a fresh run 1 (a brand-new fighter — the
/// app rebuilds the engine session around it).
class RunReset extends RunEvent {
  const RunReset();
}
