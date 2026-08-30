// lib/features/combat/combat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'combat_bloc.dart';
import 'combat_event.dart';
import 'presentation/log_replay_combat_presentation.dart';

class CombatScreen extends StatelessWidget {
  const CombatScreen({
    super.key,
    required this.enemyId,
    required this.enemyHealth,
    required this.enemyDamage,
    required this.enemyDamageStat,
    required this.onFinished,
  });

  final String enemyId;
  final num enemyHealth;
  final num enemyDamage;
  final String enemyDamageStat;
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CombatBloc>();
    if (bloc.state.log.isEmpty && bloc.state.won == null) {
      bloc.add(FightStarted(enemyId, enemyHealth, enemyDamage, enemyDamageStat));
    }
    return BlocBuilder<CombatBloc, CombatState>(
      builder: (context, state) => Scaffold(
        body: state.log.isEmpty
            ? const Center(child: Text('Fighting...'))
            : LogReplayCombatPresentation(
                log: state.log,
                onFinished: onFinished,
              ),
      ),
    );
  }
}
