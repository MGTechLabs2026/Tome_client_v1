// lib/features/tome/hall/mount.dart
//
// One mounted form: a bone plate carrying a carved seal (identity), rank
// rings (mastery), a fixed-cell state mark, its grid address, and an
// optional leader-line quantity. The same widget serves the board, the
// loose rack, and sheet previews, so a component looks identical
// wherever it hangs.
import 'package:flutter/material.dart';

import '../../../core/models/grid_cell_view.dart';
import '../../../core/models/item_view.dart';
import '../../../core/models/technique_view.dart';
import 'hall_theme.dart';
import 'ink.dart';

enum MountState { unknown, locked, usable, mastered, active, learned }

class MountData {
  const MountData({
    required this.contentId,
    required this.displayName,
    required this.kind,
    required this.state,
    this.masteryLevel = 0,
    this.masteryProgress01 = 0,
    this.itemClass,
    this.maxClass,
    this.maxed = false,
    this.address,
    this.annotation,
  });

  final String contentId;
  final String displayName;
  final GridComponentKind kind;
  final MountState state;
  final int masteryLevel;
  final double masteryProgress01;
  final int? itemClass;
  final int? maxClass;
  final bool maxed;
  final String? address;
  final String? annotation;

  factory MountData.fromItem(ItemView v, {String? address}) {
    final thresholds = v.masteryThresholds;
    final next = thresholds.firstWhere(
      (t) => t > v.masteryProgress,
      orElse: () => thresholds.isEmpty ? 1 : thresholds.last,
    );
    final prev = thresholds.lastWhere(
      (t) => t <= v.masteryProgress,
      orElse: () => 0,
    );
    final span = (next - prev);
    return MountData(
      contentId: v.definitionId,
      displayName: v.upgradeCount > 0
          ? '${_pretty(v.name)} +${v.upgradeCount}'
          : _pretty(v.name),
      kind: GridComponentKind.item,
      state: switch (v.state) {
        ItemDisplayState.locked => MountState.locked,
        ItemDisplayState.usable => MountState.usable,
        ItemDisplayState.mastered => MountState.mastered,
        ItemDisplayState.equipped => MountState.active,
      },
      masteryLevel: v.masteryLevel,
      masteryProgress01:
          span <= 0
              ? 0
              : ((v.masteryProgress - prev) / span).clamp(0, 1).toDouble(),
      itemClass: v.itemClass,
      maxClass: v.maxClass,
      maxed: v.maxClass != null && v.itemClass >= v.maxClass!,
      address: address,
      annotation: v.maxClass != null ? 'cls ${_roman(v.itemClass)}' : null,
    );
  }

  factory MountData.fromTechnique(TechniqueView v, {String? address}) =>
      MountData(
        contentId: v.definitionId,
        displayName: _pretty(v.name),
        kind: GridComponentKind.technique,
        state:
            v.learned
                ? MountState.learned
                : (v.discovered ? MountState.usable : MountState.unknown),
        masteryLevel: v.masteryLevel,
        address: address,
        annotation:
            v.evolvedFromId == null
                ? v.tier
                : '<- ${_pretty(v.evolvedFromId!)}',
      );
}

String _pretty(String id) => id
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

String _roman(int n) =>
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

class MountView extends StatelessWidget {
  const MountView({
    super.key,
    required this.data,
    this.selected = false,
    this.dimmed = false,
    this.compact = false,
    this.spotlight = false,
  });

  final MountData data;
  final bool selected;

  /// Everything that is not the current selection sits back in shadow.
  final bool dimmed;

  /// Rack / preview size: hides the address and shrinks the seal.
  final bool compact;

  /// One-time "this just arrived" emphasis.
  final bool spotlight;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final isLocked =
        data.state == MountState.locked || data.state == MountState.unknown;
    final isMastered = data.state == MountState.mastered;
    final ground = hall.bone;
    final seedTint = isLocked ? HallTheme.cLockedInk : hall.lacquerDeep;

    // Locked ink is dark on the bone plate (~5:1), not dim: a locked
    // form stays legible, its state carried by the struck mark's shape.
    final chopInk = isMastered
        ? hall.gold
        : isLocked
            ? HallTheme.cLockedInk
            : hall.vermilionInk;
    final nameInk = isLocked ? HallTheme.cLockedInk : hall.lacquerDeep;

