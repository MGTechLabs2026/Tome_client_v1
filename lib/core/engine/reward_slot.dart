import 'package:build_engine/affix_plugin.dart' show AffixResolution;

/// The resolved content of one reward card — decided once per
/// [RewardAdapter.offerLoot] and applied verbatim on TAKE.
///
/// Slot identity (`LootKind`) is separate: one offer has exactly one
/// payload per slot —
///
/// ```text
/// SLOT 1 progression → UpgradePointReward
/// SLOT 2 utility     → TomeSlotReward | ConsumableReward
/// SLOT 3 component   → ItemReward | TechniqueReward
/// ```
sealed class RewardSlotPayload {
  const RewardSlotPayload();
}

/// SLOT 1. Taking it adds exactly `ItemResources.upgradePoints += 1`.
class UpgradePointReward extends RewardSlotPayload {
  const UpgradePointReward();
}

/// SLOT 2, tome-slot branch. Taking it grows the Tome through the
/// existing `TomeAdapter.expandGrid()` — the client's tome-slot unlock.
class TomeSlotReward extends RewardSlotPayload {
  const TomeSlotReward();
}

/// SLOT 2, consumable branch. [id] is an engine `ConsumableIds` value
/// drawn from the registered `type: 'consumable'` content. Taking it
/// hangs the consumable in the Tome via `consumableReferenceType`; the
/// effect fires later through the engine's combat interpretation, never
/// on TAKE.
class ConsumableReward extends RewardSlotPayload {
  const ConsumableReward(this.id);
  final String id;
}

/// SLOT 3, item branch. Carries the engine [affixResolution] resolved at
/// offer time so preview and TAKE agree.
class ItemReward extends RewardSlotPayload {
  const ItemReward({required this.id, required this.affixResolution});
  final String id;
  final AffixResolution affixResolution;
}

/// SLOT 3, technique branch.
class TechniqueReward extends RewardSlotPayload {
  const TechniqueReward({required this.id, required this.affixResolution});
  final String id;
  final AffixResolution affixResolution;
}
