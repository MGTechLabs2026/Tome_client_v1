import 'package:build_engine/martial_arts_plugin.dart';
import 'package:build_engine/physique_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';

void main() {
  test('createCharacter assigns a name, physique, and starting health', () {
    final session = EngineSession(1);
    final adapter = CharacterAdapter(session);

    final view = adapter.createCharacter('Test Fighter');

    expect(view.name, 'Test Fighter');
    expect(PhysiqueTypes.all, contains(view.physiqueId));
    expect(view.healthCurrent, 100);
    expect(view.healthMax, 100);
  });

  test('availableStyles returns all 6 known styles', () {
    final session = EngineSession(2);
    final adapter = CharacterAdapter(session);
    adapter.createCharacter('Test Fighter');

    expect(
      adapter.availableStyles().toSet(),
      {
        MartialStyles.boxing, MartialStyles.wrestling, MartialStyles.fencing,
        MartialStyles.shaolin, MartialStyles.taiChi, MartialStyles.wingChun,
      },
    );
  });

  test('chooseStyle learns the style and fills in the tradition/style view fields', () {
    final session = EngineSession(3);
    final adapter = CharacterAdapter(session);
    adapter.createCharacter('Test Fighter');

    final view = adapter.chooseStyle(MartialStyles.boxing);

    expect(view.styleId, MartialStyles.boxing);
    expect(view.martialTradition, MartialTraditions.western);
    expect(adapter.synergyTraditionFor(MartialStyles.shaolin), MartialTraditions.eastern);
  });
}
