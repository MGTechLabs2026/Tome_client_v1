// lib/core/engine/reward_adapter.dart
import 'package:build_engine/item_plugin.dart';
import 'package:build_engine/technique_plugin.dart';

import '../models/loot_option_view.dart';
import 'engine_session.dart';
import 'technique_adapter.dart';
import 'tome_adapter.dart';

class RewardAdapter {
  RewardAdapter(
    this._session, {
    required TomeAdapter tomeAdapter,
    required TechniqueAdapter techniqueAdapter,
    required List<String> itemPool,
    required List<String> techniquePool,
  }) : _tomeAdapter = tomeAdapter,
       _techniqueAdapter = techniqueAdapter,
       _itemPool = List.of(itemPool),
       _techniquePool = List.of(techniquePool);

  final EngineSession _session;
  final TomeAdapter _tomeAdapter;
  final TechniqueAdapter _techniqueAdapter;
  final List<String> _itemPool;
  final List<String> _techniquePool;
  var _itemPoolIndex = 0;
  var _techniquePoolIndex = 0;

  /// The next pooled reward — items first, then techniques, mirroring
  /// `game_run.dart`'s own seed-shuffled-then-linear-draw reward pool
  /// pattern (this client draws in a fixed, caller-supplied order
  /// instead of reshuffling, since the pool itself is passed in already
  /// prepared by whoever wires `RewardAdapter` up, e.g. seed-shuffled at
  /// app start).
  ({bool isItem, String id})? _peekNextPoolEntry() {
    if (_itemPoolIndex < _itemPool.length) {
      return (isItem: true, id: _itemPool[_itemPoolIndex]);
    }
    if (_techniquePoolIndex < _techniquePool.length) {
      return (isItem: false, id: _techniquePool[_techniquePoolIndex]);
    }
    return null;
  }

  List<LootOptionView> offerLoot() {
    final next = _peekNextPoolEntry();
    final newComponentDetail =
        next == null
            ? 'No new components remain'
            : (next.isItem
                ? itemDefinition(next.id, _session.context).id
                : techniqueDefinition(next.id, _session.context).name);

    return [
      const LootOptionView(
        kind: LootKind.upgradePoints,
        title: '+1 Upgrade Point',
        detail: 'Bank a point to spend on any owned item or learned technique.',
      ),
      LootOptionView(
        kind: LootKind.gridExpansion,
        title: '+1 Column',
        detail:
            'Grow your Tome from ${_tomeAdapter.width}x${_tomeAdapter.height} to ${_tomeAdapter.width + 1}x${_tomeAdapter.height}.',
      ),
      LootOptionView(
        kind: LootKind.newComponent,
        title: 'New Component',
        detail: newComponentDetail,
      ),
    ];
  }

  void applyLoot(LootKind kind) {
    switch (kind) {
      case LootKind.upgradePoints:
        _session.context.resources.add(
          _session.character,
          ItemResources.upgradePoints,
          1,
        );
      case LootKind.gridExpansion:
        _tomeAdapter.expandGrid();
      case LootKind.newComponent:
        final next = _peekNextPoolEntry();
        if (next == null) return;
        if (next.isItem) {
          final item = itemDefinition(next.id, _session.context);
          ownItem(_session.character, item.id, _session.context);
          discoverItem(_session.character, item, _session.context);
          _itemPoolIndex++;
        } else {
          _techniqueAdapter.discover(next.id);
          _techniquePoolIndex++;
        }
    }
  }
}
