// lib/features/run_complete/run_complete_screen.dart
import 'package:flutter/material.dart';

import '../tome/hall/hall_theme.dart';

/// Shown when the run ends — which now only happens when the player is
/// defeated in a bout. The gauntlet is otherwise endless.
class RunCompleteScreen extends StatelessWidget {
  const RunCompleteScreen({
    super.key,
    required this.onRestart,
    this.fightsWon = 0,
  });

  final VoidCallback onRestart;

  /// How many bouts the player won before falling.
  final int fightsWon;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final tally = fightsWon == 0
        ? 'Beaten in your first bout.'
        : 'You won $fightsWon ${fightsWon == 1 ? 'bout' : 'bouts'} before falling.';

    return Scaffold(
      backgroundColor: hall.lacquer,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('YOU FELL',
                style: hall.display.copyWith(fontSize: 32, letterSpacing: 4)),
            const SizedBox(height: 12),
            Text(tally, style: hall.body.copyWith(color: hall.boneDim)),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: onRestart,
              child: const Text('Start New Run'),
            ),
          ],
        ),
      ),
    );
  }
}
