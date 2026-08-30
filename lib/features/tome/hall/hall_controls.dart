// lib/features/tome/hall/hall_controls.dart
//
// Controls drawn in the hall's own ink hand — no Material buttons in the
// committed surface.
import 'package:flutter/material.dart';

import 'hall_theme.dart';
import 'ink.dart';

/// A struck-edge action. [tone] picks the ink: seal (vermilion, the
/// primary/commit action), plain (bone outline), or gold (mastered path).
enum InkTone { seal, plain, gold, quiet }

class InkButton extends StatefulWidget {
  const InkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = InkTone.plain,
    this.glyph,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final InkTone tone;
  final CustomPainter? glyph;
  final bool dense;

  @override
  State<InkButton> createState() => _InkButtonState();
}

class _InkButtonState extends State<InkButton> {
  bool _down = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final enabled = widget.onPressed != null;
    final ink = switch (widget.tone) {
      InkTone.seal => hall.vermilion,
      InkTone.gold => hall.gold,
      InkTone.quiet => hall.boneDim,
      InkTone.plain => hall.bone,
    };
    final filled = widget.tone == InkTone.seal;
    final fg = filled ? hall.bone : ink;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: widget.onPressed,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.label,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: CustomPaint(
              painter: _InkButtonEdge(
                ink: ink,
                filled: filled,
                pressed: _down,
                hover: _hover && enabled,
                seed: widget.label.hashCode,
                shadowTint: hall.lacquerDeep,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.dense ? 12 : 18,
                  vertical: widget.dense ? 8 : 11,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.glyph != null) ...[
                      CustomPaint(
                        size: const Size(14, 14),
                        painter: widget.glyph,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label.toUpperCase(),
                      style: hall.label.copyWith(
                        color: fg,
                        fontSize: widget.dense ? 10 : 11,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InkButtonEdge extends CustomPainter {
  _InkButtonEdge({
    required this.ink,
    required this.filled,
    required this.pressed,
    required this.hover,
    required this.seed,
    required this.shadowTint,
  });
  final Color ink;
  final bool filled;
  final bool pressed;
  final bool hover;
  final int seed;
  final Color shadowTint;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(2);
    final path = handRect(r, radius: 2, seed: seed);
    if (!pressed) {
      canvas.save();
      canvas.translate(2.4, 3);
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.34)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.restore();
    }
    if (filled) {
      canvas.drawPath(
        path,
        Paint()..color = ink.withValues(alpha: hover ? 1 : 0.92),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Colors.black.withValues(alpha: 0.25),
      );
    } else {
      canvas.drawPath(
        path,
        Paint()..color = ink.withValues(alpha: hover ? 0.12 : 0.05),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = pressed ? 2 : 1.6
          ..color = ink.withValues(alpha: hover ? 0.95 : 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(_InkButtonEdge old) =>
      old.pressed != pressed ||
      old.hover != hover ||
      old.ink != ink ||
      old.filled != filled;
}

/// The struck hammer glyph — the upgrade affordance, drawn not iconified.
class HammerGlyph extends CustomPainter {
  HammerGlyph({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    final w = size.width, h = size.height;
    // handle: a tapered bar from lower-left to the head
    final handle = Path()
      ..moveTo(w * 0.34, h * 0.98)
      ..lineTo(w * 0.24, h * 0.90)
      ..lineTo(w * 0.52, h * 0.34)
      ..lineTo(w * 0.66, h * 0.44)
      ..close();
    canvas.drawPath(handle, fill);
    // head: a solid block across the top, canted with the handle
    final head = Path()
      ..moveTo(w * 0.30, h * 0.30)
      ..lineTo(w * 0.86, h * 0.10)
      ..lineTo(w * 0.98, h * 0.34)
      ..lineTo(w * 0.42, h * 0.54)
      ..close();
    canvas.drawPath(head, fill);
  }

  @override
  bool shouldRepaint(HammerGlyph old) => old.color != color;
}

/// A leader line + label: a thin drawn rule from an anchor edge out to a
/// quantity, the hall's way of annotating a relationship.
class LeaderLabel extends StatelessWidget {
  const LeaderLabel({super.key, required this.text, this.strong = false});
  final String text;
  final bool strong;
  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(22, 8),
          painter: _Leader(color: hall.boneDim),
        ),
        const SizedBox(width: 6),
        Text(text, style: strong ? hall.measureStrong : hall.measure),
      ],
    );
  }
}

class _Leader extends CustomPainter {
  _Leader({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final p =
        Paint()
          ..color = color
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(1.5, y), 1.6, Paint()..color = color);
    canvas.drawLine(Offset(3, y), Offset(size.width, y), p);
  }

  @override
  bool shouldRepaint(_Leader old) => old.color != color;
}
