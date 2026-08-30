// lib/features/tome/widgets/tome_grid.dart
import 'package:flutter/material.dart';

import '../../../core/models/grid_cell_view.dart';

class TomeGrid extends StatelessWidget {
  const TomeGrid({super.key, required this.cells, required this.width, required this.onMove});

  final List<GridCellView> cells;
  final int width;
  final void Function(String from, String to) onMove;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
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
    );
  }
}

class _CellLabel extends StatelessWidget {
  const _CellLabel(this.cell);
  final GridCellView cell;

  @override
  Widget build(BuildContext context) => Center(child: Text(cell.occupant!.displayName));
}
