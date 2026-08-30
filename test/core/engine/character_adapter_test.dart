import 'package:build_engine/martial_arts_plugin.dart';
import 'package:build_engine/physique_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/combat_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/tome_adapter.dart';

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
        MartialStyles.polearming, MartialStyles.wrestling, MartialStyles.fencing,
        MartialStyles.shaolin, MartialStyles.taiChi, MartialStyles.kunlun,
      },
    );
  });

  test('chooseStyle learns the style and fills in the tradition/style view fields', () {
    final session = EngineSession(3);
    final adapter = CharacterAdapter(session);
    adapter.createCharacter('Test Fighter');

    final view = adapter.chooseStyle(MartialStyles.polearming);

    expect(view.styleId, MartialStyles.polearming);
    expect(view.martialTradition, MartialTraditions.western);
    expect(adapter.synergyTraditionFor(MartialStyles.shaolin), MartialTraditions.eastern);
  });

  test('restoreVitality heals the fighter back to full', () {
    final session = EngineSession(7);
    final adapter = CharacterAdapter(session)..createCharacter('Test Fighter');
    adapter.chooseStyle(MartialStyles.polearming);
    final tome = TomeAdapter(session)
      ..createInitialTome()
      ..grantStartingKit();

    // A bruising bout so the fighter definitely takes damage.
    CombatAdapter(session, tomeAdapter: tome).runFight(
      'club_veteran',
      enemyHealth: 60,
      enemyDamage: 9,
      enemyDamageStat: 'fist',
    );
    expect(adapter.currentView().healthCurrent, lessThan(100));

    adapter.restoreVitality();

    final view = adapter.currentView();
    expect(view.healthCurrent, view.healthMax);
    expect(view.healthCurrent, 100);
  });
}
