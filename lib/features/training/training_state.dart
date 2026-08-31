// lib/features/training/training_state.dart
import '../../core/models/training_result_view.dart';
import 'exercise/target_strike_controller.dart' show TrainingRunSummary;

class TrainingState {
  const TrainingState({
    this.subject,
    this.isTechnique = false,
    this.result,
    this.summary,
  });

  final String? subject;
  final bool isTechnique;

  /// The engine's verdict — source of truth for gain / learning /
  /// evolution. Null until the exercise finishes.
  final TrainingResultView? result;

  /// The client-side performance read (hits / perfect / misses / avg
  /// reaction / precision) shown alongside the engine result.
  final TrainingRunSummary? summary;

  TrainingState copyWith({
    String? subject,
    bool? isTechnique,
    TrainingResultView? result,
    TrainingRunSummary? summary,
  }) =>
      TrainingState(
        subject: subject ?? this.subject,
        isTechnique: isTechnique ?? this.isTechnique,
        result: result ?? this.result,
        summary: summary ?? this.summary,
      );
}
