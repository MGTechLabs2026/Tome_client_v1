import 'package:build_engine/build_engine.dart';
import 'package:build_engine/build_interpretation.dart' show WeaponStatTags;
import 'package:build_engine/item_plugin.dart';

import '../models/combine_result_view.dart';
import '../models/item_view.dart';
import 'engine_session.dart';

class ItemAdapter {
  ItemAdapter(this._session);

  final EngineSession _session;

  /// Upgrade points sunk into each *copy* so far — the `+N` on its name.
  /// Keyed by the `ItemInstance` entity's raw value, so a freshly
  /// rewarded copy of an already-upgraded item starts at +0 and carries
  /// its own cap. The matching `+2` is bound to the same copy via
  /// `addItemStatBonuses`, so it only bites while that copy is hung and
  /// rides through Combine — exactly like an affix.
  final Map<int, int> _upgradesByInstance = {};

  /// Prefix / suffix labels for a rewarded item instance — keyed by the
  /// `ItemInstance` entity's raw value, so two copies of the same id can
  /// carry different rolls. Set by `RewardAdapter` when the card is taken.
  final Map<int, ({String? prefix, String? suffix})> _affixByInstance = {};

  /// Records the rolled affix name for the instance minted when a
  /// rewarded item was taken.
  void recordAffix(int instanceEntityValue, {String? prefix, String? suffix}) {
    if (prefix == null && suffix == null) return;
    _affixByInstance[instanceEntityValue] = (prefix: prefix, suffix: suffix);
  }

  String _prettyDef(String id) => id
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  /// The `+N` ceiling for a copy of [itemClass]: `2 * class + 1` —
  /// class 1 -> 3, class 2 -> 5, class 3 -> 7, and +2 per class beyond.
  int _capForClass(int itemClass) => 2 * itemClass + 1;

  /// The character's banked `upgrade_points` — the currency Combine and
  /// the hammer-icon upgrade path both spend. A pure read for the Tome
  /// screen's foot-bar tally.
  int upgradePoints() =>
      _session.context.resources
          .currentOf(_session.character, ItemResources.upgradePoints)
          .round();

  /// Every `ItemInstance` entity [_session.character] owns, grouped by
  /// `(definitionId, itemClass)` — the exact key `canCombine`/
  /// `combineItems` require inputs to share.
  Map<(String, int), List<EntityId>> _ownedInstancesByKey() {
    final grouped = <(String, int), List<EntityId>>{};
    for (final entity
        in _session.context.components.entitiesWith<ItemInstance>()) {
      final instance = _session.context.components.get<ItemInstance>(entity)!;
      if (instance.owner != _session.character) continue;
      grouped
          .putIfAbsent((instance.definitionId, instance.itemClass), () => [])
          .add(entity);
    }
    return grouped;
  }

  ItemView _viewFor(
    String definitionId,
    EntityId? instanceEntity,
    Map<(String, int), List<EntityId>> grouped,
  ) {
    final item = itemDefinition(definitionId, _session.context);
    final owned = isItemOwned(
      _session.character,
      definitionId,
      _session.context,
    );
    final usable =
        owned && isItemUsable(_session.character, item, _session.context);
    final active =
        owned &&
        isItemActive(_session.character, definitionId, _session.context);
    final masterySubject =
        item.requirement?.masterySubject ?? itemSubject(definitionId);
    final masteryLevel = _session.context.mastery.levelOf(
      _session.character,
      masterySubject,
    );
    final masteryProgress = _session.context.mastery.progressOf(
      _session.character,
      masterySubject,
    );
    final thresholds =
        _session.context.mastery.definitionOf(masterySubject)?.thresholds ??
        const <num>[];
    final instanceComp = instanceEntity == null
        ? null
        : _session.context.components.get<ItemInstance>(instanceEntity);
    final itemClass = instanceComp?.itemClass ?? 1;

    final state =
        active
            ? ItemDisplayState.equipped
            : (item.maxClass != null && itemClass >= item.maxClass!)
            ? ItemDisplayState.mastered
            : usable
            ? ItemDisplayState.usable
            : ItemDisplayState.locked;

    final matchedInstances =
        instanceEntity == null
            ? const <EntityId>[]
            : (grouped[(definitionId, itemClass)] ?? const <EntityId>[])
                .where((e) => e != instanceEntity)
                .toList();
    final combinableWith = matchedInstances.map((e) => e.value).toList();

    // `eligibleToCombine` answers "does Task 2's non-throwing canCombine
    // pre-check currently return true for this instance paired with its
    // first combinableWith match" — false whenever there's no match at
    // all, or the matched pair is maxed out with no eligible grade path.
    final eligibleToCombine =
        instanceEntity != null && matchedInstances.isNotEmpty
            ? canCombine(_session.character, [
              instanceEntity,
              matchedInstances.first,
            ], _session.context)
            : false;

    return ItemView(
      definitionId: definitionId,
      name: definitionId,
      category: item.category,
      properties: item.properties,
      state: state,
      itemClass: itemClass,
      maxClass: item.maxClass,
      masteryLevel: masteryLevel,
      masteryProgress: masteryProgress,
      masteryThresholds: List<num>.from(thresholds),
      instanceEntityValue: instanceEntity?.value,
      combinableWith: combinableWith,
      eligibleToCombine: eligibleToCombine,
      upgradeCount: _upgradesByInstance[instanceEntity?.value] ?? 0,
      upgradeCap: _capForClass(itemClass),
      displayName: _displayName(definitionId, instanceEntity?.value),
      // `statBonuses` now carries both rolled affixes and spent upgrade
      // points (both land there, bound to the copy). The detail sheet's
      // "AFFIXES while hung" row wants only the affix share, so subtract
      // the +2-per-upgrade portion back out.
      affixBonus: () {
        final total = instanceComp?.statBonuses.values
                .fold<num>(0, (a, b) => a + b) ??
            0;
        final upgradePortion =
            2 * (_upgradesByInstance[instanceEntity?.value] ?? 0);
        return (total - upgradePortion).clamp(0, total).round();
      }(),
    );
  }

