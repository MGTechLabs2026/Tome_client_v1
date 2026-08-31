// lib/features/training/training_preparation_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/models/game_phase.dart';
import '../run/run_bloc.dart';
import '../run/run_event.dart';
import '../tome/hall/hall_controls.dart';
import '../tome/hall/hall_theme.dart';
import 'training_bloc.dart';
import 'training_event.dart';

/// The brief pause before the exercise: what's being trained and why,
/// then straight in. No menus.
class TrainingPreparationScreen extends StatelessWidget {
  const TrainingPreparationScreen({
    super.key,
    required this.subject,
    required this.isTechnique,
  });

  final String subject;
  final bool isTechnique;

  String get _pretty => subject
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Scaffold(
      backgroundColor: hall.lacquer,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TRAINING',
                      style: hall.label
                          .copyWith(color: hall.boneDim, letterSpacing: 3)),
                  const SizedBox(height: 14),
                  Text(_pretty.toUpperCase(),
                      style: hall.displayLarge.copyWith(fontSize: 30)),
                  const SizedBox(height: 6),
                  Text(
                    isTechnique
                        ? 'A form — train to learn it, then to master it.'
                        : 'A piece — train to raise its mastery.',
                    style: hall.measure.copyWith(color: hall.boneDim),
                  ),
                  const SizedBox(height: 22),
                  Container(height: 1, color: hall.bone.withValues(alpha: 0.14)),
                  const SizedBox(height: 18),
                  Text(
                    'Three sets of three. Strike each mark fast and near '
                    'its centre.',
                    style: hall.reading.copyWith(color: hall.boneDim),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkButton(
                      label: 'Train',
                      tone: InkTone.seal,
                      onPressed: () {
                        context
                            .read<TrainingBloc>()
                            .add(TrainingSessionStarted(subject, isTechnique));
                        context
                            .read<RunBloc>()
                            .add(const PhaseCompleted(GamePhase.training));
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
