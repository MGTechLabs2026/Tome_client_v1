// lib/features/title/almanac_screen.dart
//
// ALMANAC — a reference ledger of the lineage's reach: every martial
// style, every registered item form, every plain technique the engine
// currently knows, with what this player has *met* across all runs
// (CodexRepository) marked against it.
//
// The roster is not maintained here. `AlmanacAdapter` enumerates the
// live engine content registry and hands this screen plain records; a
// style/item/technique that ships in the engine appears here with no
// edit to this file. This widget imports no build_engine type.
//
// Layout is master–detail inside the one oiled-paper panel: a roster
// column and a detail leaf side by side on a wide surface; on a narrow
// one the roster fills the panel and a tap opens the leaf as an internal
// page with its own quiet "all entries" step, separate from the page's
// own Back.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/engine/almanac_adapter.dart';
import '../../core/engine/engine_session.dart';
import '../../core/persistence/codex_repository.dart';
import '../tome/hall/hall_theme.dart';
import '../tome/hall/ink.dart';
import 'threshold_page.dart';

enum _Kind { style, item, technique }

extension on _Kind {
  String get noun => switch (this) {
        _Kind.style => 'style',
        _Kind.item => 'item',
        _Kind.technique => 'technique',
      };
  String get heading => switch (this) {
        _Kind.style => 'Styles',
        _Kind.item => 'Items',
        _Kind.technique => 'Techniques',
      };
}

class _Sel {
  const _Sel(this.kind, this.id);
  final _Kind kind;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is _Sel && other.kind == kind && other.id == id;
  @override
  int get hashCode => Object.hash(kind, id);
}

class AlmanacScreen extends StatefulWidget {
  const AlmanacScreen({super.key});

  @override
  State<AlmanacScreen> createState() => _AlmanacScreenState();
}

class _AlmanacScreenState extends State<AlmanacScreen> {
  late final AlmanacSnapshot _roster;

  late final Map<String, AlmanacStyleView> _styleById;
  late final Map<String, AlmanacItemView> _itemById;
  late final Map<String, AlmanacTechniqueView> _techById;

  _Sel? _selected;
  bool _detailPage = false; // narrow layout: roster vs. leaf

  @override
  void initState() {
    super.initState();
    _roster = AlmanacAdapter(context.read<EngineSession>()).snapshot();
    _styleById = {for (final s in _roster.styles) s.id: s};
    _itemById = {for (final i in _roster.items) i.id: i};
    _techById = {for (final t in _roster.techniques) t.id: t};
  }

  void _select(_Sel sel) => setState(() {
        _selected = sel;
        _detailPage = true;
      });

  Set<String> _met(CodexKind kind, Iterable<String> rosterIds) {
    final codex = context.read<CodexRepository>().snapshot.of(kind);
    return {for (final id in rosterIds) if (codex.contains(id)) id};
  }

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;

    final metStyles = _met(CodexKind.style, _styleById.keys);
    final metItems = _met(CodexKind.item, _itemById.keys);
    final metTech = _met(CodexKind.technique, _techById.keys);
    final metTotal = metStyles.length + metItems.length + metTech.length;
    final rosterTotal = _roster.total;
    final complete = rosterTotal > 0 && metTotal == rosterTotal;

    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return ThresholdPage(
      heading: 'Almanac',
      maxWidth: 880,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final regionHeight = math.min(
            560.0,
            MediaQuery.of(context).size.height * 0.62,
          ).clamp(360.0, 560.0);

          final roster = _Roster(
            snapshot: _roster,
            metStyles: metStyles,
            metItems: metItems,
            metTech: metTech,
            selected: _selected,
            onSelect: _select,
          );

          final Widget leaf = _DetailLeaf(
            selected: _selected,
            styleById: _styleById,
            itemById: _itemById,
            techById: _techById,
            metStyles: metStyles,
            metItems: metItems,
            metTech: metTech,
            showBack: !wide,
            onBack: () => setState(() => _detailPage = false),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _CompletionBar(
                met: metTotal,
                total: rosterTotal,
                complete: complete,
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: regionHeight,
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: 300, child: roster),
                          Container(
                            width: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            color: hall.bone.withValues(alpha: 0.14),
                          ),
                          Expanded(child: leaf),
                        ],
                      )
                    : AnimatedSwitcher(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 140),
                        child: (_detailPage && _selected != null)
                            ? leaf
                            : roster,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── completion ───────────────────────────────────────────────────────

class _CompletionBar extends StatelessWidget {
  const _CompletionBar({
    required this.met,
    required this.total,
    required this.complete,
  });

