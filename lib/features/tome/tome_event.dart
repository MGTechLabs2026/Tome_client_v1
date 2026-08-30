// lib/features/tome/tome_event.dart
sealed class TomeEvent {
  const TomeEvent();
}

class TomeRefreshRequested extends TomeEvent {
  const TomeRefreshRequested();
}

class ComponentMoved extends TomeEvent {
  const ComponentMoved(this.fromSlotId, this.toSlotId);
  final String fromSlotId;
  final String toSlotId;
}

class ComponentInserted extends TomeEvent {
  const ComponentInserted({
    required this.definitionId,
    required this.slotId,
    required this.isTechnique,
  });
  final String definitionId;
  final String slotId;
  final bool isTechnique;
}
