// lib/features/combat/combat_state.dart
import '../../core/models/combat_log_entry_view.dart';

class CombatState {
  const CombatState({this.inProgress = false, this.won, this.log = const []});
  final bool inProgress;
  final bool? won;
  final List<CombatLogEntryView> log;
}
