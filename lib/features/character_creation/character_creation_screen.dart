// lib/features/character_creation/character_creation_screen.dart
//
// Choosing a style: the lineage's two roads laid side by side — western
// traditions on the ember half, eastern on the cold-steel half, split by
// one bone hairline. Each style hangs as a hand-cut plate carrying its
// name, a synergy badge (a gold up-mark where the road answers your
// physique at ×1.25, a struck slate mark where it answers at ×0.85), and
// a line on what the road asks of you. The favoured column's plates
// kindle gold once on entry so the eye lands there first.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/game_phase.dart';
import '../run/run_bloc.dart';
import '../run/run_event.dart';
import '../tome/hall/hall_controls.dart';
import '../tome/hall/hall_theme.dart';
import '../tome/hall/ink.dart';
import 'character_creation_bloc.dart';
import 'character_creation_event.dart';

/// Style label + orientation line. Presentation data, not the engine
/// registry (widgets never import build_engine) — a new style gains its
/// entry here when it ships, the same way the almanac catalogue grows.
const _styleBook = <String, (String, String)>{
  'polearming': (
    'Polearming',
    'Reach kept long and the line held — footwork that trades ground for '
        'time and never lets the fight inside the shaft.',
  ),
  'wrestling': (
    'Wrestling',
    'Close the distance and take the hold. Grips, throws, and a frame '
        'built to outlast a longer, uglier bout.',
  ),
  'fencing': (
    'Fencing',
    'The first touch decides it — economy of motion, a straight line to '
        'the opening, and the initiative never handed back.',
  ),
  'shaolin': (
    'Shaolin',
    'Fist and palm drilled until they are conditioning itself: power from '
        'the ground up and a body hardened to trade blows.',
  ),
  'taiChi': (
    'Tai Chi',
    'Yield, turn, and return the force. Read the incoming line and let '
        "the opponent's own weight undo them.",
  ),
  'kunlun': (
    'Kunlun',
    'Quick blade and quicker feet — cuts chained off the last, building '
        'speed until the streak breaks a guard.',
  ),
};

class CharacterCreationScreen extends StatelessWidget {
  const CharacterCreationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CharacterCreationBloc, CharacterCreationState>(
      listener: (context, state) {
        if (state.confirmed) {
          context.read<RunBloc>().add(const PhaseCompleted(GamePhase.tome));
          context.go('/tome');
        }
      },
      builder: (context, state) {
        if (state.name == null) {
          return _NameStep(
            onSubmit:
                (name) => context.read<CharacterCreationBloc>().add(
                  NameSubmitted(name),
                ),
          );
        }
        return _StyleStep(
          state: state,
          onChoose:
              (id) =>
                  context.read<CharacterCreationBloc>().add(StyleChosen(id)),
        );
      },
    );
  }
}

// ── name ────────────────────────────────────────────────────────────────

class _NameStep extends StatefulWidget {
  const _NameStep({required this.onSubmit});
  final ValueChanged<String> onSubmit;

