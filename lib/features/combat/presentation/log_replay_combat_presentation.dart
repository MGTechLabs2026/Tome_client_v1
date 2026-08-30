// lib/features/combat/presentation/log_replay_combat_presentation.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/combat_log_entry_view.dart';
import 'combat_presentation.dart';

class LogReplayCombatPresentation extends CombatPresentation {
  const LogReplayCombatPresentation({super.key, required this.log, required this.onFinished});
  final List<CombatLogEntryView> log;
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) => _Replay(log: log, onFinished: onFinished);
}

class _Replay extends StatefulWidget {
  const _Replay({required this.log, required this.onFinished});
  final List<CombatLogEntryView> log;
  final VoidCallback onFinished;

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

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const Text('PLAYER  vs  ENEMY'),
      Expanded(
        child: ListView(
          children: [for (final entry in widget.log.take(_shown)) Text(entry.text)],
        ),
      ),
    ]);
  }
}
