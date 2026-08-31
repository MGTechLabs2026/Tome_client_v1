// lib/core/engine/technique_adapter.dart
import 'package:build_engine/build_engine.dart';
import 'package:build_engine/technique_plugin.dart';

import '../models/technique_view.dart';
import 'engine_session.dart';

class TechniqueAdapter {
  TechniqueAdapter(this._session);

  final EngineSession _session;

  /// Every id this adapter has ever called `discover` for — the client's
  /// own tracked roster, since (unlike the reference `game_run.dart`) this
  /// client has no fixed reward-pool constant of its own; `RewardAdapter`
  /// (Task 12) calls `discover` whenever a technique reward is granted.
  final Set<String> _discoveredIds = {};

  void discover(String definitionId) {
    final technique = techniqueDefinition(definitionId, _session.context);
    discoverTechnique(_session.character, technique, _session.context);
    _discoveredIds.add(definitionId);
    // `TechniquePlugin` registers a MASTERY axis only for the 3 base
    // forms; evolved branches get none, so their rank would stay 0
    // forever. Give every technique on the roster the same [5, 15, 30]
    // rank axis so training shows a per-technique rank.
    final subject = techniqueSubject(definitionId);
    if (_session.context.mastery.definitionOf(subject) == null) {
      _session.context.mastery.define(
        MasteryDefinition(subject: subject, thresholds: const [5, 15, 30]),
      );
    }
  }

  /// Whether [definitionId] is on this run's roster yet (granted as a
  /// reward or produced by an evolution). Used by `RewardAdapter` to
  /// stop re-offering a technique the player already has.
  bool isOnRoster(String definitionId) => _discoveredIds.contains(definitionId);

  TechniqueView viewOf(String definitionId) {
    final technique = techniqueDefinition(definitionId, _session.context);
    return TechniqueView(
      definitionId: technique.id,
      name: technique.name,
      tier: technique.tier,
      properties: technique.properties,
      discovered: isTechniqueDiscovered(
        _session.character,
        technique,
        _session.context,
      ),
      learned: isTechniqueLearned(
        _session.character,
        technique,
        _session.context,
      ),
      masteryLevel: techniqueMasteryLevel(
        _session.character,
        technique,
        _session.context,
      ),
      evolvedFromId: _session.lineage[definitionId],
    );
  }

  List<TechniqueView> discoveredTechniques() => [
    for (final id in _discoveredIds) viewOf(id),
  ];
}
