// lib/features/tome/hall/lineage_board.dart
//
// The hall itself: a fixed coordinate lattice of mounts that the player
// pans and zooms over. West traditions hang left, east right, across one
// ground-and-light gradient — the axis that never collapses. Cords tie
// combine matches; the active mount takes the raking light and the rest
// fall into shadow.
import 'package:flutter/material.dart';

import '../../../core/models/grid_cell_view.dart';
import '../../../core/models/item_view.dart';
import 'board_drag.dart';
import 'hall_theme.dart';
import 'ink.dart';
import 'mount.dart';

class LineageBoard extends StatefulWidget {
  const LineageBoard({
    super.key,
    required this.cells,
    required this.width,
    required this.height,
    required this.ownedByInstanceValue,
    required this.spotlight,
    required this.selectedSlotId,
    required this.armed,
    required this.onSelect,
    required this.onDrop,
    required this.onCellTapped,
    required this.reduceMotion,
    this.cellSize = 128,
  });

  final List<GridCellView> cells;
  final int width;
  final int height;
  final Map<int, ItemView> ownedByInstanceValue;
  final Set<int> spotlight;
  final String? selectedSlotId;

  /// A rack piece waiting to be dropped by tap (tap-to-place fallback).
  final bool armed;

  final ValueChanged<String?> onSelect;
  final void Function(TomeDrag drag, String toSlotId) onDrop;
  final ValueChanged<String> onCellTapped;
  final bool reduceMotion;
  final double cellSize;

  @override
  State<LineageBoard> createState() => _LineageBoardState();
}

class _LineageBoardState extends State<LineageBoard> {
  final _controller = TransformationController();
  Size _viewport = Size.zero;
  bool _fitted = false;
  String _fittedGrid = '';

  static const _gap = 22.0;

  double get _cell => widget.cellSize;
  double get _contentW => widget.width * _cell + (widget.width + 1) * _gap;
  double get _contentH => widget.height * _cell + (widget.height + 1) * _gap;

