// lib/features/defeat/defeat_screen.dart
//
// The lineage is down. A short beat — how far the line got — then one
// way out: back to the Hall. This is in-game chrome, not a threshold
// surface, so it stays opaque flat lacquer (no oiled-paper frost).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../run/run_bloc.dart';
import '../run/run_event.dart';
import '../tome/hall/hall_controls.dart';
import '../tome/hall/hall_theme.dart';

class DefeatScreen extends StatelessWidget {
  const DefeatScreen({super.key, required this.runNumber, required this.bout});

  final int runNumber;
  final int bout;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Scaffold(
      backgroundColor: hall.lacquer,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'THE LINE ENDS',
              style: hall.display.copyWith(color: hall.slate, letterSpacing: 3),
            ),
            const SizedBox(height: 16),
            Text(
              'The lineage fell on run $runNumber, bout $bout.',
              style: hall.reading.copyWith(color: hall.boneDim),
            ),
            const SizedBox(height: 32),
            InkButton(
              label: 'Return to the Hall',
              tone: InkTone.plain,
              onPressed: () => context.read<RunBloc>().add(const RunReset()),
            ),
          ],
        ),
      ),
    );
  }
}
