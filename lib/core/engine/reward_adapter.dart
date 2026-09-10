// lib/core/engine/reward_adapter.dart
import 'package:build_engine/affix_plugin.dart';
import 'package:build_engine/almanac.dart';
import 'package:build_engine/item_plugin.dart';
import 'package:build_engine/martial_arts_plugin.dart' show styleAlignedFamilies;
import 'package:build_engine/technique_plugin.dart';

import '../models/loot_option_view.dart';
import '../persistence/codex_repository.dart';
import 'almanac_session.dart';
import 'character_adapter.dart';
import 'engine_session.dart';
import 'item_adapter.dart';
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
    AlmanacSession? almanac,
    ({int seed, int number}) Function()? currentRun,
  })  : _tomeAdapter = tomeAdapter,
        _techniqueAdapter = techniqueAdapter,
        _characterAdapter = characterAdapter,
        _itemAdapter = itemAdapter,
        _codex = codex,
        _almanac = almanac,
        _currentRun = currentRun ?? (() => (seed: 1, number: 1)),
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

  /// App-lifetime engine Almanac owner — used on TAKE to record every
  /// acquired affix. Optional so tests can skip it.
  final AlmanacSession? _almanac;

  /// Supplies the live run identity for affix acquisition ids. Defaults
  /// to a fixed (1, 1) so tests need not wire RunBloc.
  final ({int seed, int number}) Function() _currentRun;

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

  /// The affix slots resolved for the current offer — engine-owned,
  /// resolved once by [offerLoot], carried unchanged into [applyLoot].
  /// Null before the first offer / after a non-newComponent take.
  AffixResolution? _offeredAffixes;

  /// The 3-card list [offerLoot] last built. [currentOffer] returns it
  /// verbatim — a pure re-read with no RNG / Almanac / state effect.
  List<LootOptionView>? _lastOffer;

  /// One per RewardAdapter lifetime (== one per lineage/EngineSession).
  /// Mints the engine-owned affixEventId for each acquired affix.
  final AffixAcquisitionIdSource _affixIdSource = AffixAcquisitionIdSource();

  /// A contextually weighted pick (via the run's seeded RNG) from the
  /// reward pool — Content Expansion V1, matrix §I. Items are always
  /// eligible (a duplicate feeds Combine); a technique drops out once
  /// the player already has it. Weight = a flat rarity base, then:
  ///
  /// * ×2.0 if the candidate's family tag is in the fighter's style lane
  ///   ([styleAlignedFamilies]);
  /// * ×1.5 if it carries the fighter's `aff:<physique>` tag;
  /// * ×2.0 if it fills a hole in the current Tome (no weapon / no
  ///   armour / no technique);
  /// * ÷2.0 if the codex has already seen it (favour novelty).
  ({bool isItem, String id})? _rollNext() {
    final candidates = [
      for (final entry in _pool)
        if (entry.isItem || !_techniqueAdapter.isOnRoster(entry.id)) entry,
    ];
    if (candidates.isEmpty) return null;

    final weights = [for (final c in candidates) _weightOf(c)];
    final total = weights.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return candidates[_session.rng.nextInt(candidates.length)];
    var roll = _session.rng.nextDouble() * total;
    for (var i = 0; i < candidates.length; i++) {
      roll -= weights[i];
      if (roll <= 0) return candidates[i];
    }
    return candidates.last;
  }

  Set<String> _tagsOf(({bool isItem, String id}) e) => e.isItem
      ? itemDefinition(e.id, _session.context).tags
      : techniqueDefinition(e.id, _session.context).tags;

  double _weightOf(({bool isItem, String id}) e) {
    final view = _characterAdapter.currentView();
    final tags = _tagsOf(e);
    var w = 100.0; // rarity base — every pooled entry is a common base form

    final aligned = styleAlignedFamilies[view.styleId] ?? const <String>{};
    if (aligned.isNotEmpty && tags.any(aligned.contains)) w *= 2.0;

    if (view.physiqueId.isNotEmpty && tags.contains('aff:${view.physiqueId}')) {
      w *= 1.5;
    }

    if (_fillsBuildGap(e)) w *= 2.0;

    final seen = _codex?.snapshot
            .of(e.isItem ? CodexKind.item : CodexKind.technique)
            .contains(e.id) ??
        false;
    if (seen) w /= 2.0;

    return w;
  }

  /// True when taking [e] would plug a hole in the current Tome — no
  /// technique hung, or no weapon / no armour to match [e]'s category.
  bool _fillsBuildGap(({bool isItem, String id}) e) {
    var hasWeapon = false, hasArmour = false, hasTechnique = false;
    for (final p in _session.context.tome.inspect(_session.character)) {
      final ref = p.buildComponentRef;
      if (ref.referenceType == techniqueReferenceType) {
        hasTechnique = true;
      } else if (ref.referenceType == itemReferenceType) {
        final cat = itemDefinition(ref.contentId, _session.context).category;
        cat == 'armor' ? hasArmour = true : hasWeapon = true;
      }
    }
    if (!e.isItem) return !hasTechnique;
    final cat = itemDefinition(e.id, _session.context).category;
    return cat == 'armor' ? !hasArmour : !hasWeapon;
  }

  String _prettyId(String id) => id
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  String _roman(int n) => const ['0', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII',
        'VIII', 'IX']
      .elementAtOrNull(n) ??
      '$n';

  /// One card line for a resolved affix, from its engine [AffixMechanic].
  String _affixEffectLine(AffixDefinition def, ({bool isItem, String id}) reward) {
    final m = def.mechanic;
    if (m is WeaponStatBonus) {
      final stat = WeaponStatTags.matchOrFallback(
          itemDefinition(reward.id, _session.context).tags, 'item:${reward.id}');
      return '+${_n(m.amount)} $stat';
    }
    if (m is ImmediateHeal) return 'restore ${_n(m.amount)} vitality';
    if (m is BankProgression) return '+${_n(m.amount)} upgrade points';
    return def.label; // unreachable for the v1 closed union
  }

  String _n(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  /// The current offer without re-rolling — for preview / re-render. No
  /// RNG draw, no Almanac write, no state mutation. Call [offerLoot] first.
  List<LootOptionView> currentOffer() => _lastOffer ?? const [];

  List<LootOptionView> offerLoot() {
    final next = _offered = _rollNext();

    LootOptionView componentCard;
    if (next == null) {
      _offeredAffixes = null;
      componentCard = const LootOptionView(
        kind: LootKind.newComponent,
        title: 'Nothing on the rack',
        detail: 'No new components remain in the pool.',
      );
    } else {
      // Either slot can come up empty — a plain, unadorned piece.
      final resolution = _offeredAffixes = resolveRewardAffixes(
        ctx: AffixRewardContext(
          domain: next.isItem ? AffixDomain.item : AffixDomain.technique,
          physiqueTradition:
              _characterAdapter.currentView().physiqueAffinityTradition,
        ),
        rng: _session.rng,
        content: _session.context.content,
      );
      final prefix = resolution.slots[0].affix;
      final suffix = resolution.slots[1].affix;

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
          if (prefix != null) _affixEffectLine(prefix, next),
          if (suffix != null) _affixEffectLine(suffix, next),
          if (prefix == null && suffix == null) 'plain — no bonuses rolled',
        ],
        prefixAffixId: prefix?.id,
        suffixAffixId: suffix?.id,
      );
    }

    final offer = [
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
    _lastOffer = offer;
    return _lastOffer!;
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
        final resolution = _offeredAffixes;

        final AffixApplicationTarget target;
        if (next.isItem) {
          final item = itemDefinition(next.id, _session.context);
          // A fresh instance every time — two of the same id/class can
          // then be Combined regardless of their affixes.
          final instance =
              ownItem(_session.character, item.id, _session.context);
          discoverItem(_session.character, item, _session.context);
          _codex?.discover(CodexKind.item, item.id);
          // Item affixes are flat stat bumps bound to *this* copy — the
          // engine does that inside `applyAffixMechanic`, so they only
          // bite while it's hung and ride along through Combine.
          target = ItemInstanceTarget(instance: instance, itemId: item.id);
          // Per-session display cache: the engine labels follow the copy
          // into the Tome UI.
          if (resolution != null) {
            final prefix = resolution.slots[0].affix;
            final suffix = resolution.slots[1].affix;
            _itemAdapter.recordAffix(
              instance.value,
              prefix: prefix == null
                  ? null
                  : affixDefinition(prefix.id, _session.context).label,
              suffix: suffix == null
                  ? null
                  : affixDefinition(suffix.id, _session.context).label,
            );
          }
        } else {
          _techniqueAdapter.discover(next.id);
          _codex?.discover(CodexKind.technique, next.id);
          // A technique isn't instanced, so its affixes are one-shot
          // boons claimed with the card — never a persistent modifier.
          target = CharacterTarget(character: _session.character);
        }

        if (resolution != null) {
          final run = _currentRun();
          final acquisitions = acquireAffixes(
            resolution: resolution,
            target: target,
            idSource: _affixIdSource,
            run: RunRef(runId: '${run.seed}:${run.number}', runNumber: run.number),
            context: _session.context,
          );
          for (final acq in acquisitions) {
            _almanac?.recorder.recordAffixDiscovered(
              affixId: acq.affixId,
              observation: AffixObservation(
                affixEventId: acq.affixEventId,
                runId: acq.runId,
                runNumber: acq.runNumber,
              ),
              snapshot: AffixSnapshot(
                affixId: acq.affixId,
                stat: acq.stat,
                value: acq.value,
                category: acq.category,
              ),
              timestamp: DateTime.now(),
            );
          }
          if (acquisitions.isNotEmpty) _almanac?.persist();
        }

        _offered = null;
        _offeredAffixes = null;
        _lastOffer = null;
    }
  }
}