  @override
  void didUpdateWidget(LineageBoard old) {
    super.didUpdateWidget(old);
    if (old.width != widget.width || old.height != widget.height) {
      _fitted = false; // grid grew — re-centre once
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _cellOrigin(int row, int col) =>
      Offset(_gap + col * (_cell + _gap), _gap + row * (_cell + _gap));

  /// Centre the lattice in the viewport once (and again after the grid
  /// grows or a double-tap). Scales down when the lattice overruns,
  /// gently up when it is small; the player pans/zooms from there.
  void _maybeFit() {
    if (_viewport.width < 60 || _viewport.height < 60) return;
    final grid = '${widget.width}x${widget.height}';
    if (_fitted && grid == _fittedGrid) return;
    _fitted = true;
    _fittedGrid = grid;
    // Fill the vertical space between the top rule and the extent rail;
    // let the lattice overflow horizontally so the player pans along the
    // west↔east axis (the one that never collapses). Never scale so far
    // that the board's own width becomes unreachably wide.
    final sy = (_viewport.height - 24) / _contentH;
    final sxCap = (_viewport.width - 24) / _contentW * 1.6;
    final scale = sy.clamp(0.55, 1.7).toDouble().clamp(0.0, sxCap).toDouble();
    final tx = (_viewport.width - _contentW * scale) / 2;
    final ty = (_viewport.height - _contentH * scale) / 2;
    final m = Matrix4.identity();
    m.setEntry(0, 0, scale);
    m.setEntry(1, 1, scale);
    m.setEntry(0, 3, tx);
    m.setEntry(1, 3, ty);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.value != m) _controller.value = m;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = Size(constraints.maxWidth, constraints.maxHeight);
        _maybeFit();
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _WallPainter(
                  deep: hall.lacquerDeep,
                  light: hall.gold,
                  bone: hall.bone,
                ),
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                onDoubleTap: () {
                  _fitted = false;
                  setState(_maybeFit);
                },
                child: InteractiveViewer(
                  transformationController: _controller,
                  minScale: 0.5,
                  maxScale: 2.4,
                  boundaryMargin: EdgeInsets.all(_cell * 1.5),
                  constrained: false,
                  child: SizedBox(
                    width: _contentW,
                    height: _contentH,
                    child: Stack(
                      children: [
                        // ground: lacquer + west->east gradient
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _GroundPainter(
                              west: HallTheme.cWestGround,
                              east: HallTheme.cEastGround,
                              lacquer: hall.lacquer,
                              lightWash: hall.gold.withValues(alpha: 0.035),
                            ),
                          ),
                        ),
                        // cords under the mounts
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _CordPainter(
                                cells: widget.cells,
                                owned: widget.ownedByInstanceValue,
                                cellOrigin: _cellOrigin,
                                cell: _cell,
                                vermilion: hall.vermilion,
                                slate: hall.slate,
                                ink: hall.bone,
                                labelStyle: hall.measure.copyWith(fontSize: 10),
                              ),
                            ),
                          ),
                        ),
                        // cells
                        for (final c in widget.cells)
                          _positionedCell(context, c),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // position + extent rails when the lattice outruns the frame
            Positioned(
              left: 8,
              right: 8,
              bottom: 6,
              child: _ExtentRail(
                controller: _controller,
                axis: Axis.horizontal,
                contentExtent: _contentW,
                viewportExtent: _viewport.width,
                color: hall.bone,
              ),
            ),
            Positioned(
              right: 6,
              top: 8,
              bottom: 22,
              child: _ExtentRail(
                controller: _controller,
                axis: Axis.vertical,
                contentExtent: _contentH,
                viewportExtent: _viewport.height,
                color: hall.bone,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _positionedCell(BuildContext context, GridCellView c) {
    final o = _cellOrigin(c.row, c.col);
    return Positioned(
      left: o.dx,
      top: o.dy,
      width: _cell,
      height: _cell,
      child: _Cell(
        cell: c,
        owned:
            c.occupant?.instanceEntityValue == null
                ? null
                : widget.ownedByInstanceValue[c.occupant!.instanceEntityValue],
        selected: widget.selectedSlotId == c.slotId,
        dimmed:
            widget.selectedSlotId != null && widget.selectedSlotId != c.slotId,
        spotlight:
            c.occupant?.instanceEntityValue != null &&
            widget.spotlight.contains(c.occupant!.instanceEntityValue),
        armed: widget.armed,
        onSelect: () => widget.onSelect(c.isEmpty ? null : c.slotId),
        onTapped: () => widget.onCellTapped(c.slotId),
        onDrop: (d) => widget.onDrop(d, c.slotId),
        reduceMotion: widget.reduceMotion,
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.cell,
    required this.owned,
    required this.selected,
    required this.dimmed,
    required this.spotlight,
    required this.armed,
    required this.onSelect,
    required this.onTapped,
    required this.onDrop,
    required this.reduceMotion,
  });

  final GridCellView cell;
  final ItemView? owned;
  final bool selected;
  final bool dimmed;
  final bool spotlight;
  final bool armed;
  final VoidCallback onSelect;
  final VoidCallback onTapped;
  final ValueChanged<TomeDrag> onDrop;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return DragTarget<TomeDrag>(
      onWillAcceptWithDetails: (d) => cell.isEmpty,
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        if (cell.isEmpty) {
          return GestureDetector(
            onTap: onTapped,
            child: CustomPaint(
              painter: _EmptyCellPainter(
                registration: hovering || armed,
                accept: hovering,
                ink: hall.bone,
                vermilion: hall.vermilion,
                seed: cell.slotId.hashCode,
              ),
            ),
          );
        }

        final data =
            owned != null
                ? MountData.fromItem(owned!, address: cell.slotId)
                : MountData(
                  contentId: cell.occupant!.contentId,
                  displayName: _titleCase(cell.occupant!.displayName),
                  kind: cell.occupant!.kind,
                  state:
                      cell.occupant!.kind == GridComponentKind.technique
                          ? MountState.learned
                          : MountState.usable,
                  address: cell.slotId,
                );

        final mount = MountView(
          data: data,
          selected: selected,
          dimmed: dimmed,
          spotlight: spotlight,
        );

        return GestureDetector(
          onTap: onSelect,
          child: Draggable<TomeDrag>(
            data: TomeDrag.fromSlot(cell.slotId),
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: _DragGhost(child: mount),
            childWhenDragging: Opacity(
              opacity: 0.25,
              child: CustomPaint(
                painter: _EmptyCellPainter(
                  registration: false,
                  accept: false,
                  ink: hall.bone,
                  vermilion: hall.vermilion,
                  seed: cell.slotId.hashCode,
                ),
              ),
            ),
            child: mount,
          ),
        );
      },
    );
  }
}

class _DragGhost extends StatelessWidget {
  const _DragGhost({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: const Offset(-64, -64),
    child: Opacity(
      opacity: 0.92,
      child: SizedBox(width: 128, height: 128, child: child),
    ),
  );
}

String _titleCase(String id) => id
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

// --- painters ---------------------------------------------------------

/// The dim hall wall the rack hangs on — never flat black.
class _WallPainter extends CustomPainter {
  _WallPainter({required this.deep, required this.light, required this.bone});
  final Color deep;
  final Color light;
  final Color bone;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(r, Paint()..color = deep);
    // a broad pool of the raking light, upper-left
    canvas.drawRect(
      r,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          center: kRakingLight,
          radius: 1.6,
          colors: [light.withValues(alpha: 0.05), Colors.transparent],
        ).createShader(r),
    );
    // faint vertical grain of the lacquered boards
    final grain = Paint()
      ..color = bone.withValues(alpha: 0.015)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 46) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grain);
    }
    // corners fall away
    canvas.drawRect(
      r,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.1,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
          stops: const [0.55, 1.0],
        ).createShader(r),
    );
  }

  @override
  bool shouldRepaint(_WallPainter old) => false;
}

