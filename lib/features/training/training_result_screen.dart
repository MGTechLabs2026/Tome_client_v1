// lib/features/training/training_result_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/engine/technique_adapter.dart';
import '../../core/models/game_phase.dart';
import '../run/run_bloc.dart';
import '../run/run_event.dart';
import '../tome/hall/hall_controls.dart';
import '../tome/hall/hall_theme.dart';
import '../tome/hall/ink.dart';
import 'exercise/target_strike_controller.dart' show TrainingRunSummary;
import 'training_bloc.dart';

/// The result beat: the performance read, the engine's progression, and
/// — if the engine's rules evolved the technique — the surprise
/// discovery. Evolution is entirely engine-authoritative; the client
/// only renders what came back.
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
      final s = state.summary;
      final evolved = result.evolvedIntoDefinitionId != null;

      final consequenceLabel = !state.isTechnique
          ? 'ITEM MASTERY'
          : (result.crossedIntoUsableOrLearned
              ? 'TECHNIQUE MASTERY'
              : 'TECHNIQUE LEARNING');

      return Scaffold(
        backgroundColor: hall.lacquer,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 30, 28, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('TRAINING COMPLETE',
                    style: hall.heading.copyWith(letterSpacing: 3)),
                const SizedBox(height: 22),

                if (evolved)
                  _EvolutionBeat(
                    into: _name(context, result.evolvedIntoDefinitionId),
                    from: _name(context, result.evolvedFromDefinitionId),
                  )
                else
                  Column(
                    children: [
                      Text(consequenceLabel,
                          style: hall.label.copyWith(
                            color: result.crossedIntoUsableOrLearned
                                ? hall.bone
                                : hall.boneDim,
                          )),
                      const SizedBox(height: 8),
                      Text('+${result.gain.toStringAsFixed(1)}',
                          style: hall.displayLarge),
                    ],
                  ),

                const SizedBox(height: 26),
                if (s != null) _SummaryLedger(s),

                const Spacer(),
                Align(
                  alignment: Alignment.center,
                  child: InkButton(
                    label: evolved ? 'Continue to the Tome' : 'Back to the Tome',
                    tone: evolved ? InkTone.seal : InkTone.plain,
                    onPressed: () => context
                        .read<RunBloc>()
                        .add(const PhaseCompleted(GamePhase.tome)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _EvolutionBeat extends StatelessWidget {
  const _EvolutionBeat({required this.into, required this.from});
  final String into;
  final String from;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Column(
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: CustomPaint(
            painter: SealChopPainter(contentId: 'evolved:$into', ink: hall.vermilion),
          ),
        ),
        const SizedBox(height: 16),
        Text('NEW TECHNIQUE',
            style: hall.label.copyWith(color: hall.vermilion, letterSpacing: 3)),
        const SizedBox(height: 10),
        Text(into.toUpperCase(),
            style: hall.displayLarge, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Text('EVOLVED FROM', style: hall.label.copyWith(color: hall.boneDim)),
        const SizedBox(height: 4),
        Text(from, style: hall.body.copyWith(color: hall.boneDim)),
      ],
    );
  }
}

class _SummaryLedger extends StatelessWidget {
  const _SummaryLedger(this.s);
  final TrainingRunSummary s;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: hall.label.copyWith(color: hall.boneDim)),
              ),
              Text(value, style: hall.measureStrong),
            ],
          ),
        );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        children: [
          Container(height: 1, color: hall.bone.withValues(alpha: 0.12)),
          const SizedBox(height: 10),
          row('HITS', '${s.hits} / ${s.total}'),
          row('PERFECT', '${s.perfect}'),
          row('MISSES', '${s.misses}'),
          row('AVG REACTION', s.avgReactionMs == 0 ? '—' : '${s.avgReactionMs} ms'),
          row('PRECISION', '${(s.precision * 100).round()}%'),
          const SizedBox(height: 10),
          Container(height: 1, color: hall.bone.withValues(alpha: 0.12)),
        ],
      ),
    );
  }
}
