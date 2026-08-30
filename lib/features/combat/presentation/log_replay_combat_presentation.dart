// lib/features/combat/presentation/log_replay_combat_presentation.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/combat_log_entry_view.dart';
import '../../tome/hall/hall_theme.dart';
import 'combat_presentation.dart';

class LogReplayCombatPresentation extends CombatPresentation {
  const LogReplayCombatPresentation({
    super.key,
    required this.log,
    required this.onFinished,
    required this.playerName,
    required this.enemyName,
  });

  final List<CombatLogEntryView> log;
  final VoidCallback onFinished;
  final String playerName;
  final String enemyName;

  @override
  Widget build(BuildContext context) => _Replay(
        log: log,
        onFinished: onFinished,
        playerName: playerName,
        enemyName: enemyName,
      );
}

class _Replay extends StatefulWidget {
  const _Replay({
    required this.log,
    required this.onFinished,
    required this.playerName,
    required this.enemyName,
  });

  final List<CombatLogEntryView> log;
  final VoidCallback onFinished;
  final String playerName;
  final String enemyName;

  @override
  State<_Replay> createState() => _ReplayState();
}

class _ReplayState extends State<_Replay> {
  var _shown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      setState(() => _shown++);
      if (_shown >= widget.log.length) {
        timer.cancel();
        widget.onFinished();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// The most recent entry that carried a health snapshot — the source
  /// of truth for both bars at the current point in the replay.
  CombatLogEntryView? get _vitals {
    for (var i = _shown - 1; i >= 0; i--) {
      final e = widget.log[i];
      if (e.playerHp != null || e.enemyHp != null) return e;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final vitals = _vitals;
    final shown = widget.log.take(_shown).toList();

    return Container(
      color: hall.lacquer,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),
            // Title — centred.
            Text(
              'COMBAT',
              textAlign: TextAlign.center,
              style: hall.heading.copyWith(letterSpacing: 4),
            ),
            const SizedBox(height: 7),
            // Name — centred.
            Text(
              '${widget.playerName.isEmpty ? 'You' : widget.playerName}'
              '   vs   ${widget.enemyName}',
              textAlign: TextAlign.center,
              style: hall.label.copyWith(color: hall.boneDim),
            ),
            const SizedBox(height: 24),
            // Player bar left, enemy bar right.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _HpBar(
                      name: widget.playerName.isEmpty
                          ? 'You'
                          : widget.playerName,
                      hp: vitals?.playerHp,
                      hpMax: vitals?.playerHpMax,
                      alignEnd: false,
                    ),
                  ),
                  const SizedBox(width: 44),
                  Expanded(
                    child: _HpBar(
                      name: widget.enemyName,
                      hp: vitals?.enemyHp,
                      hpMax: vitals?.enemyHpMax,
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 30),
              color: hall.bone.withValues(alpha: 0.12),
            ),
            // Fighting action text — centred, latest line at the bottom.
            Expanded(
              child: ListView(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(30, 20, 30, 24),
                children: [
                  for (final e in shown.reversed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Text(
                        e.text,
                        textAlign: TextAlign.center,
                        style: _styleFor(hall, e.kind),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _styleFor(HallTheme hall, CombatLogEntryKind kind) => switch (kind) {
        CombatLogEntryKind.turnStart =>
          hall.label.copyWith(color: hall.boneDim, letterSpacing: 2.4),
        CombatLogEntryKind.damage => hall.body.copyWith(color: hall.vermilion),
        CombatLogEntryKind.heal => hall.body.copyWith(color: hall.bone),
        CombatLogEntryKind.actionResolved => hall.body,
        CombatLogEntryKind.victory =>
          hall.display.copyWith(color: hall.bone, fontSize: 20),
        CombatLogEntryKind.defeat =>
          hall.display.copyWith(color: hall.slate, fontSize: 20),
      };
}

/// A single fighter's health bar. [alignEnd] mirrors it — label,
/// numerals and fill all sit to the right and the fill drains from the
/// centre outward — so the player reads left and the enemy reads right.
class _HpBar extends StatelessWidget {
  const _HpBar({
    required this.name,
    required this.hp,
    required this.hpMax,
    required this.alignEnd,
  });

  final String name;
  final num? hp;
  final num? hpMax;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final max = (hpMax ?? 0).toDouble();
    final cur = (hp ?? hpMax ?? 0).toDouble();
    final frac = max <= 0 ? 1.0 : (cur / max).clamp(0.0, 1.0);
    final cross =
        alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: cross,
      children: [
        Text(name.toUpperCase(), style: hall.label),
        const SizedBox(height: 6),
        ClipRect(
          child: Container(
            height: 8,
            color: hall.bone.withValues(alpha: 0.14),
            child: Align(
              alignment:
                  alignEnd ? Alignment.centerRight : Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: frac,
                child: Container(
                  color: frac <= 0 ? hall.slate : hall.vermilion,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          hp == null || hpMax == null
              ? '—'
              : '${cur.round()} / ${max.round()}',
          style: hall.measure,
        ),
      ],
    );
  }
}