class _GroundPainter extends CustomPainter {
  _GroundPainter({
    required this.west,
    required this.east,
    required this.lacquer,
    required this.lightWash,
  });
  final Color west;
  final Color east;
  final Color lacquer;
  final Color lightWash;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(r, Paint()..color = lacquer);

    // west (warm) → east (cool): the hall's one organising axis. A
    // monotonic left→right tint in very dark, low-chroma umber / slate,
    // laid srcOver at moderate alpha — near lacquer value throughout, so
    // the board stays near-black #141013 and the halves only lean warm
    // or cool.
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          colors: [
            west.withValues(alpha: 0.55),
            west.withValues(alpha: 0.16),
            east.withValues(alpha: 0.16),
            east.withValues(alpha: 0.55),
          ],
          stops: const [0.0, 0.4, 0.6, 1.0],
        ).createShader(r),
    );

    // THE one light: a small soft pool from the upper-left. Nothing
    // else adds light; its falloff toward the lower-right is monotonic.
    canvas.drawRect(
      r,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          center: kRakingLight,
          radius: 1.1,
          colors: [lightWash, Colors.transparent],
        ).createShader(r),
    );
    // its answering shade, deepening toward the lower-right — same source.
    canvas.drawRect(
      r,
      Paint()
        ..shader = RadialGradient(
          center: -kRakingLight,
          radius: 1.4,
          colors: [Colors.black.withValues(alpha: 0.28), Colors.transparent],
        ).createShader(r),
    );

    // the rack's own carved frame
    final frame = r.deflate(6);
    canvas.drawPath(
      handRect(frame, radius: 2, seed: 4242),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.black.withValues(alpha: 0.5),
    );
    canvas.drawPath(
      handRect(frame.deflate(3), radius: 2, seed: 99),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFE7DDCA).withValues(alpha: 0.10),
    );

    // centre seam of the tradition axis, with a carved notch top and foot
    final x = size.width / 2;
    canvas.drawLine(
      Offset(x, 8),
      Offset(x, size.height - 8),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..strokeWidth = 1,
    );
    for (final y in [10.0, size.height - 10]) {
      canvas.drawLine(
        Offset(x - 5, y),
        Offset(x + 5, y),
        Paint()
          ..color = const Color(0xFFE7DDCA).withValues(alpha: 0.22)
          ..strokeWidth = 1.4,
      );
    }
  }

  @override
  bool shouldRepaint(_GroundPainter old) => false;
}

