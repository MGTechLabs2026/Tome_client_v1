// lib/core/engine/reward_adapter.dart
import 'dart:math' as math;

import 'package:build_engine/build_engine.dart';
import 'package:build_engine/build_interpretation.dart' show WeaponStatTags;
import 'package:build_engine/combat_plugin.dart';
import 'package:build_engine/item_plugin.dart';
import 'package:build_engine/technique_plugin.dart';

import '../models/loot_option_view.dart';
import 'character_adapter.dart';
import 'engine_session.dart';
import 'reward_affix.dart';
import 'technique_adapter.dart';
import 'tome_adapter.dart';

class RewardAdapter {
  RewardAdapter(
    this._session, {
    required TomeAdapter tomeAdapter,
    required TechniqueAdapter techniqueAdapter,
    required CharacterAdapter characterAdapter,
    required List<String> itemPool,
    required List<String> techniquePool,
  })  : _tomeAdapter = tomeAdapter,
        _techniqueAdapter = techniqueAdapter,
        _characterAdapter = characterAdapter,
        _pool = [
          for (final id in itemPool) (isItem: true, id: id),
          for (final id in techniquePool) (isItem: false, id: id),
        ];

  final EngineSession _session;
  final TomeAdapter _tomeAdapter;
  final TechniqueAdapter _techniqueAdapter;
  final CharacterAdapter _characterAdapter;

  /// Items and techniques the New Component reward draws from, flattened
  /// into one pool. Drawn **with replacement** — the same id can be
  /// offered (and taken) again, so the player can farm a duplicate to
  /// Combine, and techniques stay in the rotation instead of being gated
  /// behind clearing every item first.
  final List<({bool isItem, String id})> _pool;

  /// The New Component this loot screen is offering, with the prefix
  /// (quality) and suffix (effect) rolled onto it. Re-rolled by every
  /// [offerLoot] (once per loot screen); [applyLoot] grants exactly what
  /// was shown, then clears it.
  ({bool isItem, String id})? _offered;
  Affix? _prefix;
  Affix? _suffix;

  /// Monotonic tag so a card's affix Modifiers get unique sources and
  /// stack across a run.
  int _affixSeq = 0;

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

  String _prettyId(String id) => id
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  String _roman(int n) => const ['0', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII',
        'VIII', 'IX']
      .elementAtOrNull(n) ??
      '$n';

  List<LootOptionView> offerLoot() {
    final next = _offered = _rollNext();

    final affinity = _characterAdapter.currentView().physiqueAffinityTradition;
    LootOptionView componentCard;
    if (next == null) {
      _prefix = null;
      _suffix = null;
      componentCard = const LootOptionView(
        kind: LootKind.newComponent,
        title: 'Nothing on the rack',
        detail: 'No new components remain in the pool.',
      );
    } else {
      // Either slot can come up empty — a plain, unadorned piece.
      final prefix = _prefix = rollAffixOrNone(
          next.isItem ? itemPrefixes : techniquePrefixes,
          affinity,
          _session.rng);
      final suffix = _suffix = rollAffixOrNone(
          next.isItem ? itemSuffixes : techniqueSuffixes,
          affinity,
          _session.rng);

      final String baseName;
      String? badge;
      String detail;
      if (next.isItem) {
        final item = itemDefinition(next.id, _session.context);
        baseName = _prettyId(item.id);
        badge = 'CLASS ${_roman(1)}';
        detail = '${item.category[0].toUpperCase()}${item.category.substring(1)}'
            ' — a fresh piece for the board.';
      } else {
        baseName = techniqueDefinition(next.id, _session.context).name;
        badge = 'TECHNIQUE';
        detail = 'A form to hang, then train and evolve.';
      }

      final title = [prefix?.label, baseName, suffix?.label]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ');
      componentCard = LootOptionView(
        kind: LootKind.newComponent,
        title: title,
        detail: detail,
        badge: badge,
        seed: next.id.hashCode,
        effects: [
          if (prefix != null) prefix.blurb,
          if (suffix != null) suffix.blurb,
          if (prefix == null && suffix == null) 'plain — no bonuses rolled',
        ],
      );
    }

    return [
      const LootOptionView(
        kind: LootKind.upgradePoints,
        title: 'Upgrade Point',
        detail: 'Bank a point to pour into a component from the Tome later.',
      ),
      LootOptionView(
        kind: LootKind.gridExpansion,
        title: 'Wider Board',
        detail:
            'Grow the Tome from ${_tomeAdapter.width}x${_tomeAdapter.height} '
            'to ${_tomeAdapter.width + 1}x${_tomeAdapter.height}.',
      ),
      componentCard,
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
        final String primaryStat;
        if (next.isItem) {
          final item = itemDefinition(next.id, _session.context);
          // A fresh instance every time — two of the same id/class can
          // then be Combined.
          ownItem(_session.character, item.id, _session.context);
          discoverItem(_session.character, item, _session.context);
          primaryStat =
              WeaponStatTags.matchOrFallback(item.tags, 'item:${item.id}');
        } else {
          _techniqueAdapter.discover(next.id);
          final tech = techniqueDefinition(next.id, _session.context);
          primaryStat = WeaponStatTags.matchOrFallback(
              tech.tags, techniqueSubject(next.id));
        }
        _applyAffix(_prefix, primaryStat);
        _applyAffix(_suffix, primaryStat);
        _offered = null;
        _prefix = null;
        _suffix = null;
    }
  }

  /// Turns one rolled [affix] into a real effect on the fighter.
  void _applyAffix(Affix? affix, String primaryStat) {
    if (affix == null || affix.amount == 0) return;
    _affixSeq++;
    final src = ModifierSource(
        'reward:${affix.label}:${_session.character.value}:$_affixSeq');
    switch (affix.effect) {
      case AffixEffect.statUp:
        _session.context.modifiers.add(Modifier(
          source: src,
          target: _session.character,
          stat: primaryStat,
          operation: ModifierOperation.add,
          value: affix.amount,
        ));
      case AffixEffect.initiativeUp:
        final c = _session.context.components
            .get<CombatantComponent>(_session.character);
        if (c != null) {
          _session.context.components.add(
            _session.character,
            CombatantComponent(
                team: c.team, initiative: c.initiative + affix.amount),
          );
        }
      case AffixEffect.healNow:
        final h = _session.context.components
            .get<HealthComponent>(_session.character);
        if (h != null) {
          _session.context.components.add(
            _session.character,
            HealthComponent(
              current: math.min(h.current + affix.amount, h.max),
              max: h.max,
            ),
          );
        }
      case AffixEffect.bankPoint:
        _session.context.resources.add(
          _session.character,
          ItemResources.upgradePoints,
          affix.amount,
        );
    }
  }
}
