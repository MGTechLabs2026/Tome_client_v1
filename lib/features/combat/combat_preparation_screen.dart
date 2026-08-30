// lib/features/combat/combat_preparation_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/models/game_phase.dart';
import '../run/run_bloc.dart';
import '../run/run_event.dart';
import 'combat_bloc.dart';
import 'combat_event.dart';

class CombatPreparationScreen extends StatelessWidget {
  const CombatPreparationScreen({
    super.key,
    required this.enemyId,
    required this.enemyHealth,
    required this.enemyDamage,
    required this.enemyDamageStat,
  });
  final String enemyId;
  final num enemyHealth;
  final num enemyDamage;
  final String enemyDamageStat;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Next: $enemyId  (HP $enemyHealth)'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              context
                  .read<CombatBloc>()
                  .add(FightStarted(enemyId, enemyHealth, enemyDamage, enemyDamageStat));
              context.read<RunBloc>().add(const PhaseCompleted(GamePhase.combat));
            },
            child: const Text('Confirm & Fight'),
          ),
        ]),
      ),
    );
  }
}
