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

/// Take a hung component off the board — it drops back to the loose
/// rack (items) or the technique tray (techniques). Nothing is
/// destroyed; the ownership / discovery / mastery state is untouched.
class ComponentRemoved extends TomeEvent {
  const ComponentRemoved(this.slotId);
  final String slotId;
}

/// Spend one banked upgrade point on [definitionId] — a permanent +2 to
/// its combat stat.
class ComponentUpgraded extends TomeEvent {
  const ComponentUpgraded(this.definitionId);
  final String definitionId;
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
