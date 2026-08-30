// lib/features/tome/widgets/combine_confirmation_sheet.dart
//
// The commit point for a Combine: the matched inputs drawn as mounts
// with a taut cord between them, the upgrade-point toll on a leader
// line, and one struck action. Confirming fires the combine; the
// seal-press reveal happens back on the board.
import 'package:flutter/material.dart';

import '../../../core/models/item_view.dart';
import '../hall/hall_controls.dart';
import '../hall/hall_theme.dart';
import '../hall/ink.dart';
import '../hall/mount.dart';

Future<void> showCombineConfirmation(
  BuildContext context, {
  required List<ItemView> matched,
  required VoidCallback onConfirm,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => _CombineSheet(matched: matched, onConfirm: onConfirm),
  );
}

class _CombineSheet extends StatelessWidget {
  const _CombineSheet({required this.matched, required this.onConfirm});
  final List<ItemView> matched;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final anchor = matched.first;
    final cost = anchor.itemClass;
    final toClass = anchor.itemClass + 1;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: hall.lacquer,
          border: Border(
            top: BorderSide(
              color: hall.vermilion.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 3,
                color: hall.bone.withValues(alpha: 0.28),
              ),
            ),
            const SizedBox(height: 16),
            Text('BIND THE CORD', style: hall.label),
            const SizedBox(height: 4),
            Text(
              'Combine ${matched.length} × ${_pretty(anchor.name)}',
              style: hall.display.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 108,
              child: CustomPaint(
                painter: _InputsCord(color: hall.vermilion),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final m in matched.take(4))
                      SizedBox(
                        width: 92,
                        height: 92,
                        child: MountView(
                          data: MountData.fromItem(m),
                          showAddress: false,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            LeaderLabel(
              strong: true,
              text:
                  anchor.eligibleToCombine
                      ? 'cls ${_r(anchor.itemClass)} -> ${_r(toClass)}   ·   toll $cost upgrade point${cost == 1 ? '' : 's'}'
                      : 'matched but maxed — no cord to bind',
            ),
            const SizedBox(height: 6),
            Text(
              'the roll may fail, raise the class, or evolve the form',
              style: hall.measure.copyWith(fontSize: 10.5),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                InkButton(
                  label: 'Attempt Combine',
                  tone: InkTone.seal,
                  onPressed:
                      anchor.eligibleToCombine
                          ? () {
                            Navigator.of(context).pop();
                            onConfirm();
                          }
                          : null,
                ),
                const SizedBox(width: 12),
                InkButton(
                  label: 'Back',
                  tone: InkTone.quiet,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
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

class _InputsCord extends CustomPainter {
  _InputsCord({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    inkStroke(
      canvas,
      Offset(size.width * 0.14, y),
      Offset(size.width * 0.86, y),
      color: color.withValues(alpha: 0.9),
      width: 3,
      seed: 11,
    );
  }

  @override
  bool shouldRepaint(_InputsCord old) => old.color != color;
}

String _pretty(String id) => id
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