  final int met;
  final int total;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final frac = total == 0 ? 0.0 : met / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$met',
              style: hall.measureStrong.copyWith(
                color: complete ? hall.gold : hall.bone,
                fontSize: 15,
              ),
            ),
            Text('  /  $total  met', style: hall.measure),
            const Spacer(),
            if (complete)
              Text(
                'COMPLETE',
                style: hall.label.copyWith(color: hall.gold, letterSpacing: 2.4),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 3,
          child: CustomPaint(
            painter: _ProgressRule(
              fraction: frac,
              track: hall.bone.withValues(alpha: 0.12),
              fill: complete ? hall.gold : hall.boneDim,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressRule extends CustomPainter {
  _ProgressRule({
    required this.fraction,
    required this.track,
    required this.fill,
  });

  final double fraction;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    inkStroke(
      canvas,
      Offset(0, y),
      Offset(size.width, y),
      color: track,
      width: size.height,
      seed: 0x41,
    );
    if (fraction > 0) {
      inkStroke(
        canvas,
        Offset(0, y),
        Offset(size.width * fraction.clamp(0, 1), y),
        color: fill,
        width: size.height,
        seed: 0x42,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressRule old) =>
      old.fraction != fraction || old.fill != fill;
}

// ── roster ───────────────────────────────────────────────────────────

class _Roster extends StatelessWidget {
  const _Roster({
    required this.snapshot,
    required this.metStyles,
    required this.metItems,
    required this.metTech,
    required this.selected,
    required this.onSelect,
  });

  final AlmanacSnapshot snapshot;
  final Set<String> metStyles;
  final Set<String> metItems;
  final Set<String> metTech;
  final _Sel? selected;
  final ValueChanged<_Sel> onSelect;

  @override
  Widget build(BuildContext context) {
    final anySelected = selected != null;

    Widget plateFor(_Kind kind, String id, bool met, String label,
        String descriptor, String axis) {
      final sel = _Sel(kind, id);
      return _EntryPlate(
        contentId: id,
        met: met,
        label: label,
        descriptor: descriptor,
        lockedAxis: axis,
        kindNoun: kind.noun,
        tradition: kind == _Kind.style
            ? (snapshot.styles.firstWhere((s) => s.id == id).tradition)
            : null,
        selected: sel == selected,
        dimmed: anySelected && sel != selected,
        onTap: () => onSelect(sel),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(right: 2, bottom: 4),
      children: [
        _GroupHeader(
          title: _Kind.style.heading,
          met: metStyles.length,
          total: snapshot.styles.length,
        ),
        for (final s in snapshot.styles)
          plateFor(
            _Kind.style,
            s.id,
            metStyles.contains(s.id),
            s.label,
            _styleDescriptor(s),
            s.tradition ?? 'tradition held back',
          ),
        const SizedBox(height: 18),
        _GroupHeader(
          title: _Kind.item.heading,
          met: metItems.length,
          total: snapshot.items.length,
        ),
        for (final i in snapshot.items)
          plateFor(
            _Kind.item,
            i.id,
            metItems.contains(i.id),
            i.label,
            _itemDescriptor(i),
            i.category,
          ),
        const SizedBox(height: 18),
        _GroupHeader(
          title: _Kind.technique.heading,
          met: metTech.length,
          total: snapshot.techniques.length,
        ),
        for (final t in snapshot.techniques)
          plateFor(
            _Kind.technique,
            t.id,
            metTech.contains(t.id),
            t.label,
            _techDescriptor(t),
            t.family,
          ),
      ],
    );
  }
}

String _styleDescriptor(AlmanacStyleView s) {
  final specs = s.specialtyTags
      .map((t) => t.startsWith('spec:') ? t.substring(5).replaceAll('_', ' ') : t)
      .join(', ');
  return [if (s.tradition != null) s.tradition!, if (specs.isNotEmpty) specs]
      .join(' · ');
}

String _itemDescriptor(AlmanacItemView i) => [
      i.category,
      if (i.family != i.category) i.family,
      if (i.maxClass != null) 'combines',
      if (i.affinity != null) i.affinity!,
    ].join(' · ');

String _techDescriptor(AlmanacTechniqueView t) => [
      t.tier,
      if (t.family != t.tier) t.family,
      if (t.affinity != null) t.affinity!,
    ].join(' · ');

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.met,
    required this.total,
  });

  final String title;
  final int met;
  final int total;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Semantics(
      header: true,
      label: '$title, $met of $total met',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Text(
              title.toUpperCase(),
              style: hall.label.copyWith(color: hall.bone, letterSpacing: 2.2),
            ),
            const Spacer(),
            Text('$met / $total', style: hall.measure),
          ],
        ),
      ),
    );
  }
}