class _EmptyCellPainter extends CustomPainter {
  _EmptyCellPainter({
    required this.registration,
    required this.accept,
    required this.ink,
    required this.vermilion,
    required this.seed,
  });
  final bool registration;
  final bool accept;
  final Color ink;
  final Color vermilion;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(6);
    final idle = (accept ? vermilion : ink).withValues(
      alpha: registration ? 0.9 : 0.34,
    );

    // an empty mount reads as four carved corner brackets, not a box
    final bracket = size.shortestSide * 0.16;
    final cp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = registration ? 2 : 1.4
      ..color = idle;
    void corner(Offset o, double sx, double sy) {
      canvas.drawLine(o, o + Offset(bracket * sx, 0), cp);
      canvas.drawLine(o, o + Offset(0, bracket * sy), cp);
    }

    corner(r.topLeft, 1, 1);
    corner(r.topRight, -1, 1);
    corner(r.bottomLeft, 1, -1);
    corner(r.bottomRight, -1, -1);

    if (registration) {
      // full dashed outline only when a drop is armed / hovering
      canvas.drawPath(
        _dashPath(handRect(r, radius: 2, seed: seed, jitter: 1.2), dash: 5, gap: 6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = idle.withValues(alpha: 0.7),
      );
    }

    // "+" hint
    final c = size.center(Offset.zero);
    final s = size.shortestSide * 0.1;
    final hint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.8
      ..color = (accept ? vermilion : ink).withValues(
        alpha: registration ? 0.8 : 0.22,
      );
    canvas.drawLine(c + Offset(-s, 0), c + Offset(s, 0), hint);
    canvas.drawLine(c + Offset(0, -s), c + Offset(0, s), hint);

    if (accept) {
      // registration cross-hairs at the corners
      final m = 10.0;
      final rp =
          Paint()
            ..color = vermilion.withValues(alpha: 0.8)
            ..strokeWidth = 1.4;
      for (final corner in [
        r.topLeft,
        r.topRight,
        r.bottomLeft,
        r.bottomRight,
      ]) {
        canvas.drawLine(corner + Offset(-m, 0), corner + Offset(m, 0), rp);
        canvas.drawLine(corner + Offset(0, -m), corner + Offset(0, m), rp);
      }
    }
  }

  @override
  bool shouldRepaint(_EmptyCellPainter old) =>
      old.registration != registration || old.accept != accept;
}

Path _dashPath(Path source, {required double dash, required double gap}) {
  final out = Path();
  for (final metric in source.computeMetrics()) {
    var d = 0.0;
    while (d < metric.length) {
      final end = (d + dash).clamp(0.0, metric.length);
      out.addPath(metric.extractPath(d, end), Offset.zero);
      d += dash + gap;
    }
  }
  return out;
}

class _CordPainter extends CustomPainter {
  _CordPainter({
    required this.cells,
    required this.owned,
    required this.cellOrigin,
    required this.cell,
    required this.vermilion,
    required this.slate,
    required this.ink,
    required this.labelStyle,
  });

  final List<GridCellView> cells;
  final Map<int, ItemView> owned;
  final Offset Function(int row, int col) cellOrigin;
  final double cell;
  final Color vermilion;
  final Color slate;
  final Color ink;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    // placed items by instance value -> centre
    final centreOf = <int, Offset>{};
    final viewOf = <int, ItemView>{};
    for (final c in cells) {
      final v = c.occupant?.instanceEntityValue;
      if (v == null) continue;
      centreOf[v] = cellOrigin(c.row, c.col) + Offset(cell / 2, cell / 2);
      final view = owned[v];
      if (view != null) viewOf[v] = view;
    }

    // group by (definitionId, itemClass)
    final groups = <String, List<int>>{};
    for (final e in viewOf.entries) {
      final key = '${e.value.definitionId}|${e.value.itemClass}';
      groups.putIfAbsent(key, () => []).add(e.key);
    }

