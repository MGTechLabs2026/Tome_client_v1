// lib/features/combat/combat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/models/combat_log_entry_view.dart';
import '../../core/persistence/records_repository.dart';
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
    this.isHardFight = false,
  });

  final String enemyId;
  final num enemyHealth;
  final num enemyDamage;
  final String enemyDamageStat;

  /// Fired when the replay finishes, with the outcome: `true` if the
  /// fighter won this bout. A win goes on to loot; a loss ends the run.
  final void Function(bool won) onFinished;
  final String playerName;

  /// The final bout of the run — surfaced in the matchup line.
  final bool isHardFight;

  /// The largest single drop in the enemy's health across the log — the
  /// heaviest blow the fighter landed this bout. Enemy HP only falls
  /// from player damage, so consecutive snapshot deltas are the hits.
  static int _heaviestBlow(List<CombatLogEntryView> log) {
    num? prev;
    var worst = 0.0;
    for (final e in log) {
      final hp = e.enemyHp;
      if (hp == null) continue;
      if (prev != null && hp < prev) {
        final drop = (prev - hp).toDouble();
        if (drop > worst) worst = drop;
      }
      prev = hp;
    }
    return worst.round();
  }

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
                onFinished: () {
                  context
                      .read<RecordsRepository>()
                      .recordBlow(_heaviestBlow(state.log));
                  onFinished(state.won ?? true);
                },
                playerName: playerName,
                enemyName: isHardFight ? '$_enemyName  ·  HARD' : _enemyName,
              ),
      ),
    );
  }
}
