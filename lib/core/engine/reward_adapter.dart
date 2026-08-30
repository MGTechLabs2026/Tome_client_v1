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
  })  : _tomeAdapter = tomeAdapter,
        _techniqueAdapter = techniqueAdapter,
        _itemPool = List.of(itemPool),
        _techniquePool = List.of(techniquePool);

  final EngineSession _session;
  final TomeAdapter _tomeAdapter;
  final TechniqueAdapter _techniqueAdapter;
  final List<String> _itemPool;
  final List<String> _techniquePool;

  final _grantedItems = <String>{};
  final _grantedTechniques = <String>{};

  /// The New Component this loot screen is offering. [offerLoot] rolls a
  /// fresh one every time it runs — i.e. once per loot screen, so the
  /// offer changes after every fight whether or not the last one was
  /// taken — and [applyLoot] grants exactly the id that was shown.
  ({bool isItem, String id})? _offered;

  /// Rolls a New Component: a uniformly random pick (via the run's
  /// seeded RNG) from the pooled ids the player has not been granted
  /// yet — items first while any remain, then techniques. Returns null
  /// once every pooled reward has been handed out.
  ({bool isItem, String id})? _rollNext() {
    final items =
        _itemPool.where((id) => !_grantedItems.contains(id)).toList();
    if (items.isNotEmpty) {
      return (isItem: true, id: items[_session.rng.nextInt(items.length)]);
    }
    final techs =
        _techniquePool.where((id) => !_grantedTechniques.contains(id)).toList();
    if (techs.isNotEmpty) {
      return (isItem: false, id: techs[_session.rng.nextInt(techs.length)]);
    }
    return null;
  }

  List<LootOptionView> offerLoot() {
    final next = _offered = _rollNext();
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
        final next = _offered;
        if (next == null) return;
        if (next.isItem) {
          final item = itemDefinition(next.id, _session.context);
          ownItem(_session.character, item.id, _session.context);
          discoverItem(_session.character, item, _session.context);
          _grantedItems.add(next.id);
        } else {
          _techniqueAdapter.discover(next.id);
          _grantedTechniques.add(next.id);
        }
        _offered = null;
    }
  }
}
