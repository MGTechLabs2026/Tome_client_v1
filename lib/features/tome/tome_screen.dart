// lib/features/tome/tome_screen.dart
//
// ─────────────────────────────────────────────────────────────────────
// DIRECTION CONTRACT · "The Lineage Hall" · seed 6f69b7e6 · code-led
//
// THESIS: The build is a lineage hall — a graded rack of mounted forms,
// the cords between related pieces, and the descent that produced each
// one. It refuses the neon-glass build screen and the monochrome data
// grid alike.
//
// OWN-WORLD: Lacquered near-black board (#141013); aged bone mounts
// (#E7DDCA); vermilion seal-ink (#B23A2E) for live cords, chops, and the
// strike-mark; tarnished gold (#B8933F) reserved only for mastered; cold
// slate for dead/slack. One raking light from the upper-left models
// every element. Carved Roman display (Cinzel); quiet grotesque readouts
// (Archivo); a monospace measurement hand (Spline Sans Mono) for
// leader-line quantities. Every mark — seal, rank ring, cord, control —
// is one ink hand; no stock widgets.
//
// STORY: The player reads which forms combine, what evolved from what,
// and which tradition matches their physique at a glance; trusts that
// every state is real engine truth; places, combines, spends points,
// then commits to the fight.
//
// FIRST VIEWPORT: The rack fills a pannable coordinate lattice under the
// raking light; west traditions hang left, east right, across a
// ground-and-light gradient that is the one axis that never collapses.
// Desktop: board centre, frontispiece rail right, loose rack and foot
// bar below. Phone: frontispiece a top rule, board fills, loose rack a
// bottom drawer, Start Fight at the foot.
//
// FORM: "The Lineage Hall" — grounded candidate #3 of the ordered list,
// assigned by the roll. Seed key 6f69b7e6.
//
// FINISH: unreviewed and undocumented is unfinished; this build ends
// with the finish review, the verdict, DESIGN.md, and every shipping
// raster carrying its provenance.
// ─────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/models/game_phase.dart';
import '../../core/models/grid_cell_view.dart';
import '../../core/models/item_view.dart';
import '../../core/models/technique_view.dart';
import '../run/run_bloc.dart';
import '../run/run_event.dart';
import 'hall/board_drag.dart';
import 'hall/combine_reveal.dart';
import 'hall/first_run_callout.dart';
import 'hall/frontispiece.dart';
import 'hall/hall_controls.dart';
import 'hall/hall_theme.dart';
import 'hall/lineage_board.dart';
import 'tome_bloc.dart';
import 'tome_event.dart';
import 'widgets/combine_confirmation_sheet.dart';
import 'widgets/component_detail_sheet.dart';
import 'widgets/component_tray.dart';

class TomeScreen extends StatefulWidget {
  const TomeScreen({super.key});

  @override
  State<TomeScreen> createState() => _TomeScreenState();
}

class _TomeScreenState extends State<TomeScreen> {
  String? _selectedSlotId;
  TomeDrag? _armed;
  int _revealSeq = 0;

  @override
  void initState() {
    super.initState();
    context.read<TomeBloc>().add(const TomeRefreshRequested());
  }

  bool get _reduceMotion => MediaQuery.of(context).disableAnimations;

  void _drop(TomeDrag drag, String toSlotId) {
    final bloc = context.read<TomeBloc>();
    if (drag.isMove) {
      bloc.add(ComponentMoved(drag.fromSlotId!, toSlotId));
    } else if (drag.isTechnique) {
      bloc.add(
        ComponentInserted(
          definitionId: drag.definitionId!,
          slotId: toSlotId,
          isTechnique: true,
        ),
      );
    } else {
      bloc.add(
        ComponentInserted(
          definitionId: drag.definitionId!,
          slotId: toSlotId,
          isTechnique: false,
          instanceEntityValue: drag.instanceEntityValue,
        ),
      );
    }
    setState(() => _armed = null);
  }

  void _cellTapped(String slotId, TomeState state) {
    final cell = state.cells.firstWhere((c) => c.slotId == slotId);
    if (cell.isEmpty) {
      if (_armed != null) {
        _drop(_armed!, slotId);
      } else {
        setState(() => _selectedSlotId = null);
      }
      return;
    }
    setState(() => _selectedSlotId = slotId);
    final occ = cell.occupant!;
    if (occ.kind == GridComponentKind.technique) {
      final t = state.techniquesByContentId[occ.contentId];
      if (t != null) _openTechniqueDetail(t, state);
    } else {
      final v = state.ownedByInstanceValue[occ.instanceEntityValue];
      if (v != null) _openItemDetail(v, state);
    }
  }

