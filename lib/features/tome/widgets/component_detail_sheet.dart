// lib/features/tome/widgets/component_detail_sheet.dart
//
// A component taken down and examined: its plate, its struck state
// banner (shape carries the meaning, not colour), its properties, its
// lineage, and the actions available on it.
import 'package:flutter/material.dart';

import '../../../core/models/item_view.dart';
import '../../../core/models/technique_view.dart';
import '../hall/hall_controls.dart';
import '../hall/hall_theme.dart';
import '../hall/ink.dart';
import '../hall/mount.dart';

String _stateLabel(ItemDisplayState state) => switch (state) {
  ItemDisplayState.locked => 'LOCKED',
  ItemDisplayState.usable => 'USABLE',
  ItemDisplayState.mastered => 'MASTERED',
  ItemDisplayState.equipped => 'HUNG',
};

Future<void> showComponentDetail(
  BuildContext context, {
  ItemView? item,
  TechniqueView? technique,
  required VoidCallback onTrain,
  VoidCallback? onEquip,
  VoidCallback? onUnequip,
  VoidCallback? onUpgrade,
  VoidCallback? onCombine,
  VoidCallback? onHang,
  VoidCallback? onRemove,
  List<String> lineage = const [],
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder:
        (context) => _DetailSheet(
          item: item,
          technique: technique,
          onTrain: onTrain,
          onEquip: onEquip,
          onUnequip: onUnequip,
          onUpgrade: onUpgrade,
          onCombine: onCombine,
          onHang: onHang,
          onRemove: onRemove,
          lineage: lineage,
        ),
  );
}

class _DetailSheet extends StatefulWidget {
  const _DetailSheet({
    this.item,
    this.technique,
    required this.onTrain,
    this.onEquip,
    this.onUnequip,
    this.onUpgrade,
    this.onCombine,
    this.onHang,
    this.onRemove,
    this.lineage = const [],
  });

  final ItemView? item;
  final TechniqueView? technique;
  final VoidCallback onTrain;
  final VoidCallback? onEquip;
  final VoidCallback? onUnequip;
  final VoidCallback? onUpgrade;
  final VoidCallback? onCombine;
  final VoidCallback? onHang;
  final VoidCallback? onRemove;
  final List<String> lineage;

  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  bool _lineageOpen = false;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final item = widget.item;
    final tech = widget.technique;
    final itemBase = item == null
        ? ''
        : (item.displayName.isEmpty ? _pretty(item.name) : item.displayName);
    final name = item != null
        ? (item.upgradeCount > 0 ? '$itemBase +${item.upgradeCount}' : itemBase)
        : _pretty(tech?.name ?? '');
    final subtitle =
        item != null
            ? item.category.toUpperCase()
            : (tech?.tier ?? '').toUpperCase();
    final props = item?.properties ?? tech?.properties ?? const <String, num>{};

