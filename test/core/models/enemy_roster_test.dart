// test/core/models/enemy_roster_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tome_client/core/models/enemy_roster.dart';
import 'package:tome_client/core/models/enemy_view.dart';
import 'package:tome_client/features/run/run_state.dart';

RunState _run(int number, int fightIndex) => RunState(
      runNumber: number,
      fightIndex: fightIndex,
      fightsInCurrentRun: fightsForRun(number),
    );

void main() {
  test('the final bout of every run is a boss, cycling through all three', () {
    final bosses = <EnemyArchetype>{};
    for (var n = 1; n <= 6; n++) {
      final e = enemyFor(_run(n, fightsForRun(n) - 1));
      expect(e.isBoss, isTrue, reason: 'run $n hard fight must be a boss');
      bosses.add(e.archetype);
    }
    expect(bosses, hasLength(3));
  });

  test('early runs only draw brute / fast striker for normal bouts', () {
    for (var fi = 0; fi < 2; fi++) {
      final e = enemyFor(_run(3, fi));
      expect(e.isBoss, isFalse);
      expect(
        [EnemyArchetype.brute, EnemyArchetype.fastStriker],
        contains(e.archetype),
      );
    }
  });

  test('the archetype pool widens with run number', () {
    Set<EnemyArchetype> seenOverRun(int n) => {
          for (var fi = 0; fi < fightsForRun(n) - 1; fi++)
            enemyFor(_run(n, fi)).archetype,
        };
    // by the 20s the counter/reach/evasive tests are in rotation
    final late = <EnemyArchetype>{};
    for (var n = 15; n <= 28; n++) {
      late.addAll(seenOverRun(n));
    }
    expect(late, contains(EnemyArchetype.guardSpecialist));
    expect(late.length, greaterThan(2));
  });

  test('is deterministic — same run/bout yields the same enemy', () {
    final a = enemyFor(_run(12, 2));
    final b = enemyFor(_run(12, 2));
    expect(a.id, b.id);
    expect(a.health, b.health);
    expect(a.archetype, b.archetype);
  });

  test('stats ramp up with run number', () {
    final early = enemyFor(_run(2, fightsForRun(2) - 1)); // boss
    final later = enemyFor(_run(9, fightsForRun(9) - 1)); // same boss, +7 runs
    expect(later.health, greaterThan(early.health));
  });

  test('every archetype carries a build-question string', () {
    for (final a in EnemyArchetype.values) {
      expect(a.label, isNotEmpty);
      expect(a.tests, isNotEmpty);
    }
  });
}
