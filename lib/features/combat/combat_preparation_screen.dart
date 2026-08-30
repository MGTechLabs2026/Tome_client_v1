// lib/features/combat/combat_preparation_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/models/game_phase.dart';
import '../run/run_bloc.dart';
import '../run/run_event.dart';

class CombatPreparationScreen extends StatefulWidget {
  const CombatPreparationScreen({
    super.key,
    required this.enemyId,
    required this.enemyHealth,
  });
  final String enemyId;
  final num enemyHealth;

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
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Next: ${widget.enemyId}  (HP ${widget.enemyHealth})'),
            const SizedBox(height: 16),
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
