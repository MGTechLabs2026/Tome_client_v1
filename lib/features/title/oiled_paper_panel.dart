// lib/features/title/oiled_paper_panel.dart
//
// The Threshold Panel (DESIGN.md): the one translucent surface in the
// project. A BackdropFilter blur behind a warm bone tint, a hand-cut
// `handRect` edge, and a raking shadow — so the title screen and the
// menus it opens stay legible over a full-bleed background painting
// that has not been placed yet. Reads as oiled paper over the light,
// never glass. Confined to this feature; the in-game surface stays
// opaque flat lacquer.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../tome/hall/hall_theme.dart';
import '../tome/hall/ink.dart';

class OiledPaperPanel extends StatelessWidget {
  const OiledPaperPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(28, 28, 28, 24),
    this.maxWidth = 380,
    this.seed = 0x7EA,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double maxWidth;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: rakingShadow(elevation: 1.2, tint: hall.lacquerDeep),
        ),
        child: ClipPath(
          clipper: _HandRectClipper(seed),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: CustomPaint(
              painter: _PanelFace(hall: hall, seed: seed),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Clips the blur to the hand-cut silhouette so the frost stops at the
/// torn edge, not a crisp rectangle.
class _HandRectClipper extends CustomClipper<Path> {
  const _HandRectClipper(this.seed);
  final int seed;

  @override
  Path getClip(Size size) =>
      handRect(Offset.zero & size, radius: 3, seed: seed, jitter: 1.1);

  @override
  bool shouldReclip(_HandRectClipper old) => old.seed != seed;
}

/// The warm bone wash + inner raking light + carved edge painted over
/// the blurred backdrop.
class _PanelFace extends CustomPainter {
  _PanelFace({required this.hall, required this.seed});
  final HallTheme hall;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = handRect(rect, radius: 3, seed: seed, jitter: 1.1);

    // Oiled-paper body: a warm bone tint deep enough to read as a
    // surface, not a pane of glass.
    canvas.drawPath(
      path,
      Paint()..color = hall.bone.withValues(alpha: 0.12),
    );
    // Inner light-to-shade wash from the hall's one raking light.
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          [
            Colors.white.withValues(alpha: 0.06),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.10),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );
    // Carved edge — matte, not a bright rim-light.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = hall.bone.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(_PanelFace old) => old.hall != hall || old.seed != seed;
}
