// lib/features/run/run_state.dart
import '../../core/models/game_phase.dart';

class RunState {
  const RunState({this.phase = GamePhase.characterCreation});
  final GamePhase phase;

  @override
  bool operator ==(Object other) => other is RunState && other.phase == phase;
  @override
  int get hashCode => phase.hashCode;
}
