// lib/core/engine/reward_adapter.dart
import 'dart:math' as math;

import 'package:build_engine/build_engine.dart';
import 'package:build_engine/build_interpretation.dart' show WeaponStatTags;
import 'package:build_engine/item_plugin.dart';
import 'package:build_engine/technique_plugin.dart';

import '../models/loot_option_view.dart';
import '../persistence/codex_repository.dart';
import 'character_adapter.dart';
import 'engine_session.dart';
import 'item_adapter.dart';
import 'reward_affix.dart';
import 'technique_adapter.dart';
import 'tome_adapter.dart';

class RewardAdapter {
  RewardAdapter(
    this._session, {
    required TomeAdapter tomeAdapter,
    required TechniqueAdapter techniqueAdapter,
    required CharacterAdapter characterAdapter,
    required ItemAdapter itemAdapter,
    required List<String> itemPool,
    required List<String> techniquePool,
    CodexRepository? codex,
  })  : _tomeAdapter = tomeAdapter,
        _techniqueAdapter = techniqueAdapter,
        _characterAdapter = characterAdapter,
        _itemAdapter = itemAdapter,
        _codex = codex,
        _pool = [
          for (final id in itemPool) (isItem: true, id: id),
          for (final id in techniquePool) (isItem: false, id: id),
        ];

  final EngineSession _session;
  final TomeAdapter _tomeAdapter;
  final TechniqueAdapter _techniqueAdapter;
  final CharacterAdapter _characterAdapter;
  final ItemAdapter _itemAdapter;

  /// Cross-run record of what the player has met — fed here when a new
  /// component is actually taken. Optional so tests can skip it.
  final CodexRepository? _codex;

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
        if (next.isItem) {
          final item = itemDefinition(next.id, _session.context);
          // A fresh instance every time — two of the same id/class can
          // then be Combined regardless of their affixes.
          final instance =
              ownItem(_session.character, item.id, _session.context);
          discoverItem(_session.character, item, _session.context);
          _codex?.discover(CodexKind.item, item.id);
          final stat =
              WeaponStatTags.matchOrFallback(item.tags, 'item:${item.id}');
          // Item affixes are all flat stat bumps — bind them to *this*
          // copy on the engine side, so they only bite while it's hung
          // and ride along through Combine.
          final total = (_prefix?.amount ?? 0) + (_suffix?.amount ?? 0);
          if (total > 0) {
            addItemStatBonuses(instance, {stat: total}, _session.context);
          }
          // The rolled name follows the copy for the Tome UI.
          _itemAdapter.recordAffix(instance.value,
              prefix: _prefix?.label, suffix: _suffix?.label);
        } else {
          _techniqueAdapter.discover(next.id);
          _codex?.discover(CodexKind.technique, next.id);
          // A technique isn't instanced, so its affixes are one-shot
          // boons claimed with the card — never a persistent modifier
          // (that was a leak: nothing removed it when the technique was
          // unhung or dropped).
          _applyTechniqueAffix(_prefix);
          _applyTechniqueAffix(_suffix);
        }
        _offered = null;
        _prefix = null;
        _suffix = null;
    }
  }

  /// Applies one rolled technique [affix] — an immediate, non-persistent
  /// boon. Only `healNow` / `bankPoint` reach here; `statUp` /
  /// `initiativeUp` have no per-technique home and are deliberately
  /// no-ops if the affix data ever reintroduces them.
  void _applyTechniqueAffix(Affix? affix) {
    if (affix == null || affix.amount == 0) return;
    switch (affix.effect) {
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
      case AffixEffect.statUp:
      case AffixEffect.initiativeUp:
        // No persistent per-technique effect — see the doc above.
        break;
    }
  }
}
