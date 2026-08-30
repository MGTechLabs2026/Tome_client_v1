// lib/features/combat/combat_preparation_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/models/game_phase.dart';
import '../run/run_bloc.dart';
import '../run/run_event.dart';

class CombatPreparationScreen extends StatelessWidget {
  const CombatPreparationScreen({super.key, required this.enemyId, required this.enemyHealth});
  final String enemyId;
  final num enemyHealth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Next: $enemyId  (HP $enemyHealth)'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () =>
                context.read<RunBloc>().add(const PhaseCompleted(GamePhase.combat)),
            child: const Text('Confirm & Fight'),
          ),
        ]),
      ),
    );
  }
}
