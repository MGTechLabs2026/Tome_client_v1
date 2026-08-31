// lib/features/training/presentation/training_scene.dart
//
// The two lineage training objects, drawn in the Lineage Hall's single
// ink hand (canvas only — no imported art). A scene paints the thing
// the targets sit on and leans / recoils on the last strike; it never
// owns the targets or the timing, so the exercise logic stays
// skin-agnostic and a richer scene can replace this behind the same
// `TrainingScene` interface later.
import 'package:flutter/material.dart';

import '../../tome/hall/hall_theme.dart';
import '../../tome/hall/ink.dart';
import '../exercise/training_target.dart';

/// The last strike landed on the scene — a normalized point and a
/// 1 → 0 decay value the practice object recoils on.
class StrikeImpact {
  const StrikeImpact({
    required this.at,
    required this.energy,
    required this.quality,
  });

  final Offset at; // normalized 0..1
  final double energy; // 1 at impact, decays to 0
  final StrikeQuality quality;
}

abstract class TrainingScene {
  const TrainingScene();

  /// `'western'` / `'eastern'`.
  String get id;

  /// A one-line name for the space, shown under the wave counter.
  String get label;

  void paint(Canvas canvas, Rect field, HallTheme hall, StrikeImpact? impact);

  static TrainingScene forTradition(String martialTradition) =>
      martialTradition == 'eastern'
          ? const EasternScene()
          : const WesternScene();
}

// ── shared helpers ──────────────────────────────────────────────────

/// Recoil offset for a body drawn in [field], given the last [impact]:
/// the whole object shifts a little away from the strike, more for a
/// clean hit.
Offset _recoil(Rect field, StrikeImpact? impact) {
  if (impact == null) return Offset.zero;
  final w = impact.quality == StrikeQuality.perfect
      ? 1.0
      : impact.quality == StrikeQuality.good
          ? 0.7
          : impact.quality == StrikeQuality.miss
              ? 0.25
              : 0.4;
  final push = field.shortestSide * 0.02 * w * impact.energy;
  // Away from centre, biased downward (a struck body folds).
  final from = Offset(impact.at.dx - 0.5, impact.at.dy - 0.5);
  final len = from.distance == 0 ? 1 : from.distance;
  return Offset(from.dx / len * push, from.dy / len * push + push * 0.4);
}

void _floor(Canvas canvas, Rect field, HallTheme hall) {
  final y = field.top + field.height * 0.9;
  inkStroke(
    canvas,
    Offset(field.left + field.width * 0.08, y),
    Offset(field.right - field.width * 0.08, y),
    color: hall.bone.withValues(alpha: 0.16),
    width: 1.4,
    seed: 4021,
  );
}

Paint _stroke(Color c, double w) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..color = c;

// ── Western: fighter silhouette + hanging bag ───────────────────────

class WesternScene extends TrainingScene {
  const WesternScene();
  @override
  String get id => 'western';
  @override
  String get label => 'THE STRIKING ROOM';

