// lib/features/combat/combat_state.dart
import '../../core/models/combat_log_entry_view.dart';
import '../../core/models/combat_tally_view.dart';

class CombatState {
  const CombatState({
    this.inProgress = false,
    this.won,
    this.log = const [],
    this.tally,
  });

  final bool inProgress;
  final bool? won;
  final List<CombatLogEntryView> log;

  /// What the fight recorded — hits/misses by component, defence held —
  /// set once the fight has run. Null before it runs.
  final CombatTally? tally;
}
