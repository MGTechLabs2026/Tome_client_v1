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
