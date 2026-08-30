// lib/features/run/run_event.dart
import '../../core/models/game_phase.dart';

sealed class RunEvent {
  const RunEvent();
}

class RunStarted extends RunEvent {
  const RunStarted();
}

class PhaseCompleted extends RunEvent {
  const PhaseCompleted(this.next);
  final GamePhase next;
}

/// Player picked a component to train from the Tome; carries the choice
/// into the training flow and advances to trainingPreparation.
class TrainingRequested extends RunEvent {
  const TrainingRequested(this.subject, {required this.isTechnique});
  final String subject;
  final bool isTechnique;
}

/// "Start New Run" — resets phase/fight tracking to the beginning.
class RunReset extends RunEvent {
  const RunReset();
}
