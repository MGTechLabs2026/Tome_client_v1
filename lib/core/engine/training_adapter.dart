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
/// the exact same mastery/learning/evolution side effects
/// `TrainingStage.runTraining` does — reusing the engine's own
/// `trainingGain` (from `package:build_engine/game.dart`, the same
/// composition barrel this client's adapters already draw stage classes
/// from) so the [8, 25]-ish threshold scaling never drifts from the
/// reference run. The only orchestration this adapter owns that the
/// engine's stage leaves to a caller: publishing `TechniqueEvolved` on a
/// successful evolution (the engine's `evolveTechnique` is a pure
/// resolver and never publishes) and swapping the evolved form into the
/// Tome slot the base technique occupied.
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

    String? evolvedInto;
    if (learning.learned && technique.evolutionCandidates.isNotEmpty) {
      final evolution = evolveTechnique(
        _session.character,
        technique,
        result.profile,
        _session.context,
      );
      if (evolution.evolved) {
        evolvedInto = evolution.chosenCandidate!.targetId;
        // Put the evolved form on the roster so it shows in the tray and
        // its detail sheet. Evolved branches have no independent LEARNING
        // threshold in the engine — "learned" never applies to them — so
        // the client tracks them by discovery alone.
        _techniqueAdapter.discover(evolvedInto);
        _codex?.discover(CodexKind.technique, evolvedInto);
        // evolveTechnique is a pure resolver — it never publishes
        // TechniqueEvolved (game_run.dart's TrainingStage does that as an
        // orchestration decision). EngineSession's lineage subscription
        // depends on this event, so publish it here.
        _session.context.events.publish(
          TechniqueEvolved(fromId: definitionId, toId: evolvedInto),
        );
        // Swap it into the base form's slot in place (the same
        // `tome.replace` the reference run's TomeManager uses — bypasses
        // the "must be learned" gate that would reject an evolved form).
        final slot = _slotOfTechnique(definitionId);
        if (slot != null) _tomeAdapter.replaceTechnique(slot, evolvedInto);
      }
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