class _EntryPlate extends StatelessWidget {
  const _EntryPlate({
    required this.contentId,
    required this.met,
    required this.label,
    required this.descriptor,
    required this.lockedAxis,
    required this.kindNoun,
    required this.tradition,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final String contentId;
  final bool met;
  final String label;
  final String descriptor;
  final String lockedAxis;
  final String kindNoun;
  final String? tradition;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;

    final semanticLabel = met
        ? '$label. $descriptor'
        : 'Locked $kindNoun. $lockedAxis';

    final body = met
        ? _discovered(hall)
        : _locked(hall);

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Opacity(
          opacity: dimmed ? 0.52 : 1.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: CustomPaint(
                painter: _PlatePainter(
                  seed: _seed(contentId),
                  met: met,
                  selected: selected,
                  tradition: tradition,
                  hall: hall,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
                  child: body,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _discovered(HallTheme hall) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ExcludeSemantics(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CustomPaint(
              painter: SealChopPainter(
                contentId: contentId,
                ink: hall.vermilion.withValues(alpha: selected ? 1 : 0.82),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: hall.body.copyWith(
                  color: hall.bone,
                  fontVariations: const [FontVariation('wght', 560)],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                descriptor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: hall.measure,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _locked(HallTheme hall) {
    final h = _seed(contentId);
    // Deterministic placeholder length: 46–120px from the id hash.
    final blotWidth = 46.0 + (h % 8) * 10.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: CustomPaint(
            painter: _StruckMark(ink: hall.slate.withValues(alpha: 0.5)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 13,
                child: CustomPaint(
                  painter: _BlotPainter(
                    width: blotWidth,
                    seed: h,
                    ink: hall.slate.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                lockedAxis,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: hall.measure.copyWith(
                  color: hall.boneDim.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

int _seed(String s) {
  var h = 2166136261;
  for (final c in s.codeUnits) {
    h = (h ^ c) * 16777619 & 0xFFFFFFFF;
  }
  return h;
}

class _PlatePainter extends CustomPainter {
  _PlatePainter({
    required this.seed,
    required this.met,
    required this.selected,
    required this.tradition,
    required this.hall,
  });

  final int seed;
  final bool met;
  final bool selected;
  final String? tradition;
  final HallTheme hall;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = handRect(rect, radius: 2.5, seed: seed);

    if (!met) {
      canvas.drawPath(
        path,
        Paint()..color = hall.slate.withValues(alpha: 0.08),
      );
    } else if (tradition != null) {
      // West↔east carried as hue at near-constant value — a wash, never
      // a coloured rule.
      final hue = tradition == 'western' ? hall.westGround : hall.eastGround;
      canvas.drawPath(path, Paint()..color = hue.withValues(alpha: 0.12));
    }

    if (selected && met) {
      canvas.drawPath(
        path,
        Paint()..shader = rakingHighlight(rect, hall.bone),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = selected ? 2.6 : 1.4
        ..color = selected
            ? (met ? hall.gold : hall.slate.withValues(alpha: 0.7))
            : hall.bone.withValues(alpha: met ? 0.34 : 0.18),
    );
  }

  @override
  bool shouldRepaint(_PlatePainter old) =>
      old.met != met ||
      old.selected != selected ||
      old.tradition != tradition ||
      old.seed != seed;
}

class _StruckMark extends CustomPainter {
  _StruckMark({required this.ink});
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    drawInkMark(canvas, box, InkMark.struck, color: ink, seed: 7);
  }

  @override
  bool shouldRepaint(_StruckMark old) => old.ink != ink;
}

class _BlotPainter extends CustomPainter {
  _BlotPainter({required this.width, required this.seed, required this.ink});
  final double width;
  final int seed;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final w = math.min(width, size.width);
    final r = Rect.fromLTWH(0, size.height * 0.18, w, size.height * 0.64);
    canvas.drawPath(
      handRect(r, radius: 2, seed: seed, jitter: 1.4),
      Paint()..color = ink.withValues(alpha: 0.32),
    );
    // a drier second pass, offset, so it reads as blotted ink not a bar
    canvas.drawPath(
      handRect(r.translate(2, 1).deflate(1), radius: 2, seed: seed + 5,
          jitter: 1.6),
      Paint()..color = ink.withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(_BlotPainter old) =>
      old.width != width || old.seed != seed || old.ink != ink;
}

// ── detail leaf ──────────────────────────────────────────────────────

class _DetailLeaf extends StatelessWidget {
  const _DetailLeaf({
    required this.selected,
    required this.styleById,
    required this.itemById,
    required this.techById,
    required this.metStyles,
    required this.metItems,
    required this.metTech,
    required this.showBack,
    required this.onBack,
  });

  final _Sel? selected;
  final Map<String, AlmanacStyleView> styleById;
  final Map<String, AlmanacItemView> itemById;
  final Map<String, AlmanacTechniqueView> techById;
  final Set<String> metStyles;
  final Set<String> metItems;
  final Set<String> metTech;
  final bool showBack;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final sel = selected;

    final Widget content;
    if (sel == null) {
      content = _Empty(hall: hall);
    } else {
      final met = switch (sel.kind) {
        _Kind.style => metStyles.contains(sel.id),
        _Kind.item => metItems.contains(sel.id),
        _Kind.technique => metTech.contains(sel.id),
      };
      if (!met) {
        content = _LockedLeaf(kind: sel.kind, axis: _axisFor(sel));
      } else {
        content = switch (sel.kind) {
          _Kind.style => _StyleLeaf(view: styleById[sel.id]!),
          _Kind.item => _ItemLeaf(
              view: itemById[sel.id]!,
              itemById: itemById,
              met: metItems,
            ),
          _Kind.technique => _TechniqueLeaf(
              view: techById[sel.id]!,
              techById: techById,
              met: metTech,
            ),
        };
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showBack) ...[
          _QuietBack(onTap: onBack),
          const SizedBox(height: 12),
        ],
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(right: 2, bottom: 8),
            child: content,
          ),
        ),
      ],
    );
  }

  String _axisFor(_Sel sel) => switch (sel.kind) {
        _Kind.style =>
          styleById[sel.id]?.tradition ?? 'tradition held back',
        _Kind.item => itemById[sel.id]?.category ?? 'form',
        _Kind.technique => techById[sel.id]?.family ?? 'form',
      };
}

class _QuietBack extends StatelessWidget {
  const _QuietBack({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Semantics(
      button: true,
      label: 'Back to all entries',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 10,
                height: 10,
                child: CustomPaint(painter: _Chevron(ink: hall.boneDim)),
              ),
              const SizedBox(width: 7),
              Text(
                'ALL ENTRIES',
                style: hall.label.copyWith(color: hall.boneDim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chevron extends CustomPainter {
  _Chevron({required this.ink});
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.6
      ..color = ink;
    final path = Path()
      ..moveTo(size.width * 0.7, size.height * 0.1)
      ..lineTo(size.width * 0.2, size.height * 0.5)
      ..lineTo(size.width * 0.7, size.height * 0.9);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_Chevron old) => old.ink != ink;
}

class _Empty extends StatelessWidget {
  const _Empty({required this.hall});
  final HallTheme hall;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'Choose an entry to read what the lineage has recorded of it.',
        style: hall.reading.copyWith(color: hall.boneDim),
      ),
    );
  }
}

class _LeafTitle extends StatelessWidget {
  const _LeafTitle({required this.name, required this.badge});
  final String name;
  final String badge;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: hall.display.copyWith(fontSize: 20)),
          const SizedBox(height: 6),
          _Badge(text: badge),
          const SizedBox(height: 4),
          Container(height: 1, color: hall.bone.withValues(alpha: 0.14)),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return CustomPaint(
      painter: _BadgePainter(hall: hall),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 3, 8, 4),
        child: Text(
          text.toUpperCase(),
          style: hall.label.copyWith(color: hall.bone, letterSpacing: 1.8),
        ),
      ),
    );
  }
}

class _BadgePainter extends CustomPainter {
  _BadgePainter({required this.hall});
  final HallTheme hall;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      handRect(Offset.zero & size, radius: 2, seed: 0x2B),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = hall.bone.withValues(alpha: 0.4),
    );
  }

  @override
  bool shouldRepaint(_BadgePainter old) => false;
}

class _StatRows extends StatelessWidget {
  const _StatRows({required this.properties});
  final Map<String, num> properties;

  @override
  Widget build(BuildContext context) {
    if (properties.isEmpty) return const SizedBox.shrink();
    final entries = properties.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Column(
      children: [
        for (final e in entries)
          LedgerRow(
            label: _prettyKey(e.key),
            value: _num(e.value),
          ),
      ],
    );
  }

  static String _prettyKey(String k) =>
      k[0].toUpperCase() + k.substring(1).replaceAll('_', ' ');

  static String _num(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: hall.label.copyWith(color: hall.boneDim, letterSpacing: 2),
      ),
    );
  }
}

class _TagWrap extends StatelessWidget {
  const _TagWrap({required this.tags});
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    if (tags.isEmpty) {
      return Text('none recorded', style: hall.measure);
    }
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final t in tags)
          CustomPaint(
            painter: _BadgePainter(hall: hall),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(7, 2, 7, 3),
              child: Text(
                t,
                style: hall.measure.copyWith(color: hall.bone),
              ),
            ),
          ),
      ],
    );
  }
}

