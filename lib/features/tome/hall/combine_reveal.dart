// lib/features/tome/hall/combine_reveal.dart
//
// The focal moment: after a Combine resolves, a seal is pressed onto the
// survivor and the outcome lands on a leader line. One authored motion —
// the press drops in, blooms, and holds — gated by reduced-motion.
import 'package:flutter/material.dart';

import '../../../core/models/combine_result_view.dart';
import 'hall_theme.dart';
import 'ink.dart';

class CombineRevealOverlay extends StatefulWidget {
  const CombineRevealOverlay({
    super.key,
    required this.kind,
    required this.resultName,
    required this.resultClass,
    required this.onDone,
    required this.reduceMotion,
  });

  final CombineResultKind kind;
  final String resultName;
  final int resultClass;
  final VoidCallback onDone;
  final bool reduceMotion;

  @override
  State<CombineRevealOverlay> createState() => _CombineRevealOverlayState();
}

class _CombineRevealOverlayState extends State<CombineRevealOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration:
        widget.reduceMotion
            ? const Duration(milliseconds: 1)
            : const Duration(milliseconds: 640),
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
    Future.delayed(const Duration(milliseconds: 1700), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final failed = widget.kind == CombineResultKind.fail;
    final evolved = widget.kind == CombineResultKind.evolvedIntoNewItem;
    final ink = failed ? hall.slate : (evolved ? hall.gold : hall.vermilion);
    final headline =
        failed
            ? 'THE CORD SNAPPED'
            : evolved
            ? 'A NEW FORM'
            : 'CLASS RAISED';
    final sub =
        failed
            ? 'the roll failed — the inputs hold'
            : '${_pretty(widget.resultName)} · cls ${_r(widget.resultClass)}';

    return Positioned.fill(
      child: GestureDetector(
        onTap: widget.onDone,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.5),
          child: Center(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, child) {
                final t = Curves.easeOutCubic.transform(_c.value);
                final press = widget.reduceMotion ? 1.0 : (0.4 + 0.6 * t);
                return Transform.scale(
                  scale: press,
                  child: Opacity(
                    opacity: widget.reduceMotion ? 1 : t,
                    child: child,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
                decoration: BoxDecoration(
                  color: hall.lacquer,
                  border: Border.all(
                    color: ink.withValues(alpha: 0.7),
                    width: 2,
                  ),
                  boxShadow: rakingShadow(elevation: 1.4),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 84,
                      height: 84,
                      child: CustomPaint(
                        painter: SealChopPainter(
                          contentId: widget.resultName,
                          ink: ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      headline,
                      style: hall.heading.copyWith(
                        color: ink,
                        fontSize: 15,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(sub, style: hall.measure.copyWith(fontSize: 11.5)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _r(int n) =>
      const [
        '0',
        'I',
        'II',
        'III',
        'IV',
        'V',
        'VI',
        'VII',
        'VIII',
        'IX',
      ].elementAtOrNull(n) ??
      '$n';
}

String _pretty(String id) => id
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
