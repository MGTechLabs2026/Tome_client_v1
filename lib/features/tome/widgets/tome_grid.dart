// lib/features/tome/widgets/tome_grid.dart
import 'package:flutter/material.dart';

import '../../../core/models/grid_cell_view.dart';
import '../../../core/models/item_view.dart';

class TomeGrid extends StatelessWidget {
  const TomeGrid({
    super.key,
    required this.cells,
    required this.width,
    required this.onMove,
    this.ownedByInstanceValue = const {},
  });

  final List<GridCellView> cells;
  final int width;
  final void Function(String from, String to) onMove;

  /// Every on-grid item's `instanceEntityValue` → its full [ItemView], so
  /// the tether overlay can look up `combinableWith` / `eligibleToCombine`
  /// for a placed occupant without re-querying the engine.
  final Map<int, ItemView> ownedByInstanceValue;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CombineTetherPainter(
                  cells: cells,
                  width: width,
                  ownedByInstanceValue: ownedByInstanceValue,
                ),
              ),
            ),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: width,
              children: [
                for (final cell in cells)
                  DragTarget<String>(
                    onWillAcceptWithDetails: (details) => cell.isEmpty,
                    onAcceptWithDetails: (details) => onMove(details.data, cell.slotId),
                    builder: (context, candidate, rejected) => Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: candidate.isNotEmpty ? Colors.greenAccent : Colors.white24,
                          width: candidate.isNotEmpty ? 3 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: cell.isEmpty
                          ? const Center(child: Icon(Icons.add, color: Colors.white24))
                          : Draggable<String>(
                              data: cell.slotId,
                              feedback: Material(child: _CellLabel(cell)),
                              childWhenDragging: const SizedBox.shrink(),
                              child: _CellLabel(cell),
                            ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CellLabel extends StatelessWidget {
  const _CellLabel(this.cell);
  final GridCellView cell;

  @override
  Widget build(BuildContext context) => Center(child: Text(cell.occupant!.displayName));
}

/// Draws a line between any two placed cells whose occupants are combine
/// matches (each side's `combinableWith` names the other's instance).
/// Amber when the pair is still eligible to combine, dim grey when it is
/// maxClass-capped with no grade path left.
class _CombineTetherPainter extends CustomPainter {
  _CombineTetherPainter({
    required this.cells,
    required this.width,
    required this.ownedByInstanceValue,
  });

  final List<GridCellView> cells;
  final int width;
  final Map<int, ItemView> ownedByInstanceValue;

  Offset _centerOf(GridCellView cell, double cellExtent) => Offset(
        (cell.col + 0.5) * cellExtent,
        (cell.row + 0.5) * cellExtent,
      );

  @override
  void paint(Canvas canvas, Size size) {
    if (width == 0) return;
    final cellExtent = size.width / width;
    final drawn = <String>{};

    for (final cell in cells) {
      final value = cell.occupant?.instanceEntityValue;
      if (value == null) continue;
      final view = ownedByInstanceValue[value];
      if (view == null || view.combinableWith.isEmpty) continue;

      for (final other in cells) {
        final otherValue = other.occupant?.instanceEntityValue;
        if (otherValue == null || !view.combinableWith.contains(otherValue)) continue;

        final key = value < otherValue ? '$value:$otherValue' : '$otherValue:$value';
        if (!drawn.add(key)) continue;

        final paint = Paint()
          ..color = view.eligibleToCombine ? Colors.amberAccent : Colors.grey
          ..strokeWidth = view.eligibleToCombine ? 3 : 1.5;
        canvas.drawLine(_centerOf(cell, cellExtent), _centerOf(other, cellExtent), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_CombineTetherPainter oldDelegate) =>
      oldDelegate.cells != cells || oldDelegate.ownedByInstanceValue != ownedByInstanceValue;
}
