// lib/features/combat/combat_preparation_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/models/game_phase.dart';
import '../tome/hall/hall_theme.dart';
import '../run/run_bloc.dart';
import '../run/run_event.dart';

class CombatPreparationScreen extends StatefulWidget {
  const CombatPreparationScreen({
    super.key,
    required this.enemyId,
    required this.enemyHealth,
    this.isHardFight = false,
    this.boutLabel = '',
  });
  final String enemyId;
  final num enemyHealth;
  final bool isHardFight;
  final String boutLabel;

  String get _enemyName => enemyId
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  @override
  State<CombatPreparationScreen> createState() => _CombatPreparationScreenState();
}

class _CombatPreparationScreenState extends State<CombatPreparationScreen> {
  // Ignore any tap that arrives in the same frame this screen mounts —
  // a pointer-up left over from the button that navigated here can
  // otherwise trip "Confirm & Fight" before the player sees it.
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _armed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Scaffold(
      backgroundColor: hall.lacquer,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.boutLabel.isNotEmpty)
              Text(widget.boutLabel,
                  style: hall.label.copyWith(color: hall.boneDim)),
            const SizedBox(height: 14),
            Text(
              widget.isHardFight ? 'HARD FIGHT' : 'NEXT BOUT',
              style: hall.heading.copyWith(
                letterSpacing: 4,
                color: widget.isHardFight ? hall.vermilion : hall.bone,
              ),
            ),
            const SizedBox(height: 10),
            Text(widget._enemyName, style: hall.display),
            const SizedBox(height: 4),
            Text('${widget.enemyHealth.round()} vitality',
                style: hall.measure),
            const SizedBox(height: 26),
            FilledButton(
              onPressed: _armed
                  ? () => context
                      .read<RunBloc>()
                      .add(const PhaseCompleted(GamePhase.combat))
                  : null,
              child: const Text('Confirm & Fight'),
            ),
          ],
        ),
      ),
    );
  }
}
