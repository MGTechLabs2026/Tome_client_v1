// lib/features/title/threshold_button.dart
//
// The action buttons on the oiled-paper panel. They sit on an already
// blurred surface, so the "frost" is a deeper translucent bone wash
// plus a hand-cut edge — the panel's blur carries the background
// through. NEW RUN takes a vermilion seal wash to lead the column.
import 'package:flutter/material.dart';

import '../tome/hall/hall_theme.dart';
import '../tome/hall/ink.dart';

enum ThresholdTone { seal, plain, quiet }

class ThresholdButton extends StatefulWidget {
  const ThresholdButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = ThresholdTone.plain,
  });

  final String label;
  final VoidCallback? onPressed;
  final ThresholdTone tone;

  @override
  State<ThresholdButton> createState() => _ThresholdButtonState();
}

class _ThresholdButtonState extends State<ThresholdButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final enabled = widget.onPressed != null;
    final seal = widget.tone == ThresholdTone.seal;
    final ink = switch (widget.tone) {
      ThresholdTone.seal => hall.vermilion,
      ThresholdTone.plain => hall.bone,
      ThresholdTone.quiet => hall.boneDim,
    };
    final fg = seal ? hall.bone : ink;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapUp: enabled ? (_) => setState(() => _down = false) : null,
          onTapCancel: enabled ? () => setState(() => _down = false) : null,
          onTap: widget.onPressed,
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: CustomPaint(
              painter: _ThresholdEdge(
                ink: ink,
                seal: seal,
                hover: _hover && enabled,
                pressed: _down,
                seed: widget.label.hashCode,
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.label.toUpperCase(),
                    style: hall.label.copyWith(
                      color: fg,
                      fontSize: 11,
                      letterSpacing: 2.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThresholdEdge extends CustomPainter {
  _ThresholdEdge({
    required this.ink,
    required this.seal,
    required this.hover,
    required this.pressed,
    required this.seed,
  });
  final Color ink;
  final bool seal;
  final bool hover;
  final bool pressed;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final path = handRect(
      (Offset.zero & size).deflate(1.5),
      radius: 2,
      seed: seed,
    );
    if (seal) {
      canvas.drawPath(
        path,
        Paint()..color = ink.withValues(alpha: hover ? 1 : 0.9),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Colors.black.withValues(alpha: 0.25),
      );
    } else {
      // The frosted wash: a deeper translucent bone fill over the
      // panel's blur.
      canvas.drawPath(
        path,
        Paint()..color = ink.withValues(alpha: hover ? 0.16 : 0.08),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = pressed ? 2 : 1.6
          ..color = ink.withValues(alpha: hover ? 0.9 : 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(_ThresholdEdge old) =>
      old.hover != hover ||
      old.pressed != pressed ||
      old.ink != ink ||
      old.seal != seal;
}
