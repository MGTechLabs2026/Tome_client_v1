// test/core/engine/training_adapter_test.dart
import 'package:build_engine/build_engine.dart';
import 'package:build_engine/item_plugin.dart';
import 'package:build_engine/technique_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/item_adapter.dart';
import 'package:tome_client/core/engine/technique_adapter.dart';
import 'package:tome_client/core/engine/tome_adapter.dart';
import 'package:tome_client/core/engine/training_adapter.dart';
import 'package:tome_client/core/models/training_result_view.dart';

List<TrainingAttempt> _perfectAttempts({int count = 3}) => [
      for (var i = 0; i < count; i++)
        const TrainingAttempt({'windowStart': 100, 'windowEnd': 200, 'actual': 150}),
    ];

void main() {
  late EngineSession session;
  late TrainingAdapter trainingAdapter;
  late TechniqueAdapter techniqueAdapter;

  setUp(() {
    session = EngineSession(5);
    CharacterAdapter(session).createCharacter('Test Fighter');
    final tomeAdapter = TomeAdapter(session)..createInitialTome();
    techniqueAdapter = TechniqueAdapter(session);
    trainingAdapter = TrainingAdapter(
      session,
      tomeAdapter: tomeAdapter,
      techniqueAdapter: techniqueAdapter,
    );
  });

  test('trainItem raises mastery progress toward usability for a locked item', () {
    ownItem(session.character, ItemIds.clothArmor, session.context);
    discoverItem(session.character, itemDefinition(ItemIds.clothArmor, session.context), session.context);

    final result = trainingAdapter.trainItem(ItemIds.clothArmor, _perfectAttempts());

    expect(result.gain, greaterThan(0));
    expect(ItemAdapter(session).viewOf(ItemIds.clothArmor).masteryLevel, greaterThanOrEqualTo(0));
  });

  test('trainTechnique can cross the learning threshold with enough perfect attempts', () {
    final technique = techniqueDefinition(TechniqueIds.basicPunch, session.context);
    discoverTechnique(session.character, technique, session.context);

    TrainingResultView result;
    var attempts = 0;
    do {
      result = trainingAdapter.trainTechnique(TechniqueIds.basicPunch, _perfectAttempts());
      attempts++;
    } while (!result.crossedIntoUsableOrLearned && attempts < 20);

    expect(TechniqueAdapter(session).viewOf(TechniqueIds.basicPunch).learned, isTrue);
  });

  test('trainTechnique raises that technique\'s own mastery rank, per '
      'technique', () {
    for (final id in [TechniqueIds.basicSlash, TechniqueIds.basicPunch]) {
      techniqueAdapter.discover(id);
    }

    // Train only the slash.
    var tries = 0;
    while (techniqueAdapter.viewOf(TechniqueIds.basicSlash).masteryLevel < 1 &&
        tries < 40) {
      trainingAdapter.trainTechnique(TechniqueIds.basicSlash, _perfectAttempts());
      tries++;
    }

    expect(techniqueAdapter.viewOf(TechniqueIds.basicSlash).masteryLevel,
        greaterThanOrEqualTo(1),
        reason: 'the trained technique gained a rank');
    expect(techniqueAdapter.viewOf(TechniqueIds.basicPunch).masteryLevel, 0,
        reason: 'an untrained technique is untouched — mastery is per technique');
  });

  test('an evolved technique becomes real: on the roster, learned, and '
      'placed where the base was', () {
    final base = techniqueDefinition(TechniqueIds.basicPunch, session.context);
    discoverTechnique(session.character, base, session.context);
    techniqueAdapter.discover(TechniqueIds.basicPunch);

    // Learn it first, then hang it so the evolution has a slot to swap.
    TrainingResultView result;
    var tries = 0;
    do {
      result = trainingAdapter.trainTechnique(
          TechniqueIds.basicPunch, _perfectAttempts());
      tries++;
    } while (!result.crossedIntoUsableOrLearned && tries < 20);

    final tomeAdapter = TomeAdapter(session);
    tomeAdapter.insertTechnique(TechniqueIds.basicPunch, '1,1');

    // Keep training until it evolves.
    String? evolved;
    tries = 0;
    while (evolved == null && tries < 40) {
      evolved = trainingAdapter
          .trainTechnique(TechniqueIds.basicPunch, _perfectAttempts())
          .evolvedIntoDefinitionId;
      tries++;
    }
    expect(evolved, isNotNull, reason: 'basic_punch should evolve eventually');

    expect(techniqueAdapter.isOnRoster(evolved!), isTrue,
        reason: 'the evolved form shows in the tray/sheet');

    final occupant = tomeAdapter
        .inspect()
        .firstWhere((c) => c.slotId == '1,1')
        .occupant;
    expect(occupant?.contentId, evolved,
        reason: 'the evolved form took the base form\'s slot');

    // And it can be taken off and hung again (no "must be learned" wall).
    tomeAdapter.remove('1,1');
    tomeAdapter.insertTechnique(evolved, '0,0');
    expect(
        tomeAdapter.inspect().firstWhere((c) => c.slotId == '0,0').occupant
            ?.contentId,
        evolved);
  });
}
