// lib/features/training/training_state.dart
import '../../core/models/training_result_view.dart';

class TrainingState {
  const TrainingState({
    this.subject,
    this.isTechnique = false,
    this.attemptsSubmitted = 0,
    this.result,
  });
  final String? subject;
  final bool isTechnique;
  final int attemptsSubmitted;
  final TrainingResultView? result;

  TrainingState copyWith({
    String? subject,
    bool? isTechnique,
    int? attemptsSubmitted,
    TrainingResultView? result,
  }) =>
      TrainingState(
        subject: subject ?? this.subject,
        isTechnique: isTechnique ?? this.isTechnique,
        attemptsSubmitted: attemptsSubmitted ?? this.attemptsSubmitted,
        result: result ?? this.result,
      );
}
