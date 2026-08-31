// lib/features/training/presentation/target_field.dart
import 'package:flutter/material.dart';

import '../../tome/hall/hall_theme.dart';
import '../../tome/hall/ink.dart';
import '../exercise/training_target.dart';
import 'training_scene.dart';

/// The interactive layer: one wave of targets painted over a lineage
/// [scene], tap-to-strike with nearest-target resolution, a closing
/// aperture per target for its timing window, and a short shape-led
/// feedback flourish on every resolution. One `Ticker` drives the whole
/// field — no per-target widgets, no controller pool.
class TargetField extends StatefulWidget {
  const TargetField({
    super.key,
    required this.scene,
    required this.wave,
    required this.onResolved,
    required this.onWaveComplete,
  });

  final TrainingScene scene;

  /// The 3 targets of the current wave. A new list identity starts a
  /// fresh wave clock.
  final List<TrainingTarget> wave;
  final void Function(TargetResolution) onResolved;
  final VoidCallback onWaveComplete;

  @override
  State<TargetField> createState() => _TargetFieldState();
}

class _Runtime {
  _Runtime(this.target);
  final TrainingTarget target;
  bool resolved = false;
  StrikeQuality quality = StrikeQuality.miss;
  int resolvedAtMs = 0;
}

class _TargetFieldState extends State<TargetField>
    with SingleTickerProviderStateMixin {
  // One long-running controller stands in for a frame clock — it drives
  // every target's aperture, the resolve flourishes, and the impact
  // decay from a single primitive (and, unlike a bare Ticker, it runs
  // under `tester.pump`). Started in initState so the `late final` is
  // actually realised.
  late final AnimationController _clock;

  int _elapsedMs = 0; // clock time
  int _waveStartMs = 0; // clock time when this wave began
  int _lastFrameMs = 0; // clock time at the previous frame
  late List<_Runtime> _rt;
  int _lastStrikeMs = -10000;
  StrikeQuality _lastStrikeQuality = StrikeQuality.miss;
  Offset _lastStrikeAt = Offset.zero;
  bool _advanced = false;

  static const _resolveMs = 220;
  static const _decayMs = 320;

  /// The largest a single frame's advance is allowed to move the wave
  /// clock. A real frame is ~16 ms; anything past this is a stall — a
  /// backgrounded browser tab (frames stop, then `lastElapsedDuration`
  /// jumps by the whole wall-clock gap on resume), a GC pause, or a
  /// debugger break. The overshoot is added back to [_waveStartMs] so
  /// [_waveMs] never leaps: hidden/stalled time is simply not counted —
  /// the player gets no free timing and does not lose a live wave to a
  /// mass timeout. (Task 9/10 — browser visibility lifecycle.)
  static const _maxFrameMs = 200;

  bool get _reduceMotion => MediaQuery.of(context).disableAnimations;
  int get _waveMs => _elapsedMs - _waveStartMs;

  @override
  void initState() {
    super.initState();
    _rt = [for (final t in widget.wave) _Runtime(t)];
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    )
      ..addListener(_onFrame)
      ..forward();
  }

  @override
  void didUpdateWidget(TargetField old) {
    super.didUpdateWidget(old);
    if (!identical(old.wave, widget.wave)) {
      _rt = [for (final t in widget.wave) _Runtime(t)];
      _waveStartMs = _elapsedMs;
      _lastStrikeMs = -10000;
      _advanced = false;
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _onFrame() {
    final raw = (_clock.lastElapsedDuration ?? Duration.zero).inMilliseconds;
    final delta = raw - _lastFrameMs;
    _lastFrameMs = raw;
    // Reject a stalled frame: advance the wave origin by the overshoot so
    // the effective per-frame step is capped. Never move the origin
    // backwards (a monotonic clock only ever loses time this way).
    if (delta > _maxFrameMs) {
      _waveStartMs += delta - _maxFrameMs;
    }
    _elapsedMs = raw;
    for (final r in _rt) {
      if (!r.resolved && _waveMs >= r.target.lifetimeMs) {
        _resolve(r, r.target.x, r.target.y, timedOut: true);
      }
    }
    if (!_advanced && _rt.every((r) => r.resolved)) {
      _advanced = true;
      final wait = _reduceMotion ? 1 : _resolveMs + 60;
      Future.delayed(Duration(milliseconds: wait), () {
        if (mounted) widget.onWaveComplete();
      });
    }
    setState(() {});
  }

  void _resolve(_Runtime r, double tapX, double tapY, {required bool timedOut}) {
    if (r.resolved) return;
    final res = TargetResolution(
      target: r.target,
      tapX: tapX,
      tapY: tapY,
      latencyMs: _waveMs.clamp(0, r.target.lifetimeMs),
      timedOut: timedOut,
    );
    r
      ..resolved = true
      ..quality = res.quality
      ..resolvedAtMs = _waveMs;
    if (res.quality.isHit || !timedOut) {
      _lastStrikeMs = _waveMs;
      _lastStrikeQuality = res.quality;
      _lastStrikeAt = Offset(r.target.x, r.target.y);
    }
    widget.onResolved(res);
  }

  void _handleTap(Offset local, Size size) {
    final live = _rt.where((r) => !r.resolved).toList();
    if (live.isEmpty) return;
    final nx = (local.dx / size.width).clamp(0.0, 1.0);
    final ny = (local.dy / size.height).clamp(0.0, 1.0);
    final aspect = size.width / size.height;
    double d2(_Runtime r) {
      final dx = (nx - r.target.x) * aspect;
      final dy = ny - r.target.y;
      return dx * dx + dy * dy;
    }

    live.sort((a, b) => d2(a).compareTo(d2(b)));
    _resolve(live.first, nx, ny, timedOut: false);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final reduce = _reduceMotion;
    final impactAge = _waveMs - _lastStrikeMs;
    final impact = (reduce || impactAge > _decayMs)
        ? null
        : StrikeImpact(
            at: _lastStrikeAt,
            energy: (1 - impactAge / _decayMs).clamp(0.0, 1.0),
            quality: _lastStrikeQuality,
          );

    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _handleTap(d.localPosition, size),
          child: CustomPaint(
            size: size,
            painter: _FieldPainter(
              scene: widget.scene,
              hall: hall,
              rt: _rt,
              waveMs: _waveMs,
              impact: impact,
              resolveMs: reduce ? 0 : _resolveMs,
            ),
          ),
        );
      },
    );
  }
}

