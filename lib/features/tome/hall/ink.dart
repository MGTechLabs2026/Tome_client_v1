// lib/features/tome/hall/ink.dart
//
// One drawn ink hand for the whole surface (direction seed 6f69b7e6):
// every mark — chop, rank ring, cord, state mark, control edge — is a
// brushed/carved stroke from these primitives, never a stock widget or
// an icon font. Wobble is deterministic per input so nothing jitters
// between frames.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'hall_theme.dart';

/// Deterministic pseudo-random in [-1, 1] from an integer seed — the
/// "hand" behind every wobble. Stable for a given seed, so a mark drawn
/// from a contentId looks the same every rebuild.
double _wobble(int seed) {
  var h = seed * 2654435761 & 0xFFFFFFFF;
  h ^= h >> 15;
  h = (h * 2246822519) & 0xFFFFFFFF;
  h ^= h >> 13;
  return (h / 0xFFFFFFFF) * 2 - 1;
}

int _hash(String s) {
  var h = 2166136261;
  for (final c in s.codeUnits) {
    h = (h ^ c) * 16777619 & 0xFFFFFFFF;
  }
  return h;
}

/// A short list of soft, offset shadows consistent with the hall's one
/// raking light — never a zero-offset colour halo.
List<BoxShadow> rakingShadow({double elevation = 1, Color? tint}) {
  final dir = -kRakingLight; // shadow falls away from the light
  final base = tint ?? Colors.black;
  return [
    BoxShadow(
      color: base.withValues(alpha: 0.42 * elevation.clamp(0.4, 2.2)),
      offset: Offset(dir.x * 6 * elevation, dir.y * 6 * elevation),
      blurRadius: 14 * elevation,
    ),
    BoxShadow(
      color: base.withValues(alpha: 0.22),
      offset: Offset(dir.x * 2 * elevation, dir.y * 2 * elevation),
      blurRadius: 4 * elevation,
    ),
  ];
}

/// A hand-drawn rounded rectangle path — the corner language for every
/// mount, sheet edge, and control. [seed] fixes the wobble.
Path handRect(
  Rect r, {
  double radius = 3,
  required int seed,
  double jitter = 0.9,
}) {
  final path = Path();
  double w(int i) => _wobble(seed + i) * jitter;
  final rr = radius;
  path.moveTo(r.left + rr + w(1), r.top + w(2));
  path.lineTo(r.right - rr + w(3), r.top + w(4));
  path.quadraticBezierTo(
    r.right + w(5),
    r.top + w(6),
    r.right + w(7),
    r.top + rr + w(8),
  );
  path.lineTo(r.right + w(9), r.bottom - rr + w(10));
  path.quadraticBezierTo(
    r.right + w(11),
    r.bottom + w(12),
    r.right - rr + w(13),
    r.bottom + w(14),
  );
  path.lineTo(r.left + rr + w(15), r.bottom + w(16));
  path.quadraticBezierTo(
    r.left + w(17),
    r.bottom + w(18),
    r.left + w(19),
    r.bottom - rr + w(20),
  );
  path.lineTo(r.left + w(21), r.top + rr + w(22));
  path.quadraticBezierTo(
    r.left + w(23),
    r.top + w(24),
    r.left + rr + w(1),
    r.top + w(2),
  );
  path.close();
  return path;
}

/// A brushed straight stroke between two points, drawn as a doubled line
/// (a heavier body + a faint drier echo) for ink weight.
void inkStroke(
  Canvas canvas,
  Offset a,
  Offset b, {
  required Color color,
  double width = 2,
  double dryAlpha = 0.28,
  int seed = 0,
  bool dashed = false,
}) {
  final mid = Offset.lerp(a, b, 0.5)!;
  final n = (b - a);
  final len = n.distance;
  if (len < 0.5) return;
  final perp = Offset(-n.dy, n.dx) / len;
  final bow = perp * (_wobble(seed + 3) * (len * 0.03).clamp(0, 6));
  final ctrl = mid + bow;

  final body =
      Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);

  if (dashed) {
    canvas.drawPath(
      _dash(body, dash: 6, gap: 5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = width
        ..color = color,
    );
    return;
  }

  canvas.drawPath(
    body,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width
      ..color = color,
  );
  canvas.drawPath(
    body.shift(perp * 0.9),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width * 0.6
      ..color = color.withValues(alpha: dryAlpha),
  );
}

Path _dash(Path source, {required double dash, required double gap}) {
  final out = Path();
  for (final metric in source.computeMetrics()) {
    var d = 0.0;
    while (d < metric.length) {
      out.addPath(
        metric.extractPath(d, math.min(d + dash, metric.length)),
        Offset.zero,
      );
      d += dash + gap;
    }
  }
  return out;
}

/// The four fixed-cell state marks. Shape carries the meaning; colour
/// only reinforces it (a11y baseline: never colour alone).
enum InkMark { filled, hollow, struck, sealed }

