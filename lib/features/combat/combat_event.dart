// lib/features/combat/combat_event.dart
sealed class CombatEvent {
  const CombatEvent();
}

class FightStarted extends CombatEvent {
  const FightStarted(this.enemyId, this.enemyHealth, this.enemyDamage, this.enemyDamageStat);
  final String enemyId;
  final num enemyHealth;
  final num enemyDamage;
  final String enemyDamageStat;
}
