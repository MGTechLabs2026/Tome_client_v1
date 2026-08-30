// lib/features/combat/combat_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/engine/combat_adapter.dart';
import 'combat_event.dart';
import 'combat_state.dart';

export 'combat_state.dart';

class CombatBloc extends Bloc<CombatEvent, CombatState> {
  CombatBloc(this._adapter) : super(const CombatState()) {
    on<FightStarted>((event, emit) {
      final outcome = _adapter.runFight(
        event.enemyId,
        enemyHealth: event.enemyHealth,
        enemyDamage: event.enemyDamage,
        enemyDamageStat: event.enemyDamageStat,
      );
      emit(CombatState(inProgress: false, won: outcome.won, log: outcome.log));
    });
  }

  final CombatAdapter _adapter;
}