class _FieldPainter extends CustomPainter {
  _FieldPainter({
    required this.scene,
    required this.hall,
    required this.rt,
    required this.waveMs,
    required this.impact,
    required this.resolveMs,
  });

  final TrainingScene scene;
  final HallTheme hall;
  final List<_Runtime> rt;
  final int waveMs;
  final StrikeImpact? impact;
  final int resolveMs;

  @override
  void paint(Canvas canvas, Size size) {
    scene.paint(canvas, Offset.zero & size, hall, impact);

    final unit = size.shortestSide;
    Offset px(double nx, double ny) => Offset(nx * size.width, ny * size.height);

    for (final r in rt) {
      final centre = px(r.target.x, r.target.y);
      final radius = r.target.radius * unit;
      if (!r.resolved) {
        _live(canvas, centre, radius, r.target.lifetimeMs);
      } else {
        final age = (waveMs - r.resolvedAtMs).clamp(0, resolveMs == 0 ? 1 : resolveMs);
        final p = resolveMs == 0 ? 1.0 : age / resolveMs;
        _resolvedFlourish(canvas, centre, radius, r.quality, p);
      }
    }
  }

  void _rings(Canvas canvas, Offset c, double r, Color col, double scale) {
    for (final f in const [1.0, 0.65, 0.30]) {
      canvas.drawCircle(
        c,
        r * f * scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = f == 1.0 ? 1.8 : 1.3
          ..color = col,
      );
    }
    canvas.drawCircle(c, 1.6 * scale.clamp(0.0, 1.0), Paint()..color = col);
  }

  void _live(Canvas canvas, Offset c, double r, int lifetimeMs) {
    _rings(canvas, c, r, hall.bone.withValues(alpha: 0.7), 1);
    // Closing aperture — the timing window as geometry.
    final frac = (waveMs / lifetimeMs).clamp(0.0, 1.0);
    canvas.drawCircle(
      c,
      r * (1.5 - 0.5 * frac),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = hall.bone.withValues(alpha: 0.20 + 0.4 * frac),
    );
  }

  void _resolvedFlourish(
      Canvas canvas, Offset c, double r, StrikeQuality q, double p) {
    final e = Curves.easeOutCubic.transform(p);
    switch (q) {
      case StrikeQuality.perfect:
        _rings(canvas, c, r, hall.bone.withValues(alpha: 0.7 * (1 - e)),
            1 - 0.9 * e);
        canvas.drawCircle(c, r * (0.18 + 0.5 * e),
            Paint()..color = hall.vermilion.withValues(alpha: 1 - e));
        for (var i = 0; i < 4; i++) {
          final o = Offset.fromDirection(i * 1.5708 + 0.785, r * (0.4 + 0.8 * e));
          canvas.drawLine(
            c + o * 0.62,
            c + o,
            Paint()
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round
              ..color = hall.vermilion.withValues(alpha: (1 - e) * 0.9),
          );
        }
      case StrikeQuality.good:
        _rings(canvas, c, r, hall.bone.withValues(alpha: 0.7 * (1 - e)),
            1 - 0.85 * e);
      case StrikeQuality.weak:
        canvas
          ..save()
          ..translate(c.dx, c.dy)
          ..scale(1 + 0.15 * e, 1 - 0.25 * e);
        _rings(canvas, Offset.zero, r,
            hall.boneDim.withValues(alpha: 0.6 * (1 - e)), 1);
        canvas.restore();
      case StrikeQuality.miss:
        _rings(canvas, c, r, hall.slate.withValues(alpha: 0.55 * (1 - e)), 1);
        final d = Offset(r, r) * 0.9;
        inkStroke(canvas, c - d, c + d,
            color: hall.slate.withValues(alpha: (1 - e) * 0.8),
            width: 2.4,
            seed: c.dx.round() * 31 + c.dy.round());
    }
  }

  @override
  bool shouldRepaint(_FieldPainter old) => true;
}
