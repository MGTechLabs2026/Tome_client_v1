// lib/core/engine/training_adapter.dart
import 'package:build_engine/build_engine.dart';
import 'package:build_engine/game.dart';
import 'package:build_engine/item_plugin.dart';
import 'package:build_engine/technique_plugin.dart';

import '../models/seeded_random.dart';
import '../models/training_result_view.dart';
import '../persistence/codex_repository.dart';
import 'engine_session.dart';
import 'target_strike_exercise.dart';
import 'technique_adapter.dart';
import 'tome_adapter.dart';

/// Drives a real headless `TrainingSession` for one item or technique
/// with the player's actual submitted `TrainingAttempt`s, then applies
/// the mastery/learning side effects and asks the engine
/// (`resolveTechniqueEvolutionAfterTraining`) whether the technique just
/// evolved — reusing the engine's own `trainingGain` (from
/// `package:build_engine/game.dart`) so the threshold scaling never
/// drifts from the reference run.
///
/// A4: the client does **not** decide whether a technique evolves and no
/// longer publishes `TechniqueEvolved` itself. That decision and that
/// event are owned by the Technique domain
/// ([resolveTechniqueEvolutionAfterTraining]); this adapter only does the
/// client-facing follow-up on a successful evolution — putting the
/// evolved form on the roster / codex and swapping it into the Tome slot
/// the base technique occupied.
class TrainingAdapter {
  TrainingAdapter(
    this._session, {
    required TomeAdapter tomeAdapter,
    TechniqueAdapter? techniqueAdapter,
    CodexRepository? codex,
  })  : _tomeAdapter = tomeAdapter,
        _techniqueAdapter = techniqueAdapter ?? TechniqueAdapter(_session),
        _codex = codex;

  final EngineSession _session;
  final TomeAdapter _tomeAdapter;
  final TechniqueAdapter _techniqueAdapter;

  /// Cross-run record of met content — an evolved form is a discovery.
  final CodexRepository? _codex;

  /// The seeded random source the interactive exercise draws its wave
  /// layout from — a run's own RNG, so the target sequence is
  /// deterministic for a given seed.
  SeededRandom get random => EngineSeededRandom(_session.rng);

  TrainingResultView trainItem(
    String definitionId,
    List<TrainingAttempt> attempts, {
    TrainingExercise base = const TimingExercise(),
  }) {
    final item = itemDefinition(definitionId, _session.context);
    final wasUsable = isItemUsable(_session.character, item, _session.context);
    final exercise = itemTrainingExerciseFor(item, base);
    final session = TrainingSession(
      trainee: _session.character,
      subject: itemSubject(definitionId),
      exercise: exercise,
    );
    for (final attempt in attempts) {
      session.submitAttempt(attempt);
    }
    final result = session.complete();
    final gain = trainingGain(result.profile);
    _session.context.mastery.increase(
      _session.character,
      itemSubject(definitionId),
      gain,
    );
    final nowUsable = isItemUsable(_session.character, item, _session.context);

    return TrainingResultView(
      subject: itemSubject(definitionId),
      dimensions: result.profile.dimensions,
      gain: gain,
      crossedIntoUsableOrLearned: !wasUsable && nowUsable,
    );
  }

  TrainingResultView trainTechnique(
    String definitionId,
    List<TrainingAttempt> attempts, {
    TrainingExercise base = const TimingExercise(),
  }) {
    final technique = techniqueDefinition(definitionId, _session.context);
    final exercise = techniqueTrainingExerciseFor(technique, base);
    final session = TrainingSession(
      trainee: _session.character,
      subject: techniqueSubject(definitionId),
      exercise: exercise,
    );
    for (final attempt in attempts) {
      session.submitAttempt(attempt);
    }
    final result = session.complete();
    final gain = trainingGain(result.profile);

    // MASTERY is a third, per-technique axis (subject `technique:<id>`),
    // independent of LEARNING and evolution. `trainItem` raises the item
    // axis this same way; techniques were missing the call entirely, so
    // a technique's rank never moved no matter how much it was trained.
    trainTechniqueMastery(_session.character, technique, gain, _session.context);

    final learning = attemptToLearnTechnique(
      _session.character,
      technique,
      gain,
      _session.context,
    );

    // A4: one authoritative evolution decision, in the Technique domain.
    // It runs the resolver only when eligible (learned + has candidates)
    // and publishes TechniqueEvolved itself, exactly once, on success —
    // EngineSession's lineage subscription still hears it, just from the
    // engine rather than from here.
    final evolution = resolveTechniqueEvolutionAfterTraining(
      _session.character,
      technique,
      result.profile,
      _session.context,
    );
    String? evolvedInto;
    if (evolution.evolved) {
      evolvedInto = evolution.chosenCandidate!.targetId;
      // Client follow-up only: put the evolved form on the roster / codex
      // (evolved branches have no LEARNING threshold, so the client
      // tracks them by discovery) and swap it into the base form's Tome
      // slot in place (`tome.replace` bypasses the "must be learned" gate).
      _techniqueAdapter.discover(evolvedInto);
      _codex?.discover(CodexKind.technique, evolvedInto);
      final slot = _slotOfTechnique(definitionId);
      if (slot != null) _tomeAdapter.replaceTechnique(slot, evolvedInto);
    }

    return TrainingResultView(
      subject: techniqueSubject(definitionId),
      dimensions: result.profile.dimensions,
      gain: gain,
      crossedIntoUsableOrLearned: learning.learned,
      evolvedIntoDefinitionId: evolvedInto,
      evolvedFromDefinitionId: evolvedInto == null ? null : definitionId,
    );
  }

  String? _slotOfTechnique(String definitionId) {
    for (final cell in _tomeAdapter.inspect()) {
      if (cell.occupant?.contentId == definitionId) return cell.slotId;
    }
    return null;
  }
}
