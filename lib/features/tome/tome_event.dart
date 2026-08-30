// lib/features/tome/tome_event.dart
sealed class TomeEvent {
  const TomeEvent();
}

class TomeRefreshRequested extends TomeEvent {
  const TomeRefreshRequested();
}

class FirstRunCalloutDismissed extends TomeEvent {
  const FirstRunCalloutDismissed();
}

class ComponentMoved extends TomeEvent {
  const ComponentMoved(this.fromSlotId, this.toSlotId);
  final String fromSlotId;
  final String toSlotId;
}

class CombineRequested extends TomeEvent {
  const CombineRequested(this.instanceEntityValues);
  final List<int> instanceEntityValues;
}

class ComponentInserted extends TomeEvent {
  const ComponentInserted({
    required this.definitionId,
    required this.slotId,
    required this.isTechnique,
    this.instanceEntityValue,
  });
  final String definitionId;
  final String slotId;
  final bool isTechnique;

  /// For an already-owned item dragged from the rack: the specific copy
  /// to place, so it is not re-minted. Null for the grant path and for
  /// techniques.
  final int? instanceEntityValue;
}
