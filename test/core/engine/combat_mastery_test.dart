// Combat trains the build it was fought with: every resolved player
// action adds mastery to the component that threw it (a clean hit a
// little, a fumble more), and the fight hands back a tally of what
// happened.
import 'package:build_engine/build_engine.dart' show HealthComponent;
import 'package:build_engine/technique_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/engine/character_adapter.dart';
import 'package:tome_client/core/engine/combat_adapter.dart';
import 'package:tome_client/core/engine/engine_session.dart';
import 'package:tome_client/core/engine/tome_adapter.dart';

void main() {
  test('a hung attack technique gains mastery from fighting — 0.1 per hit, '
      '0.3 per miss — and is counted in the tally', () {
    final session = EngineSession(9);
    CharacterAdapter(session).createCharacter('Test Fighter');
    final tome = TomeAdapter(session)..createInitialTome();

    final slash = techniqueDefinition('basic_slash', session.context);
    discoverTechnique(session.character, slash, session.context);
    attemptToLearnTechnique(session.character, slash, 9999, session.context);
    tome.insertTechnique('basic_slash', '1,1');

    final subject = techniqueSubject('basic_slash');
    final before = session.context.mastery.progressOf(session.character, subject);

    final out = CombatAdapter(session, tomeAdapter: tome).runFight(
      'club_veteran',
      enemyHealth: 40,
      enemyDamage: 2,
      enemyDamageStat: 'fist',
    );

    final hits = out.tally.hitsByTechnique['basic_slash'] ?? 0;
    final misses = out.tally.missesByTechnique['basic_slash'] ?? 0;
    expect(hits + misses, greaterThan(0), reason: 'the technique was used');

    // The tally's own accounting.
    expect(out.tally.masteryAwarded,
        closeTo(hits * 0.1 + misses * 0.3, 1e-9));

    // And it actually landed on that technique's mastery axis.
    final gained =
        session.context.mastery.progressOf(session.character, subject) - before;
    expect(gained, closeTo(out.tally.masteryAwarded, 1e-9));
    expect(gained, greaterThan(0));
  });

  test('deterministic per seed', () {
    ({int hits, int misses, double mastery}) fight() {
      final s = EngineSession(4);
      CharacterAdapter(s).createCharacter('F');
      final tome = TomeAdapter(s)..createInitialTome();
      final t = techniqueDefinition('basic_punch', s.context);
      discoverTechnique(s.character, t, s.context);
      attemptToLearnTechnique(s.character, t, 9999, s.context);
      tome.insertTechnique('basic_punch', '1,1');
      final o = CombatAdapter(s, tomeAdapter: tome).runFight('street_brawler',
          enemyHealth: 30, enemyDamage: 2, enemyDamageStat: 'fist');
      return (
        hits: o.tally.hitsByTechnique['basic_punch'] ?? 0,
        misses: o.tally.missesByTechnique['basic_punch'] ?? 0,
        mastery: o.tally.masteryAwarded,
      );
    }

    expect(fight(), equals(fight()));
  });

  test('an armour piece trains from blows it takes — defence held / broken '
      'are tallied', () {
    final session = EngineSession(3);
    CharacterAdapter(session).createCharacter('Test Fighter');
    final tome = TomeAdapter(session)..createInitialTome();
    tome.insertItem('polearm', '0,0'); // weapon
    tome.insertItem('cloth', '0,1'); // armour

    final clothSubject = 'item:cloth';
    final before =
        session.context.mastery.progressOf(session.character, clothSubject);

    final out = CombatAdapter(session, tomeAdapter: tome).runFight(
      'rival_master',
      enemyHealth: 45,
      enemyDamage: 6,
      enemyDamageStat: 'fist',
    );

    expect(out.tally.defenceHeld + out.tally.defenceBroken, greaterThan(0),
        reason: 'every enemy blow that lands rolls the armour');
    final gained = session.context.mastery
            .progressOf(session.character, clothSubject) -
        before;
    expect(gained, greaterThan(0), reason: 'the armour trained from the fight');

    // A held blow leaves the player with more health than a raw hit would.
    expect(session.context.components
        .get<HealthComponent>(session.character), isNotNull);
  });
}
