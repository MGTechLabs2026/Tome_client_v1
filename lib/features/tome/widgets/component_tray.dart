// lib/features/tome/widgets/component_tray.dart
//
// The loose rack: components the player owns or has discovered but has
// not hung yet. Drag one onto the board, or tap it for its plate. When
// the rack holds fewer forms than it has room for, it still shows its
// empty mounting positions — a rack with capacity, never a black void.
import 'package:flutter/material.dart';

import '../../../core/models/item_view.dart';
import '../../../core/models/technique_view.dart';
import '../hall/board_drag.dart';
import '../hall/hall_theme.dart';
import '../hall/mount.dart';

enum RackFilter { all, items, techniques }

class LooseRack extends StatefulWidget {
  const LooseRack({
    super.key,
    required this.items,
    required this.techniques,
    required this.spotlight,
    required this.onItemTap,
    required this.onTechniqueTap,
    this.height = 132,
  });

  final List<ItemView> items;
  final List<TechniqueView> techniques;
  final Set<int> spotlight;
  final void Function(ItemView item) onItemTap;
  final void Function(TechniqueView technique) onTechniqueTap;
  final double height;

  @override
  State<LooseRack> createState() => _LooseRackState();
}

class _LooseRackState extends State<LooseRack> {
  RackFilter _filter = RackFilter.all;

  /// The rack always shows at least this many mounting positions.
  static const _minSlots = 8;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final showItems = _filter != RackFilter.techniques;
    final showTech = _filter != RackFilter.items;

    final pieces = <Widget>[
      if (showItems)
        for (final item in widget.items)
          _RackPiece(
            key: ValueKey('i${item.instanceEntityValue}'),
            drag: item.instanceEntityValue == null
                ? null
                : TomeDrag.rackItem(
                    item.definitionId, item.instanceEntityValue!),
            onTap: () => widget.onItemTap(item),
            child: MountView(
              data: MountData.fromItem(item),
              compact: true,
              spotlight: item.instanceEntityValue != null &&
                  widget.spotlight.contains(item.instanceEntityValue),
            ),
          ),
      if (showTech)
        for (final t in widget.techniques)
          _RackPiece(
            key: ValueKey('t${t.definitionId}'),
            drag: TomeDrag.rackTechnique(t.definitionId),
            onTap: () => widget.onTechniqueTap(t),
            child: MountView(data: MountData.fromTechnique(t), compact: true),
          ),
    ];
    final emptySlots = (_minSlots - pieces.length).clamp(0, _minSlots);

    return Container(
      decoration: BoxDecoration(
        color: hall.lacquer,
        border: Border(top: BorderSide(color: hall.bone.withValues(alpha: 0.16))),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('THE LOOSE RACK', style: hall.label),
              if (pieces.isEmpty) ...[
                const SizedBox(width: 12),
                Text('win a fight for loot',
                    style: hall.body.copyWith(fontSize: 11, color: hall.boneDim)),
              ],
              const Spacer(),
              _FilterTab(
                label: 'All',
                active: _filter == RackFilter.all,
                onTap: () => setState(() => _filter = RackFilter.all),
              ),
              _FilterTab(
                label: 'Items',
                active: _filter == RackFilter.items,
                onTap: () => setState(() => _filter = RackFilter.items),
              ),
              _FilterTab(
                label: 'Techniques',
                active: _filter == RackFilter.techniques,
                onTap: () => setState(() => _filter = RackFilter.techniques),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: widget.height,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                ...pieces,
                for (var i = 0; i < emptySlots; i++)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: _EmptyMount(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMount extends StatelessWidget {
  const _EmptyMount();
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 104,
        child: CustomPaint(
          painter: _EmptyMountPainter(ink: context.hall.bone),
        ),
      );
}

class _EmptyMountPainter extends CustomPainter {
  _EmptyMountPainter({required this.ink});
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(6);
    final b = size.shortestSide * 0.16;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4
      ..color = ink.withValues(alpha: 0.26);
    void corner(Offset o, double sx, double sy) {
      canvas.drawLine(o, o + Offset(b * sx, 0), p);
      canvas.drawLine(o, o + Offset(0, b * sy), p);
    }

    corner(r.topLeft, 1, 1);
    corner(r.topRight, -1, 1);
    corner(r.bottomLeft, 1, -1);
    corner(r.bottomRight, -1, -1);
    // a faint mounting-peg mark
    final c = size.center(Offset.zero);
    canvas.drawCircle(
        c, 2.4, Paint()..color = ink.withValues(alpha: 0.18));
  }

  @override
  bool shouldRepaint(_EmptyMountPainter old) => old.ink != ink;
}

class _RackPiece extends StatelessWidget {
  const _RackPiece({
    super.key,
    required this.drag,
    required this.onTap,
    required this.child,
  });
  final Widget child;
  final TomeDrag? drag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final piece = GestureDetector(
      onTap: onTap,
      child: SizedBox(width: 104, child: child),
    );
    if (drag == null) {
      return Padding(padding: const EdgeInsets.only(right: 12), child: piece);
    }
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Draggable<TomeDrag>(
        data: drag,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: Transform.translate(
          offset: const Offset(-52, -52),
          child: Opacity(
            opacity: 0.92,
            child: SizedBox(width: 104, height: 104, child: child),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: piece),
        child: piece,
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Semantics(
      button: true,
      selected: active,
      label: '$label filter',
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: hall.label.copyWith(
                  fontSize: 9.5,
                  color: active ? hall.bone : hall.boneDim,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                height: 2,
                width: label.length * 6.0,
                color: active ? hall.vermilion : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
