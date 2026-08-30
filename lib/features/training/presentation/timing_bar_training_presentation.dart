// lib/features/training/presentation/timing_bar_training_presentation.dart
import 'dart:async';

import 'package:flutter/material.dart';

import 'training_presentation.dart';

class TimingBarTrainingPresentation extends TrainingPresentation {
  const TimingBarTrainingPresentation({
    super.key,
    required this.onTap,
    this.windowStartMs = 100,
    this.windowEndMs = 200,
  });

  final void Function(double timestampMs) onTap;
  final double windowStartMs;
  final double windowEndMs;

  @override
  Widget build(BuildContext context) {
    return _TimingBar(onTap: onTap, windowStartMs: windowStartMs, windowEndMs: windowEndMs);
  }
}

class _TimingBar extends StatefulWidget {
  const _TimingBar({required this.onTap, required this.windowStartMs, required this.windowEndMs});
  final void Function(double timestampMs) onTap;
  final double windowStartMs;
  final double windowEndMs;

  @override
  State<_TimingBar> createState() => _TimingBarState();
}

class _TimingBarState extends State<_TimingBar> {
  final _stopwatch = Stopwatch()..start();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = (_stopwatch.elapsedMilliseconds % 300).toDouble();
    return GestureDetector(
      onTap: () => widget.onTap(elapsed),
      child: Container(
        height: 48,
        color: Colors.black26,
        child: Stack(children: [
          Positioned(
            left: widget.windowStartMs,
            width: widget.windowEndMs - widget.windowStartMs,
            top: 0,
            bottom: 0,
            child: Container(color: Colors.greenAccent.withValues(alpha: 0.4)),
          ),
          Positioned(
            left: elapsed,
            top: 0,
            bottom: 0,
            width: 2,
            child: Container(color: Colors.white),
          ),
        ]),
      ),
    );
  }
}
