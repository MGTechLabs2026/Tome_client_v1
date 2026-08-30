// lib/features/training/training_result_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/engine/technique_adapter.dart';
import '../../core/models/game_phase.dart';
import '../tome/hall/hall_theme.dart';
import '../run/run_bloc.dart';
import '../run/run_event.dart';
import 'training_bloc.dart';

/// The result beat of the training loop: the gains you earned, and — if
/// the engine's rules evolved the technique — the surprise discovery,
/// shown with the form it grew out of. The evolution is entirely
/// engine-authoritative (`TrainingAdapter` -> `evolveTechnique`); the
/// client only renders what came back.
class TrainingResultScreen extends StatelessWidget {
  const TrainingResultScreen({super.key});

  String _name(BuildContext context, String? id) {
    if (id == null) return '';
    try {
      return context.read<TechniqueAdapter>().viewOf(id).name;
    } catch (_) {
      return id.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return BlocBuilder<TrainingBloc, TrainingState>(builder: (context, state) {
      final result = state.result!;
      final discovered = result.evolvedIntoDefinitionId != null;

      return Scaffold(
        backgroundColor: hall.lacquer,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('TRAINING COMPLETE',
                    style: hall.heading.copyWith(letterSpacing: 3)),
                const SizedBox(height: 24),

                if (discovered) ...[
                  Text('NEW TECHNIQUE',
                      style: hall.label.copyWith(color: hall.vermilion)),
                  const SizedBox(height: 8),
                  Text(_name(context, result.evolvedIntoDefinitionId),
                      style: hall.displayLarge, textAlign: TextAlign.center),
                  const SizedBox(height: 14),
                  Text('EVOLVED FROM', style: hall.label),
                  const SizedBox(height: 4),
                  Text(_name(context, result.evolvedFromDefinitionId),
                      style: hall.body.copyWith(color: hall.boneDim)),
                ] else ...[
                  Text(
                    result.crossedIntoUsableOrLearned
                        ? (state.isTechnique ? 'TECHNIQUE LEARNED' : 'FORM READY')
                        : (state.isTechnique
                            ? 'progress toward learning'
                            : 'mastery raised'),
                    style: hall.label.copyWith(
                      color: result.crossedIntoUsableOrLearned
                          ? hall.bone
                          : hall.boneDim,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('+${result.gain.toStringAsFixed(1)}',
                      style: hall.displayLarge),
                  Text('mastery', style: hall.measure),
                ],

                const SizedBox(height: 22),
                for (final entry in result.dimensions.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${entry.key.toUpperCase()}   '
                      '${(entry.value * 100).toStringAsFixed(0)}%',
                      style: hall.measure,
                    ),
                  ),

                const Spacer(),
                FilledButton(
                  onPressed: () => context
                      .read<RunBloc>()
                      .add(const PhaseCompleted(GamePhase.tome)),
                  child: Text(discovered ? 'Continue to Tome' : 'Back to Tome'),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
