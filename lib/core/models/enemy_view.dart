// lib/core/models/enemy_view.dart

/// The eight normal archetypes plus three bosses (Content Expansion V1,
/// matrix §G/§H). Each exposes a reason a specific build is good or bad
/// against it — the roguelike's "enemies force you to adapt" rule — via
/// the behaviour fields on [EnemyView], never a bare HP ladder.
enum EnemyArchetype {
  brute,
  fastStriker,
  guardSpecialist,
  counterFighter,
  reachFighter,
  evasive,
  armorFighter,
  enduranceFighter,
  // bosses
  ironWall,
  flashDuelist,
  counterMaster;

  bool get isBoss => index >= EnemyArchetype.ironWall.index;

  String get label => switch (this) {
        EnemyArchetype.brute => 'Heavy Brute',
        EnemyArchetype.fastStriker => 'Fast Striker',
        EnemyArchetype.guardSpecialist => 'Guard Specialist',
        EnemyArchetype.counterFighter => 'Counter Fighter',
        EnemyArchetype.reachFighter => 'Reach Fighter',
        EnemyArchetype.evasive => 'Evasive Fighter',
        EnemyArchetype.armorFighter => 'Armor Fighter',
        EnemyArchetype.enduranceFighter => 'Endurance Fighter',
        EnemyArchetype.ironWall => 'The Iron Wall',
        EnemyArchetype.flashDuelist => 'The Flash Duelist',
        EnemyArchetype.counterMaster => 'The Counter Master',
      };

  /// The build question this fight asks — shown on the prep screen.
  String get tests => switch (this) {
        EnemyArchetype.brute => 'Can you take a big hit and keep swinging?',
        EnemyArchetype.fastStriker => 'End it before the small hits pile up.',
        EnemyArchetype.guardSpecialist => 'Bring power, or precision that never misses.',
        EnemyArchetype.counterFighter => "Don't over-swing — every miss is punished.",
        EnemyArchetype.reachFighter => 'It strikes first. Out-initiative or out-last it.',
        EnemyArchetype.evasive => 'Precision and consistency beat raw power here.',
        EnemyArchetype.armorFighter => 'Raw output and patience. Chip it down.',
        EnemyArchetype.enduranceFighter => 'Win the race — it heals every turn.',
        EnemyArchetype.ironWall => 'Break the armour, or grind it with sure hits.',
        EnemyArchetype.flashDuelist => 'Land through the dodge, or out-armour the trade.',
        EnemyArchetype.counterMaster => 'Only high-percentage actions. Patience wins.',
      };
}

/// One resolved enemy for a bout — plain data the combat adapter reads.
/// [armour]/[dodge]/[missPunish] are 0..1 fractions; [regen] is flat
/// HP restored on the enemy's turn; [hits] is how many times it strikes
/// per turn.
class EnemyView {
  const EnemyView({
    required this.id,
    required this.archetype,
    required this.health,
    required this.damage,
    required this.damageStat,
    this.initiative = 8,
    this.armour = 0,
    this.dodge = 0,
    this.missPunish = 0,
    this.regen = 0,
    this.hits = 1,
  });

  final String id;
  final EnemyArchetype archetype;
  final num health;
  final num damage;
  final String damageStat;
  final num initiative;

  /// Fraction of each landed player hit this enemy shrugs off (0..1).
  final double armour;

  /// Fraction reduction to the player's hit chance (0..1).
  final double dodge;

  /// Extra enemy damage, as a fraction of [damage], when a player action
  /// misses (0..1).
  final double missPunish;

  /// Flat HP the enemy regains at the end of its turn.
  final num regen;

  /// Strikes per enemy turn.
  final int hits;

  bool get isBoss => archetype.isBoss;
  String get label => archetype.label;
}