  @override
  State<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<_NameStep> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _controller.text.trim();
    widget.onSubmit(t.isEmpty ? 'Fighter' : t);
  }

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Scaffold(
      backgroundColor: hall.lacquer,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THE LINEAGE',
                    style: hall.label.copyWith(
                      color: hall.boneDim,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'NAME YOUR FIGHTER',
                    style: hall.displayLarge.copyWith(
                      fontSize: 28,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'The name carried at the head of the sheet, and into '
                    'every bout after.',
                    style: hall.measure.copyWith(color: hall.boneDim),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    height: 1,
                    color: hall.bone.withValues(alpha: 0.14),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    style: hall.reading,
                    textCapitalization: TextCapitalization.words,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Fighter',
                      hintStyle: hall.reading.copyWith(
                        color: hall.boneDim.withValues(alpha: 0.6),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: hall.bone.withValues(alpha: 0.3),
                        ),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: hall.bone.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkButton(
                      label: 'Continue',
                      tone: InkTone.seal,
                      onPressed: _submit,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── style ───────────────────────────────────────────────────────────────

class _StyleStep extends StatefulWidget {
  const _StyleStep({required this.state, required this.onChoose});
  final CharacterCreationState state;
  final ValueChanged<String> onChoose;

  @override
  State<_StyleStep> createState() => _StyleStepState();
}

class _StyleStepState extends State<_StyleStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 660),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _intro.duration =
          MediaQuery.of(context).disableAnimations
              ? const Duration(milliseconds: 1)
              : const Duration(milliseconds: 660);
      _intro.forward();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  void _choose(String id) {
    if (_selected != null) return;
    setState(() => _selected = id);
    widget.onChoose(id);
  }

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final state = widget.state;
    final affinity = state.character!.physiqueAffinityTradition; // west / east
    final west =
        state.availableStyles
            .where((s) => state.synergyByStyle[s] == 'western')
            .toList();
    final east =
        state.availableStyles
            .where((s) => state.synergyByStyle[s] == 'eastern')
            .toList();

    return Scaffold(
      backgroundColor: hall.lacquer,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 720;

            final westCol = _TraditionColumn(
              title: 'Western Traditions',
              styleIds: west,
              matched: affinity == 'western',
              tradition: 'western',
              controller: _intro,
              order: 0,
              selectedId: _selected,
              onChoose: _choose,
            );
            final eastCol = _TraditionColumn(
              title: 'Eastern Traditions',
              styleIds: east,
              matched: affinity == 'eastern',
              tradition: 'eastern',
              controller: _intro,
              order: 1,
              selectedId: _selected,
              onChoose: _choose,
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 40),
              child: ConstrainedBox(
                // Centre the table when it fits the viewport; let it scroll
                // from the top once the columns outgrow the height (mobile).
                constraints: BoxConstraints(minHeight: c.maxHeight - 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PhysiqueBand(
                          physiqueId: state.character!.physiqueId,
                          affinity: affinity,
                        ),
                        const SizedBox(height: 28),
                        if (wide)
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: westCol),
                                Container(
                                  width: 1,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 28,
                                  ),
                                  color: hall.bone.withValues(alpha: 0.14),
                                ),
                                Expanded(child: eastCol),
                              ],
                            ),
                          )
                        else ...[
                          westCol,
                          const SizedBox(height: 26),
                          Container(
                            height: 1,
                            color: hall.bone.withValues(alpha: 0.14),
                          ),
                          const SizedBox(height: 26),
                          eastCol,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PhysiqueBand extends StatelessWidget {
  const _PhysiqueBand({required this.physiqueId, required this.affinity});
  final String physiqueId;
  final String affinity; // 'western' / 'eastern'

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final road = affinity == 'western' ? 'western' : 'eastern';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'YOUR PHYSIQUE',
          style: hall.label.copyWith(color: hall.boneDim, letterSpacing: 3),
        ),
        const SizedBox(height: 8),
        Text(
          _pretty(physiqueId).toUpperCase(),
          style: hall.displayLarge.copyWith(fontSize: 26, height: 1.05),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            'Bred for the $road road — its traditions answer your training '
            'in kind, at ×1.25. The other half answers slower, at ×0.85. '
            'Choose where your fighter stands.',
            style: hall.reading.copyWith(color: hall.boneDim, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _TraditionColumn extends StatelessWidget {
  const _TraditionColumn({
    required this.title,
    required this.styleIds,
    required this.matched,
    required this.tradition,
    required this.controller,
    required this.order,
    required this.selectedId,
    required this.onChoose,
  });

  final String title;
  final List<String> styleIds;
  final bool matched;
  final String tradition; // 'western' / 'eastern'
  final AnimationController controller;
  final int order; // 0 = enters first, 1 = enters second
  final String? selectedId;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final base = order == 0 ? 0.0 : 0.32;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                title.toUpperCase(),
                style: hall.heading.copyWith(
                  fontSize: 12.5,
                  letterSpacing: 2.4,
                ),
              ),
            ),
            if (matched) ...[
              const SizedBox(width: 8),
              Text(
                'FAVOURED',
                style: hall.label.copyWith(
                  color: hall.gold,
                  fontSize: 8.5,
                  letterSpacing: 2,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < styleIds.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _StylePlate(
            styleId: styleIds[i],
            matched: matched,
            tradition: tradition,
            selected: selectedId == styleIds[i],
            dimmed: selectedId != null && selectedId != styleIds[i],
            controller: controller,
            slot: base + i * 0.08,
            kindleSlot: 0.5 + i * 0.06,
            onTap: () => onChoose(styleIds[i]),
          ),
        ],
      ],
    );
  }
}

class _StylePlate extends StatelessWidget {
  const _StylePlate({
    required this.styleId,
    required this.matched,
    required this.tradition,
    required this.selected,
    required this.dimmed,
    required this.controller,
    required this.slot,
    required this.kindleSlot,
    required this.onTap,
  });

  final String styleId;
  final bool matched;
  final String tradition;
  final bool selected;
  final bool dimmed;
  final AnimationController controller;
  final double slot; // interval start for the rise/fade
  final double kindleSlot; // interval start for the one-time gold kindle
  final VoidCallback onTap;

  (String, String) get _entry => _styleBook[styleId] ?? (_pretty(styleId), '');

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final entry = _entry;
    // West leans ember, east leans cold steel — the hall's one organising
    // axis, carried in hue at near-constant value on the bone plate.
    final ground = Color.alphaBlend(
      (tradition == 'western' ? hall.westGround : hall.eastGround).withValues(
        alpha: tradition == 'western' ? 0.22 : 0.2,
      ),
      hall.bone,
    );
    final nameInk = hall.lacquerDeep;
    final bodyInk = hall.lacquerDeep.withValues(alpha: 0.72);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(
          ((controller.value - slot) / 0.5).clamp(0.0, 1.0),
        );
        final glow =
            matched
                ? math.sin(
                  (((controller.value - kindleSlot) / 0.34).clamp(0.0, 1.0)) *
                      math.pi,
                )
                : 0.0;
        return Opacity(
          opacity: (dimmed ? 0.45 : 1.0) * (t == 0 ? 0.0 : (0.08 + 0.92 * t)),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 9),
            child: _plate(context, hall, entry, ground, nameInk, bodyInk, glow),
          ),
        );
      },
    );
  }

  Widget _plate(
    BuildContext context,
    HallTheme hall,
    (String, String) entry,
    Color ground,
    Color nameInk,
    Color bodyInk,
    double glow,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        button: true,
        label: entry.$1,
        value:
            matched
                ? 'physique synergy, quantity one point two five'
                : 'physique mismatch, quantity zero point eight five',
        excludeSemantics: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: CustomPaint(
            painter: _PlatePainter(
              ground: ground,
              edgeTint: hall.lacquerDeep,
              selected: selected,
              matched: matched,
              glow: glow,
              gold: hall.gold,
              seed: styleId.hashCode,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 15, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.$1.toUpperCase(),
                          style: hall.display.copyWith(
                            color: nameInk,
                            fontSize: 16.5,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _SynergyBadge(matched: matched),
                    ],
                  ),
                  if (entry.$2.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Text(
                      entry.$2,
                      style: hall.body.copyWith(
                        color: bodyInk,
                        fontSize: 12.5,
                        height: 1.42,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The synergy badge — box + drawn mark carry the colour (gold when the
/// road matches the physique, slate when it does not); the quantity text
/// stays dark so it reads on the bone plate. Mark shape, not colour
/// alone, tells the two apart: point up for aligned, struck down for
/// opposed — the same hand as the frontispiece.
class _SynergyBadge extends StatelessWidget {
  const _SynergyBadge({required this.matched});
  final bool matched;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final mark = matched ? hall.gold : const Color(0xFF565B5E);
    final border =
        matched
            ? hall.gold.withValues(alpha: 0.8)
            : hall.slate.withValues(alpha: 0.6);
    final text =
        matched ? hall.lacquerDeep : hall.lacquerDeep.withValues(alpha: 0.64);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: border)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: const Size(10, 10),
            painter: _BadgeGlyph(color: mark, matched: matched),
          ),
          const SizedBox(width: 6),
          Text(
            matched ? '×1.25' : '×0.85',
            style: hall.measureStrong.copyWith(color: text, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _BadgeGlyph extends CustomPainter {
  _BadgeGlyph({required this.color, required this.matched});
  final Color color;
  final bool matched;

  @override
  void paint(Canvas canvas, Size size) {
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
        Paint()
          ..color = color
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_BadgeGlyph old) =>
      old.color != color || old.matched != matched;
}

class _PlatePainter extends CustomPainter {
  _PlatePainter({
    required this.ground,
    required this.edgeTint,
    required this.selected,
    required this.matched,
    required this.glow,
    required this.gold,
    required this.seed,
  });

  final Color ground;
  final Color edgeTint;
  final bool selected;
  final bool matched;
  final double glow; // 0..1, one-time kindle
  final Color gold;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(3);
    final path = handRect(r, radius: 3, seed: seed);

    // raking shadow, cast away from the hall's one light
    canvas.save();
    canvas.translate(3.6, 4.6);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.restore();

    // plate fill
    canvas.drawPath(path, Paint()..color = ground);

    canvas.save();
    canvas.clipPath(path);
    // one raking source: top-left lifts, bottom-right sinks
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: kRakingLight,
          end: -kRakingLight,
          colors: [
            Colors.white.withValues(alpha: 0.14),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.10),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(r),
    );
    // matched plates carry a low resting gold wash; selection lifts it,
    // and the kindle blooms it once on entry.
    if (matched || selected) {
      final a = selected ? 0.20 : (0.045 + 0.24 * glow);
      canvas.drawRect(
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            r.topLeft + Offset(r.width * 0.16, r.height * 0.16),
            r.longestSide * 0.95,
            [gold.withValues(alpha: a), gold.withValues(alpha: 0)],
          ),
      );
    }
    canvas.restore();

    // carved edge
    final Color edgeColor;
    double edgeWidth;
    if (selected) {
      edgeColor = gold.withValues(alpha: 0.9);
      edgeWidth = 2.6;
    } else if (matched) {
      edgeColor = gold.withValues(alpha: 0.5 + 0.4 * glow);
      edgeWidth = 1.6;
    } else {
      edgeColor = edgeTint.withValues(alpha: 0.45);
      edgeWidth = 1.6;
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = edgeWidth
        ..color = edgeColor,
    );
  }

  @override
  bool shouldRepaint(_PlatePainter old) =>
      old.ground != ground ||
      old.selected != selected ||
      old.matched != matched ||
      old.glow != glow;
}

String _pretty(String id) => id
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
