// lib/features/title/settings_screen.dart
//
// SETTINGS — one real switch at v0.0.1. Reduce motion is persisted and
// fed into MediaQuery, so turning it on collapses the surface's
// decorative animation everywhere.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/persistence/settings_repository.dart';
import '../tome/hall/hall_theme.dart';
import 'threshold_page.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    final settings = context.read<SettingsRepository>();

    return ThresholdPage(
      heading: 'Settings',
      maxWidth: 420,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: settings.reduceMotion,
            builder: (context, on, _) => _Toggle(
              label: 'Reduce motion',
              note: 'Collapse the panel and reveal animations.',
              value: on,
              onChanged: settings.setReduceMotion,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'More settings — audio, text size — arrive as the game fills out.',
            style: hall.reading.copyWith(color: hall.boneDim),
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.note,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String note;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: hall.body),
                const SizedBox(height: 3),
                Text(
                  note,
                  style: hall.measure.copyWith(
                    fontSize: 11,
                    color: hall.boneDim,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _Switch(value: value),
        ],
      ),
    );
  }
}

/// A drawn two-state switch — a bone rail with a vermilion stone that
/// slides to the lit end. No Material Switch in the surface.
class _Switch extends StatelessWidget {
  const _Switch({required this.value});
  final bool value;

  @override
  Widget build(BuildContext context) {
    final hall = context.hall;
    return Container(
      width: 44,
      height: 20,
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(
          color: hall.bone.withValues(alpha: value ? 0.5 : 0.22),
        ),
      ),
      child: Container(
        width: 16,
        height: 16,
        color: value ? hall.vermilion : hall.boneDim.withValues(alpha: 0.5),
      ),
    );
  }
}
