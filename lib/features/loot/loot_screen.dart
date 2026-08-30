// lib/features/loot/loot_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/models/loot_option_view.dart';
import '../tome/hall/hall_controls.dart';
import '../tome/hall/hall_theme.dart';
import '../tome/hall/ink.dart';
import 'loot_bloc.dart';
import 'loot_event.dart';

class LootScreen extends StatelessWidget {
  const LootScreen({super.key, this.onApplied});

  /// Fired once the chosen loot has been applied — the router uses it to
  /// send the player back to the Tome for the next bout.
  final VoidCallback? onApplied;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final bloc = context.read<LootBloc>();
    if (bloc.state.options.isEmpty && !bloc.state.applied) {
      bloc.add(const LootOffered());
    }
    return BlocConsumer<LootBloc, LootState>(
      listenWhen: (prev, next) => !prev.applied && next.applied,
      listener: (context, state) => onApplied?.call(),
      builder: (context, state) => Scaffold(
        backgroundColor: hall.lacquer,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
            child: Column(
              children: [
                Text('FIGHT REWARDS',
                    style: hall.heading.copyWith(fontSize: 17, letterSpacing: 5)),
                const SizedBox(height: 6),
                Text('take one',
                    style: hall.label.copyWith(color: hall.boneDim)),
                const SizedBox(height: 24),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final cards = [
                        for (final o in state.options)
                          _RewardCard(
                            option: o,
                            onTake: () => context
                                .read<LootBloc>()
                                .add(LootChosen(o.kind)),
                          ),
                      ];
                      if (c.maxWidth >= 720) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < cards.length; i++) ...[
                              if (i > 0) const SizedBox(width: 16),
                              Expanded(child: cards[i]),
                            ],
                          ],
                        );
                      }
                      return ListView.separated(
                        itemCount: cards.length,
                        separatorBuilder: (_, i) => const SizedBox(height: 14),
                        itemBuilder: (_, i) => cards[i],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.option, required this.onTake});
  final LootOptionView option;
  final VoidCallback onTake;

  String get _chopId => switch (option.kind) {
        LootKind.upgradePoints => 'reward:point',
        LootKind.gridExpansion => 'reward:board',
        LootKind.newComponent => 'reward:${option.title}',
      };

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return GestureDetector(
      onTap: onTake,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: _CardEdge(ink: hall.bone.withValues(alpha: 0.5)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: CustomPaint(
                  painter: SealChopPainter(
                    contentId: _chopId,
                    ink: hall.vermilion,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(option.title,
                  style: hall.display.copyWith(fontSize: 16, height: 1.15)),
              if (option.badge != null) ...[
                const SizedBox(height: 6),
                Text(option.badge!,
                    style: hall.label.copyWith(
                        color: hall.vermilion, fontSize: 9.5, letterSpacing: 2)),
              ],
              const SizedBox(height: 10),
              Text(option.detail,
                  style: hall.body.copyWith(color: hall.boneDim, fontSize: 12.5)),
              const SizedBox(height: 12),
              for (final e in option.effects)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 5, right: 8),
                        width: 5,
                        height: 5,
                        color: hall.vermilion,
                      ),
                      Expanded(
                        child: Text(e,
                            style:
                                hall.measure.copyWith(fontSize: 11, height: 1.3)),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              Align(
                alignment: Alignment.centerLeft,
                child: InkButton(
                  label: 'Take',
                  tone: InkTone.seal,
                  onPressed: onTake,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardEdge extends CustomPainter {
  _CardEdge({required this.ink});
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      handRect(Offset.zero & size, radius: 3, seed: (size.width * 7).round()),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = ink,
    );
  }

  @override
  bool shouldRepaint(_CardEdge old) => old.ink != ink;
}
