// lib/features/combat/combat_event.dart
import '../../core/models/enemy_view.dart';

sealed class CombatEvent {
  const CombatEvent();
}

class FightStarted extends CombatEvent {
  const FightStarted(this.enemy);
  final EnemyView enemy;
}
