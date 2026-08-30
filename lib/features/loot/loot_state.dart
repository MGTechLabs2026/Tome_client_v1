// lib/features/loot/loot_state.dart
import '../../core/models/loot_option_view.dart';

class LootState {
  const LootState({this.options = const [], this.applied = false});
  final List<LootOptionView> options;
  final bool applied;
}
