// lib/core/models/enemy_roster.dart
import '../../features/run/run_state.dart';
import 'enemy_view.dart';

/// Resolves the enemy for the current bout (Content Expansion V1, matrix
/// §G/§H). Deterministic — a pure function of `runNumber` + `fightIndex`,
/// like the stat-ramp it replaces; no RNG, so a given run always meets
/// the same sequence.
///
/// Normal bouts draw from an archetype pool that widens as the run count
/// climbs (early runs teach "survive a hit" / "stop a rush"; later runs
/// add the counter/reach/evasive/armour tests). The final bout of every
/// run is a boss, cycled by run number so all three come round.
EnemyView enemyFor(RunState run) {
  final ramp = run.runNumber - 1; // 0 on run 1

  if (run.isHardFight) {
    final boss = _bosses[(run.runNumber - 1) % _bosses.length];
    return _scaled(boss, ramp: ramp, fightIndex: 0, boss: true);
  }

  final pool = _normalPoolFor(run.runNumber);
  final pick = pool[(run.runNumber * 7 + run.fightIndex * 3) % pool.length];
  return _scaled(pick, ramp: ramp, fightIndex: run.fightIndex, boss: false);
}

List<EnemyArchetype> _normalPoolFor(int runNumber) {
  final pool = <EnemyArchetype>[EnemyArchetype.brute, EnemyArchetype.fastStriker];
  if (runNumber > 10) {
    pool.addAll([
      EnemyArchetype.guardSpecialist,
      EnemyArchetype.counterFighter,
      EnemyArchetype.reachFighter,
    ]);
  }
  if (runNumber > 20) {
    pool.addAll([EnemyArchetype.evasive, EnemyArchetype.armorFighter]);
  }
  if (runNumber > 30) {
    pool.add(EnemyArchetype.enduranceFighter);
  }
  return pool;
}

const _bosses = [
  EnemyArchetype.ironWall,
  EnemyArchetype.flashDuelist,
  EnemyArchetype.counterMaster,
];

/// Per-archetype base line — deliberately simple, tuned only enough to
/// make each fight ask its question. Ramp scaling is applied on top.
EnemyView _base(EnemyArchetype a) => switch (a) {
      EnemyArchetype.brute => EnemyView(
          id: 'heavy_brute', archetype: a,
          health: 26, damage: 6, damageStat: 'fist', initiative: 3),
      EnemyArchetype.fastStriker => EnemyView(
          id: 'fast_striker', archetype: a,
          health: 14, damage: 2, damageStat: 'fist', initiative: 12, hits: 2),
      EnemyArchetype.guardSpecialist => EnemyView(
          id: 'guard_specialist', archetype: a,
          health: 22, damage: 4, damageStat: 'fist', initiative: 6, armour: 0.35),
      EnemyArchetype.counterFighter => EnemyView(
          id: 'counter_fighter', archetype: a,
          health: 20, damage: 4, damageStat: 'fist', initiative: 7, missPunish: 0.4),
      EnemyArchetype.reachFighter => EnemyView(
          id: 'reach_fighter', archetype: a,
          health: 20, damage: 4, damageStat: 'reach', initiative: 20),
      EnemyArchetype.evasive => EnemyView(
          id: 'evasive_fighter', archetype: a,
          health: 16, damage: 3, damageStat: 'fist', initiative: 9, dodge: 0.35),
      EnemyArchetype.armorFighter => EnemyView(
          id: 'armor_fighter', archetype: a,
          health: 30, damage: 3, damageStat: 'fist', initiative: 4, armour: 0.55),
      EnemyArchetype.enduranceFighter => EnemyView(
          id: 'endurance_fighter', archetype: a,
          health: 24, damage: 4, damageStat: 'fist', initiative: 6, regen: 3),
      EnemyArchetype.ironWall => EnemyView(
          id: 'the_iron_wall', archetype: a,
          health: 40, damage: 5, damageStat: 'fist', initiative: 4, armour: 0.55),
      EnemyArchetype.flashDuelist => EnemyView(
          id: 'the_flash_duelist', archetype: a,
          health: 30, damage: 4, damageStat: 'blade', initiative: 20, dodge: 0.35, hits: 2),
      EnemyArchetype.counterMaster => EnemyView(
          id: 'the_counter_master', archetype: a,
          health: 34, damage: 5, damageStat: 'fist', initiative: 8, missPunish: 0.4),
    };

EnemyView _scaled(EnemyArchetype a,
    {required int ramp, required int fightIndex, required bool boss}) {
  final b = _base(a);
  return EnemyView(
    id: b.id,
    archetype: b.archetype,
    health:
        (b.health + ramp * (boss ? 6 : 3) + fightIndex * 2).round(),
    damage: (b.damage + (boss ? ramp : ramp ~/ 2)).round(),
    damageStat: b.damageStat,
    initiative: b.initiative,
    armour: b.armour,
    dodge: b.dodge,
    missPunish: b.missPunish,
    regen: b.regen,
    hits: b.hits,
  );
}