    return Semantics(
      label: data.displayName,
      value: _semanticsValue(),
      child: Opacity(
      opacity: dimmed ? 0.52 : 1,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth.isFinite ? c.maxWidth : 120.0;
          final h = c.maxHeight.isFinite ? c.maxHeight : 120.0;
          final side = w < h ? w : h;
          return Stack(
            fit: StackFit.expand,
            children: [
              // mount plate: raking shadow + hand-cut bone card
              CustomPaint(
                painter: _PlatePainter(
                  ground:
                      isLocked
                          ? Color.alphaBlend(
                            hall.slate.withValues(alpha: 0.22),
                            ground,
                          )
                          : ground,
                  edge: seedTint,
                  selected: selected,
                  spotlight: spotlight,
                  light: hall.gold,
                  vermilion: hall.vermilion,
                  seed: data.contentId.hashCode,
                ),
              ),
              Padding(
                padding: EdgeInsets.all(side * (compact ? 0.09 : 0.11)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // seal chop
                          Expanded(
                            flex: 3,
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: CustomPaint(
                                painter: SealChopPainter(
                                  contentId: data.contentId,
                                  ink: chopInk,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          // rank rings
                          if (data.masteryLevel > 0 ||
                              data.masteryProgress01 > 0)
                            SizedBox(
                              width: side * 0.24,
                              height: side * 0.24,
                              child: CustomPaint(
                                painter: RankRingsPainter(
                                  level: data.masteryLevel,
                                  progress: data.masteryProgress01,
                                  ink: hall.lacquerDeep.withValues(alpha: 0.72),
                                  mastered: isMastered,
                                  goldInk: hall.gold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: side * 0.04),
                    Text(
                      data.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: hall.label.copyWith(
                        color: nameInk,
                        fontSize: compact ? 9 : 10.5,
                        letterSpacing: 1.4,
                      ),
                    ),
                    if (!compact) ...[
                      SizedBox(height: side * 0.03),
                      Text(
                        [
                          if (data.address != null)
                            data.address!.replaceAll(',', '·'),
                          if (data.annotation != null) data.annotation!,
                        ].join('   '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: hall.measure.copyWith(
                          color: (isLocked
                                  ? HallTheme.cLockedInk
                                  : hall.lacquerDeep)
                              .withValues(alpha: 0.7),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // fixed-cell state mark, top-right
              Positioned(
                top: side * 0.06,
                right: side * 0.06,
                width: side * 0.16,
                height: side * 0.16,
                child: CustomPaint(
                  painter: _StateMarkPainter(
                    mark: _markFor(data),
                    color: switch (data.state) {
                      MountState.mastered => hall.gold,
                      MountState.locked || MountState.unknown => hall.slate,
                      _ => hall.vermilionInk,
                    },
                    seed: data.contentId.hashCode,
                  ),
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }

  String _semanticsValue() {
    final parts = <String>[
      switch (data.state) {
        MountState.locked || MountState.unknown => 'locked',
        MountState.usable => 'usable',
        MountState.learned => 'learned',
        MountState.mastered => 'mastered',
        MountState.active => 'in the Tome',
      },
      if (data.maxClass != null) 'class ${data.itemClass}',
      if (data.masteryLevel > 0) 'mastery ${data.masteryLevel}',
      if (data.maxed) 'at maximum',
      if (data.address != null) 'slot ${data.address!.replaceAll(',', ' ')}',
    ];
    return parts.join(', ');
  }

  InkMark _markFor(MountData d) => switch (d.state) {
    MountState.mastered => InkMark.sealed,
    MountState.locked ||
    MountState.unknown => d.maxed ? InkMark.struck : InkMark.hollow,
    MountState.usable ||
    MountState.learned ||
    MountState.active => d.maxed ? InkMark.struck : InkMark.filled,
  };
}

class _StateMarkPainter extends CustomPainter {
  _StateMarkPainter({
    required this.mark,
    required this.color,
    required this.seed,
  });
  final InkMark mark;
  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    drawInkMark(canvas, Offset.zero & size, mark, color: color, seed: seed);
  }

  @override
  bool shouldRepaint(_StateMarkPainter old) =>
      old.mark != mark || old.color != color;
}

class _PlatePainter extends CustomPainter {
  _PlatePainter({
    required this.ground,
    required this.edge,
    required this.selected,
    required this.spotlight,
    required this.light,
    required this.vermilion,
    required this.seed,
  });

  final Color ground;
  final Color edge;
  final bool selected;
  final bool spotlight;
  final Color light;
  final Color vermilion;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(3);
    final path = handRect(r, radius: 3, seed: seed);

    // raking shadow, cast away from the light
    canvas.save();
    canvas.translate(4.4, 5.4);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.44)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.restore();

    // plate fill
    canvas.drawPath(path, Paint()..color = ground);

    // top-left inner light, bottom-right inner shade (one raking source)
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: kRakingLight,
          end: -kRakingLight,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.14),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(r),
    );
    if (selected) {
      canvas.drawRect(r, Paint()..shader = rakingHighlight(r, light));
    }
    canvas.restore();

    // carved edge
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.6 : 1.6
        ..color =
            selected
                ? light.withValues(alpha: 0.9)
                : edge.withValues(alpha: 0.5),
    );
    if (spotlight) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = vermilion.withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(_PlatePainter old) =>
      old.ground != ground ||
      old.selected != selected ||
      old.spotlight != spotlight;
}