  String _displayName(String definitionId, int? instanceValue) {
    final base = _prettyDef(definitionId);
    final affix = instanceValue == null ? null : _affixByInstance[instanceValue];
    if (affix == null) return base;
    return [affix.prefix, base, affix.suffix]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');
  }

  List<ItemView> ownedItems() {
    final grouped = _ownedInstancesByKey();
    return [
      for (final entry in grouped.entries)
        for (final instance in entry.value)
          _viewFor(entry.key.$1, instance, grouped),
    ];
  }

  ItemView viewOf(String definitionId) {
    final grouped = _ownedInstancesByKey();
    final firstOwned = grouped.entries.firstWhere(
      (e) => e.key.$1 == definitionId,
      orElse: () => MapEntry((definitionId, 1), const []),
    );
    final instance = firstOwned.value.isEmpty ? null : firstOwned.value.first;
    return _viewFor(definitionId, instance, grouped);
  }

  /// Spends one banked upgrade point on a single owned copy — the one
  /// whose `ItemInstance` entity has raw value [instanceEntityValue] —
  /// giving that copy's combat stat a permanent +2. The bonus is bound
  /// to the copy via `addItemStatBonuses` (same path rolled affixes
  /// take): it only bites while that copy is hung, and rides through
  /// Combine on the survivor. Returns false and does nothing when the
  /// copy is gone or unowned, no point is banked, or the copy is
  /// already at its class `+N` ceiling.
  bool spendUpgradePoint(int instanceEntityValue) {
    final entity = EntityId(instanceEntityValue);
    final instance = _session.context.components.get<ItemInstance>(entity);
    if (instance == null || instance.owner != _session.character) return false;
    if ((_upgradesByInstance[instanceEntityValue] ?? 0) >=
        _capForClass(instance.itemClass)) {
      return false;
    }
    final points = _session.context.resources
        .currentOf(_session.character, ItemResources.upgradePoints);
    if (points < 1) return false;
    _session.context.resources
        .subtract(_session.character, ItemResources.upgradePoints, 1);
    _upgradesByInstance[instanceEntityValue] =
        (_upgradesByInstance[instanceEntityValue] ?? 0) + 1;
    final item = itemDefinition(instance.definitionId, _session.context);
    final stat = WeaponStatTags.matchOrFallback(
        item.tags, 'item:${instance.definitionId}');
    addItemStatBonuses(entity, {stat: 2}, _session.context);
    return true;
  }

  /// Resolves [instanceEntityValues] back to `EntityId`s and calls
  /// `combineItems`. `combineItems` returns only the surviving entity's
  /// id (not the `CombineOutcome` directly), so the outcome kind is
  /// re-derived here by capturing the first input's pre-call
  /// `definitionId`/`itemClass` and comparing against the survivor's
  /// post-call state: unchanged both = `fail`; same id, class increased
  /// = `classUpgraded`; different id = `evolvedIntoNewItem`. This keeps
  /// `combine()` synchronous and self-contained rather than subscribing
  /// to `ItemCombineSucceeded`/`ItemCombineFailed`.
  CombineResultView combine(List<int> instanceEntityValues) {
    final entities = [for (final v in instanceEntityValues) EntityId(v)];
    final before =
        _session.context.components.get<ItemInstance>(entities.first)!;
    final survivor = combineItems(
      _session.character,
      entities,
      _session.context,
    );
    final after = _session.context.components.get<ItemInstance>(survivor)!;

    // The non-survivors are destroyed — drop their per-copy bookkeeping.
    // The survivor keeps its own upgrade count and affix labels
    // (`combineItems` already carries its `statBonuses` forward).
    for (final v in instanceEntityValues) {
      if (v == survivor.value) continue;
      _upgradesByInstance.remove(v);
      _affixByInstance.remove(v);
    }

    final kind =
        after.definitionId != before.definitionId
            ? CombineResultKind.evolvedIntoNewItem
            : after.itemClass > before.itemClass
            ? CombineResultKind.classUpgraded
            : CombineResultKind.fail;

    return CombineResultView(
      kind: kind,
      resultingDefinitionId: after.definitionId,
      resultingItemClass: after.itemClass,
    );
  }
}
