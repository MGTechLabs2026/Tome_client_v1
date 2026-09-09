// lib/core/engine/almanac_adapter.dart
//
// The one Almanac module allowed to import build_engine. It enumerates
// the engine's *currently registered* reference content and hands the
// screen plain, immutable client records — the screen itself imports no
// engine type.
//
// Sources of truth (nothing here is a hand-maintained catalogue):
//   * items      — every ContentDefinition tagged `item`
//                  (`ContentRegistry.withTag`), each parsed through the
//                  engine's own `itemDefinitionFromContent`. Covers base
//                  forms and every registered Combine grade.
//   * techniques — every ContentDefinition tagged `technique`, parsed
//                  through `techniqueDefinitionFromContent`. The plain
//                  technique families (punch/slash/guard/palm/finger/
//                  kick) and their evolved branches. MartialArts' own
//                  style techniques register as `type: 'technique'` but
//                  carry no `name`/`tier` in `extra` — the engine
//                  converter cannot build a definition for them and the
//                  §2 truth rule forbids inventing those fields, so the
//                  `technique` *tag* (which only the plain families set)
//                  is the selection axis, mirroring items.
//   * styles     — NOT ContentRegistry entries. The engine models a
//                  style as a marker tag, not a structured definition,
//                  so this reads the MartialArts *vocabulary*:
//                  `stylesForTradition`, `martialTraditionOf`,
//                  `MartialSpecs.byStyle`, `styleAlignedFamilies`. The
//                  engine exposes no style archetype and no style
//                  specialty as a data object — `learnStyle`'s numeric
//                  affinity modifiers live only in procedural code — so
//                  a style view carries id, deterministic label,
//                  tradition, `spec:*` tags, and aligned families, and
//                  nothing else.
//
// Completion is not computed here: the screen intersects a CodexSnapshot
// with these rosters, so an id the codex still holds after the engine
// dropped it from its content simply stops counting.
import 'package:build_engine/build_engine.dart';
import 'package:build_engine/item_plugin.dart';
import 'package:build_engine/martial_arts_plugin.dart';
import 'package:build_engine/technique_plugin.dart';

import 'engine_session.dart';

/// A drawn dimension out of one evolution / Combine branch: where it
/// leads and which `TrainingDimensions` tags steer a trainee toward it.
/// `targetId` resolves against the same roster list this edge came from
/// — the screen walks the chain by id, so the graph is recursive without
/// this record nesting.
class AlmanacEvolutionEdge {
  const AlmanacEvolutionEdge({
    required this.targetId,
    required this.targetLabel,
    required this.trainingTags,
  });

  final String targetId;
  final String targetLabel;
  final List<String> trainingTags;
}

/// One martial style, from MartialArts vocabulary only. `tradition` is
/// `'western'` / `'eastern'` / null (a style id the plugin does not
/// recognise gets no tradition tag). `specialtyTags` are the raw
/// `spec:*` markers; `alignedFamilies` the family tags the style is "in
/// its lane" for. No archetype, no numeric modifier — the engine has
/// neither as data.
class AlmanacStyleView {
  const AlmanacStyleView({
    required this.id,
    required this.label,
    required this.tradition,
    required this.specialtyTags,
    required this.alignedFamilies,
  });

  final String id;
  final String label;
  final String? tradition;
  final List<String> specialtyTags;
  final List<String> alignedFamilies;
}

/// One registered item definition, flattened. `family` is the first
/// recognised family tag (the locked-state structural axis for an item
/// is its [category]; `family` only enriches the discovered descriptor).
/// `maxClass` / `classScalingPercent` describe an *instance's* class
/// scaling and are kept distinct from [evolutionCandidates], which are
/// the Combine grade graph.
class AlmanacItemView {
  const AlmanacItemView({
    required this.id,
    required this.label,
    required this.category,
    required this.family,
    required this.affinity,
    required this.tags,
    required this.properties,
    required this.maxClass,
    required this.classScalingPercent,
    required this.evolutionCandidates,
  });

  final String id;
  final String label;
  final String category;
  final String family;
  final String? affinity;
  final List<String> tags;
  final Map<String, num> properties;
  final int? maxClass;
  final num classScalingPercent;
  final List<AlmanacEvolutionEdge> evolutionCandidates;
}

/// One registered plain-technique definition, flattened. `family` is the
/// structural axis a locked technique reveals.
class AlmanacTechniqueView {
  const AlmanacTechniqueView({
    required this.id,
    required this.label,
    required this.tier,
    required this.family,
    required this.affinity,
    required this.tags,
    required this.properties,
    required this.evolutionCandidates,
  });

  final String id;
  final String label;
  final String tier;
  final String family;
  final String? affinity;
  final List<String> tags;
  final Map<String, num> properties;
  final List<AlmanacEvolutionEdge> evolutionCandidates;
}

