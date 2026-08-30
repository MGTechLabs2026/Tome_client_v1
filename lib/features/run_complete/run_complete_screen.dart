// lib/features/run_complete/run_complete_screen.dart
import 'package:flutter/material.dart';

import '../tome/hall/hall_theme.dart';

/// Shown after the final (hard) bout of a run. The character and build
/// carry over — [onContinue] starts the next, longer run; [onRestart]
/// begins again with a fresh fighter.
class RunCompleteScreen extends StatelessWidget {
  const RunCompleteScreen({
    super.key,
    required this.onContinue,
    required this.onRestart,
    this.runNumber = 1,
    this.fightsCleared = 3,
    this.nextRunFights = 3,
  });

  final VoidCallback onContinue;
  final VoidCallback onRestart;
  final int runNumber;
  final int fightsCleared;
  final int nextRunFights;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Scaffold(
      backgroundColor: hall.lacquer,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('RUN $runNumber CLEARED',
                style: hall.display.copyWith(fontSize: 30, letterSpacing: 4)),
            const SizedBox(height: 12),
            Text(
              '$fightsCleared bouts fought. Run ${runNumber + 1} brings '
              '$nextRunFights.',
              style: hall.body.copyWith(color: hall.boneDim),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: onContinue,
              child: const Text('Continue'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRestart,
              child: Text('Start Over',
                  style: hall.label.copyWith(color: hall.boneDim)),
            ),
          ],
        ),
      ),
    );
  }
}