  void _openItemDetail(ItemView item, TomeState state) {
    final run = context.read<RunBloc>();
    final placed = state.cells.any(
      (c) => c.occupant?.instanceEntityValue == item.instanceEntityValue,
    );
    showComponentDetail(
      context,
      item: item,
      onTrain:
          () =>
              run.add(TrainingRequested(item.definitionId, isTechnique: false)),
      onUpgrade:
          state.upgradePoints > 0
              ? () => Navigator.of(context).maybePop()
              : null,
      onCombine:
          item.combinableWith.isEmpty
              ? null
              : () {
                Navigator.of(context).pop();
                _confirmCombine(item, state);
              },
      onHang:
          placed
              ? null
              : () {
                Navigator.of(context).pop();
                setState(
                  () =>
                      _armed =
                          item.instanceEntityValue == null
                              ? null
                              : TomeDrag.rackItem(
                                item.definitionId,
                                item.instanceEntityValue!,
                              ),
                );
              },
    );
  }

  void _openTechniqueDetail(TechniqueView t, TomeState state) {
    final run = context.read<RunBloc>();
    final placed =
        !state.trayTechniques.any((x) => x.definitionId == t.definitionId);
    // Build the accumulated lineage chain from evolvedFromId hops.
    final chain = <String>[];
    var cur = t;
    final guard = <String>{};
    while (cur.evolvedFromId != null && guard.add(cur.definitionId)) {
      chain.insert(0, cur.evolvedFromId!);
      final parent = state.techniquesByContentId[cur.evolvedFromId!];
      if (parent == null) break;
      cur = parent;
    }
    chain.add(t.definitionId);
    showComponentDetail(
      context,
      technique: t,
      lineage: chain,
      onTrain:
          () => run.add(TrainingRequested(t.definitionId, isTechnique: true)),
      onHang:
          placed
              ? null
              : () {
                Navigator.of(context).pop();
                setState(() => _armed = TomeDrag.rackTechnique(t.definitionId));
              },
    );
  }

