// lib/features/training/active_training_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/engine/character_adapter.dart';
import '../../core/engine/training_adapter.dart';
import '../../core/models/game_phase.dart';
import '../../core/persistence/training_pace_repository.dart';
import '../run/run_bloc.dart';
import '../run/run_event.dart';
import '../tome/hall/hall_theme.dart';
import 'exercise/target_strike_controller.dart';
import 'exercise/training_target.dart';
import 'presentation/target_field.dart';
import 'presentation/training_scene.dart';
import 'training_bloc.dart';
import 'training_event.dart';

/// ACTIVE TRAINING — the interactive target-strike exercise. Three
/// waves of three targets over a lineage scene; tap fast and centred.
/// The scene and targets own the frame; the timing/score strip at the
/// foot stays quiet.
class ActiveTrainingScreen extends StatefulWidget {
  const ActiveTrainingScreen({super.key});

  @override
  State<ActiveTrainingScreen> createState() => _ActiveTrainingScreenState();
}

class _ActiveTrainingScreenState extends State<ActiveTrainingScreen> {
  late final TargetStrikeController _controller;
  late final TrainingScene _scene;
  int _wave = 0;
  bool _handedOff = false;

  @override
  void initState() {
    super.initState();
    _controller = TargetStrikeController(
      context.read<TrainingAdapter>().random,
      initialPace: context.read<TrainingPaceRepository>().pace,
    );
    final tradition =
        context.read<CharacterAdapter>().currentView().martialTradition;
    _scene = TrainingScene.forTradition(tradition);
  }

  void _onResolved(TargetResolution res) {
    _controller.resolve(res);
    setState(() {}); // refresh the foot meters
  }

  void _onWaveComplete() {
    if (_wave + 1 < TargetStrikeController.waveCount) {
      setState(() => _wave++);
      return;
    }
    if (_handedOff) return;
    _handedOff = true;
    // Carry this run's skill forward (heavily smoothed) so the next
    // session starts where this one left off.
    context.read<TrainingPaceRepository>().recordSession(_controller.sessionScore);
    context.read<TrainingBloc>().add(TrainingRunCompleted(
          _controller.attemptMeasurements,
          _controller.summary,
        ));
  }

  String _prettySubject(String? id) => (id ?? '')
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;

    return BlocListener<TrainingBloc, TrainingState>(
      listenWhen: (p, n) => p.result == null && n.result != null,
      listener: (context, _) => context
          .read<RunBloc>()
          .add(const PhaseCompleted(GamePhase.trainingResult)),
      child: Scaffold(
        backgroundColor: hall.lacquer,
        body: SafeArea(
          child: BlocBuilder<TrainingBloc, TrainingState>(
            builder: (context, state) {
              final s = _controller.summary;
              return Column(
                children: [
                  _Header(
                    subject: _prettySubject(state.subject),
                    sceneLabel: _scene.label,
                    wave: _wave + 1,
                    waves: TargetStrikeController.waveCount,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: TargetField(
                        key: ValueKey(_wave),
                        scene: _scene,
                        wave: _controller.wave(_wave),
                        onResolved: _onResolved,
                        onWaveComplete: _onWaveComplete,
                      ),
                    ),
                  ),
                  _FootMeters(summary: s),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.subject,
    required this.sceneLabel,
    required this.wave,
    required this.waves,
  });

  final String subject;
  final String sceneLabel;
  final int wave;
  final int waves;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('TRAINING',
                  style: hall.label.copyWith(color: hall.boneDim, letterSpacing: 3)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  subject.toUpperCase(),
                  style: hall.heading.copyWith(fontSize: 13, letterSpacing: 2.4),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('$wave / $waves', style: hall.measureStrong),
            ],
          ),
          const SizedBox(height: 3),
          Text(sceneLabel,
              style: hall.measure.copyWith(
                  fontSize: 10, color: hall.boneDim.withValues(alpha: 0.7))),
          const SizedBox(height: 8),
          Container(height: 1, color: hall.bone.withValues(alpha: 0.12)),
        ],
      ),
    );
  }
}

class _FootMeters extends StatelessWidget {
  const _FootMeters({required this.summary});
  final TrainingRunSummary summary;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    // Live estimates from what's resolved so far.
    final speed = summary.hits == 0
        ? 0.0
        : (1 - summary.avgReactionMs / 1200).clamp(0.0, 1.0);
    final precision = summary.precision;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        children: [
          Container(height: 1, color: hall.bone.withValues(alpha: 0.12)),
          const SizedBox(height: 12),
          _Meter(label: 'SPEED', value: speed),
          const SizedBox(height: 8),
          _Meter(label: 'PRECISION', value: precision),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('MISS', style: hall.label.copyWith(color: hall.boneDim)),
              const SizedBox(width: 12),
              Text('${summary.misses}', style: hall.measureStrong),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Row(
      children: [
        SizedBox(
          width: 78,
          child:
              Text(label, style: hall.label.copyWith(color: hall.boneDim)),
        ),
        Expanded(
          child: ClipRect(
            child: Container(
              height: 5,
              color: hall.bone.withValues(alpha: 0.12),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0),
                child: Container(color: hall.bone.withValues(alpha: 0.7)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