class _StyleLeaf extends StatelessWidget {
  const _StyleLeaf({required this.view});
  final AlmanacStyleView view;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LeafTitle(
          name: view.label,
          badge: view.tradition == null
              ? 'martial style'
              : '${view.tradition} tradition',
        ),
        Text(
          'The engine records a style as a marker, not a stat block. What '
          'it can show of ${view.label} is its tradition, the specialties '
          'it is granted, and the families it fights inside.',
          style: hall.reading.copyWith(color: hall.boneDim),
        ),
        const _SectionLabel('Specialties'),
        _TagWrap(
          tags: view.specialtyTags
              .map((t) =>
                  t.startsWith('spec:') ? t.substring(5).replaceAll('_', ' ') : t)
              .toList(),
        ),
        const _SectionLabel('Aligned families'),
        _TagWrap(tags: view.alignedFamilies),
      ],
    );
  }
}

class _ItemLeaf extends StatelessWidget {
  const _ItemLeaf({
    required this.view,
    required this.itemById,
    required this.met,
  });

  final AlmanacItemView view;
  final Map<String, AlmanacItemView> itemById;
  final Set<String> met;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LeafTitle(name: view.label, badge: view.category),
        if (view.tags.isNotEmpty) ...[
          _TagWrap(tags: view.tags),
          const SizedBox(height: 4),
        ],
        const _SectionLabel('Properties'),
        _StatRows(properties: view.properties),
        if (view.maxClass != null) ...[
          const _SectionLabel('Class scaling'),
          LedgerRow(label: 'Max class', value: '${view.maxClass}'),
          LedgerRow(
            label: 'Per-class gain',
            value: '+${_pct(view.classScalingPercent)}%',
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Class scales an instance in place; the grades below are a '
              'separate Combine chain.',
              style: hall.measure,
            ),
          ),
        ],
        if (view.evolutionCandidates.isNotEmpty) ...[
          const _SectionLabel('Combine grades'),
          _EvolutionGraph(
            rootId: view.id,
            edgesById: {
              for (final e in itemById.entries) e.key: e.value.evolutionCandidates,
            },
            labelById: {for (final e in itemById.entries) e.key: e.value.label},
            met: met,
          ),
        ],
      ],
    );
  }

  static String _pct(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _TechniqueLeaf extends StatelessWidget {
  const _TechniqueLeaf({
    required this.view,
    required this.techById,
    required this.met,
  });

  final AlmanacTechniqueView view;
  final Map<String, AlmanacTechniqueView> techById;
  final Set<String> met;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LeafTitle(name: view.label, badge: '${view.tier} tier'),
        if (view.tags.isNotEmpty) ...[
          _TagWrap(tags: view.tags),
          const SizedBox(height: 4),
        ],
        const _SectionLabel('Properties'),
        _StatRows(properties: view.properties),
        if (view.evolutionCandidates.isNotEmpty) ...[
          const _SectionLabel('Evolution branches'),
          _EvolutionGraph(
            rootId: view.id,
            edgesById: {
              for (final e in techById.entries)
                e.key: e.value.evolutionCandidates,
            },
            labelById: {for (final e in techById.entries) e.key: e.value.label},
            met: met,
          ),
        ],
      ],
    );
  }
}

