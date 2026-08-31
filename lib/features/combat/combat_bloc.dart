// lib/features/combat/combat_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/engine/combat_adapter.dart';
import 'combat_event.dart';
import 'combat_state.dart';

export 'combat_state.dart';

class CombatBloc extends Bloc<CombatEvent, CombatState> {
  CombatBloc(this._adapter) : super(const CombatState()) {
    on<FightStarted>((event, emit) {
      final e = event.enemy;
      final outcome = _adapter.runFight(
        e.id,
        enemyHealth: e.health,
        enemyDamage: e.damage,
        enemyDamageStat: e.damageStat,
        enemyInitiative: e.initiative.round(),
        enemyArmour: e.armour,
        enemyDodge: e.dodge,
        enemyMissPunish: e.missPunish,
        enemyRegen: e.regen,
        enemyHits: e.hits,
      );
      emit(CombatState(
        inProgress: false,
        won: outcome.won,
        log: outcome.log,
        tally: outcome.tally,
      ));
    });
  }

  final CombatAdapter _adapter;
}
