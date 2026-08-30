// lib/features/training/training_result_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/models/game_phase.dart';
import '../run/run_bloc.dart';
import '../run/run_event.dart';
import 'training_bloc.dart';

class TrainingResultScreen extends StatelessWidget {
  const TrainingResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrainingBloc, TrainingState>(builder: (context, state) {
      final result = state.result!;
      return Scaffold(
        body: Column(children: [
          Text('Gain: ${result.gain.toStringAsFixed(1)}'),
          for (final entry in result.dimensions.entries)
            Text('${entry.key}: ${(entry.value * 100).toStringAsFixed(0)}%'),
          if (result.evolvedIntoDefinitionId != null) ...[
            const Text('NEW TECHNIQUE DISCOVERED'),
            Text('Evolved from: ${result.evolvedFromDefinitionId}'),
          ],
          const Spacer(),
          FilledButton(
            onPressed: () =>
                context.read<RunBloc>().add(const PhaseCompleted(GamePhase.tome)),
            child: const Text('Back to Tome'),
          ),
        ]),
      );
    });
  }
}