class _LockedLeaf extends StatelessWidget {
  const _LockedLeaf({required this.kind, required this.axis});
  final _Kind kind;
  final String axis;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: SizedBox(
            height: 16,
            child: CustomPaint(
              painter: _BlotPainter(
                width: 150,
                seed: axis.hashCode,
                ink: hall.slate.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _Badge(text: '${kind.noun} · not yet met'),
        const SizedBox(height: 16),
        Text(
          'This ${kind.noun} has not been met in any run. The ledger keeps '
          'only its $axis until it is.',
          style: hall.reading.copyWith(color: hall.boneDim),
        ),
      ],
    );
  }
}

/// A recursive evolution / Combine graph drawn from edge data only —
/// indentation is layout, connectors are drawn strokes, node order and
/// depth come straight from [edgesById]. Nodes past the first
/// undiscovered one keep their names blotted (§8).
class _EvolutionGraph extends StatelessWidget {
  const _EvolutionGraph({
    required this.rootId,
    required this.edgesById,
    required this.labelById,
    required this.met,
  });

  final String rootId;
  final Map<String, List<AlmanacEvolutionEdge>> edgesById;
  final Map<String, String> labelById;
  final Set<String> met;

  @override
  Widget build(BuildContext context) {
    return _node(context, rootId, const <String>[], <String>{}, isRoot: true);
  }

