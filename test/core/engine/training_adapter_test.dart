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

  setUp(() {
    session = EngineSession(5);
    CharacterAdapter(session).createCharacter('Test Fighter');
    final tomeAdapter = TomeAdapter(session)..createInitialTome();
    trainingAdapter = TrainingAdapter(session, tomeAdapter: tomeAdapter);
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
}
