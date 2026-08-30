// lib/features/training/training_preparation_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/models/game_phase.dart';
import '../run/run_bloc.dart';
import '../run/run_event.dart';
import 'presentation/timing_bar_training_presentation.dart';
import 'training_bloc.dart';
import 'training_event.dart';

class TrainingPreparationScreen extends StatelessWidget {
  const TrainingPreparationScreen({super.key, required this.subject, required this.isTechnique});
  final String subject;
  final bool isTechnique;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Prepare to train: $subject'),
          FilledButton(
            onPressed: () {
              context.read<TrainingBloc>().add(TrainingSessionStarted(subject, isTechnique));
              context.read<RunBloc>().add(const PhaseCompleted(GamePhase.training));
            },
            child: const Text('Begin Training'),
          ),
        ]),
      ),
    );
  }
}

class TrainingExerciseScreen extends StatelessWidget {
  const TrainingExerciseScreen({super.key});

  static const _requiredAttempts = 3;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TrainingBloc, TrainingState>(
      listenWhen: (prev, next) => prev.result == null && next.result != null,
      listener: (context, state) =>
          context.read<RunBloc>().add(const PhaseCompleted(GamePhase.trainingResult)),
      builder: (context, state) {
        return Scaffold(
          body: Column(children: [
            TimingBarTrainingPresentation(
              onTap: (t) {
                final bloc = context.read<TrainingBloc>();
                bloc.add(AttemptSubmitted(t));
                if (state.attemptsSubmitted + 1 >= _requiredAttempts) {
                  bloc.add(const TrainingCompleted());
                }
              },
            ),
            Text('Attempts: ${state.attemptsSubmitted} / $_requiredAttempts'),
          ]),
        );
      },
    );
  }
}
