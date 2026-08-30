enum ItemDisplayState { locked, usable, mastered, equipped }

class ItemView {
  const ItemView({
    required this.definitionId,
    required this.name,
    required this.category,
    required this.properties,
    required this.state,
    required this.itemClass,
    required this.maxClass,
    required this.masteryLevel,
    required this.masteryProgress,
    required this.masteryThresholds,
    required this.instanceEntityValue,
    required this.combinableWith,
    required this.eligibleToCombine,
  });

  final String definitionId;
  final String name;
  final String category;
  final Map<String, num> properties;
  final ItemDisplayState state;
  final int itemClass;
  final int? maxClass;
  final int masteryLevel;
  final num masteryProgress;
  final List<num> masteryThresholds;

  /// This specific owned copy's entity id (raw `EntityId.value`) — null
  /// for a definition-level view with no single copy in context.
  final int? instanceEntityValue;

  /// Other owned instance entity values (raw `EntityId.value`) sharing
  /// this item's `definitionId`+`itemClass` right now — the Tome
  /// screen draws a tether to each of these. Empty if none.
  final List<int> combinableWith;

  /// Whether `canCombine` (the engine's non-throwing Combine
  /// eligibility pre-check) currently returns true for this instance
  /// paired with the first entry in `combinableWith` — false when
  /// `combinableWith` is empty, or when matched items are maxed out
  /// with no eligible grade path. Drives the Tome screen's bright
  /// (eligible) vs. dim (matched-but-ineligible) combine tether — see
  /// Task 17.
  final bool eligibleToCombine;
}
