// test/core/engine/technique_adapter_test.dart
import 'package:build_engine/technique_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/technique_adapter.dart';

void main() {
  late EngineSession session;
  late TechniqueAdapter techniqueAdapter;

  setUp(() {
    session = EngineSession(11);
    CharacterAdapter(session).createCharacter('Test Fighter');
    techniqueAdapter = TechniqueAdapter(session);
  });

  test('an undiscovered technique reports discovered=false, learned=false', () {
    final view = techniqueAdapter.viewOf(TechniqueIds.basicPunch);
    expect(view.discovered, isFalse);
    expect(view.learned, isFalse);
  });

  test('discoverTechnique makes discovered=true', () {
    techniqueAdapter.discover(TechniqueIds.basicPunch);
    expect(techniqueAdapter.viewOf(TechniqueIds.basicPunch).discovered, isTrue);
  });

  test('discoveredTechniques only returns ids this adapter has discovered', () {
    techniqueAdapter.discover(TechniqueIds.basicPunch);
    final ids = techniqueAdapter.discoveredTechniques().map((v) => v.definitionId).toSet();
    expect(ids, {TechniqueIds.basicPunch});
  });

  test('lineage from EngineSession surfaces on evolvedFromId', () {
    session.lineage[TechniqueIds.lightPunch] = TechniqueIds.basicPunch;
    techniqueAdapter.discover(TechniqueIds.lightPunch);
    expect(techniqueAdapter.viewOf(TechniqueIds.lightPunch).evolvedFromId, TechniqueIds.basicPunch);
  });
}
