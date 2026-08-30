// lib/features/loot/loot_event.dart
import '../../core/models/loot_option_view.dart';

sealed class LootEvent {
  const LootEvent();
}

class LootOffered extends LootEvent {
  const LootOffered();
}

class LootChosen extends LootEvent {
  const LootChosen(this.kind);
  final LootKind kind;
}
