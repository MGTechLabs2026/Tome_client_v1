// lib/features/training/training_event.dart
sealed class TrainingEvent {
  const TrainingEvent();
}

class TrainingSessionStarted extends TrainingEvent {
  const TrainingSessionStarted(this.subject, this.isTechnique);
  final String subject;
  final bool isTechnique;
}

class AttemptSubmitted extends TrainingEvent {
  const AttemptSubmitted(this.timestampMs);
  final double timestampMs;
}

class TrainingCompleted extends TrainingEvent {
  const TrainingCompleted();
}