  void _confirmCombine(ItemView item, TomeState state) {
    final matched = <ItemView>[
      item,
      for (final v in item.combinableWith)
        if (state.ownedByInstanceValue[v] != null)
          state.ownedByInstanceValue[v]!,
    ];
    final values = <int>[
      if (item.instanceEntityValue != null) item.instanceEntityValue!,
      ...item.combinableWith,
    ];
    final bloc = context.read<TomeBloc>();
    showCombineConfirmation(
      context,
      matched: matched,
      onConfirm: () => bloc.add(CombineRequested(values)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Scaffold(
      backgroundColor: hall.lacquerDeep,
      body: BlocConsumer<TomeBloc, TomeState>(
        listenWhen:
            (a, b) => (b.lastCombine?.seq ?? 0) != (a.lastCombine?.seq ?? 0),
        listener: (context, state) {
          setState(() => _revealSeq = state.lastCombine!.seq);
        },
        builder: (context, state) {
          final wide = MediaQuery.of(context).size.width >= 760;
          final board = LineageBoard(
            cells: state.cells,
            width: state.width,
            height: state.height,
            ownedByInstanceValue: state.ownedByInstanceValue,
            spotlight: state.spotlightInstanceValues,
            selectedSlotId: _selectedSlotId,
            armed: _armed != null,
            reduceMotion: _reduceMotion,
            cellSize: wide ? 132 : 108,
            onSelect: (slot) => setState(() => _selectedSlotId = slot),
            onDrop: _drop,
            onCellTapped: (slot) => _cellTapped(slot, state),
          );

          final rack = LooseRack(
            items: state.tray,
            techniques: state.trayTechniques,
            spotlight: state.spotlightInstanceValues,
            height: wide ? 132 : 120,
            onItemTap: (i) => _openItemDetail(i, state),
            onTechniqueTap: (t) => _openTechniqueDetail(t, state),
          );

          final run = context.read<RunBloc>().state;
          final foot = _FootBar(
            upgradePoints: state.upgradePoints,
            runLabel: 'RUN ${run.runNumber}  ·  BOUT ${run.fightIndex + 1} / '
                '${run.fightsInCurrentRun}',
            armedHint: _armed != null,
            canTrain: _selectedSlotId != null,
            onCancelArm: () => setState(() => _armed = null),
            onTrainSelected: () {
              final cell = state.cells.firstWhere(
                (c) => c.slotId == _selectedSlotId,
              );
              final occ = cell.occupant;
              if (occ == null) return;
              context.read<RunBloc>().add(
                TrainingRequested(
                  occ.contentId,
                  isTechnique: occ.kind == GridComponentKind.technique,
                ),
              );
            },
            onStartFight: () => context
                .read<RunBloc>()
                .add(const PhaseCompleted(GamePhase.combatPreparation)),
          );

          final content =
              wide
                  ? Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: board),
                            SizedBox(
                              width: 320,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: hall.lacquer,
                                  border: Border(
                                    left: BorderSide(
                                      color: hall.bone.withValues(alpha: 0.16),
                                    ),
                                  ),
                                ),
                                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                                child: SingleChildScrollView(
                                  child: Frontispiece(
                                    character: state.character,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      rack,
                      foot,
                    ],
                  )
                  : Column(
                    children: [
                      Frontispiece(character: state.character, compact: true),
                      Expanded(child: board),
                      rack,
                      foot,
                    ],
                  );

          return SafeArea(
            child: Stack(
              children: [
                Positioned.fill(child: content),
                if (state.showFirstRunCallout && _armed == null)
                  Positioned(
                    top: wide ? 12 : 74,
                    left: 0,
                    right: wide ? 312 : 0,
                    child: FirstRunCallout(
                      onDismiss:
                          () => context.read<TomeBloc>().add(
                            const FirstRunCalloutDismissed(),
                          ),
                    ),
                  ),
                if (state.lastCombine != null &&
                    state.lastCombine!.seq == _revealSeq)
                  CombineRevealOverlay(
                    key: ValueKey(_revealSeq),
                    kind: state.lastCombine!.kind,
                    resultName: state.lastCombine!.resultName,
                    resultClass: state.lastCombine!.resultClass,
                    reduceMotion: _reduceMotion,
                    onDone: () => setState(() => _revealSeq = 0),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FootBar extends StatelessWidget {
  const _FootBar({
    required this.upgradePoints,
    required this.runLabel,
    required this.armedHint,
    required this.canTrain,
    required this.onCancelArm,
    required this.onTrainSelected,
    required this.onStartFight,
  });

  final int upgradePoints;
  final String runLabel;
  final bool armedHint;
  final bool canTrain;
  final VoidCallback onCancelArm;
  final VoidCallback onTrainSelected;
  final VoidCallback onStartFight;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Container(
      decoration: BoxDecoration(
        color: hall.lacquer,
        border: Border(
          top: BorderSide(color: hall.bone.withValues(alpha: 0.16)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        children: [
          CustomPaint(
            size: const Size(15, 15),
            painter: HammerGlyph(
              color: upgradePoints > 0 ? hall.bone : hall.boneDim,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$upgradePoints',
            style: hall.measureStrong.copyWith(
              color: upgradePoints > 0 ? hall.bone : hall.boneDim,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 4),
          Text('PTS', style: hall.label.copyWith(fontSize: 9)),
          const SizedBox(width: 18),
          Text(runLabel, style: hall.label.copyWith(fontSize: 9)),
          const Spacer(),
          if (armedHint) ...[
            Flexible(
              child: Text(
                'tap an open mount to hang it',
                overflow: TextOverflow.ellipsis,
                style: hall.measure.copyWith(fontSize: 10.5),
              ),
            ),
            const SizedBox(width: 10),
            InkButton(
              label: 'Cancel',
              tone: InkTone.quiet,
              dense: true,
              onPressed: onCancelArm,
            ),
          ] else ...[
            InkButton(
              label: 'Train',
              dense: true,
              onPressed: canTrain ? onTrainSelected : null,
            ),
          ],
          const SizedBox(width: 10),
          InkButton(
            key: const Key('startFightButton'),
            label: 'Start Fight',
            tone: InkTone.seal,
            onPressed: onStartFight,
          ),
        ],
      ),
    );
  }
}