    for (final members in groups.values) {
      if (members.length < 2) continue;
      final anchor = viewOf[members.first]!;
      final eligible = anchor.eligibleToCombine;
      final color = eligible ? vermilion : slate;

      if (members.length >= 3) {
        // radial hub
        var hub = Offset.zero;
        for (final m in members) {
          hub += centreOf[m]!;
        }
        hub = hub / members.length.toDouble();
        for (final m in members) {
          _cord(canvas, hub, centreOf[m]!, color, eligible);
        }
        canvas.drawCircle(hub, 5, Paint()..color = color);
        canvas.drawCircle(
          hub,
          8,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = color,
        );
        _cordLabel(
          canvas,
          hub + const Offset(10, -6),
          '${members.length} matched  ${eligible ? "" : "· maxed"}',
        );
      } else {
        final a = centreOf[members[0]]!;
        final b = centreOf[members[1]]!;
        _cord(canvas, a, b, color, eligible);
        final mid = Offset.lerp(a, b, 0.5)!;
        final label =
            eligible
                ? 'cls ${_r(anchor.itemClass)} -> ${_r(anchor.itemClass + 1)} · ${anchor.itemClass} pt'
                : 'maxed';
        _cordLabel(canvas, mid + const Offset(0, -12), label);
      }
    }
  }

  void _cord(Canvas canvas, Offset a, Offset b, Color color, bool eligible) {
    inkStroke(
      canvas,
      a,
      b,
      color: color.withValues(alpha: eligible ? 0.92 : 0.5),
      width: eligible ? 3 : 1.6,
      seed: (a.dx + b.dy).round(),
      dashed: !eligible,
    );
    if (!eligible) {
      // strike-through the slack cord
      final mid = Offset.lerp(a, b, 0.5)!;
      final n = (b - a);
      final perp =
          n.distance < 1
              ? const Offset(0, 1)
              : Offset(-n.dy, n.dx) / n.distance;
      inkStroke(
        canvas,
        mid - perp * 8,
        mid + perp * 8,
        color: color,
        width: 2,
        seed: 7,
      );
    }
  }

  void _cordLabel(Canvas canvas, Offset at, String text) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final pad = const Offset(5, 3);
    final rect = Rect.fromLTWH(
      at.dx - pad.dx,
      at.dy - pad.dy,
      tp.width + pad.dx * 2,
      tp.height + pad.dy * 2,
    );
    canvas.drawRect(
      rect,
      Paint()..color = const Color(0xFF0C090B).withValues(alpha: 0.78),
    );
    tp.paint(canvas, at);
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

  @override
  bool shouldRepaint(_CordPainter old) => true;
}

class _ExtentRail extends StatelessWidget {
  const _ExtentRail({
    required this.controller,
    required this.axis,
    required this.contentExtent,
    required this.viewportExtent,
    required this.color,
  });

  final TransformationController controller;
  final Axis axis;
  final double contentExtent;
  final double viewportExtent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final m = controller.value;
        final scale = m.getMaxScaleOnAxis();
        final scaledContent = contentExtent * scale;
        if (scaledContent <= viewportExtent + 1) return const SizedBox.shrink();

        final translate =
            axis == Axis.horizontal
                ? -m.getTranslation().x
                : -m.getTranslation().y;
        final frac = (viewportExtent / scaledContent).clamp(0.05, 1.0);
        final pos = (translate / scaledContent).clamp(0.0, 1.0 - frac);

        return LayoutBuilder(
          builder: (context, c) {
            final full = axis == Axis.horizontal ? c.maxWidth : c.maxHeight;
            final thumb = full * frac;
            final offset = full * pos;
            return Stack(
              children: [
                Align(
                  alignment:
                      axis == Axis.horizontal
                          ? Alignment.center
                          : Alignment.center,
                  child: Container(
                    width: axis == Axis.horizontal ? full : 2,
                    height: axis == Axis.horizontal ? 2 : full,
                    color: color.withValues(alpha: 0.14),
                  ),
                ),
                Positioned(
                  left: axis == Axis.horizontal ? offset : 0,
                  top: axis == Axis.horizontal ? 0 : offset,
                  child: Container(
                    width: axis == Axis.horizontal ? thumb : 3,
                    height: axis == Axis.horizontal ? 3 : thumb,
                    color: color.withValues(alpha: 0.4),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