    final data =
        item != null
            ? MountData.fromItem(item)
            : tech != null
            ? MountData.fromTechnique(tech)
            : null;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        decoration: BoxDecoration(
          color: hall.lacquer,
          border: Border(
            top: BorderSide(color: hall.bone.withValues(alpha: 0.2), width: 2),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _grip(hall),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data != null)
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: MountView(data: data),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (subtitle.isNotEmpty)
                          Text(subtitle, style: hall.label),
                        const SizedBox(height: 4),
                        Text(name, style: hall.display.copyWith(fontSize: 20)),
                        const SizedBox(height: 10),
                        if (item != null) _ItemBanner(item: item),
                        if (tech != null) _TechBanner(tech: tech),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _rule(hall),
              const SizedBox(height: 14),
              if (props.isNotEmpty) ...[
                Text('PROPERTIES', style: hall.label),
                const SizedBox(height: 8),
                ...props.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: LeaderLabel(
                      text:
                          '${e.key}  ${e.value is int || e.value == e.value.roundToDouble() ? '+${e.value.round()}' : '+${e.value}'}',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (tech?.evolvedFromId != null) ...[
                GestureDetector(
                  onTap: () => setState(() => _lineageOpen = !_lineageOpen),
                  child: Row(
                    children: [
                      Text('EVOLVED FROM  ', style: hall.label),
                      Text(
                        _pretty(tech!.evolvedFromId!),
                        style: hall.measureStrong.copyWith(fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        _lineageOpen ? 'HIDE LINEAGE' : 'VIEW LINEAGE',
                        style: hall.label.copyWith(
                          color: hall.vermilion,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_lineageOpen) ...[
                  const SizedBox(height: 10),
                  _LineageDescent(
                    chain: [
                      ...widget.lineage,
                      if (widget.lineage.isEmpty) tech.evolvedFromId!,
                      tech.definitionId,
                    ],
                  ),
                ],
                const SizedBox(height: 14),
              ],
              if ((item?.combinableWith.isNotEmpty ?? false)) ...[
                Row(
                  children: [
                    Text('COMBINABLE WITH', style: hall.label),
                    const SizedBox(width: 8),
                    CustomPaint(
                      size: const Size(18, 8),
                      painter: _Arrow(color: hall.boneDim),
                    ),
                    const Spacer(),
                    Text(
                      '${item!.combinableWith.length} match${item.combinableWith.length == 1 ? '' : 'es'}',
                      style: hall.measure,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.eligibleToCombine
                      ? 'a taut cord runs between them on the board'
                      : 'matched, but maxed — the cord hangs slack',
                  style: hall.measure.copyWith(fontSize: 10.5),
                ),
                const SizedBox(height: 14),
              ],
              _rule(hall),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (data?.state != MountState.mastered)
                    InkButton(
                      label: 'Train',
                      onPressed: () {
                        Navigator.of(context).maybePop();
                        widget.onTrain();
                      },
                    ),
                  if (widget.onCombine != null)
                    InkButton(
                      label: 'Combine',
                      tone: InkTone.seal,
                      onPressed: widget.onCombine,
                    ),
                  if (widget.onHang != null)
                    InkButton(label: 'Hang in Tome', onPressed: widget.onHang),
                  if (widget.onEquip != null)
                    InkButton(label: 'Equip', onPressed: widget.onEquip),
                  if (widget.onUnequip != null)
                    InkButton(
                      label: 'Unequip',
                      tone: InkTone.quiet,
                      onPressed: widget.onUnequip,
                    ),
                  if (widget.onUpgrade != null)
                    InkButton(
                      label: 'Upgrade',
                      tone: InkTone.gold,
                      glyph: HammerGlyph(color: hall.gold),
                      onPressed: widget.onUpgrade,
                    ),
                  if (widget.onRemove != null)
                    InkButton(
                      label: 'Unhang',
                      tone: InkTone.quiet,
                      onPressed: widget.onRemove,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grip(HallTheme hall) => Center(
    child: Container(
      width: 44,
      height: 3,
      color: hall.bone.withValues(alpha: 0.28),
    ),
  );

  Widget _rule(HallTheme hall) =>
      Container(height: 1, color: hall.bone.withValues(alpha: 0.14));
}

class _ItemBanner extends StatelessWidget {
  const _ItemBanner({required this.item});
  final ItemView item;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final label = _stateLabel(item.state);
    final locked = item.state == ItemDisplayState.locked;
    final mastered = item.state == ItemDisplayState.mastered;
    final ink = mastered ? hall.gold : (locked ? hall.slate : hall.vermilion);
    final mark =
        mastered
            ? InkMark.sealed
            : locked
            ? InkMark.hollow
            : InkMark.filled;

    final threshold = item.masteryThresholds.firstWhere(
      (t) => t > item.masteryProgress,
      orElse:
          () =>
              item.masteryThresholds.isEmpty ? 0 : item.masteryThresholds.last,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CustomPaint(
              size: const Size(14, 14),
              painter: _MarkGlyph(mark: mark, color: ink),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: hall.heading.copyWith(
                fontSize: 12,
                color: ink,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        if (locked && item.masteryThresholds.isNotEmpty) ...[
          const SizedBox(height: 6),
          LeaderLabel(
            text:
                'mastery  ${item.masteryProgress.toStringAsFixed(0)} / ${threshold.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 2),
          Text(
            'train it to raise the rule past the next mark',
            style: hall.measure.copyWith(fontSize: 10),
          ),
        ],
      ],
    );
  }
}

class _TechBanner extends StatelessWidget {
  const _TechBanner({required this.tech});
  final TechniqueView tech;
  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final label =
        tech.learned ? 'LEARNED' : (tech.discovered ? 'DISCOVERED' : 'UNKNOWN');
    final ink = tech.learned ? hall.vermilion : hall.slate;
    return Row(
      children: [
        CustomPaint(
          size: const Size(14, 14),
          painter: _MarkGlyph(
            mark: tech.learned ? InkMark.filled : InkMark.hollow,
            color: ink,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: hall.heading.copyWith(
            fontSize: 12,
            color: ink,
            letterSpacing: 2,
          ),
        ),
        if (tech.masteryLevel > 0) ...[
          const SizedBox(width: 12),
          Text('rank ${tech.masteryLevel}', style: hall.measure),
        ],
      ],
    );
  }
}

class _LineageDescent extends StatelessWidget {
  const _LineageDescent({required this.chain});
  final List<String> chain;
  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final seen = <String>{};
    final ordered = [
      for (final c in chain)
        if (seen.add(c)) c,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < ordered.length; i++)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 14,
                  child: Column(
                    children: [
                      Container(width: 5, height: 5, color: hall.vermilion),
                      if (i < ordered.length - 1)
                        Container(
                          width: 1,
                          height: 18,
                          color: hall.bone.withValues(alpha: 0.3),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    _pretty(ordered[i]),
                    style: hall.body.copyWith(
                      fontSize: 12.5,
                      color: i == ordered.length - 1 ? hall.bone : hall.boneDim,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MarkGlyph extends CustomPainter {
  _MarkGlyph({required this.mark, required this.color});
  final InkMark mark;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) =>
      drawInkMark(canvas, Offset.zero & size, mark, color: color, seed: 3);
  @override
  bool shouldRepaint(_MarkGlyph old) => old.mark != mark || old.color != color;
}

class _Arrow extends CustomPainter {
  _Arrow({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final p =
        Paint()
          ..color = color
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    canvas.drawLine(Offset(size.width - 5, y - 4), Offset(size.width, y), p);
    canvas.drawLine(Offset(size.width - 5, y + 4), Offset(size.width, y), p);
  }

  @override
  bool shouldRepaint(_Arrow old) => old.color != color;
}

String _pretty(String id) => id
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
