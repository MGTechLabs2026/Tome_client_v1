// lib/core/engine/training_adapter.dart
import 'package:build_engine/build_engine.dart';
import 'package:build_engine/game.dart';
import 'package:build_engine/item_plugin.dart';
import 'package:build_engine/technique_plugin.dart';

import '../models/training_result_view.dart';
import 'engine_session.dart';
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
  TrainingAdapter(this._session, {required TomeAdapter tomeAdapter}) : _tomeAdapter = tomeAdapter;

  final EngineSession _session;
  final TomeAdapter _tomeAdapter;

  TrainingResultView trainItem(String definitionId, List<TrainingAttempt> attempts) {
    final item = itemDefinition(definitionId, _session.context);
    final wasUsable = isItemUsable(_session.character, item, _session.context);
    final exercise = itemTrainingExerciseFor(item, const TimingExercise());
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
    _session.context.mastery.increase(_session.character, itemSubject(definitionId), gain);
    final nowUsable = isItemUsable(_session.character, item, _session.context);

    return TrainingResultView(
      subject: itemSubject(definitionId),
      dimensions: result.profile.dimensions,
      gain: gain,
      crossedIntoUsableOrLearned: !wasUsable && nowUsable,
    );
  }

  TrainingResultView trainTechnique(String definitionId, List<TrainingAttempt> attempts) {
    final technique = techniqueDefinition(definitionId, _session.context);
    final exercise = techniqueTrainingExerciseFor(technique, const TimingExercise());
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

    final learning = attemptToLearnTechnique(_session.character, technique, gain, _session.context);

    String? evolvedInto;
    if (learning.learned && technique.evolutionCandidates.isNotEmpty) {
      final evolution = evolveTechnique(_session.character, technique, result.profile, _session.context);
      if (evolution.evolved) {
        evolvedInto = evolution.chosenCandidate!.targetId;
        // evolveTechnique is a pure resolver — it never publishes
        // TechniqueEvolved (game_run.dart's TrainingStage does that as an
        // orchestration decision). EngineSession's lineage subscription
        // depends on this event, so publish it here.
        _session.context.events.publish(
          TechniqueEvolved(fromId: definitionId, toId: evolvedInto),
        );
        final slot = _slotOfTechnique(definitionId);
        if (slot != null) {
          _tomeAdapter.remove(slot);
          _tomeAdapter.insertTechnique(evolvedInto, slot);
        }
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
