import 'package:build_engine/build_engine.dart';
import 'package:build_engine/build_interpretation.dart' show WeaponStatTags;
import 'package:build_engine/item_plugin.dart';

import '../models/combine_result_view.dart';
import '../models/item_view.dart';
import 'engine_session.dart';

class ItemAdapter {
  ItemAdapter(this._session);

  final EngineSession _session;

  /// Monotonic tag so each spent point adds its own stacking Modifier
  /// (mirrors `TomeManager.upgradeSpendCounter` in the reference run).
  int _spendSeq = 0;

  /// Upgrade points sunk into each item definition so far — the `+N` on
  /// its name. Per-definition, matching the character-level `+2` Modifier
  /// `spendUpgradePoint` adds (keyed by definition id, like the
  /// reference run).
  final Map<String, int> _upgradesByDefinition = {};

  /// The `+N` ceiling for [definitionId]: `2 * c + 1` where `c` is the
  /// highest class among the owned copies (1 if none) — class 1 -> 3,
  /// class 2 -> 5, class 3 -> 7, and +2 for each class beyond.
  int upgradeCapFor(String definitionId) {
    var maxClass = 1;
    for (final entity
        in _session.context.components.entitiesWith<ItemInstance>()) {
      final instance = _session.context.components.get<ItemInstance>(entity)!;
      if (instance.owner != _session.character ||
          instance.definitionId != definitionId) {
        continue;
      }
      if (instance.itemClass > maxClass) maxClass = instance.itemClass;
    }
    return 2 * maxClass + 1;
  }

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
    final itemClass =
        instanceEntity == null
            ? 1
            : _session.context.components
                .get<ItemInstance>(instanceEntity)!
                .itemClass;

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
      upgradeCount: _upgradesByDefinition[definitionId] ?? 0,
      upgradeCap: 2 * itemClass + 1,
    );
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

  /// Spends one banked upgrade point to give [definitionId]'s combat
  /// stat a permanent +2 — the `item:<id>` branch of `runGame`'s own
  /// `applyUpgrade` (`tome_manager.dart`): same value, same
  /// `WeaponStatTags` stat resolution, same `upgrade:item:...` source
  /// shape, and the point is subtracted the same way. Returns false and
  /// does nothing if no point is banked, or if the item is already at
  /// its class `+N` ceiling ([upgradeCapFor]).
  bool spendUpgradePoint(String definitionId) {
    if ((_upgradesByDefinition[definitionId] ?? 0) >=
        upgradeCapFor(definitionId)) {
      return false;
    }
    final points = _session.context.resources
        .currentOf(_session.character, ItemResources.upgradePoints);
    if (points < 1) return false;
    _session.context.resources
        .subtract(_session.character, ItemResources.upgradePoints, 1);
    _upgradesByDefinition[definitionId] =
        (_upgradesByDefinition[definitionId] ?? 0) + 1;
    _spendSeq++;
    final item = itemDefinition(definitionId, _session.context);
    final stat =
        WeaponStatTags.matchOrFallback(item.tags, 'item:$definitionId');
    _session.context.modifiers.add(Modifier(
      source: ModifierSource(
          'upgrade:item:$definitionId:${_session.character.value}:$_spendSeq'),
      target: _session.character,
      stat: stat,
      operation: ModifierOperation.add,
      value: 2,
    ));
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
