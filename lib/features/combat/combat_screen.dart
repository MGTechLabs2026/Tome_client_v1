// lib/features/combat/combat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../tome/hall/hall_theme.dart';
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
    this.playerName = '',
  });

  final String enemyId;
  final num enemyHealth;
  final num enemyDamage;
  final String enemyDamageStat;
  final VoidCallback onFinished;
  final String playerName;

  /// `sparring_partner` -> `Sparring Partner`.
  String get _enemyName => enemyId
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final bloc = context.read<CombatBloc>();
    if (bloc.state.log.isEmpty && bloc.state.won == null) {
      bloc.add(FightStarted(enemyId, enemyHealth, enemyDamage, enemyDamageStat));
    }
    return BlocBuilder<CombatBloc, CombatState>(
      builder: (context, state) => Scaffold(
        backgroundColor: hall.lacquer,
        body: state.log.isEmpty
            ? Center(
                child: Text('Fighting…',
                    style: hall.label.copyWith(color: hall.boneDim)),
              )
            : LogReplayCombatPresentation(
                log: state.log,
                onFinished: onFinished,
                playerName: playerName,
                enemyName: _enemyName,
              ),
      ),
    );
  }
}