void drawInkMark(
  Canvas canvas,
  Rect box,
  InkMark mark, {
  required Color color,
  int seed = 0,
}) {
  final c = box.center;
  final r = box.shortestSide / 2;
  final stroke =
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = color;
  final fill = Paint()..color = color;

  switch (mark) {
    case InkMark.filled:
      canvas.drawPath(
        handRect(
          Rect.fromCircle(center: c, radius: r * 0.72),
          radius: 1.5,
          seed: seed,
        ),
        fill,
      );
    case InkMark.hollow:
      canvas.drawPath(
        handRect(
          Rect.fromCircle(center: c, radius: r * 0.72),
          radius: 1.5,
          seed: seed,
        ),
        stroke,
      );
    case InkMark.struck:
      canvas.drawPath(
        handRect(
          Rect.fromCircle(center: c, radius: r * 0.72),
          radius: 1.5,
          seed: seed,
        ),
        stroke..color = color.withValues(alpha: 0.6),
      );
      inkStroke(
        canvas,
        box.topLeft + Offset(r * 0.28, r * 0.28),
        box.bottomRight - Offset(r * 0.28, r * 0.28),
        color: color,
        width: 2.2,
        seed: seed + 9,
      );
    case InkMark.sealed:
      // a small carved chop
      final chop = Rect.fromCircle(center: c, radius: r * 0.86);
      canvas.drawPath(
        handRect(chop, radius: 2, seed: seed),
        stroke..strokeWidth = 2,
      );
      canvas.drawPath(
        handRect(chop.deflate(r * 0.34), radius: 1, seed: seed + 4),
        stroke..strokeWidth = 1.3,
      );
  }
}

/// A carved seal chop for [contentId] — a deterministic abstract glyph
/// inside a squared chop border. Reads as identity + ownership.
class SealChopPainter extends CustomPainter {
  SealChopPainter({
    required this.contentId,
    required this.ink,
    this.border = true,
  });

  final String contentId;
  final Color ink;
  final bool border;

  @override
  void paint(Canvas canvas, Size size) {
    final seed = _hash(contentId);
    final box = (Offset.zero & size).deflate(size.shortestSide * 0.06);
    final stroke =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = ink;

    if (border) {
      canvas.drawPath(
        handRect(box, radius: 3, seed: seed),
        stroke..strokeWidth = 2.4,
      );
    }

    // 3–4 carved strokes laid on a 3x3 sub-grid, chosen from the seed.
    final inner = box.deflate(box.shortestSide * 0.22);
    Offset node(int gx, int gy) => Offset(
      inner.left + inner.width * (gx / 2),
      inner.top + inner.height * (gy / 2),
    );
    final strokes = 3 + (seed % 2);
    for (var i = 0; i < strokes; i++) {
      final a = ((seed >> (i * 3)) & 0x7);
      final b = ((seed >> (i * 3 + 8)) & 0x7);
      final p1 = node(a % 3, (a ~/ 3) % 3);
      final p2 = node(b % 3, (b ~/ 3) % 3);
      inkStroke(canvas, p1, p2, color: ink, width: 2.6, seed: seed + i * 17);
    }
    // one horizontal base rule, the chop's "ground"
    inkStroke(
      canvas,
      Offset(inner.left, inner.bottom),
      Offset(inner.right, inner.bottom),
      color: ink.withValues(alpha: 0.8),
      width: 2,
      seed: seed + 101,
    );
  }

  @override
  bool shouldRepaint(SealChopPainter old) =>
      old.contentId != contentId || old.ink != ink;
}

/// Concentric carved rank rings + a partial arc for progress toward the
/// next threshold. Rank is level, not colour.
class RankRingsPainter extends CustomPainter {
  RankRingsPainter({
    required this.level,
    required this.progress, // 0..1 toward next
    required this.ink,
    required this.mastered,
    this.goldInk,
  });

  final int level;
  final double progress;
  final Color ink;
  final bool mastered;
  final Color? goldInk;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.shortestSide / 2 - 2;
    final rings = level.clamp(0, 5);
    final ringColor = mastered ? (goldInk ?? ink) : ink;

    for (var i = 0; i < rings; i++) {
      final r = maxR - i * 5.0;
      if (r < 3) break;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = ringColor.withValues(alpha: 0.9 - i * 0.12),
      );
    }
    // progress arc on the outermost open track
    if (!mastered && progress > 0) {
      final r = maxR + 3;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        progress.clamp(0, 1) * math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.4
          ..color = ink,
      );
    }
  }

  @override
  bool shouldRepaint(RankRingsPainter old) =>
      old.level != level ||
      old.progress != progress ||
      old.mastered != mastered;
}

/// The hall's single raking light as a subtle top-left highlight wash to
/// composite over a mount that is currently selected/active.
Shader rakingHighlight(Rect rect, Color light) {
  return ui.Gradient.radial(
    rect.topLeft + Offset(rect.width * 0.18, rect.height * 0.14),
    rect.longestSide * 0.9,
    [light.withValues(alpha: 0.22), light.withValues(alpha: 0.0)],
  );
}