  Widget _node(
    BuildContext context,
    String id,
    List<String> incomingTags,
    Set<String> seen, {
    bool isRoot = false,
  }) {
    final hall = context.hall;
    final cycle = seen.contains(id);
    final nextSeen = {...seen, id};
    final revealed = isRoot || met.contains(id);
    final edges = cycle ? const <AlmanacEvolutionEdge>[] : (edgesById[id] ?? const []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CustomPaint(
                  painter: _NodeGlyph(
                    ink: revealed
                        ? hall.vermilion.withValues(alpha: 0.8)
                        : hall.slate.withValues(alpha: 0.5),
                    filled: isRoot,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: revealed
                    ? Text(
                        labelById[id] ?? id,
                        style: hall.body.copyWith(
                          color: isRoot ? hall.bone : hall.boneDim,
                        ),
                      )
                    : SizedBox(
                        height: 12,
                        child: CustomPaint(
                          painter: _BlotPainter(
                            width: 60.0 + (_seed(id) % 5) * 12.0,
                            seed: _seed(id),
                            ink: hall.slate.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
              ),
              if (incomingTags.isNotEmpty) ...[
                const SizedBox(width: 10),
                Text(
                  incomingTags.join(' · '),
                  style: hall.measure.copyWith(fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        for (final e in edges)
          Padding(
            padding: const EdgeInsets.only(left: 7),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 16,
                    child: CustomPaint(painter: _Elbow(ink: hall.boneDim)),
                  ),
                  Expanded(
                    child: _node(context, e.targetId, e.trainingTags, nextSeen),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _NodeGlyph extends CustomPainter {
  _NodeGlyph({required this.ink, required this.filled});
  final Color ink;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.36;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r, c.dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..color = ink,
    );
  }

  @override
  bool shouldRepaint(_NodeGlyph old) =>
      old.ink != ink || old.filled != filled;
}

class _Elbow extends CustomPainter {
  _Elbow({required this.ink});
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.3
      ..color = ink.withValues(alpha: 0.7);
    final x = size.width * 0.3;
    final midY = size.height * 0.5;
    canvas.drawPath(
      Path()
        ..moveTo(x, 0)
        ..lineTo(x, midY)
        ..lineTo(size.width, midY),
      p,
    );
  }

  @override
  bool shouldRepaint(_Elbow old) => old.ink != ink;
}