  @override
  void paint(Canvas canvas, Rect field, HallTheme hall, StrikeImpact? impact) {
    _floor(canvas, field, hall);
    final r = _recoil(field, impact);
    final cx = field.center.dx;
    final w = field.width;
    final h = field.height;

    // Hanging bag, centred — a filled bone form with a raking gradient.
    final bagW = w * 0.30;
    final bagTop = field.top + h * 0.14;
    final bagBottom = field.top + h * 0.82;
    final bag = RRect.fromRectAndRadius(
      Rect.fromLTRB(cx - bagW / 2 + r.dx, bagTop, cx + bagW / 2 + r.dx,
          bagBottom + r.dy * 0.4),
      Radius.circular(bagW * 0.42),
    );
    canvas.drawRRect(
      bag,
      Paint()..color = hall.bone.withValues(alpha: 0.10),
    );
    canvas.drawRRect(bag, _stroke(hall.bone.withValues(alpha: 0.55), 1.8));
    // chain
    inkStroke(
      canvas,
      Offset(cx + r.dx, field.top + h * 0.04),
      Offset(cx + r.dx, bagTop),
      color: hall.bone.withValues(alpha: 0.4),
      width: 1.6,
      seed: 771,
    );
    // seam rings
    for (final t in const [0.28, 0.52, 0.74]) {
      final y = bagTop + (bagBottom - bagTop) * t;
      canvas.drawLine(
        Offset(cx - bagW / 2 + r.dx, y),
        Offset(cx + bagW / 2 + r.dx, y),
        _stroke(hall.bone.withValues(alpha: 0.22), 1),
      );
    }

    // Fighter silhouette behind/left — a spare figure, lacquer-dark on
    // the field, edge-lit only.
    final sx = field.left + w * 0.22 - r.dx * 0.4;
    final baseY = field.top + h * 0.9;
    final scale = h * 0.62;
    Offset p(double nx, double ny) => Offset(sx + nx * w * 0.22, baseY - ny * scale);
    final body = Path()
      ..moveTo(p(0, 0).dx, p(0, 0).dy)
      ..lineTo(p(-0.5, 0.02).dx, p(-0.5, 0.02).dy)
      ..lineTo(p(-0.22, 0.46).dx, p(-0.22, 0.46).dy)
      ..lineTo(p(-0.5, 0.9).dx, p(-0.5, 0.9).dy) // trailing arm
      ..lineTo(p(-0.28, 0.92).dx, p(-0.28, 0.92).dy)
      ..lineTo(p(-0.05, 0.55).dx, p(-0.05, 0.55).dy)
      ..lineTo(p(0.6, 0.72).dx, p(0.6, 0.72).dy) // lead arm toward the bag
      ..lineTo(p(0.62, 0.62).dx, p(0.62, 0.62).dy)
      ..lineTo(p(0.12, 0.5).dx, p(0.12, 0.5).dy)
      ..lineTo(p(0.34, 0.02).dx, p(0.34, 0.02).dy)
      ..lineTo(p(0.14, 0.0).dx, p(0.14, 0.0).dy)
      ..close();
    canvas.drawPath(body, Paint()..color = hall.lacquerDeep.withValues(alpha: 0.9));
    canvas.drawPath(body, _stroke(hall.bone.withValues(alpha: 0.28), 1.4));
    // head
    canvas.drawCircle(p(0.02, 1.0), w * 0.028,
        Paint()..color = hall.lacquerDeep.withValues(alpha: 0.9));
    canvas.drawCircle(
        p(0.02, 1.0), w * 0.028, _stroke(hall.bone.withValues(alpha: 0.28), 1.4));
  }
}

// ── Eastern: wooden dummy / bamboo post ─────────────────────────────

class EasternScene extends TrainingScene {
  const EasternScene();
  @override
  String get id => 'eastern';
  @override
  String get label => 'THE PRACTICE YARD';

  @override
  void paint(Canvas canvas, Rect field, HallTheme hall, StrikeImpact? impact) {
    _floor(canvas, field, hall);
    final r = _recoil(field, impact);
    final cx = field.center.dx + r.dx;
    final top = field.top + field.height * 0.08;
    final bottom = field.top + field.height * 0.9;
    final postW = field.width * 0.06;

    // The post — a single upright, rocking on the recoil.
    final tilt = r.dx * 0.5;
    final post = Path()
      ..moveTo(cx - postW / 2 + tilt, top)
      ..lineTo(cx + postW / 2 + tilt, top)
      ..lineTo(cx + postW / 2, bottom)
      ..lineTo(cx - postW / 2, bottom)
      ..close();
    canvas.drawPath(post, Paint()..color = hall.bone.withValues(alpha: 0.12));
    canvas.drawPath(post, _stroke(hall.bone.withValues(alpha: 0.55), 1.8));
    // grain nodes (bamboo)
    for (final t in const [0.2, 0.42, 0.63, 0.84]) {
      final y = top + (bottom - top) * t;
      final tx = tilt * (1 - t);
      canvas.drawLine(
        Offset(cx - postW / 2 + tx, y),
        Offset(cx + postW / 2 + tx, y),
        _stroke(hall.bone.withValues(alpha: 0.3), 1.4),
      );
    }

    // Three practice arms — upper, centre, lower — angled outward.
    void arm(double t, double dir, double len, double drop) {
      final y = top + (bottom - top) * t;
      final tx = tilt * (1 - t);
      final a = Offset(cx + tx, y);
      final b = Offset(a.dx + dir * field.width * len, y + field.height * drop);
      inkStroke(canvas, a, b,
          color: hall.bone.withValues(alpha: 0.5), width: 3, seed: (t * 97).round());
    }

    arm(0.24, -1, 0.13, -0.02); // upper, left
    arm(0.24, 1, 0.10, -0.01);
    arm(0.5, 1, 0.15, 0.0); // centre, right
    arm(0.5, -1, 0.08, 0.01);
    arm(0.76, -1, 0.12, 0.03); // lower, left (a leg bar)

    // A struck arm judders — a short echo stroke near the impact.
    if (impact != null && impact.energy > 0.05) {
      final y = field.top + impact.at.dy * field.height;
      canvas.drawLine(
        Offset(cx, y),
        Offset(cx + (impact.at.dx - 0.5).sign * field.width * 0.16, y),
        _stroke(hall.vermilion.withValues(alpha: 0.35 * impact.energy), 2.4),
      );
    }
  }
}