/// The whole reference roster as of right now. `total` is the current
/// roster size — the denominator the screen shows before any completion
/// math.
class AlmanacSnapshot {
  const AlmanacSnapshot({
    required this.styles,
    required this.items,
    required this.techniques,
  });

  final List<AlmanacStyleView> styles;
  final List<AlmanacItemView> items;
  final List<AlmanacTechniqueView> techniques;

  int get total => styles.length + items.length + techniques.length;
}

/// Reads the reference content registered in [_session]'s `PluginContext`
/// and converts it to the plain records above. Pure enumeration — needs
/// only `context.content`, never a character — so it is safe to call
/// from a title-menu screen with no active run.
class AlmanacAdapter {
  AlmanacAdapter(this._session);

  final EngineSession _session;

  ContentRegistry get _content => _session.context.content;

  AlmanacSnapshot snapshot() => AlmanacSnapshot(
        styles: _styles(),
        items: _items(),
        techniques: _techniques(),
      );

  // --- styles ---------------------------------------------------------

  List<AlmanacStyleView> _styles() {
    final ids = <String>[
      ...stylesForTradition(MartialTraditions.western),
      ...stylesForTradition(MartialTraditions.eastern),
    ];
    return [
      for (final id in ids)
        AlmanacStyleView(
          id: id,
          label: _label(id),
          tradition: martialTraditionOf(id),
          specialtyTags: List.unmodifiable(
            MartialSpecs.byStyle[id] ?? const <String>[],
          ),
          alignedFamilies: List.unmodifiable(
            (styleAlignedFamilies[id] ?? const <String>{}).toList()..sort(),
          ),
        ),
    ];
  }

  // --- items ---------------------------------------------------------

  List<AlmanacItemView> _items() {
    final defs = _content.withTag('item').toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return [for (final d in defs) _itemView(itemDefinitionFromContent(d))];
  }

  AlmanacItemView _itemView(ItemDefinition d) {
    final structural = _structuralTags(d.tags, drop: {'item', d.category});
    return AlmanacItemView(
      id: d.id,
      label: _label(d.id),
      category: d.category,
      family: _family(structural),
      affinity: _affinity(d.tags),
      tags: structural,
      properties: Map.unmodifiable(d.properties),
      maxClass: d.maxClass,
      classScalingPercent: d.classScalingPercent,
      evolutionCandidates: _edges(d.gradeEvolutionCandidates),
    );
  }

  // --- techniques --------------------------------------------------

  List<AlmanacTechniqueView> _techniques() {
    final defs = _content.withTag('technique').toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return [
      for (final d in defs)
        _techniqueView(techniqueDefinitionFromContent(d)),
    ];
  }

  AlmanacTechniqueView _techniqueView(TechniqueDefinition d) {
    final structural = _structuralTags(d.tags, drop: {'technique'});
    return AlmanacTechniqueView(
      id: d.id,
      label: d.name,
      tier: d.tier,
      family: _family(structural),
      affinity: _affinity(d.tags),
      tags: structural,
      properties: Map.unmodifiable(d.properties),
      evolutionCandidates: _edges(d.evolutionCandidates),
    );
  }

  // --- shared -----------------------------------------------------

  List<AlmanacEvolutionEdge> _edges(List<EvolutionCandidate> candidates) => [
        for (final c in candidates)
          AlmanacEvolutionEdge(
            targetId: c.targetId,
            targetLabel: _label(c.targetId),
            trainingTags: c.tags.toList()..sort(),
          ),
      ];

  /// Structural tags only: drops the `item`/`technique`/category marker,
  /// the reward-weighter `aff:*` affinity, the `rarity:*` gate, and the
  /// `spec:*` style markers. What remains is the family / mechanism
  /// vocabulary the screen composes a descriptor from.
  List<String> _structuralTags(Set<String> tags, {required Set<String> drop}) {
    return [
      for (final t in tags)
        if (!drop.contains(t) &&
            t != 'martial' &&
            !t.startsWith('aff:') &&
            !t.startsWith('rarity:') &&
            !t.startsWith('spec:'))
          t,
    ]..sort();
  }

  String _family(List<String> structural) {
    for (final t in structural) {
      if (recognisedFamilyTags.contains(t)) return t;
    }
    return structural.isEmpty ? 'form' : structural.first;
  }

  String? _affinity(Set<String> tags) {
    for (final t in tags) {
      if (t.startsWith('aff:')) return t.substring(4);
    }
    return null;
  }

  /// Deterministic label from a content id — `basic_punch` -> "Basic
  /// Punch", `taiChi` -> "Tai Chi". The only naming the Almanac invents,
  /// and it invents nothing an id does not already spell.
  String _label(String id) => id
      .replaceAllMapped(RegExp(r'(?<=[a-z0-9])(?=[A-Z])'), (_) => ' ')
      .replaceAll('_', ' ')
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
