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
        _pool = [
          for (final id in itemPool) (isItem: true, id: id),
          for (final id in techniquePool) (isItem: false, id: id),
        ];

  final EngineSession _session;
  final TomeAdapter _tomeAdapter;
  final TechniqueAdapter _techniqueAdapter;

  /// Items and techniques the New Component reward draws from, flattened
  /// into one pool. Drawn **with replacement** — the same id can be
  /// offered (and taken) again, so the player can farm a duplicate to
  /// Combine, and techniques stay in the rotation instead of being gated
  /// behind clearing every item first.
  final List<({bool isItem, String id})> _pool;

  /// The New Component this loot screen is offering. [offerLoot] rolls a
  /// fresh one every time it runs — i.e. once per loot screen, so the
  /// offer changes after every fight whether or not the last one was
  /// taken — and [applyLoot] grants exactly the id that was shown.
  ({bool isItem, String id})? _offered;

  /// A uniformly random pick (via the run's seeded RNG) from the reward
  /// pool. Items are always eligible (a duplicate feeds Combine); a
  /// technique drops out once the player already has it — a second copy
  /// would do nothing.
  ({bool isItem, String id})? _rollNext() {
    final candidates = [
      for (final entry in _pool)
        if (entry.isItem || !_techniqueAdapter.isOnRoster(entry.id)) entry,
    ];
    return candidates.isEmpty
        ? null
        : candidates[_session.rng.nextInt(candidates.length)];
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
          // A fresh instance every time — two of the same id/class can
          // then be Combined.
          ownItem(_session.character, item.id, _session.context);
          discoverItem(_session.character, item, _session.context);
        } else {
          _techniqueAdapter.discover(next.id);
        }
        _offered = null;
    }
  }
}
