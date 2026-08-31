// lib/features/training/training_event.dart
import 'exercise/target_strike_controller.dart' show TrainingRunSummary;

sealed class TrainingEvent {
  const TrainingEvent();
}

/// Enters a session for [subject] (an item or, when [isTechnique],
/// a technique). Fired from the preparation screen.
class TrainingSessionStarted extends TrainingEvent {
  const TrainingSessionStarted(this.subject, this.isTechnique);
  final String subject;
  final bool isTechnique;
}

/// The interactive exercise finished. [attemptMeasurements] is one
/// opaque measurement bag per resolved target (Precision + Reaction
/// keys); [summary] is the client-side performance read for the result
/// screen. The bloc wraps the bags in `TrainingAttempt`s and hands them
/// to the engine via `TrainingAdapter`.
class TrainingRunCompleted extends TrainingEvent {
  const TrainingRunCompleted(this.attemptMeasurements, this.summary);
  final List<Map<String, double>> attemptMeasurements;
  final TrainingRunSummary summary;
}
