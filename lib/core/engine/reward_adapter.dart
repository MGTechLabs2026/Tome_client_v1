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
       _techniquePool = List.of(techniquePool) {
    // Shuffle each pool once, up front, with the run's own seeded RNG:
    // the New Component reward's identity is then random per run but
    // still fully reproducible from the seed (and the shuffle is done
    // here, not re-rolled per draw, so a run never re-offers a component
    // it already spent).
    _shuffleInPlace(_itemPool);
    _shuffleInPlace(_techniquePool);
  }

  /// Fisher-Yates over [_session.rng] — the package's only sanctioned
  /// randomness source, so this stays inside the seed's determinism.
  void _shuffleInPlace(List<String> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = _session.rng.nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }

  final EngineSession _session;
  final TomeAdapter _tomeAdapter;
  final TechniqueAdapter _techniqueAdapter;
  final List<String> _itemPool;
  final List<String> _techniquePool;
  var _itemPoolIndex = 0;
  var _techniquePoolIndex = 0;

  /// The next pooled reward — items first, then techniques. Both pools
  /// were seed-shuffled once in the constructor (mirroring
  /// `game_run.dart`'s own seed-shuffled-then-linear-draw reward pool
  /// pattern), so this linear walk hands back a run-random order that is
  /// still reproducible from the seed.
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
