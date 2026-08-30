// lib/features/tome/hall/frontispiece.dart
//
// The hall's frontispiece: who this lineage belongs to. Name lettered in
// carved caps, physique and style as struck marks, and the real
// physique/tradition synergy shown as a quantity on a leader line
// (x1.25 match / x0.85 mismatch) — never flavour text.
import 'package:flutter/material.dart';

import '../../../core/models/character_view.dart';
import 'hall_theme.dart';

class Frontispiece extends StatelessWidget {
  const Frontispiece({
    super.key,
    required this.character,
    this.compact = false,
  });

  final CharacterView? character;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final c = character;
    final name = (c?.name.isNotEmpty ?? false) ? c!.name : 'Unnamed';
    final matched =
        c != null &&
        c.martialTradition.isNotEmpty &&
        c.physiqueAffinityTradition == c.martialTradition;
    final synergy =
        c == null || c.martialTradition.isEmpty
            ? null
            : (matched ? '×1.25 synergy' : '×0.85 mismatch');

    final marks = <Widget>[
      if (c != null && c.physiqueId.isNotEmpty)
        _StruckMark(label: 'PHYSIQUE', value: _pretty(c.physiqueId)),
      if (c != null && c.styleId.isNotEmpty)
        _StruckMark(label: 'STYLE', value: _pretty(c.styleId)),
      if (c != null && c.martialTradition.isNotEmpty)
        _StruckMark(label: 'TRADITION', value: _pretty(c.martialTradition)),
    ];

    final health =
        c == null
            ? null
            : _Vitality(current: c.healthCurrent, max: c.healthMax);

    if (compact) {
      final parts = <String>[
        if (c != null && c.physiqueId.isNotEmpty) _pretty(c.physiqueId),
        if (c != null && c.styleId.isNotEmpty) _pretty(c.styleId),
        if (c != null && c.martialTradition.isNotEmpty)
          _pretty(c.martialTradition),
        if (c != null)
          '${c.healthCurrent.round()} / ${c.healthMax.round()} vitality',
      ];
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 11),
        decoration: BoxDecoration(
          color: hall.lacquer,
          border: Border(
            bottom: BorderSide(color: hall.bone.withValues(alpha: 0.16)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: hall.display.copyWith(
                      fontSize: 16,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
                if (synergy != null) ...[
                  const SizedBox(width: 10),
                  _SynergyTag(text: synergy, matched: matched),
                ],
              ],
            ),
            const SizedBox(height: 5),
            Text(
              parts.join('   ·   '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: hall.body.copyWith(fontSize: 11, color: hall.boneDim),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name.toUpperCase(),
          style: hall.displayLarge.copyWith(fontSize: 27, height: 1.06),
        ),
        const SizedBox(height: 18),
        _Rule(color: hall.bone.withValues(alpha: 0.16)),
        const SizedBox(height: 16),
        ...marks.map(
          (m) => Padding(padding: const EdgeInsets.only(bottom: 12), child: m),
        ),
        if (synergy != null) ...[
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SynergyTag(text: synergy, matched: matched),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  matched
                      ? 'physique favours your tradition'
                      : 'physique favours the other tradition',
                  style: hall.body.copyWith(
                    fontSize: 11.5,
                    height: 1.35,
                    color: hall.boneDim,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (health != null) ...[
          const SizedBox(height: 18),
          _Rule(color: hall.bone.withValues(alpha: 0.16)),
          const SizedBox(height: 16),
          health,
        ],
      ],
    );
  }
}

class _StruckMark extends StatelessWidget {
  const _StruckMark({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: hall.label.copyWith(fontSize: 9)),
        const SizedBox(height: 2),
        Text(value, style: hall.body.copyWith(fontSize: 13)),
      ],
    );
  }
}

class _SynergyTag extends StatelessWidget {
  const _SynergyTag({required this.text, required this.matched});
  final String text;
  final bool matched;
  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final ink = matched ? hall.gold : hall.slate;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: ink.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: const Size(10, 10),
            painter: _TagGlyph(color: ink, matched: matched),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: hall.measureStrong.copyWith(color: ink, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _TagGlyph extends CustomPainter {
  _TagGlyph({required this.color, required this.matched});
  final Color color;
  final bool matched;
  @override
  void paint(Canvas canvas, Size size) {
    final p =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = color;
    final c = size.center(Offset.zero);
    final rad = size.shortestSide / 2 - 1;
    // aligned forces point up; opposed forces point down and are struck.
    final path =
        matched
            ? (Path()
              ..moveTo(c.dx, c.dy - rad)
              ..lineTo(c.dx + rad, c.dy + rad)
              ..lineTo(c.dx - rad, c.dy + rad)
              ..close())
            : (Path()
              ..moveTo(c.dx, c.dy + rad)
              ..lineTo(c.dx + rad, c.dy - rad)
              ..lineTo(c.dx - rad, c.dy - rad)
              ..close());
    canvas.drawPath(path, Paint()..color = color);
    if (!matched) {
      canvas.drawLine(
        c + Offset(-rad - 1, 0),
        c + Offset(rad + 1, 0),
        p..strokeWidth = 1.4,
      );
    }
  }

  @override
  bool shouldRepaint(_TagGlyph old) =>
      old.color != color || old.matched != matched;
}

class _Vitality extends StatelessWidget {
  const _Vitality({required this.current, required this.max});
  final num current;
  final num max;
  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final frac = max <= 0 ? 0.0 : (current / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text('VITALITY', style: hall.label.copyWith(fontSize: 9)),
            const SizedBox(width: 8),
            Text(
              '${current.round()} / ${max.round()}',
              style: hall.measure.copyWith(fontSize: 10.5),
            ),
          ],
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: 132,
          height: 6,
          child: CustomPaint(
            painter: _RuleGauge(frac: frac.toDouble(), ink: hall.bone),
          ),
        ),
      ],
    );
  }
}

class _RuleGauge extends CustomPainter {
  _RuleGauge({required this.frac, required this.ink});
  final double frac;
  final Color ink;
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = ink.withValues(alpha: 0.18)
        ..strokeWidth = size.height,
    );
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width * frac, y),
      Paint()
        ..color = ink.withValues(alpha: 0.85)
        ..strokeWidth = size.height
        ..strokeCap = StrokeCap.butt,
    );
    // tick at quarters
    for (var i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = const Color(0xFF0C090B).withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_RuleGauge old) => old.frac != frac;
}

class _Rule extends StatelessWidget {
  const _Rule({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(height: 1, color: color);
}

String _pretty(String id) => id
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
